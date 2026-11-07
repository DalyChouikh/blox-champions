"""Unit tests for scripts/art/build_ball.py's Default skin picture (#400): the black band's rows and the PNG's bytes.
The mesh export needs Blender and is checked by running the script there. Run: python -m unittest discover -s
scripts/ci -p "test_*.py"."""

import importlib.util
import math
import struct
import unittest
import zlib
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "art" / "build_ball.py"
spec = importlib.util.spec_from_file_location("build_ball", SCRIPT)
build_ball = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build_ball)

HEIGHT = build_ball.PICTURE_HEIGHT
STEP = math.pi / HEIGHT


def chunks(png: bytes) -> list[tuple[bytes, bytes]]:
    """A PNG's chunks as (kind, data), each checked against its CRC."""
    assert png[:8] == b"\x89PNG\r\n\x1a\n"
    found, at = [], 8
    while at < len(png):
        (length,) = struct.unpack(">I", png[at : at + 4])
        kind, data = png[at + 4 : at + 8], png[at + 8 : at + 8 + length]
        (crc,) = struct.unpack(">I", png[at + 8 + length : at + 12 + length])
        assert crc == zlib.crc32(kind + data), kind
        found.append((kind, data))
        at += 12 + length
    return found


def pixels(png: bytes) -> tuple[int, int, list[bytes]]:
    """Width, height and the RGBA rows of an 8-bit RGBA PNG with unfiltered rows."""
    found = dict(chunks(png))
    width, height, depth, colour, _, _, interlace = struct.unpack(">IIBBBBB", found[b"IHDR"])
    assert (depth, colour, interlace) == (8, 6, 0)
    raw = zlib.decompress(found[b"IDAT"])
    stride = 1 + 4 * width
    rows = [raw[i * stride : (i + 1) * stride] for i in range(height)]
    assert all(row[0] == 0 for row in rows)
    return width, height, [row[1:] for row in rows]


class BandCoverage(unittest.TestCase):
    def test_the_band_spans_its_width_in_latitude(self):
        covered = sum(build_ball.band_coverage(row) for row in range(HEIGHT)) * STEP
        self.assertAlmostEqual(covered, 2 * math.asin(build_ball.BAND_WIDTH / 2 / build_ball.RADIUS), places=12)

    def test_the_band_sits_on_the_middle(self):
        for row in range(HEIGHT):
            self.assertAlmostEqual(build_ball.band_coverage(row), build_ball.band_coverage(HEIGHT - 1 - row), places=12)

    def test_rows_are_inside_outside_or_one_edge_row_each_side(self):
        values = [build_ball.band_coverage(row) for row in range(HEIGHT)]
        self.assertEqual(values[0], 0)
        self.assertEqual(values[HEIGHT // 2], 1)
        self.assertTrue(all(0 <= value <= 1 for value in values))
        self.assertLessEqual(sum(1 for value in values if 0 < value < 1), 2)

    def test_the_width_is_the_owners_choice(self):
        self.assertEqual(build_ball.BAND_WIDTH, 0.8)
        self.assertEqual(build_ball.RADIUS, 1.0)


class DefaultPicture(unittest.TestCase):
    def test_ink_everywhere_opaque_only_over_the_band(self):
        width, height, rows = pixels(build_ball.default_picture())
        self.assertEqual((width, height), (build_ball.PICTURE_WIDTH, HEIGHT))
        for index, row in enumerate(rows):
            alpha = round(255 * build_ball.band_coverage(index))
            self.assertEqual(row, bytes((*build_ball.INK, alpha)) * width, index)

    def test_only_the_three_needed_chunks(self):
        self.assertEqual([kind for kind, _ in chunks(build_ball.default_picture())], [b"IHDR", b"IDAT", b"IEND"])

    def test_the_same_bytes_every_time(self):
        self.assertEqual(build_ball.default_picture(), build_ball.default_picture())

    def test_square_pixels_within_robloxs_limit(self):
        # The paint map spans 360 degrees across and 180 up, so a picture twice as wide as tall has square pixels.
        self.assertEqual(build_ball.PICTURE_WIDTH, 2 * build_ball.PICTURE_HEIGHT)
        self.assertLessEqual(build_ball.PICTURE_WIDTH, 1024)

    def test_look_cs_ink(self):
        self.assertEqual(build_ball.INK, (11, 14, 24))


class ObjText(unittest.TestCase):
    def test_positions_paint_map_normals_and_triangles_counted_from_one(self):
        text = build_ball.obj_text(
            positions=[(0, 1, 0), (1, 0, 0), (0, 0, -1)],
            normals=[(0, 1, 0), (1, 0, 0), (0, 0, -1)],
            uvs=[(0.5, 1), (0.25, 0.5)],
            triangles=[((0, 0), (1, 1), (2, 1))],
        )
        self.assertEqual(
            text,
            "o Ball\n"
            "v 0.000000 1.000000 0.000000\n"
            "v 1.000000 0.000000 0.000000\n"
            "v 0.000000 0.000000 -1.000000\n"
            "vt 0.500000 1.000000\n"
            "vt 0.250000 0.500000\n"
            "vn 0.000000 1.000000 0.000000\n"
            "vn 1.000000 0.000000 0.000000\n"
            "vn 0.000000 0.000000 -1.000000\n"
            "f 1/1/1 2/2/2 3/2/3\n",
        )

    def test_never_a_negative_zero(self):
        text = build_ball.obj_text(positions=[(-0.0, -1e-9, 0.0)], normals=[(-0.0, 1, -0.0)], uvs=[], triangles=[])
        self.assertNotIn("-0.000000", text)
        self.assertIn("v 0.000000 0.000000 0.000000\n", text)


if __name__ == "__main__":
    unittest.main()
