"""Rebuild AstroCat with Blender 5.2. Run with --background --python and -- --draft for previews."""

import bpy
import json
import math
import sys
from mathutils import Vector, Quaternion
from pathlib import Path
from random import Random

ROOT = Path(__file__).resolve().parents[1]
ARGS = set(sys.argv[sys.argv.index("--")+1:]) if "--" in sys.argv else set()
DRAFT = "--draft" in ARGS
SWATCHES = "ivory beige seam rim rubber sole orange gold dark_visor eye_edge eye_lid glint glint_blue nose nose_top mark fur fur_warm fur_dark ear_brown ear_dark muzzle screen screen_glass latch panel liner crimson strap gold_shade tail_dark ear_ochre".split()
CAMERAS = {
    "Front": (0,-8.5,1.72), "Back": (0,8.5,1.72),
    "Left": (-8.5,0,1.72), "Right": (8.5,0,1.72),
    "ThreeQuarter_L": (-4.6,-8.0,2.40), "ThreeQuarter_R": (4.6,-8.0,2.4)
}

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.render.fps = 30
scene.frame_start, scene.frame_end = 1, 48
bpy.context.preferences.filepaths.save_version = 0

def collection(name):
    col = bpy.data.collections.new(name)
    scene.collection.children.link(col)
    return col

RIGS = collection("01 • Rig")
HEAD = collection("02 • Head and helmet")
SUIT = collection("03 • Suit and hardware")
TAIL = collection("04 • Tail")
STUDIO = collection("90 • Studio")
parts = []
weights = {}

def load_image(name, color_space="sRGB"):
    image = bpy.data.images.load(str(ROOT/"textures"/name), check_existing=True)
    image.colorspace_settings.name = color_space
    image.pack()
    image.filepath = "//textures/" + name
    return image

def material(name, rgba, rough=.75):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = rgba
    mat.use_nodes = True
    pbr = mat.node_tree.nodes.get("Principled BSDF")
    pbr.inputs["Base Color"].default_value = rgba
    pbr.inputs["Roughness"].default_value = rough
    return mat, pbr

def texture_node(mat, pbr, image, input_name):
    tree = mat.node_tree
    node = tree.nodes.new("ShaderNodeTexImage")
    node.image = image
    node.location = (-560, 250 if input_name == "Base Color" else -90)
    tree.links.new(node.outputs["Color"], pbr.inputs[input_name])
    return node

palette, pbr = material("AstroCat • Suit / detail atlas", (.71,.49,.32,1))
texture_node(palette, pbr, load_image("Suit_BaseColor.png"), "Base Color")
tree = palette.node_tree
mr = tree.nodes.new("ShaderNodeTexImage")
mr.image = load_image("Suit_MetallicRoughness.png", "Non-Color")
mr.location = (-560,-90)
split = tree.nodes.new("ShaderNodeSeparateColor")
split.location = (-300,-90)
tree.links.new(mr.outputs["Color"], split.inputs["Color"])
tree.links.new(split.outputs["Green"], pbr.inputs["Roughness"])
tree.links.new(split.outputs["Blue"], pbr.inputs["Metallic"])
paint, pbr = material("AstroCat • Hand-painted tabby", (.53,.29,.14,1), .86)
texture_node(paint, pbr, load_image("Face_BaseColor.png"), "Base Color")
for m in (palette, paint):
    m.use_backface_culling = False

def mesh(name, verts, faces, colors, bone, col=SUIT, projection=None, influence=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.validate(verbose=False)
    data.update()
    obj = bpy.data.objects.new(name, data)
    col.objects.link(obj)
    data.materials.append(paint if projection else palette)
    coords = data.uv_layers.new(name="UV0")
    for poly in data.polygons:
        if projection:
            for li in poly.loop_indices:
                x, _, z = data.vertices[data.loops[li].vertex_index].co
                coords.data[li].uv = ((x/.948+1)*.5, ((z-2.123)/.636+1)*.5)
        else:
            swatch = SWATCHES.index(colors if isinstance(colors,str) else colors[poly.index])
            corners = [(0,0), (1,0), (1,1), (0,1)]
            for i, li in enumerate(poly.loop_indices):
                # Each region tiles inside its own atlas cell with a 14 px gutter.
                u,v = corners[i%4] if len(poly.loop_indices) <= 4 else (
                    .5+.5*math.cos(i*math.tau/len(poly.loop_indices)),
                    .5+.5*math.sin(i*math.tau/len(poly.loop_indices)))
                coords.data[li].uv = ((swatch%8+(14+36*u)/64)/8,
                                      1-(swatch//8+(14+36*v)/64)/8)
    # Recalculate outside normals for each independently modeled part.
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    # The face is an open cap, so its visible side is explicitly oriented to -Y.
    if projection and sum(p.normal.y for p in data.polygons) > 0:
        for p in data.polygons:
            p.flip()
    parts.append(obj)
    weights[obj.name] = (bone, influence)
    return obj

def loft(name, rings, mats, bone, col=SUIT, caps=True, influence=None):
    n = len(rings[0])
    faces, palette_indices = [], []
    for j in range(len(rings)-1):
        for i in range(n):
            nxt = (i+1)%n
            faces.append((j*n+i, j*n+n+i, j*n+n+nxt, j*n+nxt))
            choice = mats[j]
            palette_indices.append(choice(i) if callable(choice) else choice)
    if caps:
        faces.extend([tuple(reversed(range(n))), tuple(range((len(rings)-1)*n,len(rings)*n))])
        palette_indices.extend([palette_indices[0], palette_indices[-1]])
    return mesh(name, [p for ring in rings for p in ring], faces, palette_indices,
                bone, col, influence=influence)

def tube(name, path, mats, bone, col=SUIT, n=12, influence=None, flatten=1.0):
    rings = []
    for k,(center, rx, ry) in enumerate(path):
        base = Vector(center)
        tangent = Vector(path[min(len(path)-1,k+1)][0])-Vector(path[max(0,k-1)][0])
        tangent.normalize()
        side = tangent.cross(Vector((0,1,0))).normalized()
        if side.length < .5:
            side = Vector((1,0,0))
        other = tangent.cross(side).normalized()
        rings.append([base + side*(math.cos(t)*rx) + other*(ry*math.sin(t)*flatten)
                      for t in [math.tau*i/n for i in range(n)]])
    return loft(name, rings, mats, bone, col, influence=influence)

def rounded(name, center, dimensions, bevel_size, ink, bone, col=SUIT, angles=None, segments=2):
    bpy.ops.mesh.primitive_cube_add()
    cube = bpy.context.object
    cube.name = name
    for old in list(cube.users_collection):
        old.objects.unlink(cube)
    col.objects.link(cube)
    for v in cube.data.vertices:
        for i in range(3):
            v.co[i] *= dimensions[i]*.5
    mod = cube.modifiers.new("Manufactured chamfer", "BEVEL")
    mod.width, mod.segments = bevel_size, segments
    evaluated = cube.evaluated_get(bpy.context.evaluated_depsgraph_get())
    co = [v.co.copy() for v in evaluated.data.vertices]
    fs = [tuple(f.vertices) for f in evaluated.data.polygons]
    bpy.data.objects.remove(cube, do_unlink=True)
    rot = angles.to_matrix() if angles else None
    return mesh(name,[Vector(center)+(rot@v if rot else v) for v in co],fs,ink,bone,col)

def ball(name, center, dimensions, ink, bone, col=SUIT, segments=12, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings)
    raw = bpy.context.object
    co = [Vector(center)+Vector(tuple(v.co[j]*dimensions[j] for j in range(3)))
          for v in raw.data.vertices]
    fs = [tuple(f.vertices) for f in raw.data.polygons]
    bpy.data.objects.remove(raw,do_unlink=True)
    return mesh(name,co,fs,ink,bone,col)

def profile(t):
    x,z = math.cos(t), math.sin(t)
    return x*(1+.065*max(-z,0)), math.copysign(abs(z)**.91,z)

def helmet():
    dims = [
        (.675,.22,.23,2.20),(.62,.51,.42,2.19),(.49,.79,.60,2.17),
        (.24,1.04,.73,2.15),(-.13,1.126,.791,2.16),(-.49,1.121,.797,2.16),
        (-.755,1.069,.773,2.157),(-.867,1.028,.740,2.144),
        (-.885,.949,.633,2.123),(-.818,.915,.614,2.122),(-.702,.907,.622,2.128)
    ]
    n=32
    rings=[]
    for y,w,h,c in dims:
        ring=[]
        for i in range(n):
            t=math.tau*i/n
            x,z=profile(t)
            depth=y
            if y < -.60:
                depth += .055*abs(x) - .019*z
            ring.append((x*w,depth,c+z*h))
        rings.append(ring)
    # Shell remains open around the face. Rear is a concave closed dome.
    ring_colors = ["beige","ivory","ivory","ivory","ivory","beige",
                   lambda i:"ivory" if i < 17 else "beige", "rim", "seam", "liner"]
    shell=loft("Helmet • shell and rolled aperture",rings,ring_colors,"head",HEAD,caps=False)
    close = list(reversed(rings[0]))
    mesh("Helmet • rear inset",close,[tuple(range(n))],"beige","head",HEAD)
    for side in (-1,1):
        suffix="L" if side>0 else "R"
        y,z=-.189,2.085
        path=[((side*a,y,z),r,r*.86) for a,r in
              [(1.018,.24),(1.076,.294),(1.144,.307),(1.219,.271),(1.247,.233),
               (1.262,.192),(1.273,.132)]]
        # Ear-cup shaft is X, so the two elliptical radii span Z and Y.
        tube("Helmet • ear cup."+suffix,path,["seam","beige","ivory","rim","ivory","rim"],
             "head",HEAD, n=16)
        rounded("Helmet • cup latch."+suffix,(side*1.08,-.16,1.841),(.12,.29,.16),
                .028,"beige","head",HEAD)
    # A rigid enamel stamp follows the shallow angle of the brow.
    points=[]
    for i in range(10):
        angle=math.pi/2+i*math.tau/10
        radius=.105 if i%2==0 else .052
        x,z=math.cos(angle)*radius*1.30,2.823+math.sin(angle)*radius
        y=-.928+max(0,z-2.80)*.46
        points.append((x,y,z))
    front=[(x,y-.025,z) for x,y,z in points]
    faces=[(i,(i+1)%10,(i+1)%10+10,i+10) for i in range(10)]
    faces += [(10+i,10+(i+1)%10,20) for i in range(10)]
    faces.append(tuple(reversed(range(10))))
    mesh("Helmet • five-point enamel star",points+front+[(0,-.954,2.823)],faces,
         ["gold_shade"]*10+["gold"]*10+["gold_shade"],"head",HEAD)
    # Rear decal lives on the helmet itself, with a projected UV island.
    project_rear(shell)
    project_rear(bpy.data.objects["Helmet • rear inset"], force=True)

def project_rear(obj, force=False):
    data = obj.data
    uv = data.uv_layers.active.data
    for face in data.polygons:
        if not force and min(data.vertices[i].co.y for i in face.vertices) < .238:
            continue
        for loop in face.loop_indices:
            x,_,z=data.vertices[data.loops[loop].vertex_index].co
            s=min(.986,max(.014, (x/1.20+1)*.5))
            t=min(.986,max(.014, (z-1.35)/1.66))
            uv[loop].uv=(s/4,t/8)


def ears():
    for sign in (-1,1):
        suffix="L" if sign>0 else "R"
        outline=[(.49,.045,2.59),(.50,.087,2.876),(.72,.035,3.143),
                 (1.024,.054,3.366),(1.066,.075,3.327),(1.127,.049,3.045),
                 (1.123,-.003,2.866),(.993,-.108,2.59)]
        center=Vector((.894,-.024,2.913))
        loops=[]
        for f,depth in ((.91,.184),(1,.018),(.83,-.075),(.62,.042)):
            row=[]
            for p in outline:
                v=center+(Vector(p)-center)*f
                v.x*=sign
                v.y+=depth
                row.append(v)
            loops.append(row)
        loft("Tabby • faceted ear."+suffix,loops,["fur","fur_warm",
             lambda i:["ear_ochre","ear_brown","ear_brown","ear_ochre",
                        "fur_dark","ear_brown","ear_dark","ear_dark"][i]],
             "head",HEAD,caps=False)
        back=loops[0]
        mesh("Tabby • outer ear."+suffix,back,[tuple(range(len(back)))],"fur","head",HEAD)
        inner=loops[-1]
        floor=Vector((sign*.91,.096,2.93))
        f=[(i,(i+1)%len(inner),len(inner)) for i in range(len(inner))]
        mesh("Tabby • ear well."+suffix,inner+[floor],f,
             ["ear_dark","ear_dark","ear_brown","ear_brown","ear_dark",
              "ear_dark","ear_dark","ear_dark"],"head",HEAD)

def face_y(x,z):
    r=(x/.948)**2+((z-2.123)/.636)**2
    snout=.045*math.exp(-((x/.30)**2+((z-1.885)/.21)**2))
    return -.946+.217*r-snout

def face():
    n=32
    verts=[(0,face_y(0,2.123),2.123)]
    faces=[]
    for j,r in enumerate((.17,.33,.50,.66,.82,.93,1.0)):
        for i in range(n):
            t=math.tau*i/n + (math.pi/n if j%2 else 0)
            px,pz=profile(t)
            x,z=px*.948*r,2.123+pz*.636*r
            verts.append((x,face_y(x,z),z))
        for i in range(n):
            nxt=(i+1)%n
            if j==0:
                faces.append((0,1+i,1+nxt))
                continue
            a,b=1+(j-1)*n+i,1+(j-1)*n+nxt
            c,d=1+j*n+i,1+j*n+nxt
            faces.extend([(a,c,d),(a,d,b)] if (j+i)%2 else [(a,c,b),(b,c,d)])
    mesh("Tabby • face wrap",verts,faces,"fur","head",HEAD,projection=True)

def eyes():
    outline=[(-.97,-.31),(-.99,.29),(-.69,.77),(-.27,1),(.27,.95),(.68,.70),
             (.98,.25),(1.0,-.32),(.67,-.75),(.24,-.98),(-.36,-.90),(-.76,-.65)]
    for sign in (-1,1):
        x0,z0=sign*.407,2.204
        suffix="L" if sign>0 else "R"
        rings=[]
        for factor, depth in ((1.10,.017),(1.048,.050),(.975,.077),(.91,.091),
                              (.66,.102),(.33,.107),(.095,.111)):
            r=[]
            for u,v in outline:
                x=x0+sign*u*.281*factor
                z=z0+v*.263*factor
                r.append((x,face_y(x,z)-depth,z))
            rings.append(r)
        loft("Tabby • eye inset."+suffix,rings,["eye_edge","eye_lid","rim",
                                                "dark_visor","dark_visor","dark_visor"],
             "head",HEAD,caps=False)
        last=rings[-1]
        co=last+[(x0,face_y(x0,z0)-.113,z0)]
        mesh("Tabby • pupil."+suffix,co,[(i,(i+1)%len(last),len(last)) for i in range(len(last))],
             "dark_visor","head",HEAD)
        for idx,(xoff,zoff,sz,col) in enumerate(((.071,.131,.045,"glint"),
                                                 (.101,.110,.014,"glint"),
                                                 (-.144,.036,.017,"glint_blue"))):
            x,z=x0+xoff,z0+zoff
            offset=.114 if idx<2 else .106
            glint=ball("Tabby • eye catchlight.%s.%d"%(suffix,idx),
                       (x,face_y(x,z)-offset,z),(sz,.008,sz*.76),col,"head",HEAD,
                       segments=9,rings=5)
            # A subtle tilt keeps the painted highlight off the sclera outline.
            glint["detail"]="Painted, low-sheen highlight"

def face_stroke(name, coords, stroke, widths):
    path=[((x,face_y(x,z)-.014,z),w,w*.65) for (x,z),w in zip(coords,widths)]
    return tube(name,path,[stroke]*(len(path)-1),"head",HEAD,n=5)

def muzzle():
    nose_verts=[(-.117,-.990,1.968),(-.066,-1.028,1.995),(0,-1.048,1.997),
                (.077,-1.025,1.988),(.116,-.990,1.961),(.047,-1.067,1.921),
                (0,-1.077,1.906),(-.062,-1.059,1.93),(0,-1.088,1.958)]
    mesh("Tabby • sculpted nose",nose_verts,
         [(i,(i+1)%8,8) for i in range(8)]+[tuple(reversed(range(8)))],
         ["nose_top","nose_top","nose_top","nose","nose","nose","nose","nose","nose"],
         "head",HEAD)
    face_stroke("Tabby • mouth seam",[(0,1.923),(0,1.794)],"mark",[.014,.015])
    for sign in (-1,1):
        face_stroke("Tabby • smile",[(0,1.797),(.106*sign,1.738),(.188*sign,1.75)],
                    "mark",[.012,.015,.007])
        for row,coords in enumerate((
            [(.279,1.929),(.431,1.942),(.631,1.924),(.733,1.899)],
            [(.278,1.879),(.452,1.857),(.634,1.822),(.708,1.805)],
            [(.263,1.831),(.441,1.779),(.562,1.721),(.635,1.680)])):
            face_stroke("Tabby • whisker.%s%d"%("L" if sign>0 else "R",row+1),
                        [(x*sign,z) for x,z in coords],"mark",[.008,.015,.013,.004])
        for x,z in [(.267,1.905),(.301,1.865),(.263,1.853)]:
            ball("Tabby • whisker follicle",(sign*x,face_y(sign*x,z)-.006,z),
                 (.015,.009,.011),"strap","head",HEAD,segments=7,rings=4)

def load_module(name):
    path=ROOT/"scripts"/name
    exec(compile(path.read_text(encoding="utf-8"),str(path),"exec"),globals())

load_module("suit.py")
load_module("rig_and_studio.py")
helmet()
ears()
face()
eyes()
muzzle()
astronaut_suit()
cat_tail()
rig=rig_character()
animate(rig)
studio()
print("ASTROCAT", json.dumps(stats(rig)), flush=True)
if not DRAFT:
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"AstroCat.blend"))
    export_character(rig)
if "--skip-renders" not in ARGS:
    render_views()
