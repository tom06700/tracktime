import 'dart:math' as math;
import 'dart:ui';

/// Shared camera and hinge pose for the resting door and the full-screen passage.
/// Values follow the approved Three.js prototype, in world units.
double portalEase(double start, double end, double seconds) {
  final t = ((seconds - start) / (end - start)).clamp(0.0, 1.0);
  return t * t * t * (t * (t * 6 - 15) + 10);
}

typedef Point3 = ({double x, double y, double z});

class PortalGeometry {
  PortalGeometry({
    required this.stage,
    required this.viewport,
    required this.phase,
    this.seconds = 0,
    this.travelling = false,
  });
  final Rect stage;
  final Size viewport;
  final double phase, seconds;
  final bool travelling;
  double get align => travelling ? portalEase(0, .85, seconds) : 0;
  double get travel => travelling ? portalEase(.27, 1.88, seconds) : 0;
  double get reveal => travelling ? portalEase(.25, .85, seconds) : 0;
  double get angle {
    final rest = .72 + .22 * (1 - math.cos(phase * math.pi * 2)) / 2;
    return rest +
        (1.86 - rest) * (travelling ? portalEase(0, .72, seconds) : 0);
  }

  Offset project(double x, double y, double z, {bool door = false}) {
    if (door) {
      final local = x + .706;
      x = -.706 + local * math.cos(angle) - z * math.sin(angle);
      z = .23 + local * math.sin(angle) + z * math.cos(angle);
    }
    final roll = -.025 * (1 - align);
    final xx = x * math.cos(roll) - y * math.sin(roll);
    y = x * math.sin(roll) + y * math.cos(roll);
    x = xx;
    final cx = 3 * (1 - align), cy = 1.75 * (1 - align);
    final cz = 6.5 * (1 - travel) + .055 * travel;
    final targetY = -.03 * (1 - align);
    final length = math.sqrt(
      cx * cx + (cy - targetY) * (cy - targetY) + cz * cz,
    );
    final fx = -cx / length, fy = (targetY - cy) / length, fz = -cz / length;
    final rightLength = math.sqrt(fz * fz + fx * fx);
    final rx = -fz / rightLength, rz = fx / rightLength;
    final ux = -rz * fy, uy = rz * fx - rx * fz, uz = rx * fy;
    final dx = x - cx, dy = y - cy, dz = z - cz;
    final depth = math.max(.025, dx * fx + dy * fy + dz * fz);
    final focal =
        stage.height / 3.66 * math.sqrt(3 * 3 + 1.78 * 1.78 + 6.5 * 6.5);
    final center = Offset.lerp(
      stage.center,
      viewport.center(Offset.zero),
      align,
    )!;
    return center +
        Offset(
          (dx * rx + dz * rz) * focal / depth,
          -(dx * ux + dy * uy + dz * uz) * focal / depth,
        );
  }

  List<Offset> archPoints(
    double width,
    double height,
    double z, {
    bool door = false,
  }) {
    final r = width / 2, shoulder = height / 2 - r;
    final points = <Offset>[
      project(-r, -height / 2, z, door: door),
      project(r, -height / 2, z, door: door),
    ];
    for (var i = 0; i <= 48; i++) {
      final a = math.pi * i / 48;
      points.add(
        project(r * math.cos(a), shoulder + r * math.sin(a), z, door: door),
      );
    }
    return points;
  }

  Path arch(double w, double h, double z, {bool door = false}) =>
      Path()..addPolygon(archPoints(w, h, z, door: door), true);
  Path get aperture => seconds >= 1.86 && travelling
      ? (Path()..addRect(Offset.zero & viewport))
      : arch(1.44, 2.17, -.09);
}
