import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'portal_geometry.dart';
import 'portal_surface_mesh.dart';

/// Projected ceramic and metal surfaces share the live Explorer's camera.
class PortalDoorPainter extends CustomPainter {
  PortalDoorPainter({required this.geometry, super.repaint});
  final PortalGeometry Function(Size) geometry;
  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry(size);
    if (g.travelling && g.seconds >= 1.95) return;
    final opacity = g.travelling ? 1 - portalEase(1.78, 1.95, g.seconds) : 1.0;
    final breath = (1 - math.cos(g.phase * math.pi * 2)) / 2;
    if (g.travel < .75) {
      final center = g.project(0, -1.35, .25);
      final width = g.stage.height * .58 * (1 + g.travel);
      canvas.drawOval(
        Rect.fromCenter(center: center, width: width, height: width * .23),
        Paint()
          ..shader = ui.Gradient.radial(center, width * .5, [
            Colors.black.withValues(alpha: .5 * opacity * (1 - g.travel)),
            Colors.transparent,
          ])
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      final spill = Path()
        ..addPolygon([
          g.project(-.60, -1.29, .20),
          g.project(.60, -1.29, .20),
          g.project(.94, -1.29, 1.85 + breath * .12),
          g.project(-.94, -1.29, 1.85 + breath * .12),
        ], true);
      canvas.drawPath(
        spill,
        Paint()
          ..shader = ui.Gradient.linear(
            g.project(0, -1.29, .20),
            g.project(0, -1.29, 2),
            [
              const Color(0xFFFFAC76).withValues(
                alpha: (.14 + breath * .035) * opacity * (1 - g.travel),
              ),
              Colors.transparent,
            ],
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }
    final interior = g.arch(1.45, 2.18, -.105), bounds = interior.getBounds();
    canvas.drawPath(
      interior,
      Paint()
        ..shader = ui.Gradient.linear(bounds.topCenter, bounds.bottomCenter, [
          const Color(0xFF45266B).withValues(alpha: opacity * (1 - g.reveal)),
          const Color(0xFFF9A16D).withValues(alpha: opacity * (1 - g.reveal)),
        ]),
    );
    PortalSurfaceMesh.instance.paint(canvas, g, opacity);
  }

  @override
  bool shouldRepaint(covariant PortalDoorPainter oldDelegate) =>
      oldDelegate.geometry != geometry;
}
