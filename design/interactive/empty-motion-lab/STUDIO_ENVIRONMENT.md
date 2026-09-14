# Nitrate portal studio lighting

`app/assets/portal/studio_ibl.ktx` is an original procedural environment for the
native PBR portal. It contains a soft cool-neutral room, large warm-white
rectangular key and ceiling diffusers, a narrow front reflection strip, and a
faint lilac fill. It follows the broad studio-lighting idea of the Three.js
prototype without copying RoomEnvironment geometry, textures, or radiance.

The source is `generate-studio-environment.py`: an analytic room intersection
and linear RGB lighting function, written for Nitrate. No photographs, downloaded
HDRIs, AI-generated images, or third-party visual assets are included. The source
and resulting asset belong to this project under its applicable licensing terms;
there is no separate third-party image license or attribution requirement.

## Runtime

Use `viewer.loadIbl('assets/portal/studio_ibl.ktx', intensity: 30000)` as the
starting point. Tune the viewer's exposure and scene lights during device review.
This is relative studio radiance, not a measured physical space. No skybox needs
to be loaded; this asset supplies diffuse irradiance and specular reflections
while the scene background remains transparent.

- Filament KTX1, R11F_G11F_B10F packed floating point, six cubemap faces.
- Five GGX roughness levels: 256, 128, 64, 32, 16 pixels per face.
- Embedded `sh` metadata: nine RGB irradiance coefficients (27 floats).
- File size: **2,095,444 bytes** (about 2.00 MiB).
- SHA-256: `40274077d3dfa3cb905044f4a284f4d3b68f22890488b80e58e5a8ceb569f6c7`.

The structure and all 30 face/mip blobs were checked with both the generator's
parser and the official Filament 1.69.1 `image::Ktx1Bundle`. Its native
`getSphericalHarmonics()` returned success with finite values, matching the
metadata path used by Thermion Dart 0.5.0's `loadIbl`. L00 RGB is approximately
`(0.911510, 0.885517, 0.874611)`. Rendering validation belongs to the native portal
integration; asset parsing alone does not validate final camera exposure.

## Rebuild

Requires Python 3, NumPy, and the official Filament **1.69.1** `cmgen` executable.
The original bake used the arm64 binary in Google's macOS release:

https://github.com/google/filament/releases/tag/v1.69.1

```sh
curl -L --fail https://github.com/google/filament/releases/download/v1.69.1/filament-v1.69.1-mac.tgz -o /tmp/filament-v1.69.1-mac.tgz
mkdir -p /tmp/filament-1.69.1
tar -xzf /tmp/filament-v1.69.1-mac.tgz -C /tmp/filament-1.69.1
python3 design/interactive/empty-motion-lab/generate-studio-environment.py --cmgen /tmp/filament-1.69.1/filament/bin/cmgen
python3 design/interactive/empty-motion-lab/generate-studio-environment.py --verify-only
```

Official tool archive SHA-256:
`a9eba4bcb474c0b3ca0c639c90d8e416f604287a768d7129be058785c42754da`.
Filament is Apache-2.0 licensed; the tools are not shipped with the application.
The generator uses a 2048×1024 Radiance source and cmgen with 1024 IBL integration
samples. Only the finished IBL is retained; the HDR, skybox, and standalone SH
file are temporary. Cross-platform floating point differences can change the
binary hash slightly when rebaking.
