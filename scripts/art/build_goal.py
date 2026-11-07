"""Builds the goal's meshes: the Halo pylon (#410; the owner's Q310-Q315), the ring growing out of a slim pylon set in
the outer wall.

Run with Blender 5.2 LTS:
    blender --background --factory-startup --python scripts/art/build_goal.py -- <out dir>

Its numbers are the game's own: src/shared/Config/GoalShape.json, which Config.Arena reads too, so the mesh and the
rules that judge goals never disagree. They are in the goal's frame, the track's own (Centerline.at): the origin at
the opening's centre, X across the track toward the outer wall, Y up, and Z back toward oncoming skaters (a track
frame looks the way skaters travel). Each `along` is a place the way skaters travel, so the housing's front, facing
oncoming skaters, has a negative along and lies at +Z. The opening's height and the pylon's foot and top are heights
above the lowest floor; `opening.across` is the centre's distance from the middle glass's face.
"""

import hashlib
import json
import math
import sys
from pathlib import Path

# Blender runs a --python script without its folder on sys.path.
sys.path.insert(0, str(Path(__file__).resolve().parent))

import meshkit

SHAPE_FILE = Path(__file__).resolve().parents[2] / "src" / "shared" / "Config" / "GoalShape.json"
# What the build writes for the game beside it: each piece's box, and the shape file it was built from.
PIECES_FILE = SHAPE_FILE.with_name("GoalPieces.json")

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


# Below: the build, which needs Blender (bpy is imported inside, so the tests above run without it).

# The shell after decimation: under Roblox's limit, with room for the collapse landing a little over its ratio.
SHELL_TRIANGLES = 19000
# Steps round the opening (the housing's lathe, the lip and the band) and round each of the housing's corners.
AROUND, CORNER_STEPS, TORUS_SECTION = 128, 6, 16
# Bevel segments rounding the pylon's and the strips' corners.
PYLON_SEGMENTS, STRIP_SEGMENTS = 10, 4
# The opening's cutter runs this far either way along the lap, through everything round the opening.
CUTTER_LENGTH = 60.0


def _blender_point(across: float, up: float, along: float) -> tuple[float, float, float]:
    """A goal-frame point in Blender's axes: meshkit.to_roblox turns Blender's +Y into Roblox's -Z, the way skaters
    travel, so `along` runs up Blender's Y."""
    return (across, along, up)


def _link(name: str, verts: list, faces: list):
    import bpy

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _baked(name: str):
    """The object just added, named, its place, turn and size written into its mesh, so its points read back in the
    goal's frame (an evaluated mesh leaves the object's transform out)."""
    import bpy

    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def _rounded_box(name: str, centre: tuple, size: tuple, corner: float, segments: int):
    import bpy

    bpy.ops.mesh.primitive_cube_add(location=centre, scale=tuple(side / 2 for side in size))
    obj = _baked(name)
    bevel = obj.modifiers.new("Round", "BEVEL")
    bevel.width, bevel.segments, bevel.limit_method = corner, segments, "NONE"
    return obj


def _housing(shape: dict):
    """The lens round the opening (Q305, Q307): its section a thin front lip widening to the back, every corner
    rounded by a quadratic from the edge in to the edge out, turned round the opening's axis."""
    radius, housing = shape["opening"]["radius"], shape["housing"]
    half, corner = housing["depth"] / 2, housing["corner"]
    # (distance from the opening's axis, place along the lap): the front at -half.
    outline = [(radius, -half), (housing["frontRadius"], -half), (housing["backRadius"], half), (radius, half)]
    section = []
    for i, (r, a) in enumerate(outline):
        before, after = outline[i - 1], outline[(i + 1) % len(outline)]
        into, out = (before[0] - r, before[1] - a), (after[0] - r, after[1] - a)
        length_in, length_out = math.hypot(*into), math.hypot(*out)
        start = (r + into[0] / length_in * corner, a + into[1] / length_in * corner)
        end = (r + out[0] / length_out * corner, a + out[1] / length_out * corner)
        for k in range(CORNER_STEPS + 1):
            t = k / CORNER_STEPS
            section.append(
                (
                    (1 - t) ** 2 * start[0] + 2 * (1 - t) * t * r + t * t * end[0],
                    (1 - t) ** 2 * start[1] + 2 * (1 - t) * t * a + t * t * end[1],
                )
            )
    verts = []
    for step in range(AROUND):
        angle = 2 * math.pi * step / AROUND
        for r, a in section:
            verts.append(_blender_point(r * math.cos(angle), r * math.sin(angle), a))
    n = len(section)
    faces = [
        (step * n + j, step * n + (j + 1) % n, ((step + 1) % AROUND) * n + (j + 1) % n, ((step + 1) % AROUND) * n + j)
        for step in range(AROUND)
        for j in range(n)
    ]
    return _link("Housing", verts, faces)


def _torus(name: str, radius: float, thickness: float, along: float):
    import bpy

    bpy.ops.mesh.primitive_torus_add(
        major_radius=radius,
        minor_radius=thickness,
        major_segments=AROUND,
        minor_segments=TORUS_SECTION,
        location=_blender_point(0.0, 0.0, along),
        rotation=(math.radians(90), 0, 0),
    )
    return _baked(name)


def _melted(name: str, sources: list, cutter, shape: dict):
    """One smooth body: the sources' signed distances unioned and their creases filleted (Q314: melted, no sharp
    edge), the cutter taken out after so the opening stays round, meshed again."""
    import bpy

    melt = shape["melt"]
    target = _link(name, [], [])
    tree = bpy.data.node_groups.new(name + "Melt", "GeometryNodeTree")
    tree.interface.new_socket(name="Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    output = tree.nodes.new("NodeGroupOutput")
    union = tree.nodes.new("GeometryNodeSDFGridBoolean")
    union.operation = "UNION"
    cut = tree.nodes.new("GeometryNodeSDFGridBoolean")
    cut.operation = "DIFFERENCE"

    def sdf(source, into) -> None:
        info = tree.nodes.new("GeometryNodeObjectInfo")
        # Relative: the source as its modifiers leave it (the bevels).
        info.transform_space = "RELATIVE"
        info.inputs["Object"].default_value = source
        grid = tree.nodes.new("GeometryNodeMeshToSDFGrid")
        grid.inputs["Voxel Size"].default_value = melt["voxel"]
        grid.inputs["Band Width"].default_value = 4
        tree.links.new(info.outputs["Geometry"], grid.inputs["Mesh"])
        tree.links.new(grid.outputs["SDF Grid"], into)
        source.hide_render = True
        source.hide_viewport = True

    for source in sources:
        sdf(source, union.inputs["Grid 2"])
    sdf(cutter, cut.inputs["Grid 2"])
    fillet = tree.nodes.new("GeometryNodeSDFGridFillet")
    fillet.inputs["Iterations"].default_value = melt["fillet"]
    to_mesh = tree.nodes.new("GeometryNodeGridToMesh")
    to_mesh.inputs["Threshold"].default_value = 0.0
    tree.links.new(union.outputs["Grid"], fillet.inputs["Grid"])
    tree.links.new(fillet.outputs["Grid"], cut.inputs["Grid 1"])
    tree.links.new(cut.outputs["Grid"], to_mesh.inputs["Grid"])
    tree.links.new(to_mesh.outputs["Mesh"], output.inputs[0])
    target.modifiers.new("Melt", "NODES").node_group = tree
    return target


def _triangles(obj) -> tuple[list, list]:
    """The object as its modifiers leave it: its points in Roblox's axes and its triangles."""
    import bpy

    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    positions = [meshkit.to_roblox(tuple(vertex.co)) for vertex in mesh.vertices]
    triangles = [tuple(triangle.vertices) for triangle in mesh.loop_triangles]
    evaluated.to_mesh_clear()
    return positions, triangles


def _decimated(name: str, positions: list, triangles: list, target: int) -> tuple[list, list]:
    """The mesh collapsed to about `target` triangles, from its canonical order so the collapse runs the same way
    on every build."""
    positions, triangles = meshkit.canonical_mesh(positions, triangles)
    if len(triangles) <= target:
        return positions, triangles
    # Back into Blender's axes for the collapse (meshkit.to_roblox's inverse: a turn back about X).
    obj = _link(name + "Collapse", [(x, -z, y) for x, y, z in positions], triangles)
    decimate = obj.modifiers.new("Collapse", "DECIMATE")
    decimate.decimate_type = "COLLAPSE"
    decimate.ratio = target / len(triangles)
    return meshkit.canonical_mesh(*_triangles(obj))


def _piece(name: str, positions: list, triangles: list) -> "meshkit.Piece":
    positions, triangles = meshkit.canonical_mesh(positions, triangles)
    return meshkit.Piece(name, positions, meshkit.vertex_normals(positions, triangles), triangles)


def _joined(*meshes: tuple[list, list]) -> tuple[list, list]:
    positions, triangles = [], []
    for points, faces in meshes:
        offset = len(positions)
        positions += points
        triangles += [tuple(corner + offset for corner in face) for face in faces]
    return positions, triangles


def build_pieces(shape: dict) -> list:
    """The goal's four meshes in the goal's frame, in Roblox's axes: the Shell (the housing and the pylon melted into
    one body, Q314-Q315), the two neon Strips down the pylon's face, the Lip (the neon ring round the housing's front,
    which glows when the goal opens) and the Band (the dark ring in the opening's bore)."""
    import bpy

    bpy.ops.wm.read_factory_settings(use_empty=True)
    opening, pylon, swell, strips = shape["opening"], shape["pylon"], shape["swell"], shape["strips"]
    foot, top = pylon["foot"] - opening["height"], pylon["top"] - opening["height"]
    housing = _housing(shape)
    body = _rounded_box(
        "Pylon",
        _blender_point(pylon["front"] + pylon["depth"] / 2, (foot + top) / 2, 0.0),
        (pylon["depth"], pylon["width"], top - foot),
        pylon["corner"],
        PYLON_SEGMENTS,
    )
    # The pylon swells round the ring's wall side, so the ring grows out of it (Q315).
    radii = swell["radii"]
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=64,
        ring_count=32,
        location=_blender_point(swell["across"], 0, 0),
        scale=(radii["across"], radii["along"], radii["up"]),
    )
    bulge = _baked("Swell")
    bpy.ops.mesh.primitive_cylinder_add(
        radius=opening["radius"], depth=2 * CUTTER_LENGTH, vertices=AROUND, rotation=(math.radians(90), 0, 0)
    )
    cutter = _baked("Cutter")
    shell = _decimated("Shell", *_triangles(_melted("Shell", [housing, body, bulge], cutter, shape)), SHELL_TRIANGLES)

    length = top - foot - 2 * strips["inset"]
    strip_meshes = [
        _triangles(
            _rounded_box(
                f"Strip{side}",
                _blender_point(pylon["front"], (foot + top) / 2, side * strips["apart"] / 2),
                (strips["depth"], strips["width"], length),
                strips["corner"],
                STRIP_SEGMENTS,
            )
        )
        for side in (-1, 1)
    ]
    lip, band = shape["lip"], shape["band"]
    return [
        _piece("Shell", *shell),
        _piece("Strips", *_joined(*strip_meshes)),
        _piece("Lip", *_triangles(_torus("Lip", lip["radius"], lip["thickness"], lip["along"]))),
        _piece("Band", *_triangles(_torus("Band", band["radius"], band["thickness"], band["along"]))),
    ]


def pieces_json(pieces: list, shape_digest: str) -> str:
    """Each piece's box in the goal's frame (its centre and size, six decimals): Roblox centres an imported mesh on
    its box, so Config.Arena places each MeshPart by it. With the sha256 of the shape file the mesh was built from:
    the Shell's melt is not byte-reproducible (Blender 5.2's SDF fillet runs in parallel and moves a few points in
    the sixth decimal between runs), so this is what ties the mesh to its numbers (a test checks it)."""
    boxes = {}
    for piece in pieces:
        centre, size = meshkit.bounds(piece.positions)
        boxes[piece.name] = {"centre": [round(c, 6) + 0.0 for c in centre], "size": [round(s, 6) + 0.0 for s in size]}
    return json.dumps({"shape": shape_digest, "pieces": boxes}, indent="\t") + "\n"


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if len(args) != 1:
        raise SystemExit("usage: blender --background --factory-startup --python build_goal.py -- <out dir>")
    out = Path(args[0])
    out.mkdir(parents=True, exist_ok=True)
    shape = load_shape(SHAPE_FILE)
    check_shape(shape)
    pieces = build_pieces(shape)
    (out / "goal.glb").write_bytes(meshkit.glb_bytes(pieces))
    digest = hashlib.sha256(SHAPE_FILE.read_bytes()).hexdigest()
    (out / PIECES_FILE.name).write_text(pieces_json(pieces, digest), encoding="utf-8", newline="\n")
    counts = ", ".join(f"{piece.name} {len(piece.triangles)}" for piece in pieces)
    print(f"build_goal: wrote {out / 'goal.glb'} ({counts} triangles) and {out / 'GoalPieces.json'}")


if __name__ == "__main__":
    main()
