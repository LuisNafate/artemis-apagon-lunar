
"""Build the decorative Nobile horizon GLB from the NASA PGDA Site06 LDEM.

Usage: python tools/generar_relieve_nobile.py INPUT.tif OUTPUT.glb
Requires Pillow. See the asset register for the data URL and crop.
"""
import argparse
import json
import math
from pathlib import Path
import struct

from PIL import Image

CROP = (2150, 1450, 2790, 1930)
COLS, ROWS = 33, 25
WIDTH, DEPTH, HEIGHT = 39.0, 11.0, 4.8


def unit_normal(dx, dz):
    norm = math.sqrt(dx * dx + dz * dz + 1)
    return (-dx / norm, 1 / norm, -dz / norm)


def terrain(raster):
    with Image.open(raster) as image:
        if image.size != (4000, 4000) or image.tag_v2.get(33922) != (
            0.0, 0.0, 0.0, 74000.0, 120000.0, 0.0
        ):
            raise ValueError("Expected the PGDA Site06 5 m LDEM")
        samples = list(image.crop(CROP).resize((COLS, ROWS), Image.Resampling.BOX).get_flattened_data())
    if any(not math.isfinite(sample) for sample in samples):
        raise ValueError("Crop contains cells with no elevation")
    bottom, top = min(samples), max(samples)
    heights = []
    for index, sample in enumerate(samples):
        row = index // COLS
        edge = min(1.0, (ROWS - 1 - row) / 5)
        edge = edge * edge * (3 - 2 * edge)
        heights.append(HEIGHT * edge * (sample - bottom) / (top - bottom))

    step_x, step_z = WIDTH / (COLS - 1), DEPTH / (ROWS - 1)
    positions, normals, indices = [], [], []
    for row in range(ROWS):
        for col in range(COLS):
            i = row * COLS + col
            positions.append((-WIDTH / 2 + step_x * col, heights[i], -DEPTH + step_z * row))
            left, right = max(0, col - 1), min(COLS - 1, col + 1)
            rear, front = max(0, row - 1), min(ROWS - 1, row + 1)
            dx = (heights[row * COLS + right] - heights[row * COLS + left]) / (step_x * (right - left))
            dz = (heights[front * COLS + col] - heights[rear * COLS + col]) / (step_z * (front - rear))
            normals.append(unit_normal(dx, dz))
            if row < ROWS - 1 and col < COLS - 1:
                indices.extend((i, i + COLS, i + 1, i + 1, i + COLS, i + COLS + 1))
    return positions, normals, indices


def write_glb(path, positions, normals, indices):
    pos_bytes = b"".join(struct.pack("<3f", *v) for v in positions)
    nor_bytes = b"".join(struct.pack("<3f", *v) for v in normals)
    idx_bytes = struct.pack(f"<{len(indices)}H", *indices)
    blob = pos_bytes + nor_bytes + idx_bytes
    doc = {
        "asset": {"version": "2.0", "generator": "Artemis · NASA PGDA Site06"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "relieve_nobile_lola", "mesh": 0}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1}, "indices": 2, "material": 0}]}],
        "materials": [{
            "name": "regolito_nobile",
            "pbrMetallicRoughness": {"baseColorFactor": [0.085, 0.099, 0.134, 1], "metallicFactor": 0, "roughnessFactor": 1},
        }],
        "buffers": [{"byteLength": len(blob)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": len(pos_bytes), "target": 34962},
            {"buffer": 0, "byteOffset": len(pos_bytes), "byteLength": len(nor_bytes), "target": 34962},
            {"buffer": 0, "byteOffset": len(pos_bytes) + len(nor_bytes), "byteLength": len(idx_bytes), "target": 34963},
        ],
        "accessors": [
            {
                "bufferView": 0, "componentType": 5126, "count": len(positions), "type": "VEC3",
                "min": [min(v[i] for v in positions) for i in range(3)],
                "max": [max(v[i] for v in positions) for i in range(3)],
            },
            {"bufferView": 1, "componentType": 5126, "count": len(normals), "type": "VEC3"},
            {"bufferView": 2, "componentType": 5123, "count": len(indices), "type": "SCALAR"},
        ],
    }
    data = json.dumps(doc, ensure_ascii=True, separators=(",", ":")).encode()
    data += b" " * (-len(data) % 4)
    blob += b"\0" * (-len(blob) % 4)
    with path.open("wb") as out:
        out.write(struct.pack("<4sII", b"glTF", 2, 28 + len(data) + len(blob)))
        out.write(struct.pack("<I4s", len(data), b"JSON") + data)
        out.write(struct.pack("<I4s", len(blob), b"BIN\0") + blob)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    vertices, normals, indices = terrain(args.input)
    write_glb(args.output, vertices, normals, indices)
    print(f"{len(vertices)} vertices, {len(indices) // 3} triangles")
