import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'common.dart';

/// Opens [urls] full screen at [initial]: the whole photo on black, pinch or double-tap to zoom,
/// swipe between photos, swipe down or tap ✕ to close.
Future<void> openPhotoViewer(BuildContext context, List<String> urls, {int initial = 0}) =>
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => PhotoViewer(urls: urls, initial: initial),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );

class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.urls, this.initial = 0});

  final List<String> urls;
  final int initial;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _page = widget.initial;
  bool _zoomed = false; // while zoomed in, a drag pans the photo instead of changing it
  double _dragDown = 0; // how far a swipe down has gone, to close

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: (1 - _dragDown / 400).clamp(0.3, 1)),
        body: Stack(
          children: [
            GestureDetector(
              onVerticalDragUpdate: _zoomed
                  ? null
                  : (d) => setState(() => _dragDown = (_dragDown + d.delta.dy).clamp(0, 600)),
              onVerticalDragEnd: _zoomed
                  ? null
                  : (d) {
                      if (_dragDown > 120 || (d.primaryVelocity ?? 0) > 800) {
                        Navigator.pop(context);
                      } else {
                        setState(() => _dragDown = 0);
                      }
                    },
              child: Transform.translate(
                offset: Offset(0, _dragDown),
                child: PageView.builder(
                  controller: _pages,
                  physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
                  itemCount: widget.urls.length,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (_, i) =>
                      _ZoomablePhoto(url: widget.urls[i], onZoomChanged: (zoomed) => setState(() => _zoomed = zoomed)),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: l10n.close,
                      color: Colors.white,
                      style: IconButton.styleFrom(backgroundColor: Colors.black45),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x),
                    ),
                    const Spacer(),
                    if (widget.urls.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(16)),
                        child: Text(
                          '${_page + 1} / ${widget.urls.length}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One photo, fitted whole; pinch to zoom up to 5x, double-tap to zoom in or back out.
class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({required this.url, required this.onZoomChanged});

  final String url;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final _animation = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  Animation<Matrix4>? _zoom;
  TapDownDetails? _doubleTap;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _animation.addListener(() => _transform.value = _zoom!.value);
    _transform.addListener(() {
      final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
      if (zoomed != _zoomed) {
        _zoomed = zoomed;
        widget.onZoomChanged(zoomed);
      }
    });
  }

  @override
  void dispose() {
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final Matrix4 target;
    if (_zoomed) {
      target = Matrix4.identity();
    } else {
      final point = _doubleTap?.localPosition ?? Offset.zero;
      const scale = 2.5;
      target = Matrix4.identity()
        ..translateByDouble(-point.dx * (scale - 1), -point.dy * (scale - 1), 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
    }
    _zoom = Matrix4Tween(
      begin: _transform.value,
      end: target,
    ).animate(CurvedAnimation(parent: _animation, curve: Curves.easeOut));
    _animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onDoubleTapDown: (details) => _doubleTap = details,
    onDoubleTap: _toggleZoom,
    child: InteractiveViewer(
      transformationController: _transform,
      maxScale: 5,
      child: SizedBox.expand(
        // Not NetworkPhoto: its placeholder would show around the photo on black
        child: Image.network(
          widget.url,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
          errorBuilder: (_, _, _) => const Center(child: Icon(LucideIcons.imageOff, color: Colors.white54, size: 48)),
        ),
      ),
    ),
  );
}

/// A photo that opens full screen when tapped, e.g. in a small preview.
class TappablePhoto extends StatelessWidget {
  const TappablePhoto(this.url, {super.key, this.fit = BoxFit.cover});

  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final photo = NetworkPhoto(url, fit: fit);
    if (url == null) return photo;
    return Stack(
      fit: StackFit.expand,
      children: [
        photo,
        Material(
          type: MaterialType.transparency,
          child: InkWell(onTap: () => openPhotoViewer(context, [url!])),
        ),
      ],
    );
  }
}
