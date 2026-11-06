"""Helpers the art build scripts share (build_ball.py, build_goal.py): Blender's axes turned into Roblox's, numbers
written the same way on every run, one face order whatever order Blender lists faces in, Roblox's triangle budget,
and a GLB writer (glTF 2.0's one-file binary form) whose bytes depend only on the meshes. Pure Python: no Blender.
"""

import json
import struct
from dataclasses import dataclass

Vector = tuple[float, float, float]
# A face's corner as Blender gives it: (vertex index, its point on the paint map).
Corner = tuple[int, tuple[float, float]]

# Roblox's mesh specifications: "Individual meshes can not exceed 20,000 triangles."
TRIANGLE_LIMIT = 20000

# glTF 2.0's codes: component types, buffer view targets, its binary file's magic and chunk kinds.
FLOAT, UNSIGNED_INT = 5126, 5125
ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER = 34962, 34963
GLB_MAGIC, GLB_VERSION, JSON_CHUNK, BIN_CHUNK = b"glTF", 2, 0x4E4F534A, 0x004E4942
GENERATOR = "blox-champions scripts/art/meshkit.py"


def to_roblox(point: Vector) -> Vector:
    """Blender's Z-up axes to Roblox's Y-up ones: a quarter turn about X (a turn, not a mirror, so faces keep their
    winding), Blender's forward (+Y) becoming Roblox's -Z."""
    x, y, z = point
    return (x, z, -y)


def number(value: float) -> str:
    """Six decimals, never "-0.000000" (Blender's -0.0 and float dust would otherwise change bytes between builds)."""
    text = f"{value:.6f}"
    return "0.000000" if text == "-0.000000" else text


def canonical_faces(faces: list[list[Corner]]) -> list[list[Corner]]:
    """The faces in one order whatever order Blender lists them in (its UV sphere's faces come out in a different
    order on every run; the vertices do not): each starts at its lowest vertex, its winding kept, and they are sorted
    by their vertices."""
    started = []
    for face in faces:
        lowest = min(range(len(face)), key=lambda corner: face[corner][0])
        started.append(face[lowest:] + face[:lowest])
    return sorted(started, key=lambda face: [vertex for vertex, _ in face])


def check_budget(name: str, triangles: int) -> None:
    """Fails a build whose mesh Roblox would refuse."""
    if triangles > TRIANGLE_LIMIT:
        raise ValueError(f"{name}: {triangles} triangles, over Roblox's {TRIANGLE_LIMIT}")


@dataclass(frozen=True)
class Piece:
    """One mesh: its name (its MeshPart's once imported), its points, one normal per point (smooth shading), and its
    triangles as three point indices each, counted from 0, wound counter-clockwise seen from outside."""

    name: str
    positions: list[Vector]
    normals: list[Vector]
    triangles: list[tuple[int, int, int]]


def _float32(values: list[float]) -> tuple[float, ...]:
    """The values as the file stores them, so the bounds written beside them match them exactly."""
    return struct.unpack(f"<{len(values)}f", struct.pack(f"<{len(values)}f", *values))


def glb_bytes(pieces: list[Piece]) -> bytes:
    """The pieces as one GLB, a node and a mesh each in one scene, in the order given: Roblox's importer makes a Model
    with one MeshPart per mesh. Every view starts on a 4-byte boundary (all data here is 4-byte), and nothing in the
    file depends on when or where it was written."""
    binary = bytearray()
    views: list[dict] = []
    accessors: list[dict] = []

    def add(data: bytes, target: int, count: int, component: int, kind: str, bounds: dict | None = None) -> int:
        views.append({"buffer": 0, "byteOffset": len(binary), "byteLength": len(data), "target": target})
        binary.extend(data)
        accessors.append(
            {"bufferView": len(views) - 1, "componentType": component, "count": count, "type": kind, **(bounds or {})}
        )
        return len(accessors) - 1

    meshes, nodes = [], []
    for index, piece in enumerate(pieces):
        check_budget(piece.name, len(piece.triangles))
        points = _float32([c for point in piece.positions for c in point])
        bounds = {
            "min": [min(points[axis::3]) for axis in range(3)],
            "max": [max(points[axis::3]) for axis in range(3)],
        }
        normals = [c for normal in piece.normals for c in normal]
        corners = [corner for triangle in piece.triangles for corner in triangle]
        attributes = {
            "POSITION": add(
                struct.pack(f"<{len(points)}f", *points), ARRAY_BUFFER, len(piece.positions), FLOAT, "VEC3", bounds
            ),
            "NORMAL": add(struct.pack(f"<{len(normals)}f", *normals), ARRAY_BUFFER, len(piece.normals), FLOAT, "VEC3"),
        }
        triangles = add(
            struct.pack(f"<{len(corners)}I", *corners), ELEMENT_ARRAY_BUFFER, len(corners), UNSIGNED_INT, "SCALAR"
        )
        meshes.append({"name": piece.name, "primitives": [{"attributes": attributes, "indices": triangles, "mode": 4}]})
        nodes.append({"name": piece.name, "mesh": index})

    document = {
        "asset": {"version": "2.0", "generator": GENERATOR},
        "scene": 0,
        "scenes": [{"nodes": list(range(len(nodes)))}],
        "nodes": nodes,
        "meshes": meshes,
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(binary)}],
    }
    text = json.dumps(document, separators=(",", ":")).encode("utf-8")
    # Each chunk is padded to 4 bytes: the JSON with spaces, the binary with zeros (glTF 2.0's binary layout).
    text += b" " * (-len(text) % 4)
    binary.extend(b"\x00" * (-len(binary) % 4))
    chunks = struct.pack("<II", len(text), JSON_CHUNK) + text + struct.pack("<II", len(binary), BIN_CHUNK) + binary
    return struct.pack("<4sII", GLB_MAGIC, GLB_VERSION, 12 + len(chunks)) + chunks
