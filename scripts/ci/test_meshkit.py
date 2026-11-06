"""Unit tests for scripts/art/meshkit.py, the helpers the art build scripts share: Blender's axes turned into Roblox's,
one face order whatever order Blender lists faces in, Roblox's triangle budget, and the GLB file the goal's meshes
ship in (#410). Run: python -m unittest discover -s scripts/ci -p "test_*.py"."""

import importlib.util
import json
import struct
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "art" / "meshkit.py"
spec = importlib.util.spec_from_file_location("meshkit", SCRIPT)
meshkit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(meshkit)

# A tetrahedron's corners, faces wound outward, and its corners' directions from its middle as normals.
CORNERS = [(0.0, 0.0, 0.0), (2.0, 0.0, 0.0), (0.0, 3.0, 0.0), (0.0, 0.0, 4.0)]
TETRA = [(0, 2, 1), (0, 1, 3), (0, 3, 2), (1, 2, 3)]
NORMALS = [(-0.577, -0.577, -0.577), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)]


def piece(name: str, scale: float = 1.0) -> "meshkit.Piece":
    return meshkit.Piece(
        name=name, positions=[tuple(c * scale for c in p) for p in CORNERS], normals=NORMALS, triangles=TETRA
    )


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def read_glb(data: bytes) -> tuple[dict, bytes]:
    """A GLB's JSON and its binary chunk, its framing checked against glTF 2.0's binary layout."""
    magic, version, length = struct.unpack("<4sII", data[:12])
    assert (magic, version, length) == (b"glTF", 2, len(data)), (magic, version, length)
    json_length, json_kind = struct.unpack("<II", data[12:20])
    assert json_kind == 0x4E4F534A and json_length % 4 == 0
    text = data[20 : 20 + json_length]
    at = 20 + json_length
    bin_length, bin_kind = struct.unpack("<II", data[at : at + 8])
    assert bin_kind == 0x004E4942 and bin_length % 4 == 0 and at + 8 + bin_length == len(data)
    return json.loads(text.decode("utf-8")), data[at + 8 :]


def accessor_values(document: dict, binary: bytes, index: int) -> list:
    """An accessor's values from the binary chunk: tuples for VEC3, numbers for SCALAR."""
    accessor = document["accessors"][index]
    view = document["bufferViews"][accessor["bufferView"]]
    fmt = {5126: "f", 5125: "I", 5123: "H"}[accessor["componentType"]]
    width = 3 if accessor["type"] == "VEC3" else 1
    size = struct.calcsize("<" + fmt)
    start = view["byteOffset"] + accessor.get("byteOffset", 0)
    flat = struct.unpack_from(f"<{accessor['count'] * width}{fmt}", binary, start)
    assert view["byteLength"] == accessor["count"] * width * size
    if width == 1:
        return list(flat)
    return [tuple(flat[i : i + 3]) for i in range(0, len(flat), 3)]


class ToRoblox(unittest.TestCase):
    def test_blenders_up_is_robloxs_up(self):
        self.assertEqual(meshkit.to_roblox((0, 0, 1)), (0, 1, 0))

    def test_blenders_forward_is_robloxs_minus_z(self):
        self.assertEqual(meshkit.to_roblox((0, 1, 0)), (0, 0, -1))
        self.assertEqual(meshkit.to_roblox((1, 0, 0)), (1, 0, 0))

    def test_a_turn_not_a_mirror_so_faces_keep_their_winding(self):
        a, b = (1.0, 2.0, 3.0), (-2.0, 0.5, 4.0)
        self.assertEqual(meshkit.to_roblox(cross(a, b)), cross(meshkit.to_roblox(a), meshkit.to_roblox(b)))


class CanonicalFaces(unittest.TestCase):
    QUAD = [(3, (0.5, 0.5)), (1, (0.0, 0.5)), (2, (0.0, 1.0)), (4, (0.5, 1.0))]
    TRIANGLE = [(7, (1.0, 0.0)), (5, (0.5, 0.0)), (6, (0.5, 0.5))]

    def test_each_face_starts_at_its_lowest_vertex_keeping_its_winding(self):
        self.assertEqual(
            meshkit.canonical_faces([self.QUAD]),
            [[(1, (0.0, 0.5)), (2, (0.0, 1.0)), (4, (0.5, 1.0)), (3, (0.5, 0.5))]],
        )

    def test_the_same_faces_in_any_order_or_start_come_out_the_same(self):
        rotated = self.TRIANGLE[1:] + self.TRIANGLE[:1]
        self.assertEqual(
            meshkit.canonical_faces([self.TRIANGLE, self.QUAD]),
            meshkit.canonical_faces([self.QUAD, rotated]),
        )

    def test_faces_sorted_by_their_vertices(self):
        faces = meshkit.canonical_faces([self.TRIANGLE, self.QUAD])
        self.assertEqual([face[0][0] for face in faces], [1, 5])


class Number(unittest.TestCase):
    def test_six_decimals_and_never_a_negative_zero(self):
        self.assertEqual(meshkit.number(1 / 3), "0.333333")
        self.assertEqual(meshkit.number(-0.0), "0.000000")
        self.assertEqual(meshkit.number(-1e-9), "0.000000")


class Budget(unittest.TestCase):
    def test_robloxs_limit_per_mesh(self):
        # Roblox's mesh specifications: "Individual meshes can not exceed 20,000 triangles."
        self.assertEqual(meshkit.TRIANGLE_LIMIT, 20000)

    def test_a_piece_at_the_limit_passes_and_one_over_names_itself(self):
        meshkit.check_budget("Shell", 20000)
        with self.assertRaisesRegex(ValueError, r"Shell: 20001 triangles, over Roblox's 20000"):
            meshkit.check_budget("Shell", 20001)


class Glb(unittest.TestCase):
    def test_one_node_and_mesh_per_piece_by_name_in_one_scene(self):
        document, _ = read_glb(meshkit.glb_bytes([piece("Shell"), piece("Lip", 2.0)]))
        self.assertEqual(document["asset"]["version"], "2.0")
        self.assertEqual(document["scenes"], [{"nodes": [0, 1]}])
        self.assertEqual(document["scene"], 0)
        self.assertEqual([node["name"] for node in document["nodes"]], ["Shell", "Lip"])
        self.assertEqual([node["mesh"] for node in document["nodes"]], [0, 1])
        self.assertEqual([mesh["name"] for mesh in document["meshes"]], ["Shell", "Lip"])

    def test_positions_normals_and_triangles_read_back_as_given(self):
        document, binary = read_glb(meshkit.glb_bytes([piece("Shell"), piece("Lip", 2.0)]))
        for index, scale in ((0, 1.0), (1, 2.0)):
            primitive = document["meshes"][index]["primitives"][0]
            self.assertEqual(primitive.get("mode", 4), 4)
            positions = accessor_values(document, binary, primitive["attributes"]["POSITION"])
            normals = accessor_values(document, binary, primitive["attributes"]["NORMAL"])
            indices = accessor_values(document, binary, primitive["indices"])
            for got, want in zip(positions, CORNERS, strict=True):
                for g, w in zip(got, want, strict=True):
                    self.assertAlmostEqual(g, w * scale, places=6)
            for got, want in zip(normals, NORMALS, strict=True):
                for g, w in zip(got, want, strict=True):
                    self.assertAlmostEqual(g, w, places=6)
            self.assertEqual([tuple(indices[i : i + 3]) for i in range(0, len(indices), 3)], TETRA)

    def test_positions_carry_their_bounds(self):
        document, _ = read_glb(meshkit.glb_bytes([piece("Lip", 2.0)]))
        position = document["accessors"][document["meshes"][0]["primitives"][0]["attributes"]["POSITION"]]
        self.assertEqual(position["min"], [0.0, 0.0, 0.0])
        self.assertEqual(position["max"], [4.0, 6.0, 8.0])

    def test_every_view_starts_on_a_four_byte_boundary_inside_the_one_buffer(self):
        document, binary = read_glb(meshkit.glb_bytes([piece("Shell"), piece("Lip", 2.0)]))
        self.assertEqual(len(document["buffers"]), 1)
        self.assertGreaterEqual(len(binary), document["buffers"][0]["byteLength"])
        for view in document["bufferViews"]:
            self.assertEqual(view["byteOffset"] % 4, 0)
            self.assertLessEqual(view["byteOffset"] + view["byteLength"], document["buffers"][0]["byteLength"])

    def test_the_same_bytes_every_time(self):
        self.assertEqual(meshkit.glb_bytes([piece("Shell")]), meshkit.glb_bytes([piece("Shell")]))

    def test_refuses_a_piece_over_robloxs_budget(self):
        many = meshkit.Piece(name="Shell", positions=CORNERS, normals=NORMALS, triangles=TETRA * 5001)
        with self.assertRaisesRegex(ValueError, "Shell: 20004 triangles"):
            meshkit.glb_bytes([many])


if __name__ == "__main__":
    unittest.main()
