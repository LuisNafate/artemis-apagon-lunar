"""Render original pixel artwork for the lunar training base. Requires Pillow."""

from math import cos, sin, tau
from pathlib import Path
from random import Random

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / "assets"
SPRITES = ROOT / "sprites_25d"
TERRAIN = ROOT / "tilemaps"
UI = ROOT / "ui"

INK = "#141d31"
PAPER = "#f7e9d2"
SAND = "#dbbfa0"
STEEL = "#949eac"
SLATE = "#535d78"
GOLD = "#efad62"
MINT = "#8edac3"
BLUE = "#6aadd4"


def canvas(width, height):
    image = Image.new("RGBA", (width, height))
    return image, ImageDraw.Draw(image)


def iso(x, y, z=0):
    return 70 + (x - y) * 2, 55 + x + y - z


def face(d, vertices, fill, outline=None):
    d.polygon([iso(*vertex) for vertex in vertices], fill=fill, outline=outline)


def box(d, x, y, z, width, depth, height, colors):
    a, b, c, e = (x, y), (x + width, y), (x + width, y + depth), (x, y + depth)
    top = z + height
    face(d, [(*e, z), (*c, z), (*c, top), (*e, top)], colors[1], INK)
    face(d, [(*c, z), (*b, z), (*b, top), (*c, top)], colors[2], INK)
    face(d, [(*a, top), (*b, top), (*c, top), (*e, top)], colors[0], INK)


def track(d, points, fill, width=1):
    d.line([iso(*point) for point in points], fill=fill, width=width)


def pad(d, tint):
    box(d, -15, -15, -3, 30, 30, 3, ("#4c566e", "#373e55", "#262d43"))
    track(d, [(-13, 13, 1), (-8, 13, 1)], tint, 2)
    track(d, [(9, 13, 1), (13, 13, 1), (13, 9, 1)], tint, 2)


def module(key):
    image, d = canvas(140, 96)
    if key == "solar":
        pad(d, BLUE)
        for xo in [-9, 7]:
            box(d, xo-1,-5,0,3,12,11,(STEEL,SLATE,INK))
            for col in range(2):
                for row in range(4):
                    x, y = xo-6+col*6, -12+row*6
                    z = 24-row*2
                    face(d, [(x,y,z),(x+6,y,z),(x+6,y+6,z-2),(x,y+6,z-2)],
                         "#4779ae" if (row+col)%2 else "#376492", "#8badc5")
                    track(d, [(x+1,y+3,z-1),(x+5,y+3,z-1)], "#27476f")
        box(d, 5, 8, 0, 7, 5, 7, (PAPER, SAND, SLATE))
        track(d, [(7,13,4),(10,13,4)], GOLD, 2)
    elif key == "airlock":
        pad(d, GOLD)
        box(d, -10, -10, 0, 20, 20, 21, (PAPER, "#a58f83", STEEL))
        box(d, -11, -11, 21, 22, 22, 3, (SAND, "#9c735f", SLATE))
        box(d, -7, 9, 0, 14, 5, 20, ("#c17b59", "#734d50", "#545065"))
        box(d, -5, 14, 0, 10, 1, 16, (STEEL, "#2e374d", INK))
        track(d, [(-3,15,12),(3,15,12)], BLUE, 2)
        track(d, [(-12,7,12),(-12,7,25)], STEEL)
        track(d, [(-12,7,24),(-12,7,27)], GOLD, 2)
        track(d, [(10, -7, 5), (10,7,5)], "#91594c", 2)
    elif key == "beacon":
        box(d, -7,-7,0,14,14,4,(STEEL,SLATE,"#363b57"))
        box(d, -3,-3,4,6,6,5,(SAND,SLATE,INK))
        box(d, -1,-1,9,2,2,24,(PAPER,STEEL,SLATE))
        box(d, -3,-3,33,6,6,5,("#ffe3aa",GOLD,"#a75a54"))
        track(d, [(-5,4,40),(0,4,40),(4,4,39)], GOLD)
    if key == "life":
        return cutaway("habitat")
    if key == "garden":
        return cutaway("greenhouse")
    return image


def cutaway(key):
    image, d = canvas(140, 96)
    tint = MINT if key == "greenhouse" else BLUE
    pad(d, tint)
    box(d, -13, -13, 0, 26, 26, 3, ("#becddd", "#54637b", "#77899d"))
    for k in [-7, 0, 7]:
        track(d, [(k, -12, 3), (k, 12, 3)], "#7b91aa")
        track(d, [(-12, k, 3), (12, k, 3)], "#7b91aa")
    glass = key == "greenhouse"
    wall = ("#a6d6dc", "#527d91", "#6396a7") if glass else (
        "#e4ebed", "#869db6", "#a4b7ca"
    )
    box(d, -13, -13, 3, 26, 2, 22, wall)
    box(d, -13, -11, 3, 2, 24, 22, wall)
    for position in [-9, -1, 7]:
        if glass:
            track(d, [(position, -11, 4), (position, -11, 24)], "#c5e8ef", 2)
            track(d, [(-11, position, 4), (-11, position, 24)], "#c5e8ef", 2)
        else:
            face(d, [(position,-10,13),(position+5,-10,13),(position+5,-10,20),
                     (position,-10,20)], "#254867", INK)
            track(d, [(position+1,-10,17),(position+4,-10,17)], MINT)
    if glass:
        for y in [-7, 2]:
            box(d, -8, y, 3, 18, 5, 4, ("#476e62", "#7ea5a0", "#45616d"))
            for x in [-6, -2, 2, 6]:
                box(d, x, y + 1, 7, 3, 3, 2, ("#72b878", "#357458", "#488d5c"))
                track(d, [(x+1, y+2, 10), (x+2, y+3, 9)], "#b1d38b")
        box(d, -10, 8, 3, 4, 4, 9, (PAPER, "#5b9eb4", "#305d84"))
        track(d, [(-10, 8, 12), (-10, 8, 18), (-10, -8, 18)], MINT)
    else:
        for x in [-7, 3]:
            box(d, x, -8, 3, 5, 10, 4, ("#719dca", "#416688", "#34516f"))
            box(d, x, -8, 7, 5, 3, 2, ("#ebedf1", "#879faf", "#6e879a"))
        box(d, -9, 6, 3, 6, 6, 5, ("#d0d9df", "#8198aa", "#5b6f82"))
        box(d, -9, 6, 8, 6, 2, 5, ("#97acb8", "#497d9c", "#324963"))
        track(d, [(-8,8,11),(-4,8,11)], MINT)
        box(d, 6, 8, 3, 4, 4, 6, ("#eee4cf", "#b09479", SLATE))
    track(d, [(-9, 13, 4), (-3, 13, 4)], tint, 2)
    track(d, [(5, 13, 4), (10, 13, 4)], tint, 2)
    return image


def battery():
    image, d = canvas(140, 96)
    pad(d, GOLD)
    for x in [-9, 2]:
        box(d, x, -9, 0, 8, 18, 15, ("#bac8d5", "#ab7c64", "#65788d"))
        for y in [-6, -1, 4]:
            box(d, x + 1, y, 15, 6, 3, 1, ("#536d83", "#40576f", INK))
        track(d, [(x + 1, 9, 10), (x + 6, 9, 10)], GOLD, 2)
    track(d, [(-5, 9, 7), (-5, 12, 7), (6, 12, 7), (6, 9, 7)], "#ca765a", 2)
    return image


def astronaut():
    image, _ = canvas(72, 128)
    for direction in range(4):
        for frame in range(3):
            tile, d = canvas(24, 32)
            rear = direction >= 2
            d.ellipse((3,25,21,30), fill=(8,13,27,125))
            feet = [(8,26),(14,26)]
            if frame:
                feet[frame-1] = (feet[frame-1][0], 24)
            for x,y in feet:
                d.rectangle((x-2,y-5,x+3,y+2), fill=INK)
                d.rectangle((x-1,y-5,x+2,y), fill=STEEL)
                d.line((x-1,y+1,x+2,y+1), fill=SAND)
            d.rounded_rectangle((2,13,9,23), radius=2, fill=SLATE, outline=INK)
            d.rounded_rectangle((14,14,21,23), radius=2, fill=SAND, outline=INK)
            d.polygon([(7,13),(16,13),(19,18),(16,24),(8,24),(5,19)],
                      fill=PAPER, outline=INK)
            d.rectangle((8,20,16,22), fill="#cb7351")
            if rear:
                d.rectangle((7,14,15,21), fill=STEEL, outline=INK)
                d.rectangle((8,15,14,19), fill=SLATE)
                d.point((13,16), fill=MINT)
            else:
                d.rectangle((10,15,15,18), fill=INK)
                d.point((11,16), fill=MINT)
                d.point((13,16), fill=GOLD)
            d.polygon([(5,4),(8,1),(16,1),(20,4),(21,10),(18,15),(14,16),
                       (8,15),(4,11),(4,6)], fill=PAPER, outline=INK)
            d.line([(6,5),(8,3),(14,3)], fill="#fff9e9")
            if rear:
                d.line([(11,3),(10,8),(11,12),(16,14)], fill=STEEL, width=2)
                d.rectangle((17,6,20,10), fill=SAND, outline=SLATE)
            else:
                d.polygon([(8,6),(19,5),(20,9),(17,13),(11,13),(8,11)],
                          fill="#644553", outline=INK)
                d.polygon([(10,7),(18,6),(18,9),(15,11),(11,11)], fill=GOLD)
                d.line((11,8,15,7), fill="#ffe4ab")
                d.rectangle((4,7,7,10), fill=SAND, outline=SLATE)
            if direction % 2:
                tile = tile.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            image.alpha_composite(tile, (frame*24,direction*32))
    return image


def scenery():
    image, d = canvas(480, 360)
    rng = Random(64)
    d.rectangle((0,0,479,359), fill="#0c1324")
    for _ in range(180):
        x, y = rng.randrange(480), rng.randrange(194)
        d.point((x,y), fill=rng.choice(["#405174","#a4aaac","#232f46","#56617b"]))
    # Earth with a hard pixel silhouette and separate limb and land palettes.
    d.ellipse((371,55,439,123), fill="#192e49")
    d.ellipse((373,54,438,119), fill="#233e5e")
    d.pieslice((373,54,438,119), 138, 332, fill="#4b83a4")
    d.polygon([(384,67),(393,59),(405,59),(412,66),(406,72),(398,72),(397,79),
               (391,82),(385,78),(386,74),(381,72)], fill="#7eb4a9")
    d.polygon([(397,80),(407,84),(409,91),(403,98),(402,106),(397,100),(395,90)],
              fill="#6a9b97")
    d.polygon([(418,65),(427,66),(434,71),(437,79),(426,76),(425,80),(416,75)],
              fill="#416d82")
    d.line([(382,72),(389,69),(397,68)], fill="#b8d9c3", width=2)
    d.line([(401,87),(408,86),(413,84)], fill="#c2d9cb", width=2)
    d.arc((373,54,438,119), 153, 312, fill="#aad0d1")
    for x, y in [(65,81),(132,108),(318,62),(452,142),(40,156)]:
        d.line((x-2,y,x+2,y), fill="#5e7093")
        d.line((x,y-2,x,y+2), fill="#8995a6")
    horizon = [(0,143),(37,134),(70,150),(111,137),(153,145),(176,156),
               (217,142),(252,153),(290,146),(334,161),(373,140),(411,138),
               (450,122),(479,126),(479,360),(0,360)]
    d.polygon(horizon, fill="#202840")
    d.polygon([(0,165),(57,150),(102,161),(147,156),(193,169),(249,159),(308,176),
               (363,156),(417,167),(479,145),(479,360),(0,360)], fill="#29314b")
    d.polygon([(0,186),(64,172),(116,174),(158,193),(210,184),(258,191),
               (315,179),(374,194),(429,180),(479,169),(479,360),(0,360)], fill="#303a55")
    for _ in range(1000):
        x, y = rng.randrange(480), rng.randrange(190,360)
        c = rng.choice(["#3a455f","#252e44","#424c65","#303751"])
        d.line((x,y,x+rng.randrange(4),y), fill=c)
    for x,y,w in [(65,239,16),(401,226,20),(416,280,31),(50,300,24),
                  (121,278,12),(341,294,11),(156,309,19),(26,206,11)]:
        d.ellipse((x-w,y-w//3,x+w,y+w//3), fill="#273047")
        d.arc((x-w,y-w//3,x+w,y+w//3), 12, 173, fill="#4d5672", width=2)
        d.arc((x-w+2,y-w//3+2,x+w-2,y+w//3), 197, 342, fill="#1d253b", width=2)
    for _ in range(86):
        x, y = rng.randrange(480), rng.randrange(178,337)
        w = rng.randrange(2,7)
        d.polygon([(x-w,y),(x-1,y-w//2-1),(x+2,y-w//2),(x+w,y),
                   (x+2,y+w//3)], fill=rng.choice(["#48536e","#4a5571","#36415c"]))
        d.line((x-w,y,x+2,y+w//3,x+w,y), fill="#242c41")
    return image


def floors():
    image, _ = canvas(128, 20)
    for i, color in enumerate(["#555e76","#5c657c","#647085","#777f89"]):
        tile, d = canvas(32, 20)
        d.polygon([(0,8),(16,16),(31,8),(31,11),(16,19),(0,11)], fill="#303951")
        d.polygon([(16,0),(31,8),(16,16),(0,8)], fill=color, outline="#485269")
        d.line((1,8,16,1,30,8), fill="#78829a" if i != 3 else "#a1988e")
        d.point((15,3), fill="#9a9faf")
        d.point((16,13), fill="#404a60")
        if i == 3:
            d.line((9,8,16,11,23,8), fill="#b5ab95")
        image.alpha_composite(tile, (i*32,0))
    return image


def icons():
    image, _ = canvas(80, 16)
    shapes = [
        (BLUE, [(8,1),(12,5),(13,10),(10,14),(5,14),(2,10),(3,5)]),
        ("#bfaee4", [(4,4),(6,2),(10,2),(12,4),(12,9),(14,11),(13,13),(2,13),(1,10),(4,8)]),
        (MINT, [(8,1),(13,8),(13,11),(10,14),(5,14),(2,11),(2,8)]),
        (GOLD, [(9,1),(3,8),(7,8),(6,15),(13,6),(9,6)]),
        (PAPER, [(8,1),(14,5),(14,11),(8,15),(2,11),(2,5)]),
    ]
    for i,(color, shape) in enumerate(shapes):
        tile,d = canvas(16,16)
        d.polygon(shape, fill=color)
        if i in (0,4):
            d.rectangle((6,6,9,10), fill="#1b263e")
        elif i == 2:
            d.line((4,8,4,10,6,12), fill="#e2fcda")
        image.alpha_composite(tile,(i*16,0))
    return image


def props():
    image, d = canvas(140, 96)
    for x,y in [(-4,4),(3,3),(4,-3)]:
        box(d,x,y,0,5,5,5,(SAND,"#9e775e",SLATE))
        track(d, [(x+2,y,5),(x+2,y+5,5)], GOLD)
    return image


def main():
    for directory in (SPRITES, TERRAIN, UI):
        directory.mkdir(parents=True, exist_ok=True)
    astronaut().save(SPRITES / "astronaut.png")
    for key in ("life","garden","solar","airlock","beacon"):
        module(key).save(SPRITES / f"{key}.png")
    battery().save(SPRITES / "battery.png")
    props().save(SPRITES / "crates.png")
    scenery().save(TERRAIN / "lunar_horizon.png")
    floors().save(TERRAIN / "deck.png")
    icons().save(UI / "resources.png")


if __name__ == "__main__":
    main()
