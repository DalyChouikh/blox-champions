"""Checks that both built places, the game (default.project.json) and the test place (test.project.json), declare each
service once and carry the service settings the game is developed and tested with: the ones stored in the dev place
(BloxChampions.rbxl, read from its file on 2026-10-24), with StarterGui.ScreenOrientation LandscapeSensor (the owner's
choice), and that only the test place may run loadstring. Builds both projects with Rojo, which must be on PATH, into
a temporary folder.
Run: python -m unittest discover -s scripts/ci -p "test_*.py"."""

import subprocess
import tempfile
import unittest
from collections import Counter
from pathlib import Path
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[2]
PROJECTS = ("default.project.json", "test.project.json")
# Each setting as Rojo writes it into an .rbxlx file: an enum as its number.
SETTINGS = {
    "Workspace": {
        "SignalBehavior2": "2",  # SignalBehavior (saved under this name): Deferred
        "PlayerScriptsUseInputActionSystem": "2",  # Enabled
        "StreamingEnabled": "true",
        "StreamingIntegrityMode": "3",  # PauseOutsideLoadedArea
        "StreamOutBehavior": "2",  # Opportunistic
        "PlayerCharacterDestroyBehavior": "2",  # Enabled
    },
    "Players": {"RespawnTime": "3"},
    "StarterPlayer": {
        "EnableMouseLockOption": "false",
        "CharacterBreakJointsOnDeath": "false",
        "CharacterUseJumpPower": "false",
        "CameraMaxZoomDistance": "128",
    },
    "StarterGui": {"ScreenOrientation": "2"},  # LandscapeSensor
    "SoundService": {"DefaultListenerLocation": "3", "RespectFilteringEnabled": "true"},  # Camera
}
# The one setting the two places differ in: Jest Roblox loads modules with loadstring, which a Roblox server allows
# only with ServerScriptService.LoadStringEnabled on. The test place turns it on for the cloud tests; the game leaves
# it at its default, off.
LOADSTRING = {"default.project.json": "false", "test.project.json": "true"}


def build(project: str, folder: str) -> list[tuple[str, dict[str, str]]]:
    """The built place's services, in order: each one's class and properties."""
    output = Path(folder) / f"{project}.rbxlx"
    result = subprocess.run(
        ["rojo", "build", project, "--output", str(output)], cwd=ROOT, capture_output=True, text=True, check=False
    )
    if result.returncode != 0:
        raise AssertionError(f"rojo build {project} failed: {result.stderr}")
    services = []
    for item in ElementTree.parse(output).getroot().findall("Item"):
        properties = item.find("Properties")
        values = {} if properties is None else {p.get("name"): p.text or "" for p in properties}
        services.append((item.get("class"), values))
    return services


class PlaceSettingsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with tempfile.TemporaryDirectory() as folder:
            cls.places = {project: build(project, folder) for project in PROJECTS}

    def test_declares_each_service_once(self):
        for project, services in self.places.items():
            with self.subTest(project=project):
                twice = sorted(name for name, count in Counter(name for name, _ in services).items() if count > 1)
                self.assertEqual(twice, [])

    def test_carries_the_dev_places_settings(self):
        for project, services in self.places.items():
            properties = dict(services)
            for service, settings in SETTINGS.items():
                for name, value in settings.items():
                    with self.subTest(project=project, setting=f"{service}.{name}"):
                        self.assertEqual(properties.get(service, {}).get(name), value)

    def test_allows_loadstring_in_the_test_place_only(self):
        for project, services in self.places.items():
            with self.subTest(project=project):
                value = dict(services).get("ServerScriptService", {}).get("LoadStringEnabled", "false")
                self.assertEqual(value, LOADSTRING[project])


if __name__ == "__main__":
    unittest.main()
