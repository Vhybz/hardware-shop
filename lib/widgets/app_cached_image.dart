import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/image_cache_service.dart';

class AppCachedImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext context)? errorBuilder;

  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
  });

  @override
  State<AppCachedImage> createState() => _AppCachedImageState();
}

class _AppCachedImageState extends State<AppCachedImage> {
  File? _localFile;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant AppCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final path = widget.imageUrl.trim();
    if (path.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    if (path.startsWith('assets/') || kIsWeb) {
      return;
    }

    if (!path.startsWith('http')) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    // Check memory cache first
    final memCached = ImageCacheService.getMemoryCachedFile(path);
    if (memCached != null) {
      if (mounted && _localFile != memCached) {
        setState(() {
          _localFile = memCached;
          _hasError = false;
        });
      }
      return;
    }

    final cached = await ImageCacheService.getCachedImageFile(path);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _localFile = cached;
          _hasError = false;
        });
      }
      return;
    }

    final downloaded = await ImageCacheService.downloadAndCacheImage(path);
    if (mounted) {
      setState(() {
        _localFile = downloaded;
        _hasError = downloaded == null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.imageUrl.trim();

    if (path.startsWith('data:image')) {
      try {
        final bytes = base64Decode(path.split(',').last);
        return Image.memory(
          bytes,
          key: ValueKey(path),
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => _buildError(context),
        );
      } catch (_) {
        return _buildError(context);
      }
    }

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        key: ValueKey(path),
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        gaplessPlayback: true,
        errorBuilder: (context, error, stack) => _buildError(context),
      );
    }

    if (kIsWeb) {
      return Image.network(
        path,
        key: ValueKey(path),
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        gaplessPlayback: true,
        errorBuilder: (context, error, stack) => _buildError(context),
      );
    }

    // Fast synchronous memory lookup in build
    final memFile = _localFile ?? ImageCacheService.getMemoryCachedFile(path);

    if (memFile != null) {
      return Image.file(
        memFile,
        key: ValueKey(memFile.path),
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        cacheWidth: 300,
        cacheHeight: 300,
        gaplessPlayback: true,
        errorBuilder: (context, error, stack) => _buildError(context),
      );
    }

    if (_hasError) {
      return _buildError(context);
    }

    return Image.network(
      path,
      key: ValueKey(path),
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      cacheWidth: 300,
      cacheHeight: 300,
      gaplessPlayback: true,
      errorBuilder: (context, error, stack) => _buildError(context),
    );
  }

  Widget _buildError(BuildContext context) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context);
    }
    return Image.asset(
      'assets/logo/logo.jpg',
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      errorBuilder: (context, error, stack) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(Icons.inventory_2_outlined, color: Theme.of(context).dividerColor),
      ),
    );
  }
}
