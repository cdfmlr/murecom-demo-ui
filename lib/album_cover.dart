import 'package:flutter/material.dart';

class AlbumCoverImage extends StatelessWidget {
  final String src;

  final double? height;
  final double? width;

  const AlbumCoverImage(this.src, {Key? key, this.height, this.width})
      : super(key: key);

  double get radius => (height ?? 50) / 5;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        src,
        width: height,
        height: width,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          // loading: placeholder
          return buildFakeImage();
        },
        errorBuilder: (context, object, trace) => buildFakeImage(),
      ),
    );
  }

  Widget buildFakeImage() {
    return Material(
      color: Colors.grey[100],
      elevation: 4,
      child: SizedBox(height: height, width: width),
    );
  }
}
