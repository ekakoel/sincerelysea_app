import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sincerelysea/services/app_check_header_service.dart';

class AppCheckCachedNetworkImage extends StatefulWidget {
  const AppCheckCachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
    this.filterQuality,
    this.fadeInDuration,
    this.placeholder,
    this.error,
    this.imageBuilder,
    this.onError,
    this.imageKey,
  });

  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;
  final FilterQuality? filterQuality;
  final Duration? fadeInDuration;
  final Widget? placeholder;
  final Widget? error;
  final Widget Function(BuildContext context, ImageProvider imageProvider)?
  imageBuilder;
  final VoidCallback? onError;
  final Key? imageKey;

  @override
  State<AppCheckCachedNetworkImage> createState() =>
      _AppCheckCachedNetworkImageState();
}

class _AppCheckCachedNetworkImageState
    extends State<AppCheckCachedNetworkImage> {
  bool _headersReady = false;
  Map<String, String> _httpHeaders = const <String, String>{};

  @override
  void initState() {
    super.initState();
    _loadHeaders();
  }

  @override
  void didUpdateWidget(covariant AppCheckCachedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _headersReady = false;
      _httpHeaders = const <String, String>{};
      _loadHeaders();
    }
  }

  Future<void> _loadHeaders() async {
    final String imageUrl = widget.imageUrl;
    try {
      if (!AppCheckHeaderService.instance.requiresHeaderFor(imageUrl)) {
        if (!mounted) {
          return;
        }
        setState(() {
          _httpHeaders = const <String, String>{};
          _headersReady = true;
        });
        return;
      }

      final Map<String, String> headers = await AppCheckHeaderService.instance
          .headersFor(imageUrl);
      if (!mounted || imageUrl != widget.imageUrl) {
        return;
      }
      setState(() {
        _httpHeaders = headers;
        _headersReady = true;
      });
    } catch (_) {
      if (!mounted || imageUrl != widget.imageUrl) {
        return;
      }
      setState(() {
        _httpHeaders = const <String, String>{};
        _headersReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_headersReady) {
      return widget.placeholder ?? const SizedBox.shrink();
    }

    return CachedNetworkImage(
      key: widget.imageKey,
      imageUrl: widget.imageUrl,
      httpHeaders: _httpHeaders,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      memCacheWidth: widget.memCacheWidth,
      memCacheHeight: widget.memCacheHeight,
      maxWidthDiskCache: widget.maxWidthDiskCache,
      maxHeightDiskCache: widget.maxHeightDiskCache,
      filterQuality: widget.filterQuality ?? FilterQuality.low,
      fadeInDuration:
          widget.fadeInDuration ?? const Duration(milliseconds: 220),
      imageBuilder: widget.imageBuilder,
      placeholder: widget.placeholder == null
          ? null
          : (BuildContext context, String _) => widget.placeholder!,
      progressIndicatorBuilder: widget.placeholder == null
          ? null
          : (BuildContext context, String _, DownloadProgress progress) =>
                widget.placeholder!,
      errorWidget: (BuildContext context, String _, Object error) {
        widget.onError?.call();
        return widget.error ?? const SizedBox.shrink();
      },
    );
  }
}

class AppCheckImageNetwork extends StatefulWidget {
  const AppCheckImageNetwork({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.error,
  });

  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? error;

  @override
  State<AppCheckImageNetwork> createState() => _AppCheckImageNetworkState();
}

class _AppCheckImageNetworkState extends State<AppCheckImageNetwork> {
  bool _headersReady = false;
  Map<String, String> _httpHeaders = const <String, String>{};

  @override
  void initState() {
    super.initState();
    _loadHeaders();
  }

  @override
  void didUpdateWidget(covariant AppCheckImageNetwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _headersReady = false;
      _httpHeaders = const <String, String>{};
      _loadHeaders();
    }
  }

  Future<void> _loadHeaders() async {
    final String imageUrl = widget.imageUrl;
    try {
      if (!AppCheckHeaderService.instance.requiresHeaderFor(imageUrl)) {
        if (!mounted) {
          return;
        }
        setState(() {
          _httpHeaders = const <String, String>{};
          _headersReady = true;
        });
        return;
      }

      final Map<String, String> headers = await AppCheckHeaderService.instance
          .headersFor(imageUrl);
      if (!mounted || imageUrl != widget.imageUrl) {
        return;
      }
      setState(() {
        _httpHeaders = headers;
        _headersReady = true;
      });
    } catch (_) {
      if (!mounted || imageUrl != widget.imageUrl) {
        return;
      }
      setState(() {
        _httpHeaders = const <String, String>{};
        _headersReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_headersReady) {
      return widget.placeholder ?? const SizedBox.shrink();
    }

    return Image.network(
      widget.imageUrl,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      headers: _httpHeaders,
      loadingBuilder:
          (
            BuildContext context,
            Widget child,
            ImageChunkEvent? loadingProgress,
          ) {
            if (loadingProgress == null) {
              return child;
            }
            return widget.placeholder ?? child;
          },
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) =>
              widget.error ?? const SizedBox.shrink(),
    );
  }
}

class AppCheckAvatar extends StatelessWidget {
  const AppCheckAvatar({
    super.key,
    required this.radius,
    required this.backgroundColor,
    required this.imageUrl,
    required this.fallback,
    this.loading,
    this.error,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final double radius;
  final Color backgroundColor;
  final String? imageUrl;
  final Widget fallback;
  final Widget? loading;
  final Widget? error;
  final int? memCacheWidth;
  final int? memCacheHeight;

  @override
  Widget build(BuildContext context) {
    final String cleanUrl = imageUrl?.trim() ?? '';
    if (cleanUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: fallback,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: SizedBox.expand(
          child: AppCheckCachedNetworkImage(
            imageUrl: cleanUrl,
            fit: BoxFit.cover,
            memCacheWidth: memCacheWidth,
            memCacheHeight: memCacheHeight,
            placeholder:
                loading ??
                ColoredBox(
                  color: backgroundColor,
                  child: const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            error:
                error ??
                ColoredBox(
                  color: backgroundColor,
                  child: Center(child: fallback),
                ),
          ),
        ),
      ),
    );
  }
}
