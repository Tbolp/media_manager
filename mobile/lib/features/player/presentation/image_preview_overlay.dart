// lib/features/player/presentation/image_preview_overlay.dart
// 图片全屏预览（非独立路由，覆盖层）

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import '../../../features/library/domain/file_model.dart';
import '../../../shared/utils/url_builder.dart';

class ImagePreviewOverlay extends StatefulWidget {
  const ImagePreviewOverlay({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.baseUrl,
    required this.token,
  });

  final List<FileModel> images;
  final int initialIndex;
  final String baseUrl;
  final String token;

  @override
  State<ImagePreviewOverlay> createState() => _ImagePreviewOverlayState();
}

class _ImagePreviewOverlayState extends State<ImagePreviewOverlay> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _showInfo = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.images.isNotEmpty
        ? widget.images[_currentIndex]
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showInfo = !_showInfo),
        child: Stack(
          children: [
            // PageView 翻页
            PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (_, i) {
                final img = widget.images[i];
                final rawUrl = UrlBuilder.rawImageUrl(
                  widget.baseUrl,
                  img.id,
                  widget.token,
                );
                final thumbUrl = UrlBuilder.thumbnailUrl(
                  widget.baseUrl,
                  img.id,
                  widget.token,
                );
                return PhotoView(
                  imageProvider:
                      CachedNetworkImageProvider(rawUrl),
                  loadingBuilder: (_, __) => Center(
                    child: CachedNetworkImage(
                      imageUrl: thumbUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                  errorBuilder: (_, __, ___) => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            color: Colors.white54, size: 48),
                        SizedBox(height: 8),
                        Text('图片加载失败',
                            style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 4,
                  backgroundDecoration: const BoxDecoration(
                    color: Colors.black,
                  ),
                );
              },
            ),

            // 顶部信息栏
            if (_showInfo)
              AnimatedOpacity(
                opacity: _showInfo ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    color: Colors.black45,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (file != null)
                                Text(
                                  file.filename,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              Text(
                                '${_currentIndex + 1} / ${widget.images.length}',
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
