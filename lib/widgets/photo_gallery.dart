// Horizontal scrolling photo cards with thumbnail, title, date, and source.

import 'dart:io';
import 'package:flutter/material.dart';
import '../models/photo.dart';

class PhotoGallery extends StatelessWidget {
  final List<HistoricalPhoto> photos;

  const PhotoGallery({super.key, required this.photos});

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text('No photos yet',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_library, size: 16, color: Colors.brown),
            const SizedBox(width: 6),
            Text('Historical Photos (${photos.length})',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) =>
                _PhotoCard(photo: photos[index]),
          ),
        ),
      ],
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final HistoricalPhoto photo;

  const _PhotoCard({required this.photo});

  static Widget _image(String url, double width, double height) {
    final fallback = Container(
      height: height,
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.grey, size: 32),
      ),
    );

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(url,
          height: height, width: width, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(
                height: height,
                color: Colors.grey.shade100,
                child: const Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))));
          });
    }

    if (url.startsWith('/') || url.startsWith('file://')) {
      return Image.file(File(url.replaceFirst('file://', '')),
          height: height, width: width, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback);
    }

    return Image.asset(url,
        height: height, width: width, fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(9)),
            child: _image(photo.imageUrl, 200, 110),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Text(photo.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Text(photo.dateLabel,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.brown.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(photo.source,
                      style: TextStyle(
                          fontSize: 10, color: Colors.brown.shade400)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
