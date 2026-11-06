"""Builds the goal's meshes: the Halo pylon (#410; the owner's Q310-Q315), the ring growing out of a slim pylon set in
the outer wall.

Run with Blender 5.2 LTS:
    blender --background --factory-startup --python scripts/art/build_goal.py -- <out dir>

Its numbers are the game's own: src/shared/Config/GoalShape.json, which Config.Arena reads too, so the mesh and the
rules that judge goals never disagree. They are in the goal's frame: the origin at the opening's centre, X across the
track toward the outer wall, Y up, Z along the track the way skaters lap (the housing's front faces oncoming skaters,
at -Z). The opening's height and the pylon's foot and top are heights above the lowest floor; `opening.across` is the
centre's distance from the middle glass's face.
"""

import json
import sys
from pathlib import Path

# Blender runs a --python script without its folder on sys.path.
sys.path.insert(0, str(Path(__file__).resolve().parent))

SHAPE_FILE = Path(__file__).resolve().parents[2] / "src" / "shared" / "Config" / "GoalShape.json"

# Every number the build reads, by group. Each is a size above zero but the `along` ones, which are signed places.
NUMBERS = {
    "opening": ("radius", "height", "across"),
    "housing": ("frontRadius", "backRadius", "depth", "corner"),
    "pylon": ("foot", "top", "front", "depth", "width", "corner"),
    "swell": ("across",),
    "swell.radii": ("across", "up", "along"),
    "strips": ("apart", "width", "depth", "inset", "corner"),
    "lip": ("radius", "thickness", "along"),
    "band": ("radius", "thickness", "along"),
    "melt": ("voxel", "fillet"),
}
SIGNED = "along"


def load_shape(path: Path) -> dict:
    """The goal's shape numbers, read from the game's config."""
    return json.loads(path.read_text(encoding="utf-8"))


def _fail(message: str) -> None:
    raise ValueError(f"GoalShape: {message}")


def _numbers(shape: dict) -> None:
    """Every number present, and every size above zero."""
    for group, keys in NUMBERS.items():
        node = shape
        for part in group.split("."):
            node = node.get(part, {}) if isinstance(node, dict) else {}
        for key in keys:
            value = node.get(key)
            if not isinstance(value, int | float) or isinstance(value, bool):
                _fail(f"{group}.{key} is missing")
            if key != SIGNED and value <= 0:
                _fail(f"{group}.{key} must be above 0")


def check_shape(shape: dict) -> None:
    """Fails a shape the goal cannot be built from, naming the first rule it breaks."""
    _numbers(shape)
    opening, housing, pylon = shape["opening"], shape["housing"], shape["pylon"]
    strips, lip, band = shape["strips"], shape["lip"], shape["band"]
    radius, half_depth = opening["radius"], housing["depth"] / 2
    rules = [
        # Q315: the opening is all in front of the pylon, which stands out of the glass behind it.
        (pylon["front"] > radius, "the whole opening must stand in front of the pylon"),
        (
            opening["height"] - housing["backRadius"] > pylon["foot"],
            "the housing must sit on the pylon, above its foot",
        ),
        (opening["height"] + housing["backRadius"] < pylon["top"], "the housing must sit on the pylon, below its top"),
        (housing["frontRadius"] > radius, "the housing's front must ring the opening"),
        (housing["backRadius"] > housing["frontRadius"], "the housing must widen to its back"),
        (
            strips["apart"] / 2 + strips["width"] / 2 <= pylon["width"] / 2 - pylon["corner"],
            "the strips must fit the pylon's flat face",
        ),
        (pylon["top"] - pylon["foot"] > 2 * strips["inset"], "the strips must run along the pylon"),
        (
            radius < lip["radius"] - lip["thickness"] and lip["radius"] + lip["thickness"] < housing["frontRadius"],
            "the lip must straddle the housing's front between the opening and its rim",
        ),
        (abs(lip["along"] + half_depth) < lip["thickness"], "the lip must sit on the housing's front face"),
        (abs(band["radius"] - radius) < band["thickness"], "the band must straddle the opening's bore"),
        (abs(band["along"]) + band["thickness"] < half_depth, "the band must lie inside the housing's depth"),
    ]
    for kept, message in rules:
        if not kept:
            _fail(message)
