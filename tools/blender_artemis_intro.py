"""Build the opening film. Blender --background --python-exit-code 1 --python this_file -- OUTPUT [--preview]."""

import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
ARGS = sys.argv[sys.argv.index("--") + 1 :]
OUTPUT = Path(ARGS[0]).resolve()
PREVIEW = "--preview" in ARGS
OUTPUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1920
scene.render.resolution_y = 1080
scene.render.resolution_percentage = 48 if PREVIEW else 100
scene.render.fps = 24
scene.frame_start, scene.frame_end = 1, 480
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGB"
scene.render.image_settings.compression = 12
scene.view_settings.view_transform = "Standard"
scene.eevee.taa_render_samples = 4 if PREVIEW else 8

rng = random.Random(852)


def rgb(value):
    srgb = [int(value[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c < 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb)


def toon(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb(color), 1)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    diffuse = nodes.new("ShaderNodeBsdfDiffuse")
    shade = nodes.new("ShaderNodeShaderToRGB")
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    ramp.color_ramp.elements[0].color = tuple(c * f for c, f in zip(rgb(color), (.60, .68, .77))) + (1,)
    ramp.color_ramp.elements[1].position = .47
    ramp.color_ramp.elements[1].color = (*rgb(color), 1)
    output = nodes.new("ShaderNodeOutputMaterial")
    links.new(diffuse.outputs[0], shade.inputs[0])
    links.new(shade.outputs[0], ramp.inputs[0])
    links.new(ramp.outputs["Color"], output.inputs["Surface"])
    return mat


def emissive(name, color, strength):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    tree = mat.node_tree
    tree.nodes.clear()
    light = tree.nodes.new("ShaderNodeEmission")
    light.inputs["Color"].default_value = (*rgb(color), 1)
    light.inputs["Strength"].default_value = strength
    tree.links.new(light.outputs[0], tree.nodes.new("ShaderNodeOutputMaterial").inputs["Surface"])
    return mat, light.inputs["Strength"]


def empty(name, location=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    scene.collection.objects.link(obj)
    obj.parent, obj.location = parent, location
    return obj


def finish(obj, name, location, mat, parent):
    obj.name, obj.parent, obj.location = name, parent, location
    obj.data.materials.append(mat)
    return obj


def ico(name, location, scale, mat, parent=None, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions)
    obj = finish(bpy.context.object, name, location, mat, parent)
    obj.scale = scale
    return obj


def box(name, location, dimensions, mat, parent=None, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.object
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Bordes suaves", "BEVEL")
        modifier.width, modifier.segments = bevel, 2
    return finish(obj, name, location, mat, parent)


def cone(name, location, lower, upper, length, mat, parent=None, sides=24):
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=lower, radius2=upper, depth=length)
    return finish(bpy.context.object, name, location, mat, parent)


def mesh(name, vertices, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    data.materials.append(mat)
    return obj


def keys(obj, field, values):
    for frame, value in values:
        setattr(obj, field, value)
        obj.keyframe_insert(data_path=field, frame=frame, group=field)


def glow_keys(socket, values):
    for frame, strength in values:
        socket.default_value = strength
        socket.keyframe_insert(data_path="default_value", frame=frame)


def scale_keys(obj, values):
    keys(obj, "scale", [(frame, (size, size, size)) for frame, size in values])


def rad(turn):
    return math.radians(turn)


sky = bpy.data.worlds.new("Espacio mate")
scene.world = sky
sky.use_nodes = True
sky.node_tree.nodes.get("Background").inputs[0].default_value = (*rgb("171820"), 1)
sky.node_tree.nodes.get("Background").inputs[1].default_value = 1

sunlight = bpy.data.lights.new("Sol", "SUN")
sunlight.energy = 2.5
sun = bpy.data.objects.new("Sol", sunlight)
scene.collection.objects.link(sun)
sun.rotation_euler = (rad(24), rad(-32), rad(-34))
fill_data = bpy.data.lights.new("Luz celeste", "SUN")
fill_data.energy = .63
fill_data.color = (.59, .79, 1)
fill = bpy.data.objects.new("Luz celeste", fill_data)
scene.collection.objects.link(fill)
fill.rotation_euler = (rad(56), rad(48), 0)

cream = toon("Cerámica crema", "EAE3D2")
orange = toon("Naranja de misión", "E87A35")
ink = toon("Resina azul noche", "26374F")
glass = toon("Ventana azul marina", "337A9B")
dust = toon("Polvo de ignición", "98A2AD")
moon_mat = toon("Regolito", "5A5D64")
stone = [toon("Roca lunar " + c, c) for c in ("7A7E89", "9293A0", "565967")]
rim = toon("Borde de cráter", "7C8190")
crater = toon("Interior de cráter", "414551")
blue = toon("Vidrio fotovoltaico", "236895")
solar, solar_emission = emissive("Celdas cian", "38E5FF", 3.5)
fire, _ = emissive("Pluma naranja", "FF7B29", 3.7)
jet, _ = emissive("Pluma cian", "38E5FF", 3.1)
hot, _ = emissive("Núcleo caliente", "FFE0A3", 4.2)
starlight, _ = emissive("Estrellas", "D4DFF1", .92)


def stars():
    vertices, faces = [], []
    for _ in range(850):
        azimuth = rng.uniform(0, math.tau)
        z = rng.uniform(-.52, 1)
        horiz = math.sqrt(1 - z * z)
        p = Vector((105 * horiz * math.cos(azimuth), 105 * horiz * math.sin(azimuth), 28 + z * 105))
        size = rng.choices((.10, .18, .27), (7, 3, 1))[0]
        index = len(vertices)
        vertices.extend(p + Vector(o) * size for o in ((-1, 0, 0), (0, 0, 1), (1, 0, 0), (0, 0, -1)))
        faces.append((index, index + 1, index + 2, index + 3))
    mesh("Campo estelar", vertices, faces, starlight)


stars()
earth = ico("Earth_Curvature", (0, 0, -15), (15, 15, 15), toon("Océano", "3677A2"), subdivisions=5)


def earth_patch(name, azimuth, latitude, width, height, mat):
    def project(a, b):
        elevation, heading = rad(b), rad(a)
        the_rad = 15.035
        return (
            the_rad * math.cos(elevation) * math.cos(heading),
            the_rad * math.cos(elevation) * math.sin(heading),
            -15 + the_rad * math.sin(elevation),
        )
    vertices = [project(azimuth, latitude)]
    for i in range(32):
        angle = math.tau * i / 32
        factor = 1 + .16 * math.sin(angle * 3) + .10 * math.cos(angle * 5)
        vertices.append(project(azimuth + width * math.cos(angle) * factor, latitude + height * math.sin(angle) * factor))
    faces = [(0, i + 1, ((i + 1) % 32) + 1) for i in range(32)]
    obj = mesh(name, vertices, faces, mat)
    # Keep the patches above the curved terrain between perimeter vertices.
    bpy.context.view_layer.objects.active = obj
    subdivide = obj.modifiers.new("Proyección terrestre", "SUBSURF")
    subdivide.subdivision_type = "SIMPLE"
    subdivide.levels = subdivide.render_levels = 2
    shrink = obj.modifiers.new("Piel terrestre", "SHRINKWRAP")
    shrink.target = earth
    shrink.wrap_mode = "OUTSIDE_SURFACE"
    shrink.offset = .024


green = toon("Continentes", "519979")
mint = toon("Islas", "79AF83")
cloud_color = toon("Nubes altas", "C0D1CA")
for spec in [(-66, 43, 26, 22, green), (-113, 28, 22, 19, mint), (-58, 8, 13, 27, green), (25, 37, 25, 20, green), (56, 64, 26, 10, mint), (-25, 65, 35, 4, cloud_color), (-138, 37, 32, 5, cloud_color)]:
    earth_patch("Relieve terrestre", *spec)

pad = cone("Plataforma terrestre", (0, 0, .035), 2.1, 2.0, .17, ink, sides=12)
cone("Círculo de partida", (0, 0, .132), 1.45, 1.45, .027, orange, sides=24)
cone("Centro de plataforma", (0, 0, .153), 1.21, 1.21, .024, glass, sides=24)

moon_x, moon_z, moon_radius = 18, 43, 12
ico("Moon_Curvature", (moon_x, 0, moon_z), (12, 12, 12), moon_mat, subdivisions=5)


def surface(x, y):
    return moon_z + math.sqrt(max(0, moon_radius**2 - (x - moon_x)**2 - y**2))


def lunar_crater(x, y, radius):
    vertices = [(x, y, surface(x, y) + .028)]
    sides = 18
    for spread, lift in ((.62, .025), (.80, .105), (1.0, .035)):
        for n in range(sides):
            angle = math.tau * n / sides
            xx = x + radius * spread * math.cos(angle)
            yy = y + radius * spread * math.sin(angle)
            vertices.append((xx, yy, surface(xx, yy) + lift))
    faces = [(0, (i + 1) % sides + 1, i + 1) for i in range(sides)]
    for band in range(2):
        for i in range(sides):
            start = 1 + band * sides
            following = (i + 1) % sides
            faces.append((start + i, start + following, start + sides + following, start + sides + i))
    obj = mesh("Cráter", vertices, faces, crater)
    obj.data.materials.append(rim)
    for polygon in obj.data.polygons:
        polygon.material_index = int(polygon.index >= sides)


for spec in [(14.6, -.2, .74), (16.9, -1.65, .42), (20.8, -.95, .83), (20, 2.0, .57),
             (17.2, 2.5, 1.07), (22.2, 1.6, 1.04), (14, 2.2, .7), (18.2, 4, .9), (21, -2.9, .61),
             (13, -1.6, .48), (18.4, -2.75, .7), (23, -3.9, .68)]:
    lunar_crater(*spec)
for i in range(52):
    x, y = moon_x + rng.uniform(-6.6, 6.6), rng.uniform(-4.9, 6.7)
    if abs(x - 16.75) < .72 and abs(y + 1.1) < .9 or abs(x - 19.4) < .82 and abs(y) < .85:
        continue
    size = rng.uniform(.065, .24)
    rock = ico("Fragmento de regolito", (x, y, surface(x, y) + .02), (size * 1.3, size, size * .53), rng.choice(stone), subdivisions=1)
    rock.rotation_euler.z = rng.uniform(0, math.tau)

rocket = empty("Rocket_Capsule")
cone("Casco de cápsula", (0, 0, .99), .61, .47, 1.22, cream, rocket)
cone("Morro", (0, 0, 1.79), .47, .11, .41, orange, rocket)
cone("Anillo de acoplamiento", (0, 0, 2), .115, .115, .08, ink, rocket)
cone("Cinturón naranja", (0, 0, .66), .628, .587, .19, orange, rocket)
cone("Escudo térmico", (0, 0, .30), .73, .61, .22, ink, rocket)
cone("Tobera", (0, 0, .145), .30, .36, .22, ink, rocket)
port = cone("Ojo de buey", (0, -.535, 1.27), .242, .242, .11, ink, rocket)
port.rotation_euler.x = rad(83)
port = cone("Cristal de cápsula", (0, -.597, 1.27), .185, .185, .07, glass, rocket)
port.rotation_euler.x = rad(83)
for angle in (0, 120, 240):
    angle = rad(angle)
    foot = box("Pata de aterrizaje", (.62 * math.cos(angle), .62 * math.sin(angle), .21), (.36, .13, .17), orange, rocket, .04)
    foot.rotation_euler.z = angle
    shoe = cone("Apoyo de cápsula", (.78 * math.cos(angle), .78 * math.sin(angle), .065), .16, .125, .11, ink, rocket, 6)
    shoe.rotation_euler.z = angle
launch_flame = empty("Ignición naranja", (0, 0, .12), rocket)
landing_flame = empty("Frenado cian", (0, 0, .12), rocket)
for anchor, color in ((launch_flame, fire), (landing_flame, jet)):
    cone("Pluma", (0, 0, -.90), .025, .33, 1.8, color, anchor, 12)
    cone("Núcleo", (0, 0, -.29), .025, .19, .60, hot if anchor == launch_flame else color, anchor, 12)
scale_keys(launch_flame, [(1, .001), (29, .001), (39, .36), (48, .92), (81, 1), (120, .74), (169, .29), (188, .001)])
scale_keys(landing_flame, [(1, .001), (202, .001), (216, .70), (236, .92), (253, .53), (264, .001)])

for i in range(15):
    angle = i * 2.39996
    v = Vector((math.cos(angle), math.sin(angle), 0))
    plume = ico("Nube de despegue", (*(.31 * v.xy), .23), (1, 1, 1), dust, subdivisions=2)
    start = 19 + i % 11
    spread = rng.uniform(1.1, 2.15)
    keys(plume, "location", [(1, (.12 * v.x, .12 * v.y, .28)), (start + 21, (*v.xy, .40)), (start + 46, (*(v.xy * spread), .37)), (107, (*(v.xy * (spread + .5)), .34))])
    scale_keys(plume, [(1, .001), (start, .001), (start + 22, rng.uniform(.27, .61)), (85, .31), (107, .001)])

landing = (20.4, 3.20)
landing_height = surface(*landing) - .033
lunar_up = Vector((landing[0] - moon_x, landing[1], surface(*landing) - moon_z)).normalized()
landing_rotation = lunar_up.to_track_quat("Z", "Y").to_euler()
keys(rocket, "location", [
    (1, (0, 0, .17)), (26, (0, 0, .17)), (31, (.028, -.017, .19)),
    (36, (-.026, .014, .17)), (40, (.017, 0, .20)), (45, (0, 0, .23)),
    (66, (.20, 0, 1.7)), (90, (1.2, .18, 9.4)), (120, (3.8, .42, 19.8)),
    (150, (6.1, 1.25, 37)), (180, (10.0, 1.8, 56.5)), (207, (19.3, 2.80, 61.0)),
    (224, (20.25, 3.19, 59.1)), (246, (20.4, 3.20, 55.98)), (264, (*landing, landing_height)),
    (480, (*landing, landing_height)),
])
keys(rocket, "rotation_euler", [(1, (0, 0, 0)), (70, (0, rad(6), 0)), (120, (0, rad(13), rad(-7))), (170, (0, rad(17), rad(-12))), (209, (0, rad(-9), rad(12))), (238, (0, rad(3), rad(6))), (264, landing_rotation), (480, landing_rotation)])

# Astronaut and solar head share the landing clearing.
hero = empty("Astronaut_Char")
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/pilotos/gato-modelo2.glb"))
cat_nodes = set(bpy.data.objects) - before
for obj in cat_nodes:
    if obj.users_collection and obj.parent not in cat_nodes:
        obj.parent = hero
rig = next(obj for obj in cat_nodes if obj.type == "ARMATURE")
cat_mesh = next(
    obj for obj in cat_nodes
    if obj.type == "MESH" and any(modifier.type == "ARMATURE" for modifier in obj.modifiers)
)
bpy.context.view_layer.update()
bounds = [cat_mesh.matrix_world @ vertex.co for vertex in cat_mesh.data.vertices]
bottom = min(point.z for point in bounds)
model_height = max(point.z for point in bounds) - bottom
size = 1.2 / model_height
keys(cat_mesh, "hide_render", [(1, True), (270, True), (271, False)])
ground_hero = surface(16.75, -1.18)
hero_base = ground_hero - bottom * size + .006
keys(hero, "location", [
    (1, (*landing, landing_height + .40)), (264, (*landing, landing_height + .40)),
    (274, (19.8, 2.12, hero_base + .59)), (289, (17.61, .52, hero_base + .77)),
    (306, (16.75, -1.18, hero_base)), (313, (16.75, -1.18, hero_base - .080)),
    (322, (16.75, -1.18, hero_base + .025)), (330, (16.75, -1.18, hero_base)), (480, (16.75, -1.18, hero_base)),
])
keys(hero, "rotation_euler", [(1, (0, 0, rad(158))), (275, (0, 0, rad(185))), (320, (0, 0, rad(211)))])
keys(hero, "scale", [
    (1, (size, size, size)), (271, (size, size, size)),
    (301, (size * .96, size * .96, size * 1.06)), (313, (size * 1.07, size * 1.07, size * .85)),
    (322, (size * .99, size * .99, size * 1.05)), (330, (size, size, size)),
    (385, (size, size, size)), (421, (size, size, size * 1.018)), (480, (size, size, size)),
])
for name, poses in {
    "Head": [(271, 0), (289, -9), (313, 5), (338, 0), (385, 0), (425, 5), (480, 0)],
    "Tail": [(271, 0), (292, 15), (316, -9), (338, 0), (385, 0), (410, -7), (451, 7), (480, 0)],
    "TailTip": [(271, 0), (292, -17), (316, 10), (338, 0), (385, 0), (410, -8), (453, 8), (480, 0)],
    "Torso": [(271, 0), (303, 7), (313, 8), (335, 0), (385, 0), (434, 1.8), (480, 0)],
    "ShoulderL": [(271, 0), (287, -25), (309, 14), (336, 0)],
    "ShoulderR": [(271, 0), (287, -34), (308, -10), (329, 0), (355, -13), (382, 0)],
    "ElbowR": [(271, 0), (287, 18), (312, -8), (334, 0), (355, 19), (382, 0)],
    "HipL": [(271, 0), (293, 20), (309, -5), (331, 0)],
    "KneeL": [(271, 0), (292, -24), (313, 15), (331, 0)],
    "HipR": [(271, 0), (291, -19), (309, 9), (332, 0)],
    "KneeR": [(271, 0), (290, 20), (313, -14), (333, 0)],
}.items():
    bone = rig.pose.bones[name]
    bone.rotation_mode = "XYZ"
    axis = 2 if name.startswith("Tail") else 0
    keys(bone, "rotation_euler", [(frame, tuple(rad(angle) if i == axis else 0 for i in range(3))) for frame, angle in poses])

panel_x, panel_y = 19.55, .33
panel = empty("Solar_Panel", (panel_x, panel_y, surface(panel_x, panel_y) + .045))
cone("Columna naranja", (0, 0, .64), .108, .083, 1.27, orange, panel, 10)
for angle in (28, 148, 268):
    a = rad(angle)
    x, y = .47 * math.cos(a), .47 * math.sin(a)
    foot = Vector((x, y, surface(panel_x + x, panel_y + y) - panel.location.z + .0265))
    top = Vector((0, 0, .67))
    vector = top - foot
    strut = cone("Trípode", (foot + top) / 2, .035, .053, vector.length, orange, panel, 8)
    strut.rotation_euler = vector.to_track_quat("Z", "Y").to_euler()
    box("Zapato de trípode", foot, (.19, .15, .055), ink, panel, .014)
head = empty("Giro de panel", (0, 0, 1.72), panel)
head.rotation_euler.x = rad(-17)
box("Divisor central", (0, 0, 0), (.16, .14, .84), orange, head, .03)
for side in (-1, 1):
    wing = empty("Ala solar", (side * .075, 0, 0), head)
    box("Marco de ala", (side * .47, 0, 0), (.95, .12, .88), cream, wing, .033)
    box("Sustrato de ala", (side * .47, -.074, 0), (.86, .026, .80), ink, wing, .013)
    for col in range(4):
        for row in range(3):
            x = side * (.13 + col * .223)
            z = -.267 + row * .267
            box("Celda fotovoltaica", (x, -.090, z), (.196, .021, .236), blue, wing, .012)
            box("Tira de energía", (x + side * .075, -.105, z), (.018, .010, .215), solar, wing, .004)
    keys(wing, "rotation_euler", [(1, (0, 0, side * rad(98))), (320, (0, 0, side * rad(98))), (362, (0, 0, side * rad(-5))), (383, (0, 0, 0))])
scale_keys(panel, [(1, .001), (312, .001), (323, .55), (346, 1.02), (365, 1)])
keys(head, "rotation_euler", [(1, (rad(-17), 0, 0)), (385, (rad(-17), 0, 0)), (410, (rad(-17), 0, rad(8))), (455, (rad(-17), 0, rad(-8))), (480, (rad(-17), 0, 0))])
glow_keys(solar_emission, [(1, 0), (328, 0), (384, 3.5), (385, 3.5), (432, 4.5), (480, 3.5)])
panel_light = bpy.data.lights.new("Rebote del panel", "POINT")
panel_light.color = (.15, .70, 1)
panel_light.shadow_soft_size = .9
panel_lamp = bpy.data.objects.new("Rebote del panel", panel_light)
scene.collection.objects.link(panel_lamp)
panel_lamp.location = (18.70, -.42, ground_hero + 1.36)
keys(panel_light, "energy", [(1, 0), (350, 0), (385, 24), (432, 33), (480, 24)])

cat_light = bpy.data.lights.new("Luz de retrato lunar", "AREA")
cat_light.shape = "DISK"
cat_light.size = 2.7
cat_light.color = (1.0, .83, .71)
portrait_light = bpy.data.objects.new("Luz de retrato lunar", cat_light)
scene.collection.objects.link(portrait_light)
portrait_light.location = (17.8, -4.0, ground_hero + 2.5)
portrait_light.rotation_euler = (Vector((16.75, -1.18, ground_hero + .75)) - portrait_light.location).to_track_quat("-Z", "Y").to_euler()
keys(cat_light, "energy", [(1, 0), (283, 0), (323, 115), (480, 115)])

camera_data = bpy.data.cameras.new("Óptica de misión")
camera_data.clip_end = 200
camera = bpy.data.objects.new("Cámara de misión", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
target = empty("Camera_Target")
track = camera.constraints.new("TRACK_TO")
track.target, track.track_axis, track.up_axis = target, "TRACK_NEGATIVE_Z", "UP_Y"
final_target = (18.05, .33, 55.72)
final_camera_x, final_camera_y = 22.1, -8.45
final_run = math.hypot(final_camera_x - final_target[0], final_camera_y - final_target[1])
final_view = (final_camera_x, final_camera_y, final_target[2] + final_run * math.tan(rad(35)))
keys(camera, "location", [
    (1, (4.0, -7.4, 3.55)), (37, (3.66, -6.65, 3.16)), (64, (3.3, -6.9, 4.10)),
    (90, (4.6, -10.9, 12.4)), (120, (4.54, -13.6, 21.4)),
    (150, (3.8, -16, 39.7)), (180, (3.8, -13.7, 59.9)),
    (207, (12.5, -10.4, 65.7)), (230, (25.5, -6.5, 63.1)),
    (264, (25.8, -5.9, 58.9)), (288, (22.75, -7.15, 58.65)),
    (310, final_view), (385, final_view), (480, final_view),
])
keys(target, "location", [
    (1, (0, 0, .99)), (37, (0, 0, 1.04)), (64, (.30, 0, 2.34)),
    (90, (1.2, .18, 9.42)), (120, (3.8, .42, 18.9)), (150, (6.1, 1.25, 37)),
    (180, (10.5, 1.8, 55.9)), (207, (19.4, 2.80, 59.6)), (230, (20.4, 3.20, 57.3)),
    (264, (20.4, 3.20, 55.09)), (288, (18.3, .54, 55.75)),
    (310, final_target), (385, final_target), (480, final_target),
])
keys(camera_data, "lens", [(1, 49), (45, 46), (90, 43), (120, 36), (180, 35), (235, 44), (310, 50), (480, 50)])

compositor = bpy.data.node_groups.new("Bloom de la misión", "CompositorNodeTree")
scene.compositing_node_group = compositor
compositor.interface.new_socket(name="Image", in_out="OUTPUT", socket_type="NodeSocketColor")
nodes = compositor.nodes
layers = nodes.new("CompositorNodeRLayers")
glare = nodes.new("CompositorNodeGlare")
glare.inputs["Type"].default_value = "Fog Glow"
compositor.links.new(layers.outputs["Image"], glare.inputs["Image"])
output = nodes.new("NodeGroupOutput")
compositor.links.new(glare.outputs["Image"], output.inputs["Image"])
if "Threshold" in glare.inputs:
    glare.inputs["Threshold"].default_value = 1.1

scene.render.use_freestyle = True
settings = bpy.context.view_layer.freestyle_settings
lineset = settings.linesets[0] if settings.linesets else settings.linesets.new("Contornos")
style = bpy.data.linestyles.new("Contorno lunar")
lineset.linestyle = style
style.color = rgb("1E1E24")
style.thickness = 1.5
style.alpha = .84

for block in (*bpy.data.objects, *bpy.data.cameras, *bpy.data.lights, *(m.node_tree for m in bpy.data.materials if m.use_nodes)):
    animation = block.animation_data
    if animation and animation.action:
        for layer in animation.action.layers:
            for strip in layer.strips:
                bag = strip.channelbag(animation.action_slot)
                if bag:
                    for curve in bag.fcurves:
                        for point in curve.keyframe_points:
                            point.handle_left_type = point.handle_right_type = "AUTO_CLAMPED"

for name, frame in (("Tierra", 1), ("Viaje", 121), ("Alunizaje", 264), ("Despliegue", 311), ("Bucle", 385)):
    scene.timeline_markers.new(name, frame=frame)

bpy.ops.file.pack_all()
scene.frame_set(400)
evaluated = cat_mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
height_points = [evaluated.matrix_world @ vertex.co for vertex in evaluated.data.vertices]
hero_height = max(p.z for p in height_points) - min(p.z for p in height_points)
assert abs(hero_height - 1.2) < .04
print(f"Altura de astronauta a f400: {hero_height:.3f} m", flush=True)
if PREVIEW:
    for frame in (1, 90, 180, 270, 350, 385, 400, 480):
        scene.frame_set(frame)
        scene.render.filepath = str(OUTPUT / f"preview-{frame:04d}.png")
        bpy.ops.render.render(write_still=True)
else:
    scene.render.filepath = "//fotogramas/artemis-"
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / "artemis-apertura.blend"))
