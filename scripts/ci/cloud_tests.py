"""Runs the Jest suite of a built test place in Roblox's cloud (Open Cloud Luau Execution) and fails unless every test
passed.

Usage: python scripts/ci/cloud_tests.py <place.rbxl> <task.luau>
Environment: ROBLOX_API_KEY (a secret), ROBLOX_TEST_UNIVERSE_ID and ROBLOX_TEST_PLACE_ID (set up once with
scripts/ci/setup-cloud-tests.sh).

1. Uploads the place as a Saved version of the test place (saved, not published).
2. Runs the task script against that exact version, so runs from different branches never test each other's code.
3. Waits while the task is QUEUED or PROCESSING, then prints its logs.
4. Passes only when the task is COMPLETE and its result is RunTests' summary with success, no failed test or suite,
   more than zero tests, and every test passed (a stray `it.only` or `it.skip` leaves some unrun).

The endpoints, states and limits are Roblox's (create.roblox.com/docs: cloud/reference/features/luau-execution and
cloud/reference/features/places). Standard library only.
"""

import http.client
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from pathlib import Path
from typing import TextIO
from urllib.parse import urlencode, urlsplit

API = "https://apis.roblox.com"
# Seconds between polls of a waiting task (Roblox's own place-ci-cd-demo polls every 3).
POLL_SECONDS = 3
# The task's own limit: Roblox's maximum, 5 minutes.
TASK_TIMEOUT = "300s"
# How long after creating the task the client gives up: the task's 5 minutes plus time spent queued.
DEADLINE_SECONDS = 600
# Waits before each retry of a rate-limited (429), failing (5xx) or dropped request, unless Roblox says how long
# (Retry-After, else x-ratelimit-reset). Without them Roblox's rate-limit page asks for exponential backoff; these
# add up to 155 s, past a second one-minute window of its 5-task-creations-a-minute limit.
RETRY_SECONDS = (5, 10, 20, 40, 80)
# Seconds a single request may take.
REQUEST_SECONDS = 60
WAITING = {"QUEUED", "PROCESSING"}
SETUP_SCRIPT = "scripts/ci/setup-cloud-tests.sh"
ANSI = re.compile(r"\x1b\[[0-9;]*m")


class SetupError(Exception):
    """A setting is missing or malformed; the message names every one."""


class CloudError(Exception):
    """Roblox rejected a request, or the task did not finish. The message never holds the API key."""


@dataclass(frozen=True)
class Settings:
    api_key: str
    universe_id: str
    place_id: str


def settings_from(env: Mapping[str, str]) -> Settings:
    problems = []
    api_key = env.get("ROBLOX_API_KEY", "").strip()
    if api_key == "":
        problems.append("ROBLOX_API_KEY (repository secret) is not set")
    ids = {}
    for name in ("ROBLOX_TEST_UNIVERSE_ID", "ROBLOX_TEST_PLACE_ID"):
        value = env.get(name, "").strip()
        if value == "":
            problems.append(f"{name} (repository variable) is not set")
        elif not value.isdigit():
            problems.append(f"{name} must be a number, got {value!r}")
        ids[name] = value
    if problems:
        raise SetupError(
            "; ".join(problems)
            + f". Run {SETUP_SCRIPT} to set them up. Pull requests from forks get no secrets, so they cannot run "
            "the cloud tests."
        )
    return Settings(api_key, ids["ROBLOX_TEST_UNIVERSE_ID"], ids["ROBLOX_TEST_PLACE_ID"])


class Client:
    """Roblox's Open Cloud, through one opener (urllib's, or a fake in tests)."""

    def __init__(
        self,
        api_key: str,
        opener: Callable = urllib.request.urlopen,
        sleep: Callable[[float], None] = time.sleep,
        clock: Callable[[], float] = time.monotonic,
    ):
        self._api_key = api_key
        self._opener = opener
        self._sleep = sleep
        self._clock = clock

    def _request(self, method: str, url: str, body: bytes | None = None, content_type: str | None = None) -> dict:
        """Sends a request and returns its JSON body, retrying a 429, a 5xx or a dropped connection."""
        path = urlsplit(url).path
        for attempt in range(len(RETRY_SECONDS) + 1):
            request = urllib.request.Request(url, data=body, method=method)
            request.add_header("x-api-key", self._api_key)
            request.add_header("Accept", "application/json")
            if content_type is not None:
                request.add_header("Content-Type", content_type)
            try:
                with self._opener(request, timeout=REQUEST_SECONDS) as response:
                    return json.loads(response.read() or b"{}")
            except urllib.error.HTTPError as error:
                with error:
                    detail = error.read().decode("utf-8", "replace")[:500]
                retryable = error.code == 429 or error.code >= 500
                if not retryable or attempt == len(RETRY_SECONDS):
                    raise CloudError(f"{method} {path} failed: HTTP {error.code}: {detail}") from None
                wait = _retry_after(error.headers) or RETRY_SECONDS[attempt]
            except (OSError, http.client.HTTPException) as error:
                # A dropped connection. urllib wraps an error while sending in a URLError, but raises one while
                # reading the answer as it is (RemoteDisconnected, TimeoutError, IncompleteRead).
                if attempt == len(RETRY_SECONDS):
                    raise CloudError(f"{method} {path} failed: {getattr(error, 'reason', error)}") from None
                wait = RETRY_SECONDS[attempt]
            except json.JSONDecodeError:
                raise CloudError(f"{method} {path} answered with a body that is not JSON") from None
            self._sleep(wait)
        raise AssertionError("unreachable")

    def upload_place(self, universe_id: str, place_id: str, place: bytes) -> int:
        url = f"{API}/universes/v1/{universe_id}/places/{place_id}/versions?versionType=Saved"
        answer = self._request("POST", url, place, "application/octet-stream")
        # The publishing guide shows a number; the API reference calls it a string.
        version = answer.get("versionNumber")
        if isinstance(version, str) and version.isdigit():
            version = int(version)
        if not isinstance(version, int):
            raise CloudError(f"the upload answered without a version number: {answer}")
        return version

    def create_task(self, universe_id: str, place_id: str, version: int, script: str) -> dict:
        version_path = f"universes/{universe_id}/places/{place_id}/versions/{version}"
        url = f"{API}/cloud/v2/{version_path}/luau-execution-session-tasks"
        body = json.dumps({"script": script, "timeout": TASK_TIMEOUT}).encode()
        return _named(self._request("POST", url, body, "application/json"))

    def wait(self, task: dict) -> dict:
        """Polls the task every POLL_SECONDS while it is QUEUED or PROCESSING, until DEADLINE_SECONDS have passed."""
        started = self._clock()
        while True:
            task = _named(self._request("GET", f"{API}/cloud/v2/{task['path']}"))
            if task.get("state") not in WAITING:
                return task
            if self._clock() - started >= DEADLINE_SECONDS:
                raise CloudError(f"the task was still {task.get('state')} after the {DEADLINE_SECONDS} s deadline")
            self._sleep(POLL_SECONDS)

    def logs(self, task: dict) -> list[str]:
        """Every message the task logged, over every page."""
        messages, token = [], None
        while True:
            url = f"{API}/cloud/v2/{task['path']}/logs"
            if token:
                url += "?" + urlencode({"pageToken": token})
            page = self._request("GET", url)
            for chunk in page.get("luauExecutionSessionTaskLogs", []):
                messages.extend(chunk.get("messages", []))
            token = page.get("nextPageToken")
            if not token:
                return messages


def _named(task: dict) -> dict:
    """The task Roblox answered with, once it names its path: every later request about it is made on that path."""
    if not isinstance(task.get("path"), str) or task["path"] == "":
        raise CloudError(f"Roblox answered with a task without a path: {task}")
    return task


def _retry_after(headers) -> float | None:
    """Seconds Roblox asks a rate-limited client to wait: Retry-After, else x-ratelimit-reset (until its quota resets).
    None when it sends neither."""
    if headers is None:
        return None
    for name in ("Retry-After", "x-ratelimit-reset"):
        value = headers.get(name)
        try:
            if value is not None:
                return float(value)
        except ValueError:
            continue
    return None


def print_logs(client: Client, task: dict, out: TextIO):
    """Prints the task's logs; a failure to read them is printed too, without hiding the run's own result."""
    print("--- task logs ---", file=out)
    try:
        for message in client.logs(task):
            print(message, file=out)
    except CloudError as error:
        print(f"(the logs could not be read: {error})", file=out)
    print("--- end of logs ---", file=out)


def verdict(task: dict) -> tuple[bool, str]:
    """Whether the finished task ran every test green, and a line saying so (with the failures, colour removed)."""
    state = task.get("state")
    if state == "FAILED":
        error = task.get("error") or {}
        return False, f"the task failed: {error.get('code')}: {error.get('message')}"
    if state != "COMPLETE":
        return False, f"the task ended {state}"
    results = (task.get("output") or {}).get("results")
    summary = results[0] if isinstance(results, list) and results and isinstance(results[0], dict) else None
    if summary is None:
        return False, f"the task returned no test summary: {results!r}"
    total, passed = summary.get("numTotalTests"), summary.get("numPassedTests")
    green = (
        summary.get("success") is True
        and summary.get("numFailedTests") == 0
        and summary.get("numFailedTestSuites") == 0
        and isinstance(total, int)
        and total > 0
    )
    line = f"{passed}/{total} tests passed"
    if green and passed != total:
        return False, f"{line}: the others were skipped (an `it.only` or `it.skip`?)"
    if green:
        return True, line
    failures = "\n".join(ANSI.sub("", str(message)) for message in summary.get("failureMessages") or [])
    return False, f"{line}\n{failures}".rstrip()


def main(argv: list[str], env: Mapping[str, str], out: TextIO, client_factory: Callable = Client) -> int:
    if len(argv) != 2:
        print("usage: cloud_tests.py <place.rbxl> <task.luau>", file=out)
        return 1
    try:
        settings = settings_from(env)
        place, script = Path(argv[0]).read_bytes(), Path(argv[1]).read_text(encoding="utf-8")
        client = client_factory(settings.api_key)
        version = client.upload_place(settings.universe_id, settings.place_id, place)
        print(f"Uploaded the test place as version {version}.", file=out)
        task = client.create_task(settings.universe_id, settings.place_id, version, script)
        try:
            task = client.wait(task)
        finally:
            print_logs(client, task, out)
    except (SetupError, CloudError) as error:
        print(f"::error::Cloud tests: {error}", file=out)
        return 1
    green, line = verdict(task)
    if green:
        print(f"Cloud tests passed: {line}", file=out)
        return 0
    print(f"::error::Cloud tests failed: {line}", file=out)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:], os.environ, sys.stdout))
