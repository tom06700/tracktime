#!/usr/bin/env python3
"""Create Nitrate's original studio radiance and bake its Filament KTX1 IBL.

Requires Python 3 + NumPy and the official Filament 1.69.1 cmgen executable.
The HDR and auxiliary cmgen products remain in a temporary directory.
"""

import argparse
import hashlib
import math
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile

import numpy as np


ROOT = Path(__file__).resolve().parents[3]
DEFAULT_OUTPUT = ROOT / "app/assets/portal/studio_ibl.ktx"


def smooth_box(u, v, center, half_size, feather=0.045):
    """A rectangular diffuser with a small, smooth penumbra."""
    distance = np.maximum(
        (np.abs(u - center[0]) - half_size[0]) / feather,
        (np.abs(v - center[1]) - half_size[1]) / feather,
    )
    t = np.clip(0.5 - distance * 0.5, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def studio_radiance(width=2048):
    """Ray-intersect an original 6×5×6 neutral studio from its center.

    Radiance is relative linear RGB, leaving exposure to Filament. Large
    warm-white front-left and overhead panels form readable broad highlights;
    a dim cool wall panel fills the chrome and lilac enamel from the right.
    """
    height = width // 2
    longitude = ((np.arange(width) + 0.5) / width * 2 - 1) * math.pi
    latitude = (0.5 - (np.arange(height) + 0.5) / height) * math.pi
    x = np.cos(latitude[:, None]) * np.sin(longitude[None, :])
    y = np.broadcast_to(np.sin(latitude[:, None]), x.shape)
    z = np.cos(latitude[:, None]) * np.cos(longitude[None, :])
    direction = np.stack((x, y, z), axis=-1)
    limits = np.array([3.0, 2.5, 3.0])
    ray_distance = limits / np.maximum(np.abs(direction), 1e-9)
    wall = np.argmin(ray_distance, axis=-1)
    hit = direction * np.min(ray_distance, axis=-1)[..., None]

    # A cool neutral room with a darker floor; slight vertical variation keeps
    # polished reflections legible without photographic clutter.
    vertical = np.clip((hit[..., 1] + 2.5) / 5.0, 0, 1)
    rgb = (0.20 + 0.20 * vertical[..., None]) * np.array([0.95, 0.97, 1.0])
    floor = (wall == 1) & (y < 0)
    rgb[floor] *= 0.58

    def panel(axis, positive, uv_axes, center, size, emission):
        visible = (wall == axis) & ((direction[..., axis] > 0) == positive)
        shape = smooth_box(hit[..., uv_axes[0]], hit[..., uv_axes[1]], center, size)
        rgb[:] += (visible * shape)[..., None] * np.array(emission)

    panel(0, False, (2, 1), (0.8, 0.4), (1.45, 1.55), (5.4, 5.05, 4.65))
    panel(1, True, (0, 2), (-0.6, 0.3), (1.70, 1.35), (3.1, 3.02, 2.90))
    panel(2, True, (0, 1), (1.4, 0.25), (0.5, 1.75), (1.8, 1.76, 1.72))
    panel(0, True, (2, 1), (-0.25, 0.55), (1.2, 1.40), (0.68, 0.59, 0.90))
    return rgb.astype(np.float32)


def write_hdr(path, rgb):
    """Write Radiance RGBE with standard per-channel scanline RLE literals."""
    height, width, _ = rgb.shape
    maximum = np.max(rgb, axis=-1)
    mantissa, exponent = np.frexp(maximum)
    scale = np.where(maximum > 1e-32, mantissa * 256 / maximum, 0)
    rgbe = np.zeros((height, width, 4), dtype=np.uint8)
    rgbe[..., :3] = np.clip(rgb * scale[..., None], 0, 255).astype(np.uint8)
    rgbe[..., 3] = np.where(maximum > 1e-32, exponent + 128, 0).astype(np.uint8)
    with path.open("wb") as output:
        output.write(f"#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n-Y {height} +X {width}\n".encode())
        for scanline in rgbe:
            output.write(bytes((2, 2, width >> 8, width & 255)))
            for channel in range(4):
                for start in range(0, width, 128):
                    values = scanline[start:start + 128, channel].tobytes()
                    output.write(bytes((len(values),)) + values)


def verify_ktx(path):
    """Reject incompatible assets and report the cubemap/SH contract."""
    data = path.read_bytes()
    if data[:12] != b"\xabKTX 11\xbb\r\n\x1a\n":
        raise ValueError("Expected KTX1")
    header = struct.unpack_from("<13I", data, 12)
    endian, gl_type, type_size, fmt, internal, base, width, height, depth, arrays, faces, levels, kv_bytes = header
    assert endian == 0x04030201
    # cmgen 1.69.1 repeats R11F_G11F_B10F in glType/glBaseInternalFormat and
    # writes glTypeSize=1. Preserve the official writer's Filament contract.
    assert (gl_type, type_size, fmt, internal, base) == (0x8C3A, 1, 0x1907, 0x8C3A, 0x8C3A)
    assert width == height and width > 0 and depth == arrays == 0 and faces == 6
    assert levels >= 5
    offset = 64
    metadata = {}
    while offset < 64 + kv_bytes:
        size, = struct.unpack_from("<I", data, offset)
        offset += 4
        key, value = data[offset:offset + size].split(b"\x00", 1)
        metadata[key.decode()] = value.rstrip(b"\x00").decode()
        offset += (size + 3) & ~3
    sh = [float(value) for value in metadata["sh"].split()]
    assert len(sh) == 27 and all(math.isfinite(value) for value in sh)
    assert min(sh[:3]) > 0
    dimensions = []
    for level in range(levels):
        image_size, = struct.unpack_from("<I", data, offset)
        dimension = max(1, width >> level)
        assert image_size == dimension * dimension * 4
        dimensions.append(dimension)
        offset += 4 + 6 * ((image_size + 3) & ~3)
    assert offset == len(data), (offset, len(data))
    print(f"{path}: KTX1 RGB_10_11_11_REV, 6 faces, mips {dimensions}, 27 SH values")
    print(f"{len(data):,} bytes; SHA-256 {hashlib.sha256(data).hexdigest()}")
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cmgen", help="Path to the official Filament 1.69.1 cmgen")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    if args.verify_only:
        verify_ktx(args.output)
        return
    cmgen = args.cmgen or shutil.which("cmgen")
    if not cmgen:
        parser.error("Supply --cmgen /path/to/filament/bin/cmgen")
    with tempfile.TemporaryDirectory(prefix="nitrate-studio-") as directory:
        work = Path(directory)
        hdr = work / "studio.hdr"
        write_hdr(hdr, studio_radiance())
        subprocess.run([
            str(cmgen), "--quiet", "--format=ktx", "--size=256",
            "--ibl-samples=1024", f"--deploy={work / 'baked'}", str(hdr),
        ], check=True)
        candidates = list((work / "baked").rglob("*_ibl.ktx"))
        if len(candidates) != 1:
            raise RuntimeError(f"Expected exactly one baked IBL: {candidates}")
        verify_ktx(candidates[0])
        args.output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(candidates[0], args.output)
    print(f"Wrote {args.output}")


if __name__ == "__main__":
    main()
