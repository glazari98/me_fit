import 'dart:ui_web' as ui;
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';

class NetworkImageHtml extends StatefulWidget {
  final String url;
  final double height;
  final BoxFit fit;

  const NetworkImageHtml(
      this.url, {
        super.key,
        this.height = 260,
        this.fit = BoxFit.cover,
      });

  @override
  State<NetworkImageHtml> createState() => _NetworkImageHtmlState();
}

class _NetworkImageHtmlState extends State<NetworkImageHtml> {
  static final Set<String> _registered = {};

  late final String viewType;
  late final web.HTMLImageElement _img;

  bool _loaded = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();

    viewType = 'img-${widget.url.hashCode}';

    _img = web.HTMLImageElement()
      ..src = widget.url
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = _boxFitToCss(widget.fit);

    // Handle cached images
    if (_img.complete) {
      _loaded = true;
    }

    _img.onLoad.listen((_) {
      if (mounted) {
        setState(() {
          _loaded = true;
        });
      }
    });

    _img.onError.listen((_) {
      if (mounted) {
        setState(() {
          _error = true;
        });
      }
    });

    if (!_registered.contains(viewType)) {
      _registered.add(viewType);

      ui.platformViewRegistry.registerViewFactory(
        viewType,
            (int viewId) => _img,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Icon(Icons.broken_image, size: 40),
        ),
      );
    }

    if (!_loaded) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: HtmlElementView(viewType: viewType),
    );
  }

  String _boxFitToCss(BoxFit fit) {
    switch (fit) {
      case BoxFit.cover:
        return 'cover';
      case BoxFit.contain:
        return 'contain';
      case BoxFit.fill:
        return 'fill';
      case BoxFit.none:
        return 'none';
      case BoxFit.scaleDown:
        return 'scale-down';
      case BoxFit.fitWidth:
      case BoxFit.fitHeight:
        return 'contain';
    }
  }
}