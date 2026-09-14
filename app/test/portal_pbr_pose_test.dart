import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'package:tracktime/widgets/portal/portal_geometry.dart';
import 'package:tracktime/widgets/portal/pbr/portal_pbr_pose.dart';

void main() {
  test(
    'Filament projection follows the Flutter aperture throughout traversal',
    () {
      const size = Size(402, 760), stage = Rect.fromLTWH(0, 18, 402, 340);
      for (final t in [0.0, .15, .6, 1.0, 1.45]) {
        final g = PortalGeometry(
          stage: stage,
          viewport: size,
          phase: .3,
          seconds: t,
          travelling: true,
        );
        final pose = PortalPbrPose(g);
        final cameraInverse = pose.camera..invert();
        final transform = pose.projection * cameraInverse * pose.root;
        for (final point in [
          vm.Vector4(-.72, -1.08, -.09, 1),
          vm.Vector4(.72, -1.08, -.09, 1),
          vm.Vector4(0, 1.085, -.09, 1),
        ]) {
          final projected = transform.transformed(point);
          final screen = Offset(
            (projected.x / projected.w + 1) * size.width / 2,
            (1 - projected.y / projected.w) * size.height / 2,
          );
          expect(
            (screen - g.project(point.x, point.y, point.z)).distance,
            lessThan(.0001),
            reason: 'time $t',
          );
        }
      }
    },
  );
  test(
    'PBR hinge transform matches the native door without a starting jump',
    () {
      final g = PortalGeometry(
        stage: const Rect.fromLTWH(10, 50, 390, 320),
        viewport: const Size(430, 800),
        phase: .6,
      );
      final pose = PortalPbrPose(g);
      final transform =
          pose.projection *
          (pose.camera..invert()) *
          pose.root *
          pose.pivot *
          vm.Matrix4.translationValues(.706, 0, 0);
      final p = vm.Vector4(.534, -.24, .21, 1), clip = transform.transformed(p);
      final screen = Offset(
        (clip.x / clip.w + 1) * 430 / 2,
        (1 - clip.y / clip.w) * 800 / 2,
      );
      expect(
        (screen - g.project(p.x, p.y, p.z, door: true)).distance,
        lessThan(.0001),
      );
    },
  );
}
