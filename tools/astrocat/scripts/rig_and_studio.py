"""Rig, animation clips, studio and exports. Invoked from build_astrocat.py."""

def rig_character():
    arm = bpy.data.armatures.new("AstroCat Skeleton")
    rig = bpy.data.objects.new("AstroCat_Rig",arm)
    RIGS.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    rig.show_in_front = True
    arm.display_type = "OCTAHEDRAL"
    bpy.ops.object.mode_set(mode="EDIT")
    def bone(name, head, tail, parent=None, connected=False, deform=True):
        b=arm.edit_bones.new(name)
        b.head,b.tail=head,tail
        if parent:
            b.parent=arm.edit_bones[parent]
            b.use_connect=connected
        b.use_deform=deform
        return b
    bone("root",(0,0,0),(0,0,.36),deform=False)
    bone("hips",(0,0,.755),(0,0,.93),"root")
    bone("torso",(0,0,.93),(0,0,1.44),"hips",True)
    bone("head",(0,0,1.44),(0,0,2.55),"torso",True)
    for sign in (-1,1):
        s="L" if sign>0 else "R"
        def limb(stems,points,parent):
            for idx,stem in enumerate(stems):
                name=stem+"."+s
                bone(name,points[idx],points[idx+1],parent,idx>0)
                parent=name
        limb(["upper_arm","forearm","hand"],
             [(sign*.307,.003,1.328),(sign*.555,-.066,1.11),(sign*.681,-.136,.879),
              (sign*.734,-.171,.699)],"torso")
        limb(["thigh","shin","foot"],
             [(sign*.212,.015,.72),(sign*.314,.0,.415),(sign*.351,-.016,.21),
              (sign*.351,-.222,.083)],"hips")
    for idx,(a,b) in enumerate(zip([0,3,6,9],[3,6,9,11]),1):
        bone("tail_%d"%idx,TAIL_POINTS[a],TAIL_POINTS[b],"hips" if idx==1 else "tail_%d"%(idx-1),idx>1)
    bpy.ops.object.mode_set(mode="OBJECT")
    for obj in parts:
        primary, fanout=weights[obj.name]
        groups={}
        for v in obj.data.vertices:
            # The loft's ring width is given by the first cap or inferred from the tube.
            ring_size = 14 if "banded tail" in obj.name else 15 if "sleeve" in obj.name else 16 if "banded leg" in obj.name else 18
            assigned=fanout(v.index//ring_size,v.index%ring_size) if fanout else {primary:1}
            for name,value in assigned.items():
                if value <= 0:
                    continue
                if name not in groups:
                    groups[name]=obj.vertex_groups.new(name=name)
                groups[name].add([v.index],value,"REPLACE")
        obj.parent=rig
        mod=obj.modifiers.new("AstroCat joint deformation","ARMATURE")
        mod.object=rig
    return rig

def rotation(pb, xyz):
    result=Quaternion((1,0,0,0))
    base=pb.bone.matrix_local.to_quaternion().inverted()
    for axis, angle in zip(((1,0,0),(0,1,0),(0,0,1)),xyz):
        result=result @ Quaternion(base@Vector(axis),math.radians(angle))
    pb.rotation_mode="QUATERNION"
    pb.rotation_quaternion=result

LENGTHS={"Idle":61,"Walk":33,"Run":25,"Jump":41,"Wave":61}

def pose(rig, clip, phase):
    pb=rig.pose.bones
    for bone in pb:
        bone.location=(0,0,0)
        bone.scale=(1,1,1)
        rotation(bone,(0,0,0))
    radians=phase*math.tau
    swing=math.sin(radians)
    sway=math.cos(radians)
    def rot(bone,x=0,y=0,z=0):
        rotation(pb[bone],(x,y,z))
    def move(bone,x=0,y=0,z=0):
        pb[bone].location=pb[bone].bone.matrix_local.to_quaternion().inverted()@Vector((x,y,z))
    bob=.014*(1-sway)
    rot("torso",x=swing*1.8,y=sway*1.3)
    rot("head",x=-swing*1.1,z=sway*2.2)
    for i in range(1,5):
        wave=math.sin(radians-.67*(i-1))
        rot("tail_%d"%i,y=2.0*wave,z=3.6*wave)
    if clip in ("Walk","Run"):
        pace=1 if clip=="Walk" else 1.63
        bob=(.021 if clip=="Walk" else .064)*(1-math.cos(2*radians))
        rot("torso",x=-3.0*pace,y=2.2*sway,z=3.5*swing)
        rot("head",x=2.5*pace,y=-2.0*sway,z=-2.6*swing)
        for s,k in (("L",1),("R",-1)):
            front=k*swing
            rot("thigh."+s,x=29*front*pace,y=k*2)
            rot("shin."+s,x=44*max(0,-front)*pace)
            rot("foot."+s,x=-14*front)
            rot("upper_arm."+s,x=-19*front*pace,y=4*k,z=3*k*sway)
            rot("forearm."+s,x=-10*max(0,front)*pace)
    elif clip=="Jump":
        crouch=math.exp(-((phase-.19)/.09)**2)+.87*math.exp(-((phase-.755)/.095)**2)
        air=max(0,math.sin(math.pi*max(0,min(1,(phase-.24)/.49))))
        bob=-.15*crouch+.53*air
        rot("torso",x=-17*crouch+11*air)
        rot("head",x=9*crouch-8*air)
        for s,k in (("L",1),("R",-1)):
            rot("thigh."+s,x=-31*crouch-26*air,y=3*k)
            rot("shin."+s,x=61*crouch+48*air)
            rot("foot."+s,x=-23*crouch-18*air)
            rot("upper_arm."+s,x=21*crouch-22*air,y=-41*k*air)
            rot("forearm."+s,x=-13*air)
        rot("tail_2",y=13*air)
    elif clip=="Wave":
        lift=min(1,max(0,phase/.22),max(0,(1-phase)/.24))
        lift=lift*lift*(3-2*lift)
        rot("torso",y=-7*lift,z=-7*lift)
        rot("head",y=9*lift,z=8*lift)
        rot("upper_arm.L",x=-24*lift,y=-40*lift,z=-19*lift)
        rot("forearm.L",x=-25*lift,y=-14*lift,z=-21*lift)
        rot("hand.L",y=(-16+19*math.sin(phase*math.tau*3.8))*lift,
            z=12*math.cos(phase*math.tau*3.8)*lift)
    move("root",z=bob)

def animate(rig):
    rig.animation_data_create()
    for name, end in LENGTHS.items():
        action=bpy.data.actions.new(name)
        action.use_fake_user=True
        rig.animation_data.action=action
        frames=sorted(set(list(range(1,end,2))+[end]))
        for frame in frames:
            pose(rig,name,(frame-1)/(end-1))
            for pb in rig.pose.bones:
                for prop in ("location","rotation_quaternion","scale"):
                    pb.keyframe_insert(prop,frame=frame,group=pb.name)
        # Keep clips individually selectable. Each is a named, muted export track.
        rig.animation_data.action=None
        track=rig.animation_data.nla_tracks.new()
        track.name=name
        track.strips.new(name,1,action)
        track.mute=True
    pose(rig,"Idle",0)
    for b in rig.pose.bones:
        b.location=(0,0,0)
        b.rotation_quaternion=(1,0,0,0)
    scene.frame_set(1)

def studio():
    scene.world=bpy.data.worlds.new("AstroCat • quiet blue studio")
    scene.world.use_nodes=True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value=(.047,.067,.107,1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value=.29
    floor,pbr=material("Studio • charcoal slate",(.025,.033,.048,1),.83)
    pbr.inputs["Emission Color"].default_value=(.013,.017,.023,1)
    pbr.inputs["Emission Strength"].default_value=1.0
    backdrop_dims=[(9.0,-.012)]
    for step in range(1,9):
        theta=math.pi/2*step/8
        backdrop_dims.append((9.0+2.7*math.sin(theta),2.7*(1-math.cos(theta))-.012))
    backdrop_dims.append((11.7,10.0))
    steps=96
    backdrop_rows=[[(r*math.cos(i*math.tau/steps),r*math.sin(i*math.tau/steps),h)
                    for i in range(steps)] for r,h in backdrop_dims]
    backdrop_faces=[tuple(range(steps))]
    for row in range(len(backdrop_rows)-1):
        for i in range(steps):
            a=row*steps+i
            b=row*steps+(i+1)%steps
            backdrop_faces.append((b,a,a+steps,b+steps))
    data=bpy.data.meshes.new("Cyclorama")
    data.from_pydata([v for row in backdrop_rows for v in row],[],backdrop_faces)
    data.materials.append(floor)
    for polygon in data.polygons:
        polygon.use_smooth=True
    obj=bpy.data.objects.new("Studio • seamless cyclorama",data)
    STUDIO.objects.link(obj)
    def area(name,xyz,power,size,color,target):
        light=bpy.data.lights.new(name,"AREA")
        light.energy,light.shape,light.size,light.color=power,"DISK",size,color
        o=bpy.data.objects.new(name,light)
        STUDIO.objects.link(o)
        o.location=xyz
        o.rotation_euler=(Vector(target)-o.location).to_track_quat("-Z","Y").to_euler()
    area("Key • warm softbox",(-3.1,-4.4,6.1),510,4.0,(1,.84,.68),(0,0,1.68))
    area("Fill • orbital blue",(4.2,-2.7,3.8),230,4.1,(.68,.80,1),(0,0,1.63))
    area("Rim • topside",(1.0,3.8,5.5),660,3.2,(1,.69,.40),(0,0,1.83))
    area("Front • eye bounce",(.1,-5,1.53),51,2.7,(1,.92,.81),(0,-.22,2.1))
    for name,xyz in CAMERAS.items():
        camera=bpy.data.cameras.new(name)
        camera.type="ORTHO"
        camera.ortho_scale=3.86
        o=bpy.data.objects.new(name,camera)
        STUDIO.objects.link(o)
        o.location=xyz
        o.rotation_euler=(Vector((0,0,1.665))-o.location).to_track_quat("-Z","Y").to_euler()
    scene.render.engine="CYCLES"
    scene.cycles.samples=16 if DRAFT else 32
    scene.cycles.use_denoising=True
    scene.render.resolution_x=scene.render.resolution_y=560 if DRAFT else 1050
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.view_settings.view_transform="AgX"
    scene.view_settings.look="AgX - Medium High Contrast"
    scene.camera=bpy.data.objects["ThreeQuarter_L"]
    # When opened interactively, the editable file starts with a framed material view.
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=="VIEW_3D":
                area.spaces.active.region_3d.view_perspective="CAMERA"
                area.spaces.active.region_3d.view_camera_zoom=4
                area.spaces.active.overlay.show_overlays=False
                shading=area.spaces.active.shading
                shading.type="MATERIAL"
                shading.use_scene_world=True
                shading.use_scene_lights=True
    return obj

def render_views():
    output=ROOT / ("draft" if DRAFT else "renders")
    output.mkdir(exist_ok=True)
    views=("Front","ThreeQuarter_L","Back") if DRAFT else CAMERAS
    for name in views:
        scene.camera=bpy.data.objects[name]
        scene.render.filepath=str(output/(name+".png"))
        bpy.ops.render.render(write_still=True)
    scene.camera=bpy.data.objects["ThreeQuarter_L"]

def export_character(rig):
    # Keep the original part breakdown in the saved .blend. Combine the skinned
    # copies for both exchange formats, which keeps the runtime to two materials.
    bpy.ops.object.select_all(action="DESELECT")
    batch=[]
    for part in parts:
        copy=part.copy()
        copy.data=part.data.copy()
        RIGS.objects.link(copy)
        copy.select_set(True)
        batch.append(copy)
    combined=batch[0]
    bpy.context.view_layer.objects.active=combined
    bpy.ops.object.join()
    combined.name="AstroCat_GameMesh"
    combined.data.name="AstroCat_GameMesh"
    bpy.data.objects[rig.name].select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(ROOT/"AstroCat.glb"),export_format="GLB",
        use_selection=True,export_animations=True,export_animation_mode="ACTIONS",
        export_frame_range=False,export_force_sampling=True,export_yup=True,
        export_normals=True,export_materials="EXPORT")
    # FBX uses the same five named tracks and embeds the textures.
    bpy.ops.export_scene.fbx(filepath=str(ROOT/"AstroCat.fbx"),use_selection=True,
        object_types={"ARMATURE","MESH"},apply_unit_scale=True,add_leaf_bones=False,
        bake_anim=True,bake_anim_use_all_actions=True,bake_anim_use_nla_strips=False,
        bake_anim_simplify_factor=.4,path_mode="COPY",embed_textures=True)
    bpy.data.objects.remove(combined,do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active=rig
    scene.frame_set(1)

def stats(rig):
    triangles=0
    for part in parts:
        part.data.calc_loop_triangles()
        triangles+=len(part.data.loop_triangles)
    return {"blender":bpy.app.version_string,"triangles":triangles,"mesh_parts":len(parts),
            "deform_bones":sum(b.use_deform for b in rig.data.bones),
            "bones":len(rig.data.bones),"materials":2}
