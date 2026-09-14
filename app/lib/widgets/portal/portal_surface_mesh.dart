import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'portal_geometry.dart';

// Small, cached sculptural mesh. Lighting is evaluated on smooth surface normals
// and interpolated by Canvas, keeping the actual Explorer underneath the arch.
class _V {
  const _V(this.x, this.y, this.z);
  final double x, y, z;
  _V operator +(_V b) => _V(x + b.x, y + b.y, z + b.z);
  _V operator -(_V b) => _V(x - b.x, y - b.y, z - b.z);
  _V operator *(double s) => _V(x * s, y * s, z * s);
  double dot(_V b) => x * b.x + y * b.y + z * b.z;
  _V get unit =>
      this * (1 / math.sqrt(dot(this)).clamp(.00001, double.infinity));
}

class _Vertex {
  const _Vertex(
    this.p,
    this.n,
    this.color, {
    this.door = false,
    this.metal = false,
  });
  final _V p, n;
  final Color color;
  final bool door, metal;
}

class _Face {
  const _Face(this.a, this.b, this.c, this.group);
  final int a, b, c, group;
}

class _Profile {
  const _Profile(this.w, this.h, this.z, this.side, this.nz);
  final double w, h, z, side, nz;
}

class _Lit {
  const _Lit(this.p, this.depth, this.r, this.g, this.b, this.facing);
  final _V p;
  final double depth, r, g, b, facing;
  _Lit mix(_Lit b, double t) => _Lit(
    p + (b.p - p) * t,
    depth + (b.depth - depth) * t,
    r + (b.r - r) * t,
    g + (b.g - g) * t,
    this.b + (b.b - this.b) * t,
    facing + (b.facing - facing) * t,
  );
}

class PortalSurfaceMesh {
  PortalSurfaceMesh._() {
    _arch(1.86, 2.58, -.12, .17, .025, ceramic, innerW: 1.46, innerH: 2.20);
    _arch(1.40, 2.14, 0, .105, .025, const Color(0xFF685282), door: true);
    _arch(1.29, 2.02, .118, .124, .018, ceramic, door: true);
    // Both hinge barrels and a capsule handle, with actual projected thickness.
    for (final y in [-.70, .45]) {
      _capsule(-.744, y, .225, .036, .22, door: false);
      _capsule(-.744, y - .075, .225, .039, .012, door: false);
      _capsule(-.744, y + .075, .225, .039, .012, door: false);
    }
    _capsule(.534, -.24, .21, .021, .21, door: true);
    for (final y in [-.33, -.15]) {
      _arch(.047, .057, .12, .19, .007, silver, door: true, cx: .534, cy: y);
    }
    _box(-.76, .76, -1.14, -1.08, -.14, .34);
  }
  static final instance = PortalSurfaceMesh._();
  static const ceramic = Color(0xFFA88BDA), silver = Color(0xFFD8D4DE);
  static const segments = 48;
  final _vertices = <_Vertex>[];
  final _faces = <_Face>[];
  int _group = -1;
  final _groupVertices = <int>[];
  void _quad(int a, int b, int c, int d) {
    _faces.add(_Face(a, b, c, _group));
    _faces.add(_Face(a, c, d, _group));
  }

  (_V, _V) _outline(int i, double w, double h) {
    if (i == 0) return (_V(-w / 2, -h / 2, 0), const _V(-.707, -.707, 0));
    if (i == 1) return (_V(w / 2, -h / 2, 0), const _V(.707, -.707, 0));
    final a = math.pi * (i - 2) / segments;
    return (
      _V(w / 2 * math.cos(a), h / 2 - w / 2 + w / 2 * math.sin(a), 0),
      _V(math.cos(a), math.sin(a), 0),
    );
  }

  void _arch(
    double w,
    double h,
    double back,
    double front,
    double bevel,
    Color color, {
    double? innerW,
    double? innerH,
    bool door = false,
    double cx = 0,
    double cy = 0,
  }) {
    _group++;
    _groupVertices.add(_vertices.length);
    final profiles = <_Profile>[];
    void curve(double w, double h, double z, bool front, bool inner) {
      for (var j = 0; j <= 4; j++) {
        final a = j / 4 * math.pi / 2;
        final side = inner ? -1.0 : 1.0;
        // Quarter-circle bevel, with a continuous normal from face to side.
        profiles.add(
          _Profile(
            w + side * 2 * bevel * math.sin(a),
            h + side * 2 * bevel * math.sin(a),
            z + (front ? 1 : -1) * bevel * math.cos(a),
            side * math.sin(a),
            (front ? 1 : -1) * math.cos(a),
          ),
        );
      }
    }

    curve(w, h, back, false, false);
    final start = profiles.length;
    curve(w, h, front, true, false);
    final outerFront = profiles.sublist(start).reversed.toList();
    profiles.replaceRange(start, profiles.length, outerFront);
    if (innerW != null) {
      curve(innerW, innerH!, front, true, true);
      final at = profiles.length;
      curve(innerW, innerH, back, false, true);
      final innerBack = profiles.sublist(at).reversed.toList();
      profiles.replaceRange(at, profiles.length, innerBack);
    }
    const count = segments + 3;
    final base = _vertices.length;
    for (final s in profiles) {
      for (var i = 0; i < count; i++) {
        final (p, n) = _outline(i, s.w, s.h);
        _vertices.add(
          _Vertex(
            _V(p.x + cx, p.y + cy, s.z),
            _V(n.x * s.side, n.y * s.side, s.nz).unit,
            color,
            door: door,
            metal: color == silver,
          ),
        );
      }
    }
    for (
      var j = 0;
      j < (innerW != null ? profiles.length : profiles.length - 1);
      j++
    ) {
      final next = (j + 1) % profiles.length;
      for (var i = 0; i < count; i++) {
        final n = (i + 1) % count;
        _quad(
          base + j * count + i,
          base + j * count + n,
          base + next * count + n,
          base + next * count + i,
        );
      }
    }
    if (innerW == null) {
      for (final side in [0, profiles.length - 1]) {
        final center = _vertices.length;
        _vertices.add(
          _Vertex(
            _V(cx, cy, profiles[side].z),
            _V(0, 0, side == 0 ? -1 : 1),
            color,
            door: door,
            metal: color == silver,
          ),
        );
        for (var i = 0; i < count; i++) {
          _faces.add(
            _Face(
              center,
              base + side * count + i,
              base + side * count + (i + 1) % count,
              _group,
            ),
          );
        }
      }
    }
  }

  void _capsule(
    double x,
    double y,
    double z,
    double radius,
    double length, {
    required bool door,
  }) {
    _group++;
    _groupVertices.add(_vertices.length);
    const around = 12, rings = 12;
    final base = _vertices.length;
    for (var j = 0; j <= rings; j++) {
      final lat = -math.pi / 2 + j / rings * math.pi;
      final yy =
          math.sin(lat) * radius + (j < rings / 2 ? -length / 2 : length / 2);
      for (var i = 0; i < around; i++) {
        final a = i / around * 2 * math.pi;
        final n = _V(
          math.cos(a) * math.cos(lat),
          math.sin(lat),
          math.sin(a) * math.cos(lat),
        );
        _vertices.add(
          _Vertex(
            _V(x + n.x * radius, y + yy, z + n.z * radius),
            n,
            silver,
            door: door,
            metal: true,
          ),
        );
      }
    }
    for (var j = 0; j < rings; j++) {
      for (var i = 0; i < around; i++) {
        final n = (i + 1) % around;
        _quad(
          base + j * around + i,
          base + j * around + n,
          base + (j + 1) * around + n,
          base + (j + 1) * around + i,
        );
      }
    }
  }

  void _box(double l, double r, double b, double t, double back, double front) {
    _group++;
    _groupVertices.add(_vertices.length);
    void face(List<_V> p, _V n) {
      final base = _vertices.length;
      for (final v in p) {
        _vertices.add(_Vertex(v, n, silver, metal: true));
      }
      _quad(base, base + 1, base + 2, base + 3);
    }

    face([
      _V(l, t, back),
      _V(r, t, back),
      _V(r, t, front),
      _V(l, t, front),
    ], const _V(0, 1, 0));
    face([
      _V(l, b, front),
      _V(r, b, front),
      _V(r, t, front),
      _V(l, t, front),
    ], const _V(0, 0, 1));
    face([
      _V(r, b, back),
      _V(r, t, back),
      _V(r, t, front),
      _V(r, b, front),
    ], const _V(1, 0, 0));
  }

  void paint(Canvas canvas, PortalGeometry g, double opacity) {
    final camera = _V(
      3 * (1 - g.align),
      1.75 * (1 - g.align),
      6.5 * (1 - g.travel) + .055 * g.travel,
    );
    final forward = (_V(0, -.03 * (1 - g.align), 0) - camera).unit;
    final key = const _V(-3, 5, 4).unit, rim = const _V(3, 1, -3).unit;
    final c = math.cos(g.angle), s = math.sin(g.angle);
    _V rotate(_V p) => _V(p.x * c - p.z * s, p.y, p.x * s + p.z * c);
    final lit = _vertices
        .map((v) {
          final p = v.door
              ? rotate(v.p + const _V(.706, 0, 0)) + const _V(-.706, 0, .23)
              : v.p;
          final n = v.door ? rotate(v.n) : v.n;
          final view = (camera - p).unit;
          final diffuse = math.max(0, n.dot(key));
          final edge = math.max(0, n.dot(rim));
          final spec = math
              .pow(math.max(0, n.dot((key + view).unit)), v.metal ? 65 : 42)
              .toDouble();
          final broad = math
              .pow(
                math.max(0, n.dot((const _V(-.8, 1.6, 3).unit + view).unit)),
                8,
              )
              .toDouble();
          final light =
              .40 +
              .70 * diffuse +
              .20 * edge +
              .065 * ((p.y + 1.3) / 2.6).clamp(0, 1);
          final reflection =
              spec * (v.metal ? .80 : .34) + broad * (v.metal ? .25 : .10);
          final warm = math.max(0, -n.y) * .045 * (1 - g.reveal);
          return _Lit(
            p,
            (p - camera).dot(forward),
            (v.color.r * light + reflection + warm).clamp(0, 1),
            (v.color.g * light + reflection * .97 + warm * .45).clamp(0, 1),
            (v.color.b * light + reflection * .97 + edge * .04).clamp(0, 1),
            n.dot(view),
          );
        })
        .toList(growable: false);
    final depths = List<double>.generate(_groupVertices.length, (i) {
      final start = _groupVertices[i],
          end = i + 1 < _groupVertices.length
              ? _groupVertices[i + 1]
              : lit.length;
      var sum = 0.0;
      for (var j = start; j < end; j++) {
        sum += lit[j].depth;
      }
      return sum / (end - start);
    });
    // Back-to-front triangles keep hardware, leaf and jambs correctly occluded.
    final order =
        _faces
            .where(
              (f) => lit[f.a].facing + lit[f.b].facing + lit[f.c].facing > 0,
            )
            .toList()
          ..sort((a, b) {
            if (a.group == 0 && b.group != 0) return -1;
            if (b.group == 0 && a.group != 0) return 1;
            if (a.group != b.group) {
              return depths[b.group].compareTo(depths[a.group]);
            }
            return (lit[b.a].depth + lit[b.b].depth + lit[b.c].depth).compareTo(
              lit[a.a].depth + lit[a.b].depth + lit[a.c].depth,
            );
          });
    final xy = <double>[], colors = <int>[];
    void emit(_Lit v) {
      final p = g.project(v.p.x, v.p.y, v.p.z);
      xy.addAll([p.dx, p.dy]);
      colors.add(
        Color.from(alpha: opacity, red: v.r, green: v.g, blue: v.b).toARGB32(),
      );
    }

    for (final f in order) {
      final polygon = [lit[f.a], lit[f.b], lit[f.c]], clipped = <_Lit>[];
      for (var i = 0; i < 3; i++) {
        final a = polygon[i], b = polygon[(i + 1) % 3];
        if (a.depth >= .05) clipped.add(a);
        if ((a.depth >= .05) != (b.depth >= .05)) {
          clipped.add(a.mix(b, (.05 - a.depth) / (b.depth - a.depth)));
        }
      }
      for (var i = 1; i < clipped.length - 1; i++) {
        emit(clipped[0]);
        emit(clipped[i]);
        emit(clipped[i + 1]);
      }
    }
    if (xy.isEmpty) return;
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List.fromList(xy),
      colors: Int32List.fromList(colors),
    );
    canvas.drawVertices(vertices, BlendMode.srcOver, Paint());
    vertices.dispose();
  }
}
