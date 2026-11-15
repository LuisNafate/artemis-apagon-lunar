/*
 * Build the playable cat from the supplied gato-modelo2.glb.
 * Uses Node.js, @gltf-transform/core, extensions and functions 4.5.1, and sharp 0.35.5.
 * Install these dependencies next to a copy of this script in an asset-tools workspace.
 */
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { dequantize, prune, textureCompress } from '@gltf-transform/functions';
import sharp from 'sharp';

const [input, output] = process.argv.slice(2);
if (!input || !output) {
  throw new Error('Usage: node articulate_cat.mjs gato-modelo2.glb output.glb');
}
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const document = await io.read(input);
const root = document.getRoot();
const [meshNode] = root.listNodes();
const [surface] = meshNode.getMesh().listPrimitives();
const buffer = root.listBuffers()[0];

await document.transform(dequantize());
meshNode.setName('Traje');
const material = surface.getMaterial();
material.setName('Traje felino');
material.setNormalTexture(null).setMetallicRoughnessTexture(null);
material.setMetallicFactor(0).setRoughnessFactor(0.9);

const smooth = (start, end, value) => {
  const unit = Math.max(0, Math.min(1, (value - start) / (end - start)));
  return unit * unit * (3 - 2 * unit);
};
const bones = [];
const inverseBind = [];
const skin = document.createSkin('Esqueleto felino');

function joint(name, position, parent = null) {
  const node = document.createNode(name);
  const local = parent ? position.map((coordinate, axis) => coordinate - parent.position[axis]) : position;
  node.setTranslation(local);
  if (parent) parent.node.addChild(node);
  else root.listScenes()[0].addChild(node);
  const [x, y, z] = position;
  inverseBind.push(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -x, -y, -z, 1);
  const entry = { node, position, index: bones.length };
  bones.push(entry);
  skin.addJoint(node);
  return entry;
}

const origin = joint('Root', [0, 0, 0]);
const torso = joint('Torso', [0, -0.304, -0.042], origin);
const head = joint('Head', [0, -0.128, -0.034], torso);
const tail = joint('Tail', [0, -0.347, 0.114], torso);
const tip = joint('TailTip', [-0.168, -0.426, 0.203], tail);
const limbs = [-1, 1].map((sign) => {
  const side = sign < 0 ? 'L' : 'R';
  const shoulder = joint('Shoulder' + side, [sign * 0.137, -0.177, -0.051], torso);
  const elbow = joint('Elbow' + side, [sign * 0.181, -0.247, -0.059], shoulder);
  const hip = joint('Hip' + side, [sign * 0.072, -0.305, -0.041], torso);
  const knee = joint('Knee' + side, [sign * 0.082, -0.388, -0.050], hip);
  const ankle = joint('Ankle' + side, [sign * 0.089, -0.459, -0.042], knee);
  return { shoulder, elbow, hip, knee, ankle };
});
skin.setSkeleton(origin.node);
meshNode.setSkin(skin);

function accessor(name, type, data) {
  return document.createAccessor(name).setType(type).setArray(data).setBuffer(buffer);
}
skin.setInverseBindMatrices(accessor('Bind inversa', 'MAT4', Float32Array.from(inverseBind)));

const positions = surface.getAttribute('POSITION').getArray();
const normals = surface.getAttribute('NORMAL').getArray();
const count = positions.length / 3;
const joints = new Uint8Array(count * 4);
const weights = new Float32Array(count * 4);

for (let vertex = 0; vertex < count; vertex++) {
  const offset = 3 * vertex;
  // Source faces +X. Bake the rotation so that the character faces Godot's -Z.
  const [x, y, z] = [positions[offset + 2], positions[offset + 1], -positions[offset]];
  positions.set([x, y, z], offset);
  normals.set([normals[offset + 2], normals[offset + 1], -normals[offset]], offset);
  const outer = Math.abs(x);
  const limb = limbs[x < 0 ? 0 : 1];

  // The head and backpack are separated by depth near the neck seam.
  const headWeight = smooth(-0.151, -0.109, y) *
    (1 - smooth(0.055, 0.135, z) * (1 - smooth(-0.105, -0.075, y)));
  const tailWeight = (1 - smooth(-0.379, -0.316, y)) * smooth(0.080, 0.147, z);
  const remaining = (1 - headWeight) * (1 - tailWeight);
  const armWeight = remaining * smooth(0.109, 0.163, outer) *
    (1 - smooth(0.040, 0.116, z)) * smooth(-0.366, -0.323, y);
  const legWeight = (remaining - armWeight) * (1 - smooth(-0.356, -0.300, y));
  const elbowBend = 1 - smooth(-0.274, -0.221, y);
  const kneeBend = 1 - smooth(-0.410, -0.367, y);
  const ankleBend = 1 - smooth(-0.476, -0.441, y);
  const tailBend = smooth(0.10, 0.21, Math.hypot(z - 0.114, x));
  const candidates = [
    [head, headWeight],
    [tail, (1 - headWeight) * tailWeight * (1 - tailBend)],
    [tip, (1 - headWeight) * tailWeight * tailBend],
    [torso, remaining - armWeight - legWeight],
    [limb.shoulder, armWeight * (1 - elbowBend)],
    [limb.elbow, armWeight * elbowBend],
    [limb.hip, legWeight * (1 - kneeBend)],
    [limb.knee, legWeight * kneeBend * (1 - ankleBend)],
    [limb.ankle, legWeight * kneeBend * ankleBend],
  ];
  const active = candidates.filter(([, weight]) => weight > 0.0001)
    .sort((first, second) => second[1] - first[1]).slice(0, 4);
  const sum = active.reduce((total, [, weight]) => total + weight, 0);
  for (const [index, [bone, weight]] of active.entries()) {
    joints[vertex * 4 + index] = bone.index;
    weights[vertex * 4 + index] = weight / sum;
  }
}

surface.setAttribute('JOINTS_0', accessor('Articulaciones', 'VEC4', joints));
surface.setAttribute('WEIGHTS_0', accessor('Pesos', 'VEC4', weights));
await document.transform(
  prune(),
  textureCompress({ encoder: sharp, targetFormat: 'jpeg', resize: [1024, 1024], quality: 91 })
);
await io.write(output, document);
console.log(`${count} vértices, ${surface.getIndices().getCount() / 3} triángulos, ${bones.length} huesos`);
