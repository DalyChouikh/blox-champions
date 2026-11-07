"""Builds the match ball's mesh, its Default skin's picture (#400; the owner's Q275-Q277) and that skin's glow mask
(#415, Q319).

Run with Blender 5.2 LTS:
    blender --background --factory-startup --python scripts/art/build_ball.py -- <out dir>

Writes, the same bytes on every run:
- <out>/ball.obj: a smooth UV sphere of radius 1, Roblox's axes (Y up), with its paint map (UVs). Roblox sizes a mesh
  to its part, so the ball part's size alone sets how big it is drawn.
- <out>/ball_default.png: the Default skin's picture over that paint map, see-through except the black band round the
  middle (Q275: 0.8 studs on the 2-stud ball). Roblox lays a picture's opaque pixels over the part's own colour, so
  the ball still shows white or its team's colour everywhere else (Q158, Q159).
- <out>/ball_default_glow.png: the Default skin's glow mask over the same paint map, white where the carried ball
  glows in its team's colour and black over the band, so the band stays fully black (Q319). Roblox scales the glow by
  the mask's brightness.

The paint map is Blender's: longitude across, latitude up (0 at the bottom pole, 1 at the top), evenly spaced, so the
band is the picture's rows within BAND_WIDTH / 2 of the middle. A later skin is another picture over the same map.
"""

import math
import struct
import sys
import zlib
from collections.abc import Callable
from pathlib import Path

# Blender runs a --python script without its folder on sys.path.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from meshkit import Vector, canonical_faces, number, to_roblox

RADIUS = 1.0
SEGMENTS = 64
RINGS = 32
# The band's width along the ball's axis, in studs on a ball of RADIUS 1 (the owner's Q275).
BAND_WIDTH = 0.8
# Look C's ink (Config UI.hud.look.ink), so the band matches the HUD's outlines.
INK = (11, 14, 24)
# Roblox shows pictures at up to 1024 pixels a side.
PICTURE_WIDTH = 1024
PICTURE_HEIGHT = 512


def band_coverage(row: int) -> float:
    """How much of picture row `row` (0 = the top row, at the top pole) lies inside the band, 0 to 1."""
    # The band's edges in rows from the top (a row spans pi / PICTURE_HEIGHT of latitude), so a row wholly inside or
    # outside comes out exactly 1 or 0.
    half = math.asin(BAND_WIDTH / 2 / RADIUS) / math.pi * PICTURE_HEIGHT
    first = PICTURE_HEIGHT / 2 - half
    last = PICTURE_HEIGHT - first
    return max(0.0, min(row + 1, last) - max(row, first))


def png_rgba(width: int, height: int, rows: list[bytes]) -> bytes:
    """A PNG of 8-bit RGBA rows, with no metadata, so the bytes depend only on the pixels."""

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    raw = b"".join(b"\x00" + row for row in rows)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def banded_picture(pixel: Callable[[float], bytes]) -> bytes:
    """A picture over the paint map whose every row is one RGBA pixel, chosen by how much of that row is band."""
    rows = [pixel(band_coverage(row)) * PICTURE_WIDTH for row in range(PICTURE_HEIGHT)]
    return png_rgba(PICTURE_WIDTH, PICTURE_HEIGHT, rows)


def default_picture() -> bytes:
    """Ink everywhere (so filtering at the band's edges never brings in a light fringe), opaque only over the band."""
    return banded_picture(lambda covered: bytes((*INK, round(255 * covered))))


def default_glow_mask() -> bytes:
    """White off the band, black over it, an edge row grey by the share of it outside the band. Opaque."""
    return banded_picture(lambda covered: bytes((round(255 * (1 - covered)),) * 3 + (255,)))


# A triangle's three corners, each (vertex index, paint map index), counted from 0.
Triangle = tuple[tuple[int, int], tuple[int, int], tuple[int, int]]


def obj_text(
    positions: list[Vector], normals: list[Vector], uvs: list[tuple[float, float]], triangles: list[Triangle]
) -> str:
    """The mesh as OBJ text, one normal per vertex (smooth shading). Written here rather than by Blender's exporter,
    which orders the paint map's points differently from one run to the next."""
    lines = ["o Ball"]
    lines += ["v " + " ".join(map(number, point)) for point in positions]
    lines += ["vt " + " ".join(map(number, uv)) for uv in uvs]
    lines += ["vn " + " ".join(map(number, normal)) for normal in normals]
    lines += ["f " + " ".join(f"{v + 1}/{t + 1}/{v + 1}" for v, t in triangle) for triangle in triangles]
    return "\n".join(lines) + "\n"


def ball_mesh() -> str:
    """Blender's smooth UV sphere (SEGMENTS x RINGS, RADIUS) as OBJ text in Roblox's axes."""
    import bpy

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=SEGMENTS, ring_count=RINGS, radius=RADIUS, calc_uvs=True)
    mesh = bpy.context.active_object.data
    paint = mesh.uv_layers.active.data
    faces = [
        [(mesh.loops[loop].vertex_index, (round(paint[loop].uv[0], 6), round(paint[loop].uv[1], 6))) for loop in face]
        for face in (polygon.loop_indices for polygon in mesh.polygons)
    ]
    uv_index: dict[tuple[float, float], int] = {}
    triangles = []
    # Each face fanned into triangles from its first corner (not Blender's loop_triangles, which also change order).
    for face in canonical_faces(faces):
        corners = [(vertex, uv_index.setdefault(uv, len(uv_index))) for vertex, uv in face]
        triangles += [(corners[0], corners[i], corners[i + 1]) for i in range(1, len(corners) - 1)]
    positions = [to_roblox(tuple(vertex.co)) for vertex in mesh.vertices]
    return obj_text(
        positions=positions,
        # A sphere's own normal at each point (Blender's averaged ones vary in the sixth decimal between runs).
        normals=[tuple(coordinate / math.dist(point, (0, 0, 0)) for coordinate in point) for point in positions],
        uvs=list(uv_index),
        triangles=triangles,
    )


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if len(args) != 1:
        raise SystemExit("usage: blender --background --factory-startup --python build_ball.py -- <out dir>")
    out = Path(args[0])
    out.mkdir(parents=True, exist_ok=True)
    (out / "ball.obj").write_text(ball_mesh(), encoding="utf-8", newline="\n")
    (out / "ball_default.png").write_bytes(default_picture())
    (out / "ball_default_glow.png").write_bytes(default_glow_mask())
    print(f"build_ball: wrote ball.obj, ball_default.png and ball_default_glow.png in {out}")


if __name__ == "__main__":
    main()
