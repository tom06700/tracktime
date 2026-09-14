import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateSync, inflateSync } from 'node:zlib';
import * as THREE from 'three';
import { GLTFExporter } from 'three/addons/exporters/GLTFExporter.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

// Export geometry first, then embed the procedural PNG without browser canvas.
globalThis.FileReader = class {
  readAsArrayBuffer(blob) {
    blob.arrayBuffer().then(result => {
      this.result = result;
      this.onloadend?.();
    });
  }
};

function crc32(data) {
  let crc = 0xffffffff;
  for (const byte of data) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function pngChunk(type, data) {
  const chunk = Buffer.alloc(data.length + 12);
  chunk.writeUInt32BE(data.length);
  chunk.write(type, 4, 4, 'ascii');
  data.copy(chunk, 8);
  chunk.writeUInt32BE(crc32(chunk.subarray(4, 8 + data.length)), 8 + data.length);
  return chunk;
}

function radialGroundPng(size = 256) {
  const stride = 1 + size * 4;
  const scanlines = Buffer.alloc(size * stride);
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const radius = Math.hypot((x + .5) / size * 2 - 1, (y + .5) / size * 2 - 1);
    const t = Math.min(1, radius / .96);
    const falloff = 1 - t * t * (3 - 2 * t);
    const offset = y * stride + 1 + x * 4;
    scanlines.fill(255, offset, offset + 3);
    scanlines[offset + 3] = Math.round(255 * .7 * falloff * falloff);
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(size, 0);
  header.writeUInt32BE(size, 4);
  header[8] = 8; // 8-bit channels
  header[9] = 6; // RGBA
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    pngChunk('IHDR', header), pngChunk('IDAT', deflateSync(scanlines, { level: 9 })),
    pngChunk('IEND', Buffer.alloc(0)),
  ]);
}

function embedGroundTexture(geometryGlb, png) {
  const original = Buffer.from(geometryGlb);
  const jsonSize = original.readUInt32LE(12);
  const data = JSON.parse(original.subarray(20, 20 + jsonSize));
  const binOffset = 20 + jsonSize;
  const geometryBytes = original.subarray(binOffset + 8, binOffset + 8 + original.readUInt32LE(binOffset));
  const view = data.bufferViews.length;
  data.bufferViews.push({ buffer: 0, byteOffset: geometryBytes.length, byteLength: png.length });
  data.images = [{ name: 'GroundRadialAlpha', mimeType: 'image/png', bufferView: view }];
  data.samplers = [{ magFilter: 9729, minFilter: 9729, wrapS: 33071, wrapT: 33071 }];
  data.textures = [{ name: 'GroundRadialAlpha', source: 0, sampler: 0 }];
  data.materials.find(material => material.name === 'PortalGround').pbrMetallicRoughness.baseColorTexture = { index: 0, texCoord: 0 };
  data.buffers[0].byteLength = geometryBytes.length + png.length;
  const json = Buffer.from(JSON.stringify(data));
  const jsonPadded = Buffer.alloc(Math.ceil(json.length / 4) * 4, 0x20);
  json.copy(jsonPadded);
  const binPadded = Buffer.alloc(Math.ceil(data.buffers[0].byteLength / 4) * 4);
  geometryBytes.copy(binPadded);
  png.copy(binPadded, geometryBytes.length);
  const result = Buffer.alloc(28 + jsonPadded.length + binPadded.length);
  result.writeUInt32LE(0x46546c67, 0);
  result.writeUInt32LE(2, 4);
  result.writeUInt32LE(result.length, 8);
  result.writeUInt32LE(jsonPadded.length, 12);
  result.writeUInt32LE(0x4e4f534a, 16);
  jsonPadded.copy(result, 20);
  result.writeUInt32LE(binPadded.length, 20 + jsonPadded.length);
  result.writeUInt32LE(0x004e4942, 24 + jsonPadded.length);
  binPadded.copy(result, 28 + jsonPadded.length);
  return result;
}

const here = dirname(fileURLToPath(import.meta.url));
const output = resolve(here, '../../../app/assets/portal/portal.glb');
const source = await readFile(resolve(here, 'sculptures.js'), 'utf8');
const helpers = source.slice(source.indexOf('const mat='), source.indexOf('function groundShadow('));
const builder = source.slice(source.indexOf('function passage('), source.indexOf('function orbit('));
assert(helpers.startsWith('const mat=') && builder.startsWith('function passage('), 'Prototype structure changed');

// Execute the actual prototype geometry builder, without its browser renderer.
// passagePose is only used in the animation callback, which is not invoked.
const passage = new Function('THREE', `${helpers}\n${builder}\nreturn passage;`)(THREE);
const root = new THREE.Group();
root.name = 'PortalRoot';
passage(root, new THREE.Scene());

assert.equal(root.children.length, 7, 'Expected frame, interior, pivot, two hinges, threshold, spill');
const [frame, interior, pivot, lower, upper, threshold, spill] = root.children;
assert.equal(pivot.children.length, 3, 'Expected leaf, raised panel and handle');
const [leaf, panel, handle] = pivot.children;
for (const [object, name] of [
  [frame, 'PortalFrame'], [pivot, 'DoorPivot'], [leaf, 'DoorLeaf'],
  [panel, 'DoorPanel'], [handle, 'DoorHandle'], [lower, 'HingeLower'],
  [upper, 'HingeUpper'], [threshold, 'Threshold'],
]) object.name = name;
root.remove(interior, spill);
const ground = new THREE.Mesh(
  new THREE.PlaneGeometry(4.4, 3.6),
  new THREE.MeshStandardMaterial({
    name: 'PortalGround', color: 0x101113, roughness: 1, metalness: 0,
    transparent: true, opacity: 1, side: THREE.DoubleSide,
  }),
);
ground.name = 'Ground';
ground.position.set(0, -1.43, 0);
ground.rotation.x = -Math.PI / 2;
ground.receiveShadow = true;
ground.castShadow = false;
root.add(ground);
frame.material.name = 'LilacCeramic';
leaf.material.name = 'DarkLeaf';
handle.material.name = 'Silver';
root.userData = {
  source: 'design/interactive/empty-motion-lab/sculptures.js:passage',
  sourceSha256: createHash('sha256').update(helpers + builder).digest('hex'),
  coordinates: 'Prototype world scale, Y up, uncentered; DoorPivot rotates about local Y.',
};
root.updateMatrixWorld(true);

const geometryGlb = await new GLTFExporter().parseAsync(root, { binary: true, trs: true });
const bytes = embedGroundTexture(geometryGlb, radialGroundPng());
assert.equal(bytes.readUInt32LE(0), 0x46546c67, 'GLB magic');
assert.equal(bytes.readUInt32LE(4), 2, 'GLB version');
assert.equal(bytes.readUInt32LE(8), bytes.length, 'GLB total length');
const jsonLength = bytes.readUInt32LE(12);
assert.equal(bytes.readUInt32LE(16), 0x4e4f534a, 'JSON chunk');
const json = JSON.parse(bytes.subarray(20, 20 + jsonLength).toString());
const binaryOffset = 20 + jsonLength;
assert.equal(bytes.readUInt32LE(binaryOffset + 4), 0x004e4942, 'BIN chunk');
assert.equal(binaryOffset + 8 + bytes.readUInt32LE(binaryOffset), bytes.length);
assert.equal(json.buffers.length, 1);
assert(json.buffers[0].byteLength <= bytes.readUInt32LE(binaryOffset));
assert.equal(json.nodes.length, 10);
assert.equal(json.meshes.length, 8);
assert.equal(json.materials.length, 4);
assert(json.extensionsUsed.includes('KHR_materials_clearcoat'));
for (const view of json.bufferViews) {
  assert.equal(view.buffer, 0);
  assert((view.byteOffset ?? 0) + view.byteLength <= json.buffers[0].byteLength);
}
const widths = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16 };
const componentBytes = { 5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4 };
for (const accessor of json.accessors) {
  const view = json.bufferViews[accessor.bufferView];
  const elementBytes = widths[accessor.type] * componentBytes[accessor.componentType];
  assert(Number.isFinite(elementBytes));
  assert((accessor.byteOffset ?? 0) + (accessor.count - 1) * (view.byteStride ?? elementBytes) + elementBytes <= view.byteLength);
}
for (const [name, color, metalness, roughness] of [
  ['LilacCeramic', 0xa88bda, .16, .38],
  ['DarkLeaf', 0x5d487a, .4, .28],
  ['Silver', 0xd8d4de, .94, .17],
]) {
  const material = json.materials.find(item => item.name === name);
  assert.deepEqual(material.pbrMetallicRoughness.baseColorFactor, [...new THREE.Color(color).toArray(), 1]);
  assert.equal(material.pbrMetallicRoughness.metallicFactor, metalness);
  assert.equal(material.pbrMetallicRoughness.roughnessFactor, roughness);
  assert.deepEqual(material.extensions.KHR_materials_clearcoat, { clearcoatFactor: .65, clearcoatRoughnessFactor: .22 });
}
const pivotNode = json.nodes.find(node => node.name === 'DoorPivot');
const groundMaterial = json.materials.find(material => material.name === 'PortalGround');
assert.equal(groundMaterial.alphaMode, 'BLEND');
assert.equal(groundMaterial.doubleSided, true);
assert.deepEqual(groundMaterial.pbrMetallicRoughness.baseColorFactor, [...new THREE.Color(0x101113).toArray(), 1]);
assert.equal(groundMaterial.pbrMetallicRoughness.metallicFactor, 0);
assert.equal(groundMaterial.pbrMetallicRoughness.roughnessFactor ?? 1, 1);
assert.deepEqual(groundMaterial.pbrMetallicRoughness.baseColorTexture, { index: 0, texCoord: 0 });
const groundMesh = json.meshes[json.nodes.find(node => node.name === 'Ground').mesh];
assert(groundMesh.primitives.every(primitive => primitive.attributes.TEXCOORD_0 !== undefined));
assert.equal(json.images[0].mimeType, 'image/png');
const imageView = json.bufferViews[json.images[0].bufferView];
const png = bytes.subarray(binaryOffset + 8 + imageView.byteOffset, binaryOffset + 8 + imageView.byteOffset + imageView.byteLength);
assert.deepEqual(png.subarray(0, 8), Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
const idat = [];
for (let offset = 8; offset < png.length;) {
  const length = png.readUInt32BE(offset);
  const type = png.toString('ascii', offset + 4, offset + 8);
  const content = png.subarray(offset + 8, offset + 8 + length);
  assert.equal(crc32(png.subarray(offset + 4, offset + 8 + length)), png.readUInt32BE(offset + 8 + length));
  if (type === 'IHDR') {
    assert.equal(content.readUInt32BE(0), 256);
    assert.equal(content.readUInt32BE(4), 256);
    assert.equal(content[9], 6);
  }
  if (type === 'IDAT') idat.push(content);
  offset += length + 12;
}
const pixels = inflateSync(Buffer.concat(idat));
assert.equal(pixels.length, 256 * 1025);
const alpha = (x, y) => pixels[y * 1025 + 1 + x * 4 + 3];
for (let i = 0; i < 256; i++) {
  assert.equal(pixels[i * 1025], 0, 'PNG rows use no filter');
  for (const value of [alpha(i, 0), alpha(i, 255), alpha(0, i), alpha(255, i)]) assert.equal(value, 0, 'Transparent outer edges');
}
assert(Math.abs(alpha(127, 127) / 255 - .7) < .005, 'Center opacity is 0.7');
for (let x = 128; x < 255; x++) assert(alpha(x + 1, 128) <= alpha(x, 128), 'Smooth monotonic radial fade');
assert.deepEqual(json.nodes.find(node => node.name === 'Ground').translation, [0, -1.43, 0]);
assert.deepEqual(json.nodes.find(node => node.name === 'Ground').rotation, ground.quaternion.toArray());
assert.deepEqual(pivotNode.translation, [-.706, 0, .23]);
assert(!pivotNode.rotation, 'Door starts closed with identity pivot rotation');
assert.deepEqual(json.nodes.find(node => node.name === 'DoorLeaf').translation, [.706, 0, 0]);

// Round trip geometry before texture embedding: Node has no browser image decoder.
// The final embedded image, UV reference, PNG data and CRCs are checked above.
const loaded = await new GLTFLoader().parseAsync(geometryGlb, '');
const restored = loaded.scene.getObjectByName('PortalRoot');
assert(restored);
restored.updateMatrixWorld(true);
for (const original of [frame, pivot, leaf, panel, handle, lower, upper, threshold, ground]) {
  const copy = restored.getObjectByName(original.name);
  assert(copy, `Round-trip node ${original.name}`);
  original.matrixWorld.elements.forEach((value, index) => {
    assert(Math.abs(value - copy.matrixWorld.elements[index]) < 1e-12, `${original.name} world transform`);
  });
}
const originalBounds = new THREE.Box3().setFromObject(root);
const restoredBounds = new THREE.Box3().setFromObject(restored);
assert(originalBounds.min.distanceTo(restoredBounds.min) < 1e-6);
assert(originalBounds.max.distanceTo(restoredBounds.max) < 1e-6);

await mkdir(dirname(output), { recursive: true });
await writeFile(output, bytes);
console.log(JSON.stringify({
  output, bytes: bytes.length, nodes: json.nodes.length, meshes: json.meshes.length,
  primitives: json.meshes.reduce((sum, mesh) => sum + mesh.primitives.length, 0),
  materials: json.materials.map(material => material.name),
  pivot: pivotNode, bounds: { min: originalBounds.min.toArray(), max: originalBounds.max.toArray() },
  texture: { name: 'GroundRadialAlpha', size: '256x256', bytes: png.length, centerAlpha: alpha(127, 127), edgeAlpha: 0 },
  validation: 'GLB chunks, buffers, accessors, PBR factors, PNG CRCs/pixels/transparent edges and geometry loader round trip passed',
}, null, 2));
