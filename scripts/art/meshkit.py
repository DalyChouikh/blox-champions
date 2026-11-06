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


def _key(point: Vector) -> Vector:
    """A point rounded to the six decimals the files keep, never with a negative zero."""
    return tuple(round(c, 6) + 0.0 for c in point)


def canonical_mesh(
    positions: list[Vector], triangles: list[tuple[int, int, int]]
) -> tuple[list[Vector], list[tuple[int, int, int]]]:
    """The mesh in one order whatever order Blender built it in (its SDF meshing and decimation reorder points and
    faces): points rounded to six decimals, those that become one merged, then sorted; each triangle starts at its
    lowest point, its winding kept, and the triangles are sorted. A triangle a merge flattens is dropped."""
    keys = [_key(point) for point in positions]
    order = sorted(set(keys))
    index = {key: i for i, key in enumerate(order)}
    kept = set()
    for triangle in triangles:
        a, b, c = (index[keys[corner]] for corner in triangle)
        if len({a, b, c}) == 3:
            lowest = min(a, b, c)
            kept.add((a, b, c) if a == lowest else (b, c, a) if b == lowest else (c, a, b))
    return order, sorted(kept)


def _cross(a: Vector, b: Vector) -> Vector:
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _unit(vector: Vector) -> Vector:
    length = sum(c * c for c in vector) ** 0.5
    return tuple(c / length for c in vector) if length > 0 else (0.0, 0.0, 0.0)


def _area(positions: list[Vector], triangle: tuple[int, int, int]) -> Vector:
    """The cross product of the triangle's two edges from its first corner: out of its counter-clockwise winding,
    twice its area long."""
    a, b, c = (positions[corner] for corner in triangle)
    return _cross(tuple(b[i] - a[i] for i in range(3)), tuple(c[i] - a[i] for i in range(3)))


def face_normal(positions: list[Vector], triangle: tuple[int, int, int]) -> Vector:
    """The triangle's unit normal, out of its counter-clockwise winding."""
    return _unit(_area(positions, triangle))


def vertex_normals(positions: list[Vector], triangles: list[tuple[int, int, int]]) -> list[Vector]:
    """Each point's smooth-shading normal: its triangles' normals weighed by their areas (their cross products), so
    the file's normals come from its own points and never from Blender's run-to-run float dust."""
    sums = [[0.0, 0.0, 0.0] for _ in positions]
    for triangle in triangles:
        area = _area(positions, triangle)
        for corner in triangle:
            for axis in range(3):
                sums[corner][axis] += area[axis]
    return [_unit(tuple(total)) for total in sums]


def bounds(positions: list[Vector]) -> tuple[Vector, Vector]:
    """The points' box, as its centre and its size: Roblox centres a mesh on its box, so a piece is placed by it."""
    lows = [min(point[axis] for point in positions) for axis in range(3)]
    highs = [max(point[axis] for point in positions) for axis in range(3)]
    return tuple((lows[i] + highs[i]) / 2 for i in range(3)), tuple(highs[i] - lows[i] for i in range(3))


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


def _imported(point: Vector) -> Vector:
    """A point as the GLB stores it: Roblox's importer turns a glTF half a turn round its up axis (glTF's front is
    +Z, Roblox's -Z; seen on the goal's first import), so the file holds each point turned the other way and the
    import lands it where it was given. A turn, not a mirror: faces keep their winding."""
    x, y, z = point
    return (-x + 0.0, y, -z + 0.0)


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
        points = _float32([c for point in piece.positions for c in _imported(point)])
        bounds = {
            "min": [min(points[axis::3]) for axis in range(3)],
            "max": [max(points[axis::3]) for axis in range(3)],
        }
        normals = [c for normal in piece.normals for c in _imported(normal)]
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
