import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;

  const Avatar({super.key, this.url, required this.name, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    if (url == null || url!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).primaryColor,
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, _) => CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey.shade300,
        ),
        errorWidget: (context, _, __) => CircleAvatar(
          radius: radius,
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(initial,
              style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
