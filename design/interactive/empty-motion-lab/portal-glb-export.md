# Portal GLB

`app/assets/portal/portal.glb` exports the solid portal directly from the existing
`passage()` builder in `sculptures.js`. It uses Three.js 0.186.0 and its official
GLTFExporter. A procedural 256 × 256 RGBA PNG is embedded in the GLB; no external
asset, texture or browser canvas is required.

Regenerate from the repository root (Node.js 18+):

```sh
npm ci --prefix design/interactive/empty-motion-lab
node design/interactive/empty-motion-lab/export-portal-glb.mjs
```

The generator validates binary chunks, buffers, accessor bounds, PBR values,
named transforms and a GLTFLoader geometry round trip before writing the asset.
It checks the embedded PNG's CRCs, dimensions, decoded alpha values and texture
UV reference separately, since Node has no browser image decoder. It prints
the resulting file size and bounds. `PortalRoot.extras.sourceSha256` identifies
the exact source helpers and portal builder used.

Hierarchy, in original prototype units with Y up:

```text
PortalRoot                         rotation Z = -0.025 radians
├── PortalFrame                    (0, 0, -0.12)
├── DoorPivot                      (-0.706, 0, 0.23), identity rotation
│   ├── DoorLeaf                   (0.706, 0, 0)
│   ├── DoorPanel                  (0.706, 0, 0.118)
│   └── DoorHandle                 (1.24, -0.24, 0.21)
├── HingeLower                     (-0.744, -0.70, 0.225)
├── HingeUpper                     (-0.744, 0.45, 0.225)
├── Threshold                      (0, -1.11, 0.10)
└── Ground                         (0, -1.43, 0), rotation X = -π/2
```

All scales are identity. The model is not centered or normalized. Set
`DoorPivot`'s local Y rotation to the negative opening angle, as in the prototype.
The leaf, raised ceramic panel and capsule handle move together. The hinges
remain attached to the frame. Root Z rotation preserves the prototype's initial
tilt; the runtime can replace the root rotation during alignment and entry.

Seven solid meshes retain the prototype's geometry, including arch bevels and
curve segments, both hinge cylinders, the capsule handle and box threshold.
An eighth mesh, `Ground`, is a 4.4 × 3.6 plane under `PortalRoot`, for receiving
runtime contact shadows. Its material is double-sided with glTF alpha mode
`BLEND` and initial opacity 1. Fade its `baseColorFactor` alpha to 0 during
traversal. The runtime should disable shadow casting for this mesh; Three.js
shadow flags are not encoded by glTF.

`GroundRadialAlpha` supplies a white RGB base-color texture with center alpha
0.7 and a smooth radial fade to zero before reaching the plane's edges. The
radial function uses a squared smoothstep falloff, centered at UV (0.5, 0.5),
with zero alpha at normalized radius 0.96 and beyond. The plane's dimensions
make this footprint elliptical in world space. All boundary pixels are fully
transparent; clamp-to-edge wrapping and linear sampling preserve the soft edge.
The texture alpha multiplies the material alpha during traversal fades.

| Material | sRGB color | Metalness | Roughness |
| --- | --- | --- | --- |
| LilacCeramic | `#a88bda` | 0.16 | 0.38 |
| DarkLeaf | `#5d487a` | 0.40 | 0.28 |
| Silver | `#d8d4de` | 0.94 | 0.17 |
| PortalGround | `#101113` | 0 | 1 |

The three solid materials include clearcoat 0.65 and clearcoat roughness 0.22 through
`KHR_materials_clearcoat`. glTF stores base colors in linear RGB, so the numeric
JSON factors differ from the listed sRGB hex values. Studio environment maps,
exposure, tone mapping and lighting are runtime responsibilities.

The shader interior, light spill, original ground-shadow texture, camera and lights are excluded.
The aperture is open so Flutter content can appear behind it. No GLB animation
clips are baked; the runtime controls the named pivot and root.
