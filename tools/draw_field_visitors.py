"""Build the distributable crew atlas from Artemis's own astronaut sprite."""

from pathlib import Path

from PIL import Image, ImageColor

SPRITES = Path(__file__).resolve().parents[1] / "assets" / "sprites_25d"


def main():
    source = Image.open(SPRITES / "astronaut.png").convert("RGBA")
    crew = Image.new("RGBA", (source.width, 2 * source.height))
    for index, accent in enumerate(("#58adbd", "#b282cd")):
        variant = source.copy()
        for y in range(source.height):
            for x in range(source.width):
                red, green, blue, alpha = source.getpixel((x, y))
                if alpha and (red, green, blue) == (203, 115, 81):
                    variant.putpixel((x, y), (*ImageColor.getrgb(accent), alpha))
        crew.alpha_composite(variant, (0, index * source.height))
    crew.save(SPRITES / "visitors.png")


if __name__ == "__main__":
    main()
