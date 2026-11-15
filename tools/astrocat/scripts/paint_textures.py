"""Paint the AstroCat texture set with Pillow. Run before building the scene."""

import math
from pathlib import Path
from random import Random
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "textures"
SIZE = 1024
TILE = 64
SWATCHES = {
    "ivory": ("e8c7a7", 177, 0),
    "beige": ("d6ae88", 200, 0),
    "seam": ("9b7460", 188, 0),
    "rim": ("f1d3b6", 156, 0),
    "rubber": ("3c2b27", 217, 0),
    "sole": ("51372f", 214, 0),
    "orange": ("cb591e", 159, 0),
    "gold": ("f69524", 148, 0),
    "dark_visor": ("100e1e", 173, 0),
    "eye_edge": ("47363a", 168, 0),
    "eye_lid": ("b09b8c", 196, 0),
    "glint": ("fff1d8", 150, 0),
    "glint_blue": ("8ab6c2", 155, 0),
    "nose": ("633025", 162, 0),
    "nose_top": ("b77358", 170, 0),
    "mark": ("45271c", 199, 0),
    "fur": ("a06a45", 217, 0),
    "fur_warm": ("b58257", 212, 0),
    "fur_dark": ("694432", 219, 0),
    "ear_brown": ("824e37", 222, 0),
    "ear_dark": ("563529", 222, 0),
    "muzzle": ("ddba92", 215, 0),
    "screen": ("362f30", 128, 0),
    "screen_glass": ("504143", 132, 0),
    "latch": ("a88770", 165, 92),
    "panel": ("dcb28d", 180, 0),
    "liner": ("57443b", 220, 0),
    "crimson": ("864038", 174, 0),
    "strap": ("8a6953", 213, 0),
    "gold_shade": ("d17521", 180, 0),
    "tail_dark": ("523427", 230, 0),
    "ear_ochre": ("98624b", 221, 0),
}


def rgb(text):
    return tuple(int(text[i:i+2], 16) for i in (0, 2, 4))


def swatches():
    color = Image.new("RGB", (TILE*8, TILE*8))
    masks = Image.new("RGB", color.size)
    rng = Random(78)
    image = color.load()
    mr = masks.load()
    for idx, (hex_value, rough, metal) in enumerate(SWATCHES.values()):
        red, green, blue = rgb(hex_value)
        tile_x, tile_y = idx % 8 * TILE, idx // 8 * TILE
        for y in range(TILE):
            for x in range(TILE):
                grain = rng.uniform(-2.0, 2.0) + math.sin(x*.18+y*.12)*1.15
                image[tile_x+x, tile_y+y] = tuple(
                    max(0, min(255, round(c+grain))) for c in (red, green, blue))
                mr[tile_x+x, tile_y+y] = (255, rough, metal)
    # Dedicated rear helmet UV island, soft satin panel and thin pressed border.
    panel = Image.new("RGB", (128,64), (232,199,167))
    back = ImageDraw.Draw(panel)
    back.rounded_rectangle((21,25,106,47),radius=7,fill=(196,155,128))
    back.rounded_rectangle((22,25,105,45),radius=6,fill=(244,209,174))
    back.rounded_rectangle((24,26,103,44),radius=5,fill=(219,185,155))
    color.paste(panel,(0,TILE*7))
    ImageDraw.Draw(masks).rectangle((0,TILE*7,127,TILE*8-1),fill=(255,181,0))
    color.save(OUT / "Suit_BaseColor.png")
    masks.save(OUT / "Suit_MetallicRoughness.png")


def pixel(x, z):
    return int((x+1)*SIZE*.5), int((1-z)*SIZE*.5)


def face():
    rng = Random(294)
    img = Image.new("RGB", (SIZE, SIZE))
    paint = ImageDraw.Draw(img)
    # A gently lighter undercoat above the muzzle, warm earthen fur at the brow.
    for y in range(SIZE):
        z = 1-y/(SIZE-1)*2
        mix = (1-z)*.5
        c = tuple(int(a+(b-a)*mix) for a,b in zip((135, 91, 57), (171, 119, 77)))
        paint.line((0,y,SIZE,y), c)

    def shape(points, color):
        paint.polygon([pixel(x,z) for x,z in points], fill=rgb(color) if isinstance(color, str) else color)

    # Low-contrast hand-painted breaks within the undercoat.
    for _ in range(155):
        x, z = rng.uniform(-1, 1), rng.uniform(-1,1)
        w, h = rng.uniform(.04,.15), rng.uniform(.04,.20)
        a, b = rng.uniform(.5,1.0), rng.uniform(.55,.95)
        tint = rng.choice([(153,104,70), (174,119,78), (143,99,68), (179,128,83),
                           (160,113,79), (166,114,76), (152,108,76), (185,135,90)])
        shape([(x-w,z+h*.15), (x-w*.50,z+h), (x+w*a,z+h*.38),
               (x+w,z-h*.2), (x+w*.1,z-h*b), (x-w*.68,z-h*.4)], tint)

    stripes = [
        [(-.13,.98),(.11,.99),(.13,.78),(.09,.64),(.085,.49),(.03,.39),(-.047,.55),(-.066,.72)],
        [(-.38,.99),(-.22,.94),(-.205,.78),(-.16,.71),(-.14,.53),(-.09,.44),(-.14,.36),
         (-.2,.47),(-.26,.56),(-.29,.68),(-.34,.73)],
        [(-.63,.92),(-.49,.94),(-.46,.76),(-.39,.67),(-.36,.51),(-.27,.42),(-.31,.38),
         (-.43,.49),(-.49,.61),(-.56,.66),(-.61,.78)],
        [(-.92,.73),(-.76,.84),(-.70,.69),(-.59,.57),(-.61,.43),(-.76,.50),(-.86,.56)],
        [(-1.00,.43),(-.85,.40),(-.76,.35),(-.67,.25),(-.71,.19),(-.83,.22),(-.95,.23)],
        [(-1.00,.19),(-.82,.14),(-.77,.04),(-.68,-.025),(-.70,-.09),(-.85,-.075),(-.98,.00)],
        [(-.97,-.08),(-.83,-.12),(-.77,-.24),(-.62,-.33),(-.66,-.40),(-.86,-.31),(-1,-.20)],
        [(-.96,-.33),(-.80,-.40),(-.74,-.50),(-.56,-.58),(-.60,-.65),(-.78,-.59),(-.96,-.54)],
    ]
    for idx, pts in enumerate(stripes):
        shape(pts, ["5e3e2e","684432","6d4933","795239","6a4834","735039","724d38","704b36"][idx])
        if idx:
            flipped = [(-x*(.98 if idx%2 else 1.04), z - (.025 if idx%2 else -.012)) for x,z in pts]
            shape(flipped, ["5c3b2b","68432e","704a34","71503b","6d4937","704b36","76513a","674634"][idx])

    # Light mouth blaze and two tabby cheek patches. The whiskers are geometry.
    shape([(-.87,-.40),(-.74,-.36),(-.58,-.41),(-.5,-.345),(-.37,-.31),(-.27,-.35),
           (-.13,-.255),(0,-.22),(.14,-.26),(.26,-.37),(.36,-.31),(.52,-.37),
           (.70,-.38),(.88,-.48),(.71,-.77),(.47,-.98),(-.5,-.98),(-.73,-.78)], "bd9069")
    shape([(-.72,-.57),(-.51,-.43),(-.35,-.39),(-.23,-.41),(-.11,-.33),(0,-.29),
           (.10,-.34),(.23,-.41),(.35,-.39),(.49,-.46),(.70,-.58),(.65,-.79),
           (.33,-.94),(.0,-1),(-.42,-.94),(-.66,-.77)], "d7ad83")
    shape([(-.51,-.69),(-.32,-.63),(-.19,-.64),(-.08,-.56),(.0,-.575),(.23,-.63),
           (.45,-.64),(.53,-.77),(.29,-.92),(-.32,-.92)], "dfbb94")
    shape([(-.065,.32),(.04,.32),(.14,.05),(.125,-.11),(.205,-.28),
           (0,-.22),(-.2,-.30),(-.13,-.095),(-.13,.055)], "a7744c")

    # Warm mottling with fine dry-brush grain instead of photographic fur.
    im = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            ink = im[x,y]
            dim = (math.sin(x*.036+y*.023)+math.sin(y*.087-x*.049))*.75
            delta = rng.uniform(-2.6,2.6)+dim
            im[x,y] = tuple(max(0,min(255,round(c+delta))) for c in ink)
    img.save(OUT / "Face_BaseColor.png")


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    swatches()
    face()
