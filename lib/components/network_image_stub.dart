import 'package:flutter/material.dart';

class NetworkImageHtml extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Image.network(
        url,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (_, __, ___) =>
        const Center(child: Icon(Icons.broken_image, size: 40)),
      ),
    );
  }
}