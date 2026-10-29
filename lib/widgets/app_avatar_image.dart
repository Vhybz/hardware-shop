import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

class AppAvatarImage extends StatelessWidget {
  final String? photoUrl;
  final double size;
  final String? nameHint;
  final Color? iconColor;
  final Color? backgroundColor;
  final BoxFit fit;

  const AppAvatarImage({
    super.key,
    required this.photoUrl,
    this.size = 40,
    this.nameHint,
    this.iconColor,
    this.backgroundColor,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String cleanUrl = photoUrl?.trim() ?? '';

    Widget fallback = Container(
      width: size,
      height: size,
      color: backgroundColor ?? theme.colorScheme.primary.withValues(alpha: 0.15),
      child: Center(
        child: nameHint != null && nameHint!.trim().isNotEmpty
            ? Text(
                nameHint!.trim()[0].toUpperCase(),
                style: TextStyle(
                  fontSize: size * 0.45,
                  fontWeight: FontWeight.bold,
                  color: iconColor ?? theme.colorScheme.primary,
                ),
              )
            : Icon(
                Icons.person_rounded,
                size: size * 0.6,
                color: iconColor ?? theme.colorScheme.primary,
              ),
      ),
    );

    if (cleanUrl.isEmpty) {
      return fallback;
    }

    // 1. Base64 Data URI
    if (cleanUrl.startsWith('data:image')) {
      try {
        final commaIndex = cleanUrl.indexOf(',');
        final base64Data = commaIndex != -1 ? cleanUrl.substring(commaIndex + 1) : cleanUrl;
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          key: ValueKey(cleanUrl),
          width: size,
          height: size,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => fallback,
        );
      } catch (e) {
        return fallback;
      }
    }

    // 2. Local File Path
    if (cleanUrl.startsWith('/') || cleanUrl.startsWith('file://')) {
      try {
        final filePath = cleanUrl.replaceFirst('file://', '');
        final file = File(filePath);
        if (file.existsSync()) {
          return Image.file(
            file,
            key: ValueKey(filePath),
            width: size,
            height: size,
            fit: fit,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => fallback,
          );
        }
      } catch (_) {}
    }

    // 3. Network HTTP/HTTPS URL
    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return Image.network(
        cleanUrl,
        key: ValueKey(cleanUrl),
        width: size,
        height: size,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return fallback;
        },
      );
    }

    return fallback;
  }
}
