"""Unit tests for scripts/art/build_goal.py's pure parts (#410): the goal's shape numbers, read from the one file the
game's config reads too (src/shared/Config/GoalShape.json), the rules they must keep, and the boxes file that ties
the committed mesh to those numbers (ruling G7). The Blender build itself is checked by running it there. Run:
python -m unittest discover -s scripts/ci -p "test_*.py"."""

import copy
import hashlib
import importlib.util
import json
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "art" / "build_goal.py"
spec = importlib.util.spec_from_file_location("build_goal", SCRIPT)
build_goal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build_goal)

SHAPE = build_goal.load_shape(build_goal.SHAPE_FILE)


def changed(path: str, value) -> dict:
    """The shape with one number changed, `path` dotted ("pylon.front")."""
    shape = copy.deepcopy(SHAPE)
    *parents, key = path.split(".")
    node = shape
    for parent in parents:
        node = node[parent]
    node[key] = value
    return shape


class Shape(unittest.TestCase):
    def test_the_owners_picks(self):
        # Q311 the opening's radius, Q310 its centre's height, Q315 its centre 67 out from the middle glass and the
        # pylon from the outer glass line at 20 (Q312) up to 84.
        self.assertEqual(SHAPE["opening"], {"radius": 9, "height": 52, "across": 67})
        self.assertEqual((SHAPE["pylon"]["foot"], SHAPE["pylon"]["top"]), (20, 84))

    def test_the_shipped_shape_keeps_every_rule(self):
        build_goal.check_shape(SHAPE)

    def test_names_a_missing_number(self):
        shape = copy.deepcopy(SHAPE)
        del shape["pylon"]["width"]
        with self.assertRaisesRegex(ValueError, r"GoalShape: pylon\.width is missing"):
            build_goal.check_shape(shape)

    def test_refuses_a_size_that_is_not_above_zero(self):
        for path in ("opening.radius", "housing.depth", "pylon.corner", "strips.width", "lip.thickness", "melt.voxel"):
            with self.subTest(path), self.assertRaisesRegex(ValueError, rf"GoalShape: {path} must be above 0"):
                build_goal.check_shape(changed(path, 0))

    def test_refuses_a_shape_that_breaks_its_rules(self):
        cases = {
            # Q315: the whole opening stands in front of the pylon.
            "pylon.front": (9, "the whole opening must stand in front of the pylon"),
            "pylon.foot": (40, "the housing must sit on the pylon, above its foot"),
            "pylon.top": (64, "the housing must sit on the pylon, below its top"),
            "housing.frontRadius": (9, "the housing's front must ring the opening"),
            "housing.backRadius": (10, "the housing must widen to its back"),
            "strips.apart": (8, "the strips must fit the pylon's flat face"),
            "strips.inset": (33, "the strips must run along the pylon"),
            "lip.radius": (11, "the lip must straddle the housing's front between the opening and its rim"),
            "lip.along": (-4, "the lip must sit on the housing's front face"),
            "band.radius": (10, "the band must straddle the opening's bore"),
            "band.along": (6, "the band must lie inside the housing's depth"),
        }
        for path, (value, message) in cases.items():
            with self.subTest(path), self.assertRaisesRegex(ValueError, f"GoalShape: {message}"):
                build_goal.check_shape(changed(path, value))


class Pieces(unittest.TestCase):
    def test_each_box_and_the_shape_it_was_built_from(self):
        square = build_goal.meshkit.Piece(
            "Lip", [(-1.0, -2.0, 0.5), (3.0, 2.0, 0.5), (3.0, -2.0, -0.5)], [(0.0, 0.0, 1.0)] * 3, [(0, 1, 2)]
        )
        boxes = json.loads(build_goal.pieces_json([square], "abc123"))
        self.assertEqual(
            boxes, {"shape": "abc123", "pieces": {"Lip": {"centre": [1.0, 0.0, 0.0], "size": [4.0, 4.0, 1.0]}}}
        )

    def test_the_committed_boxes_come_from_the_committed_shape(self):
        # G7: Blender's melt is not byte-reproducible, so the mesh's boxes carry the shape file's hash instead, and a
        # shape edited without a rebuild (and the owner's import) fails here.
        committed = json.loads(build_goal.PIECES_FILE.read_text(encoding="utf-8"))
        self.assertEqual(committed["shape"], hashlib.sha256(build_goal.SHAPE_FILE.read_bytes()).hexdigest())
        self.assertEqual(list(committed["pieces"]), ["Shell", "Strips", "Lip", "Band"])


if __name__ == "__main__":
    unittest.main()
