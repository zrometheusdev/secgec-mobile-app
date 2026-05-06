import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SmartAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  final IconData fallbackIcon;

  const SmartAvatar({
    super.key,
    this.url,
    this.radius = 24,
    this.fallbackIcon = LucideIcons.user,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty || url == 'null') {
      return _buildFallback();
    }

    if (url!.startsWith('data:image')) {
      try {
        final base64String = url!.split(',').last;
        final bytes = base64Decode(base64String);
        return CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFF222222),
          backgroundImage: MemoryImage(bytes),
        );
      } catch (e) {
        return _buildFallback();
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF222222),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: Colors.white10),
          errorWidget: (context, url, error) => Icon(fallbackIcon, size: radius, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF222222),
      child: Icon(fallbackIcon, size: radius, color: Colors.grey),
    );
  }
}
