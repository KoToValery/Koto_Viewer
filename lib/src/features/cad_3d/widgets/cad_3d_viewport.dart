import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../cad_3d_controller.dart';
import '../models/mesh_3d.dart';
import '../rendering/cad_3d_backend.dart';
import '../rendering/cad_3d_camera.dart';
import '../rendering/cad_3d_mesh_painter.dart';
import '../rendering/cad_3d_gpu_platform.dart';
import 'cad_3d_gpu_surface.dart';
import 'cad_3d_virtual_joystick.dart';

/// Common viewport for architectural, structural and imported geometry.
/// The caller owns the controller and immutable mesh; this widget owns backend
/// frames, input and ticker lifetime. Camera updates never regenerate the mesh.
class Cad3DViewport extends StatefulWidget {
  final Mesh3D mesh;
  final Cad3DController controller;
  final Cad3DShadingMode shadingMode;
  final Cad3DTheme theme;
  final bool showGrid;
  final bool showControls;
  final bool preferNativeDepth;
  final Color? modelColor;
  final double? unitsPerMeter;
  final double controlsTop;
  final Cad3DRenderBackend? backend;

  const Cad3DViewport({
    super.key,
    required this.mesh,
    required this.controller,
    this.shadingMode = Cad3DShadingMode.smoothShaded,
    this.theme = Cad3DTheme.darkCad,
    this.showGrid = true,
    this.showControls = true,
    this.preferNativeDepth = false,
    this.modelColor,
    this.unitsPerMeter,
    this.controlsTop = 12,
    this.backend,
  });

  @override
  State<Cad3DViewport> createState() => _Cad3DViewportState();
}

class _Cad3DViewportState extends State<Cad3DViewport>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late Cad3DRenderBackend _backend;
  late final Ticker _ticker;
  Duration? _lastTick;
  Offset _direction = Offset.zero;
  Offset? _lastFocal;
  int? _mousePointer;
  Offset? _mousePosition;
  double _baseZoom = 1;
  int _pointerCount = 0;
  bool _interacting = false;
  bool _scrolling = false;
  Timer? _scrollEnd;
  bool _scheduled = false;
  bool _rendering = false;
  bool _backendFailed = false;
  bool _gpuFailed = false;
  bool _gpuReady = false;
  int _revision = 0;
  int _sceneRevision = 0;
  int _frameSceneRevision = -1;
  Size _size = Size.zero;
  ui.Image? _frame;
  Cad3DCamera? _frameCamera;
  Mesh3D? _uploadedMesh;
  Color? _uploadedColor;

  Cad3DController get _controller => widget.controller;
  bool get _useGpu =>
      widget.preferNativeDepth &&
      widget.backend == null &&
      cad3dTextureSupported &&
      !_gpuFailed &&
      widget.mesh.triangles.isNotEmpty;
  bool get _useNative =>
      widget.preferNativeDepth &&
      !(_useGpu && _gpuReady) &&
      !_backendFailed &&
      _backend.isAvailable &&
      _backend.supports(widget.shadingMode) &&
      widget.mesh.triangles.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _backend = widget.backend ?? Cad3DNativeDepthBackend();
    _ticker = createTicker(_tick);
    _controller.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    _configureScene();
  }

  void _configureScene() {
    _controller.maxDimension = widget.mesh.bounds.maxDimension;
    _controller.unitsPerMeter = widget.unitsPerMeter;
    _controller.viewport = _size;
  }

  @override
  void didUpdateWidget(Cad3DViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != _controller) {
      oldWidget.controller.removeListener(_changed);
      _controller.addListener(_changed);
      _stopWalking();
    }
    if (oldWidget.backend != widget.backend) {
      _backend.dispose();
      _backend = widget.backend ?? Cad3DNativeDepthBackend();
      _uploadedMesh = null;
    }
    if (oldWidget.mesh != widget.mesh ||
        oldWidget.modelColor != widget.modelColor ||
        oldWidget.shadingMode != widget.shadingMode ||
        oldWidget.preferNativeDepth != widget.preferNativeDepth ||
        oldWidget.controller != _controller ||
        oldWidget.backend != widget.backend) {
      _backendFailed = false;
      _revision++;
      _sceneRevision++;
      _scheduleFrame();
    }
    if (oldWidget.preferNativeDepth != widget.preferNativeDepth ||
        oldWidget.backend != widget.backend) {
      _gpuReady = false;
      _gpuFailed = false;
    }
    _configureScene();
  }

  void _changed() {
    if (!mounted) return;
    if (_controller.mode != Cad3DInteractionMode.fly) _stopWalking();
    setState(() => _revision++);
    _scheduleFrame();
  }

  void _scheduleFrame() {
    if (_scheduled || _rendering || !mounted || _size.isEmpty || !_useNative) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _render();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  Future<void> _render() async {
    if (_rendering || !_useNative || _size.isEmpty) return;
    final revision = _revision;
    final backend = _backend;
    final size = _size;
    final camera = _controller.snapshot();
    _rendering = true;
    try {
      if (_uploadedMesh != widget.mesh || _uploadedColor != widget.modelColor) {
        if (!backend.setMesh(widget.mesh, color: widget.modelColor)) {
          _failBackend();
          return;
        }
        _uploadedMesh = widget.mesh;
        _uploadedColor = widget.modelColor;
      }
      final frame = await backend.render(
        camera: camera,
        viewport: size,
        modelScale: _controller.modelScale,
        // The legacy native rasterizer is CPU based. Limit its pixel work while
        // moving and refine when input stops, keeping the same projection.
        pixelRatio: math.min(
          1,
          (_interacting || _scrolling || _ticker.isActive ? 384 : 1280) /
              size.longestSide,
        ),
      );
      if (!mounted ||
          revision != _revision ||
          backend != _backend ||
          !_useNative) {
        frame?.dispose();
      } else if (frame != null) {
        final old = _frame;
        setState(() {
          _frame = frame;
          _frameCamera = camera;
          _frameSceneRevision = _sceneRevision;
        });
        old?.dispose();
      } else {
        _failBackend();
      }
    } catch (error) {
      if (mounted && backend == _backend) _failBackend();
      debugPrint('CAD native depth rendering: $error');
    } finally {
      _rendering = false;
      if (mounted && revision != _revision) _scheduleFrame();
    }
  }

  void _failBackend() {
    if (mounted && !_backendFailed) setState(() => _backendFailed = true);
  }

  void _stopWalking() {
    _direction = Offset.zero;
    _lastTick = null;
    _ticker.stop();
  }

  void _joystick(Offset direction) {
    _direction = direction;
    if (direction == Offset.zero) {
      _stopWalking();
      _changed();
    } else if (!_ticker.isActive) {
      _lastTick = null;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final seconds = _lastTick == null
        ? .016
        : (elapsed - _lastTick!).inMicroseconds / 1000000;
    _lastTick = elapsed;
    _controller.walk(_direction, seconds);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stopWalking();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled) _stopWalking();
  }

  bool get _modifierPan =>
      HardwareKeyboard.instance.isShiftPressed ||
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.logicalKeysPressed.contains(
        LogicalKeyboardKey.space,
      );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_changed);
    _ticker.dispose();
    _scrollEnd?.cancel();
    _backend.dispose();
    _frame?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (_size != size) {
          _size = size;
          _revision++;
          _sceneRevision++;
          _configureScene();
          _scheduleFrame();
        }
        // Keep the last completed frame while the next native frame is pending.
        // Its camera also draws the grid/gizmo, avoiding a second Canvas render
        // and mismatched overlays on every gesture. Scene/size changes invalidate it.
        final useFrame =
            _useNative &&
            _frame != null &&
            _frameSceneRevision == _sceneRevision;
        return ColoredBox(
          color: widget.theme.background,
          child: Stack(
            children: [
              if (_useGpu)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Cad3DGpuSurface(
                      mesh: widget.mesh,
                      controller: _controller,
                      theme: widget.theme,
                      shadingMode: widget.shadingMode,
                      modelColor: widget.modelColor,
                      showGrid: widget.showGrid,
                      active: TickerMode.valuesOf(context).enabled,
                      onReady: (ready) {
                        if (mounted && _gpuReady != ready) {
                          setState(() => _gpuReady = ready);
                        }
                      },
                      onFailure: () {
                        if (!mounted) return;
                        setState(() {
                          _gpuFailed = true;
                          _gpuReady = false;
                        });
                        _scheduleFrame();
                      },
                    ),
                  ),
                ),
              Positioned.fill(
                child: RepaintBoundary(
                  child: Listener(
                    key: const ValueKey('cad-3d-input'),
                    behavior: HitTestBehavior.opaque,
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) {
                        GestureBinding.instance.pointerSignalResolver.register(
                          event,
                          (_) {
                            _scrolling = true;
                            _scrollEnd?.cancel();
                            _scrollEnd = Timer(
                              const Duration(milliseconds: 150),
                              () {
                                _scrolling = false;
                                _changed();
                              },
                            );
                            _controller.scroll(event.scrollDelta.dy);
                          },
                        );
                      }
                    },
                    onPointerDown: (event) {
                      if ((event.buttons &
                              (kSecondaryMouseButton | kMiddleMouseButton)) !=
                          0) {
                        _mousePointer = event.pointer;
                        _mousePosition = event.localPosition;
                        setState(() {
                          _interacting = true;
                          _revision++;
                        });
                        _scheduleFrame();
                      }
                    },
                    onPointerMove: (event) {
                      if (_mousePointer == event.pointer &&
                          _mousePosition != null) {
                        final delta = event.localPosition - _mousePosition!;
                        _mousePosition = event.localPosition;
                        _controller.drag(delta, pan: true);
                      }
                    },
                    onPointerUp: (event) {
                      if (_mousePointer == event.pointer) {
                        _mousePointer = null;
                        _mousePosition = null;
                        setState(() {
                          _interacting = false;
                          _revision++;
                        });
                        _scheduleFrame();
                      }
                    },
                    onPointerCancel: (_) {
                      _mousePointer = null;
                      _mousePosition = null;
                      setState(() {
                        _interacting = false;
                        _revision++;
                      });
                      _scheduleFrame();
                      _lastFocal = null;
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onDoubleTap: _controller.reset,
                      onScaleStart: (details) {
                        _lastFocal = details.localFocalPoint;
                        _pointerCount = details.pointerCount;
                        _baseZoom = _controller.camera.zoom;
                        setState(() {
                          _interacting = true;
                          _revision++;
                        });
                        _scheduleFrame();
                      },
                      onScaleUpdate: (details) {
                        if (_mousePointer != null) return;
                        final delta =
                            details.localFocalPoint -
                            (_lastFocal ?? details.localFocalPoint);
                        _lastFocal = details.localFocalPoint;
                        if (_pointerCount != details.pointerCount) {
                          _pointerCount = details.pointerCount;
                          _baseZoom = _controller.camera.zoom / details.scale;
                          return;
                        }
                        if (details.pointerCount > 1 &&
                            !_controller.camera.isFlyMode) {
                          _controller.scale(_baseZoom * details.scale, delta);
                        } else {
                          _controller.drag(delta, pan: _modifierPan);
                        }
                      },
                      onScaleEnd: (_) {
                        _lastFocal = null;
                        setState(() {
                          _interacting = false;
                          _revision++;
                        });
                        _scheduleFrame();
                      },
                      child: CustomPaint(
                        size: size,
                        painter: Cad3DMeshPainter(
                          mesh: widget.mesh,
                          camera: useFrame ? _frameCamera! : _controller.camera,
                          shadingMode: widget.shadingMode,
                          theme: widget.theme,
                          showGrid: widget.showGrid,
                          overlayOnly: _useGpu && _gpuReady,
                          customModelColor: widget.modelColor,
                          isInteracting: _interacting,
                          gpuImage: useFrame ? _frame : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.showControls)
                Positioned(
                  top: widget.controlsTop,
                  right: 12,
                  child: Material(
                    color: widget.theme.background.withValues(alpha: .94),
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final mode in Cad3DInteractionMode.values)
                          IconButton(
                            key: ValueKey('cad-3d-${mode.name}'),
                            tooltip: switch (mode) {
                              Cad3DInteractionMode.orbit => l10n.cad3dOrbit,
                              Cad3DInteractionMode.pan => l10n.cad3dPan,
                              Cad3DInteractionMode.fly => l10n.cad3dWalk,
                            },
                            icon: Icon(mode.icon),
                            color: _controller.mode == mode
                                ? const Color(0xFF38BDF8)
                                : (widget.theme.isDark
                                      ? Colors.white70
                                      : Colors.black54),
                            onPressed: () => _controller.setMode(mode),
                          ),
                        IconButton(
                          key: const ValueKey('cad-3d-reset'),
                          tooltip: l10n.centerView,
                          icon: const Icon(Icons.fit_screen),
                          onPressed: _controller.reset,
                        ),
                      ],
                    ),
                  ),
                ),
              if (_controller.mode == Cad3DInteractionMode.fly)
                Positioned(
                  bottom: 24,
                  left: 20,
                  child: Cad3DVirtualJoystick(
                    key: const ValueKey('cad-3d-joystick'),
                    radius: size.shortestSide < 400 ? 48 : 60,
                    knobRadius: 22,
                    isDark: widget.theme.isDark,
                    onDirectionChanged: _joystick,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
