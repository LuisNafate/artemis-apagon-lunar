"""Module executed in the Blender build namespace. Contains the suit, pack and tail."""

def astronaut_suit():
    tube("Suit • pressure body",[
        ((0,0,.59),.18,.18),((0,0,.64),.285,.23),((0,0,.77),.391,.289),
        ((0,0,.91),.409,.295),((0,0,1.05),.404,.286),((0,.009,1.23),.419,.275),
        ((0,.015,1.37),.348,.229),((0,.014,1.465),.201,.192)
    ],["beige","beige","ivory","beige","beige","ivory","ivory"],"torso",n=18,
         influence=lambda ring,idx: {"hips":1} if ring<3 else
             ({"hips":.38,"torso":.62} if ring==3 else {"torso":1}))
    tube("Suit • neck seal", [
        ((0,0,1.33),.218,.207),((0,0,1.39),.277,.25),
        ((0,0,1.48),.276,.249),((0,0,1.55),.223,.21)
    ],["beige","sole","liner"],"torso",n=16)
    tube("Suit • clasped utility belt",[
        ((0,0.0,.793),.397,.295),((0,0.0,.814),.423,.318),
        ((0,0.0,.903),.424,.318),((0,0.0,.923),.415,.304)
    ],["seam","seam","strap"],"hips",n=18)
    for x,w in [(-.319,.11),(-.183,.09),(0,.172),(.174,.075),(.302,.125)]:
        rounded("Suit • belt buckle",(x,-.325+.27*x*x,.86),
                (w,.062,.116),.015,"panel" if abs(x)>.05 else "strap","hips",segments=1)

    for side in (-1,1):
        s="L" if side>0 else "R"
        arm=[
            ((side*.26,.003,1.328),.14,.136),((side*.409,-.005,1.31),.179,.178),
            ((side*.474,-.024,1.248),.181,.179),((side*.538,-.06,1.142),.173,.173),
            ((side*.565,-.073,1.094),.164,.162),((side*.59,-.092,1.046),.161,.155),
            ((side*.642,-.113,.967),.155,.148),((side*.675,-.132,.904),.151,.149),
            ((side*.685,-.14,.868),.138,.134),
        ]
        def sleeve_weights(ring,idx,s=s):
            fraction=(0,0,0,.08,.36,.72,1,1,1)[ring]
            return {"upper_arm."+s:1-fraction,"forearm."+s:fraction}
        tube("Suit • banded sleeve."+s,arm,["ivory","ivory","ivory","orange","orange",
             "ivory","ivory","beige"],"upper_arm."+s,n=15,influence=sleeve_weights)
        tube("Suit • glove."+s,[
            ((side*.681,-.136,.885),.125,.12),((side*.704,-.152,.832),.137,.125),
            ((side*.726,-.163,.771),.140,.129),((side*.738,-.166,.705),.122,.112),
            ((side*.730,-.173,.674),.088,.079)
        ],["sole","rubber","rubber","sole"],"hand."+s,n=13)
        ball("Suit • glove thumb."+s,(side*.629,-.234,.755),(.067,.062,.088),
             "rubber","hand."+s,segments=9,rings=6)
        for j in range(2):
            rounded("Suit • knuckle panel."+s,(side*(.702+.043*j),-.278,.747+.014*j),
                    (.032,.026,.077),.012,"sole","hand."+s,segments=1)

        leg=[
            ((side*.195,.016,.729),.163,.156),((side*.244,.016,.672),.194,.181),
            ((side*.278,.012,.553),.179,.173),((side*.306,.003,.442),.172,.167),
            ((side*.327,-.005,.36),.169,.162),((side*.342,-.012,.288),.163,.156),
            ((side*.351,-.014,.214),.177,.166),((side*.351,-.01,.178),.168,.158)
        ]
        def leg_weights(ring,idx,s=s):
            fraction=(0,0,.09,.36,.72,1,1,1)[ring]
            return {"thigh."+s:1-fraction,"shin."+s:fraction}
        tube("Suit • banded leg."+s,leg,
             ["beige","ivory","ivory","orange","orange","ivory","beige"],
             "thigh."+s,n=16,influence=leg_weights)
        n=16
        boot=[]
        for h,c_y,w,d in [(0,-.055,.201,.236),(.045,-.056,.207,.242),
                          (.101,-.063,.203,.231),(.151,-.083,.192,.217),
                          (.225,-.069,.169,.17),(.25,-.027,.144,.136)]:
            boot.append([(side*.351+w*math.cos(i*math.tau/n),c_y+d*math.sin(i*math.tau/n),
                          h+(.019*max(0,math.sin(i*math.tau/n)) if h>.1 else 0)) for i in range(n)])
        loft("Suit • tread boot."+s,boot,["rubber","sole","rubber","ivory","beige"],"foot."+s)
        for x in [-.096,-.029,.037,.096]:
            rounded("Suit • toe tread."+s,(side*.351+x,-.288+1.8*x*x,.055),
                    (.038,.027,.057),.008,"sole","foot."+s,segments=1)
    electronics()

def electronics():
    from mathutils import Euler
    rounded("Control • harness mount",(-.068,-.286,1.163),(.529,.14,.388),.068,"seam","torso")
    rounded("Control • chest console",(-.081,-.376,1.144),(.496,.17,.338),.044,"rim","torso")
    rounded("Control • black display",(-.146,-.471,1.147),(.177,.026,.168),.013,"screen","torso")
    rounded("Control • window inset",(-.148,-.488,1.181),(.152,.009,.071),.009,
            "screen_glass","torso",segments=1)
    for z in (1.19,1.077):
        rounded("Control • orange command key",(.039,-.472,z),(.078,.027,.076),.017,"orange","torso")
    for x in (-.283,.114):
        rounded("Control • fastener",(x,-.459,1.252),(.027,.018,.027),.007,
                "latch","torso",segments=1)
    # The chest badge sits on the forward shoulder, matching the turnaround.
    badge=(.474,-.202,1.264)
    def paw_point(dx,dz,depth=0):
        return badge[0]+dx,badge[1]+dx*.32+dz*.47-depth,badge[2]+dz
    ball("Badge • paw pad",paw_point(0,-.034,.026),(.048,.014,.036),"mark","upper_arm.L",
         segments=12,rings=6)
    for dx,dz in [(-.052,.013),(-.022,.049),(.025,.05),(.058,.016)]:
        ball("Badge • paw toe",paw_point(dx,dz,.029),(.021,.012,.027),"mark","upper_arm.L",
             segments=9,rings=6)
    for side in (-1,1):
        rounded("Pack • front shoulder strap",(side*.275,-.23,1.208),
                (.109,.068,.375),.027,"strap","torso",angles=Euler((.07,side*.19,0)))
    rounded("Pack • pressure pack",(0,.387,1.106),(.655,.368,.619),.098,"beige","torso")
    rounded("Pack • rear hard shell",(0,.582,1.092),(.571,.124,.493),.066,"ivory","torso")
    rounded("Pack • service compartment",(0,.654,1.088),(.371,.032,.302),.037,"seam","torso")
    for s in (-1,1):
        rounded("Pack • orange canister",(s*.147,.683,.998),(.146,.085,.129),
                .026,"orange","torso")
        rounded("Pack • vent",(s*.098,.679,1.163),(.118,.032,.082),.014,
                "liner","torso",segments=1)
        rounded("Pack • side canister",(s*.332,.393,1.066),(.179,.283,.439),.057,
                "panel","torso")
        for z in (.955,1.093,1.19):
            rounded("Pack • side tab",(s*.429,.416,z),(.035,.081,.045),.009,
                    "gold" if z!=1.093 else "latch","torso",segments=1)
    tube("Pack • antenna bracket",[
        ((.42,.395,1.005),.055,.048),((.94,.395,1.005),.046,.043),
        ((.977,.395,1.053),.044,.044),((.977,.395,1.232),.028,.026),
        ((.977,.395,1.503),.025,.024)
    ],["panel","panel","seam","seam"],"torso",n=9)
    ball("Pack • orange antenna tip",(.977,.395,1.54),(.102,.102,.102),
         "orange","torso",segments=14,rings=8)

TAIL_POINTS=[
    (0,.232,.681),(.085,.404,.596),(.197,.548,.476),(.361,.590,.390),
    (.536,.564,.344),(.695,.501,.325),(.842,.419,.337),(.972,.343,.386),
    (1.090,.273,.474),(1.174,.226,.594),(1.201,.194,.71),(1.190,.180,.772)
]
TAIL_RADII=[.104,.123,.139,.151,.163,.168,.167,.161,.146,.124,.095,.048]
TAIL_INKS=["fur_dark","fur","tail_dark","tail_dark","fur_warm","fur_warm","tail_dark",
           "tail_dark","fur_warm","fur","tail_dark"]

def cat_tail():
    def tail_weight(ring,index):
        progression=min(3,ring/3.45)
        first=min(3,int(progression))
        portion=progression-first
        return {f"tail_{first+1}":1-portion, f"tail_{min(4,first+2)}":portion} if first<3 else {"tail_4":1}
    path=[(xyz,rad,rad*.91) for xyz,rad in zip(TAIL_POINTS,TAIL_RADII)]
    mats=[(lambda i,c=c: "fur_dark" if c=="tail_dark" and i in (2,3,7,8) else c)
          for c in TAIL_INKS]
    tube("Tabby • curved banded tail",path,mats,"tail_1",TAIL,n=14,influence=tail_weight)
