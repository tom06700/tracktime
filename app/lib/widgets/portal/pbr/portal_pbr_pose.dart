import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vm;
import '../portal_geometry.dart';

/// The Filament camera uses exactly the perspective used by the Flutter mask.
class PortalPbrPose {
  PortalPbrPose(this.geometry);
  final PortalGeometry geometry;
  vm.Matrix4 get projection {
    final g = geometry;
    final focal = g.stage.height / 3.66 * math.sqrt(9 + 1.78 * 1.78 + 42.25);
    final centerX =
        g.stage.center.dx * (1 - g.align) + g.viewport.width / 2 * g.align;
    final centerY =
        g.stage.center.dy * (1 - g.align) + g.viewport.height / 2 * g.align;
    final matrix = vm.makePerspectiveMatrix(
      2 * math.atan(g.viewport.height / (2 * focal)),
      g.viewport.width / g.viewport.height,
      .025,
      40,
    );
    matrix[8] = 1 - 2 * centerX / g.viewport.width;
    matrix[9] = 2 * centerY / g.viewport.height - 1;
    return matrix;
  }

  vm.Matrix4 get camera {
    final g = geometry;
    return vm.makeViewMatrix(
      vm.Vector3(
        3 * (1 - g.align),
        1.75 * (1 - g.align),
        6.5 * (1 - g.travel) + .055 * g.travel,
      ),
      vm.Vector3(0, -.03 * (1 - g.align), 0),
      vm.Vector3(0, 1, 0),
    )..invert();
  }

  vm.Matrix4 get root => vm.Matrix4.rotationZ(-.025 * (1 - geometry.align));
  vm.Matrix4 get pivot =>
      vm.Matrix4.translationValues(-.706, 0, .23)..rotateY(-geometry.angle);
}
