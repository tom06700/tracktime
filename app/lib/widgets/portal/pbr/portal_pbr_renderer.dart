import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart' as t;
import '../portal_geometry.dart';
import 'portal_pbr_pose.dart';

/// One transparent Filament surface for both the resting model and traversal.
/// Native work is serialized: animation ticks replace the pending pose instead
/// of adding unbounded render-thread requests.
class PortalPbrRenderer extends StatefulWidget {
  const PortalPbrRenderer({
    super.key,
    required this.pose,
    required this.enabled,
    required this.active,
    required this.onReady,
    required this.onError,
  });
  final ValueNotifier<PortalGeometry> pose;
  final bool enabled, active;
  final VoidCallback onReady;
  final ValueChanged<Object> onError;
  @override
  State<PortalPbrRenderer> createState() => _PortalPbrRendererState();
}

class _PortalPbrRendererState extends State<PortalPbrRenderer> {
  t.ThermionViewer? _viewer;
  t.Camera? _camera;
  t.ThermionEntity? _root, _pivot;
  t.MaterialInstance? _ground;
  late final Future<void> _initialization;
  Future<void>? _update;
  PortalGeometry? _pending;
  bool _disposing = false,
      _configured = false,
      _surfaceReady = false,
      _reportedReady = false;
  Size? _pendingViewport;
  Object? _error;
  @override
  void initState() {
    super.initState();
    widget.pose.addListener(_requestPose);
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    try {
      final viewer = await t.ThermionFlutterPlugin.createViewer();
      _viewer = viewer;
      if (_disposing) return;
      await viewer.setRendering(false);
      await viewer.setBackgroundColor(0, 0, 0, 0);
      await viewer.view.setBlendMode(t.BlendMode.transparent);
      await viewer.setPostProcessing(true);
      await viewer.setAntiAliasing(true, true, false);
      await viewer.view.setShadowsEnabled(true);
      viewer.app.setTargetFramerate(60);
      await viewer.loadIbl('assets/portal/studio_ibl.ktx', intensity: 30000);
      if (_disposing) return;
      final asset = await viewer.loadGltf('assets/portal/portal.glb');
      // Asset helpers also visit transform-only nodes. Only renderables can
      // receive shadow flags (and the ground should not cast onto the door).
      for (final entity in await asset.getChildEntities()) {
        if (await viewer.app.isRenderable(entity)) {
          await viewer.app.renderableManager.setCastShadows(entity, true);
          await viewer.app.renderableManager.setReceiveShadows(entity, true);
        }
      }
      _root = await asset.getChildEntity('PortalRoot');
      _pivot = await asset.getChildEntity('DoorPivot');
      if (_root == null || _pivot == null) {
        throw StateError('La charnière du modèle est absente.');
      }
      final ground = await asset.getChildEntity('Ground');
      if (ground != null) {
        await viewer.app.renderableManager.setCastShadows(ground, false);
        _ground = await asset.getMaterialInstanceAt(entity: ground);
      }
      await viewer.addDirectLight(
        t.DirectLight.sun(
          intensity: 55000,
          colorTemperature: 5100,
          direction: t.Vector3(3, -5, -4),
          castShadows: true,
        ),
      );
      await viewer.addDirectLight(
        t.DirectLight.point(
          intensity: 3500,
          color: const t.LinearColor(.57, .42, 1),
          position: t.Vector3(3, 1, -3),
          falloffRadius: 8,
          castShadows: false,
        ),
      );
      await viewer.addDirectLight(
        t.DirectLight.point(
          intensity: 180,
          color: const t.LinearColor(1, .40, .16),
          position: t.Vector3(0, -.50, -.10),
          falloffRadius: 2.8,
        ),
      );
      _camera = await viewer.getActiveCamera();
      await _camera!.setExposure(16, 1 / 100, 100);
      if (_disposing) return;
      await _apply(widget.pose.value);
      _configured = true;
      setState(() {});
    } catch (error, stack) {
      debugPrint('Portal PBR: $error\n$stack');
      _error = error;
      if (mounted && !_disposing) {
        setState(() {});
        widget.onError(error);
      }
    }
  }

  Future<void> _apply(PortalGeometry geometry) async {
    final pose = PortalPbrPose(geometry), viewer = _viewer!, camera = _camera!;
    await viewer.app.setTransform(_root!, pose.root);
    await viewer.app.setTransform(_pivot!, pose.pivot);
    await camera.setModelMatrix(pose.camera);
    await camera.setProjectionMatrixWithCulling(pose.projection, .025, 40);
    final alpha = geometry.travelling
        ? 1 - portalEase(.1, .6, geometry.seconds)
        : 1.0;
    await _ground?.setParameterFloat4(
      'baseColorFactor',
      .00518,
      .00561,
      .00651,
      alpha,
    );
  }

  void _requestPose() {
    if (_disposing || !_configured || !_surfaceReady || _error != null) return;
    _pending = widget.pose.value;
    if (_update != null) return;
    _update = _drain().whenComplete(() {
      _update = null;
      if (_pending != null && !_disposing) _requestPose();
    });
  }

  Future<void> _drain() async {
    try {
      while (_pending != null && !_disposing) {
        final geometry = _pending!;
        _pending = null;
        if (!widget.active) {
          if (_viewer!.rendering) await _viewer!.setRendering(false);
          continue;
        }
        final viewport = _pendingViewport;
        _pendingViewport = null;
        if (viewport != null) {
          await _viewer!.view.setViewport(
            viewport.width.toInt(),
            viewport.height.toInt(),
          );
        }
        await _apply(geometry);
        await _viewer!.setRendering(true);
        if (!widget.enabled) {
          // Submit the complete frame through the native render manager.
          // renderSingleFrame splits begin/render/end across async calls and
          // can interleave with the scheduler or a surface resize (SIGABRT).
          await _viewer!.app.renderManager.render();
          await _viewer!.setRendering(false);
        }
        if (!_reportedReady && !_disposing) {
          _reportedReady = true;
          widget.onReady();
        }
      }
    } catch (error, stack) {
      debugPrint('Portal PBR update: $error\n$stack');
      _error = error;
      await _viewer?.setRendering(false);
      if (mounted && !_disposing) {
        setState(() {});
        widget.onError(error);
      }
    }
  }

  @override
  void didUpdateWidget(PortalPbrRenderer old) {
    super.didUpdateWidget(old);
    if (old.pose != widget.pose) {
      old.pose.removeListener(_requestPose);
      widget.pose.addListener(_requestPose);
    }
    _requestPose();
  }

  @override
  void dispose() {
    _disposing = true;
    widget.pose.removeListener(_requestPose);
    unawaited(_tearDown());
    super.dispose();
  }

  Future<void> _tearDown() async {
    await _initialization;
    await _update;
    final viewer = _viewer;
    if (viewer == null) return;
    try {
      await viewer.setRendering(false);
      await t.ThermionFlutterPlugin.instance.destroyTextureForView(viewer.view);
      await viewer.dispose();
      await t.ThermionFlutterPlugin.instance.onViewerDisposed(viewer.view);
    } catch (error, stack) {
      debugPrint('Portal PBR cleanup: $error\n$stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_configured || _error != null) return const SizedBox.expand();
    // A 2x surface is sufficient for this small object and bounds GPU fill cost.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        devicePixelRatio: math.min(2, MediaQuery.devicePixelRatioOf(context)),
      ),
      child: t.ThermionWidgetInternal(
        view: _viewer!.view,
        surfaceWidgetBuilder: (descriptor, view) => descriptor == null
            ? const SizedBox.expand()
            : Texture(
                key: ValueKey(descriptor.flutterTextureId),
                textureId: descriptor.flutterTextureId,
                filterQuality: FilterQuality.low,
              ),
        onTextureUpdated: (descriptor) {
          if (descriptor == null || _disposing) return;
          _pendingViewport = Size(
            descriptor.width.toDouble(),
            descriptor.height.toDouble(),
          );
          _surfaceReady = true;
          _requestPose();
        },
      ),
    );
  }
}
