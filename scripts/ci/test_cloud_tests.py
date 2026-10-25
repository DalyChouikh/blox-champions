"""Unit tests for cloud_tests.py. A fake opener plays Roblox's Open Cloud API and a fake clock drives the waits, so
nothing touches the network. Run: python -m unittest discover -s scripts/ci -p "test_*.py"."""

import http.client
import io
import json
import tempfile
import unittest
import urllib.error
from pathlib import Path
from urllib.parse import urlsplit

import cloud_tests

KEY = "secret-key-value"
ENV = {"ROBLOX_API_KEY": KEY, "ROBLOX_TEST_UNIVERSE_ID": "1", "ROBLOX_TEST_PLACE_ID": "2"}
TASK_PATH = "universes/1/places/2/versions/7/luau-execution-sessions/s/tasks/t"


def summary(**overrides):
    """RunTests' summary of a green run of 658 tests, with `overrides`."""
    fields = {
        "success": True,
        "numTotalTests": 658,
        "numPassedTests": 658,
        "numFailedTests": 0,
        "numFailedTestSuites": 0,
        "failureMessages": [],
    }
    fields.update(overrides)
    return fields


def task(state, results=None, error=None):
    body = {"path": TASK_PATH, "state": state}
    if results is not None:
        body["output"] = {"results": results}
    if error is not None:
        body["error"] = error
    return body


class Response:
    """What urlopen returns: a context manager with the body, the status and the headers."""

    def __init__(self, body, status=200):
        self._body = json.dumps(body).encode()
        self.status = status
        self.headers = {}

    def read(self):
        return self._body

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False


def ok(body):
    return lambda request: Response(body)


def fails(status, body, headers=None):
    def reply(request):
        raise urllib.error.HTTPError(
            request.full_url, status, "error", headers or {}, io.BytesIO(json.dumps(body).encode())
        )

    return reply


def drops(error):
    """A reply that loses the connection with `error`, as urllib raises it: wrapped in a URLError while the request
    is sent, raw (RemoteDisconnected, TimeoutError) while the answer is read."""

    def reply(request):
        raise error

    return reply


class Cloud:
    """Answers each request from routes of (method, path ending, query or None, reply, repeats), first match first.
    A route is used once unless it repeats. Every request is recorded."""

    def __init__(self, routes):
        self.routes = list(routes)
        self.requests = []

    def __call__(self, request, timeout=None):
        self.requests.append(request)
        url = urlsplit(request.full_url)
        for index, (method, ending, query, reply, repeats) in enumerate(self.routes):
            if request.get_method() == method and url.path.endswith(ending) and (query is None or url.query == query):
                if not repeats:
                    del self.routes[index]
                return reply(request)
        raise AssertionError(f"unexpected {request.get_method()} {request.full_url}")

    def count(self, method, ending):
        return sum(1 for r in self.requests if r.get_method() == method and urlsplit(r.full_url).path.endswith(ending))


def route(method, ending, reply, query=None, repeats=False):
    return (method, ending, query, reply, repeats)


UPLOAD = "/universes/v1/1/places/2/versions"
CREATE = "/cloud/v2/universes/1/places/2/versions/7/luau-execution-session-tasks"
POLL = "/cloud/v2/" + TASK_PATH
LOGS = POLL + "/logs"


def green_routes(final=None, logs=None):
    """A run that uploads version 7, creates the task, finds it `final` (default: COMPLETE with a green summary) and
    reads `logs`."""
    return [
        route("POST", UPLOAD, ok({"versionNumber": 7})),
        route("POST", CREATE, ok(task("QUEUED"))),
        route("GET", POLL, ok(final or task("COMPLETE", [summary()]))),
        route("GET", LOGS, ok(logs or {"luauExecutionSessionTaskLogs": [{"messages": ["[RunTests] PASS"]}]})),
    ]


class Clock:
    """A clock that only moves when the client sleeps."""

    def __init__(self):
        self.now = 0.0
        self.sleeps = []

    def sleep(self, seconds):
        self.sleeps.append(seconds)
        self.now += seconds

    def __call__(self):
        return self.now


class CloudTests(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.place = Path(folder.name) / "test.rbxl"
        self.place.write_bytes(b"place bytes")
        self.script = Path(folder.name) / "task.luau"
        self.script.write_bytes(b"return 1")
        self.clock = Clock()

    def run_main(self, cloud, env=ENV):
        out = io.StringIO()

        def client(api_key):
            return cloud_tests.Client(api_key, opener=cloud, sleep=self.clock.sleep, clock=self.clock)

        code = cloud_tests.main([str(self.place), str(self.script)], env, out, client_factory=client)
        return code, out.getvalue()

    def test_passes_when_every_test_passed(self):
        code, output = self.run_main(Cloud(green_routes()))
        self.assertEqual(code, 0)
        self.assertIn("658/658", output)
        self.assertIn("[RunTests] PASS", output)

    def test_runs_the_task_on_the_version_it_uploaded(self):
        cloud = Cloud(green_routes())
        self.run_main(cloud)
        upload, create = cloud.requests[0], cloud.requests[1]
        self.assertEqual(urlsplit(upload.full_url).query, "versionType=Saved")
        self.assertEqual(upload.get_header("Content-type"), "application/octet-stream")
        self.assertEqual(upload.get_header("X-api-key"), KEY)
        self.assertEqual(upload.data, b"place bytes")
        self.assertTrue(urlsplit(create.full_url).path.endswith(CREATE))
        self.assertEqual(json.loads(create.data), {"script": "return 1", "timeout": "300s"})

    def test_waits_while_the_task_is_queued_or_processing(self):
        routes = green_routes()
        routes[2:2] = [route("GET", POLL, ok(task("QUEUED"))), route("GET", POLL, ok(task("PROCESSING")))]
        cloud = Cloud(routes)
        code, _ = self.run_main(cloud)
        self.assertEqual(code, 0)
        self.assertEqual(cloud.count("GET", POLL), 3)
        self.assertEqual(self.clock.sleeps, [cloud_tests.POLL_SECONDS] * 2)

    def test_fails_when_a_test_failed(self):
        failed = summary(
            success=False, numPassedTests=657, numFailedTests=1, failureMessages=["\x1b[31m● Hud › renders\x1b[0m"]
        )
        code, output = self.run_main(Cloud(green_routes(final=task("COMPLETE", [failed]))))
        self.assertEqual(code, 1)
        self.assertIn("● Hud › renders", output)
        self.assertNotIn("\x1b", output)

    def test_fails_when_no_test_ran(self):
        for results in (
            [summary(success=False, numTotalTests=0, numPassedTests=0)],
            [summary(numTotalTests=0, numPassedTests=0)],
            [],
        ):
            with self.subTest(results=results):
                code, _ = self.run_main(Cloud(green_routes(final=task("COMPLETE", results))))
                self.assertEqual(code, 1)

    def test_fails_when_a_test_was_skipped(self):
        # A stray `it.only` or `it.skip`: nothing failed, but not every test ran.
        skipped = summary(numPassedTests=600)
        code, output = self.run_main(Cloud(green_routes(final=task("COMPLETE", [skipped]))))
        self.assertEqual(code, 1)
        self.assertIn("600/658", output)
        self.assertIn("skipped", output)

    def test_fails_when_the_task_failed_or_was_cancelled(self):
        failed = task("FAILED", error={"code": "SCRIPT_ERROR", "message": "attempt to call a nil value"})
        code, output = self.run_main(Cloud(green_routes(final=failed)))
        self.assertEqual(code, 1)
        self.assertIn("attempt to call a nil value", output)
        code, output = self.run_main(Cloud(green_routes(final=task("CANCELLED"))))
        self.assertEqual(code, 1)
        self.assertIn("CANCELLED", output)

    def test_fails_when_the_task_outlives_its_deadline(self):
        routes = green_routes()
        routes[2] = route("GET", POLL, ok(task("PROCESSING")), repeats=True)
        code, output = self.run_main(Cloud(routes))
        self.assertEqual(code, 1)
        self.assertIn("deadline", output)
        self.assertGreaterEqual(self.clock.now, cloud_tests.DEADLINE_SECONDS)

    def test_waits_out_a_rate_limit(self):
        routes = green_routes()
        routes.insert(1, route("POST", CREATE, fails(429, {"message": "Too many"}, {"Retry-After": "12"})))
        code, _ = self.run_main(Cloud(routes))
        self.assertEqual(code, 0)
        self.assertIn(12, self.clock.sleeps)
        self.clock = Clock()
        reset = green_routes()
        reset.insert(1, route("POST", CREATE, fails(429, {"message": "Too many"}, {"x-ratelimit-reset": "41"})))
        code, _ = self.run_main(Cloud(reset))
        self.assertEqual(code, 0)
        self.assertEqual(self.clock.sleeps, [41])
        self.clock = Clock()
        minute = green_routes()
        minute[1:1] = [route("POST", CREATE, fails(429, {"message": "Too many"}))] * 4
        code, _ = self.run_main(Cloud(minute))
        self.assertEqual(code, 0)
        self.assertGreater(sum(self.clock.sleeps), 60)
        limited = green_routes()
        limited[1] = route("POST", CREATE, fails(429, {"message": "Too many"}), repeats=True)
        code, output = self.run_main(Cloud(limited))
        self.assertEqual(code, 1)
        self.assertIn("429", output)

    def test_retries_a_server_error_or_a_dropped_connection(self):
        first, second = cloud_tests.RETRY_SECONDS[:2]
        dropped = [
            route("POST", UPLOAD, fails(503, {"message": "Unavailable"})),
            route("POST", CREATE, drops(http.client.IncompleteRead(b""))),
            route("GET", POLL, drops(urllib.error.URLError("connection reset"))),
            route("GET", POLL, drops(http.client.RemoteDisconnected("closed without response"))),
            route("GET", LOGS, drops(TimeoutError("timed out"))),
        ]
        code, _ = self.run_main(Cloud(dropped + green_routes()))
        self.assertEqual(code, 0)
        self.assertEqual(self.clock.sleeps, [first, first, first, second, first])

    def test_fails_with_the_status_of_a_rejected_request_and_never_prints_the_key(self):
        cloud = Cloud([route("POST", UPLOAD, fails(403, {"message": "Forbidden"}))])
        code, output = self.run_main(cloud)
        self.assertEqual(code, 1)
        self.assertIn("403", output)
        self.assertIn(UPLOAD, output)
        self.assertIn("Forbidden", output)
        self.assertNotIn(KEY, output)

    def test_fails_loudly_naming_each_missing_setting(self):
        code, output = self.run_main(Cloud([]), env={})
        self.assertEqual(code, 1)
        self.assertIn("::error::", output)
        for name in ("ROBLOX_API_KEY", "ROBLOX_TEST_UNIVERSE_ID", "ROBLOX_TEST_PLACE_ID"):
            self.assertIn(name, output)
        self.assertIn("scripts/ci/setup-cloud-tests.sh", output)
        code, output = self.run_main(Cloud([]), env={**ENV, "ROBLOX_TEST_PLACE_ID": "Blox Champions Tests"})
        self.assertEqual(code, 1)
        self.assertIn("ROBLOX_TEST_PLACE_ID", output)

    def test_prints_every_page_of_the_logs(self):
        routes = green_routes(
            logs={"luauExecutionSessionTaskLogs": [{"messages": ["one", "two"]}], "nextPageToken": "p2"}
        )
        routes.append(
            route("GET", LOGS, ok({"luauExecutionSessionTaskLogs": [{"messages": ["three"]}]}), "pageToken=p2")
        )
        code, output = self.run_main(Cloud(routes))
        self.assertEqual(code, 0)
        self.assertLess(output.index("one"), output.index("two"))
        self.assertLess(output.index("two"), output.index("three"))


if __name__ == "__main__":
    unittest.main()
