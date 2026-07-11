import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:epic_app/core/constants/app_assets.dart';
import 'package:epic_app/core/constants/app_colors.dart';

/// Widget avatar pengguna yang menampilkan foto profil (cached)
/// atau fallback ke ikon default jika URL kosong/error.
class UserAvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String? name; // Untuk fallback huruf inisial
  final double radius;
  final Color? borderColor;
  final double borderWidth;

  const UserAvatarWidget({
    super.key,
    required this.avatarUrl,
    this.name,
    this.radius = 22,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = avatarUrl != null && avatarUrl!.isNotEmpty;

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderWidth > 0
            ? Border.all(
                color: borderColor ?? AppColors.primary,
                width: borderWidth,
              )
            : null,
      ),
      child: ClipOval(
        child: hasPhoto
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildPlaceholder(),
                errorWidget: (context, url, error) => _buildFallback(),
              )
            : _buildFallback(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.light,
      child: Center(
        child: SizedBox(
          width: radius * 0.7,
          height: radius * 0.7,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    if (name != null && name!.isNotEmpty) {
      final initial = name!.trim().substring(0, 1).toUpperCase();
      final hash = name!.hashCode;
      final colors = [
        [const Color(0xFFFF7A00), const Color(0xFFFF5100)], // Orange
        [const Color(0xFF3B82F6), const Color(0xFF2563EB)], // Blue
        [const Color(0xFF10B981), const Color(0xFF059669)], // Green
        [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)], // Purple
        [const Color(0xFFEC4899), const Color(0xFFDB2777)], // Pink
      ];
      final colorPair = colors[hash.abs() % colors.length];

      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colorPair,
          ),
        ),
        child: Center(
          child: Text(
            initial,
            style: TextStyle(
              fontFamily: 'FredokaOne',
              fontSize: radius * 0.9,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return Container(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Center(
        child: Image.asset(
          AppAssets.epiStatic,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// Widget karakter (gambar aset lokal atau remote dengan cache)
class CharacterImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final BoxFit fit;

  const CharacterImageWidget({
    super.key,
    required this.imageUrl,
    this.size = 80,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    // Jika URL adalah path aset lokal (bukan http/https), gunakan Image.asset
    final isAsset = imageUrl == null ||
        imageUrl!.isEmpty ||
        !imageUrl!.startsWith('http');

    if (isAsset) {
      return Image.asset(
        imageUrl?.isNotEmpty == true ? imageUrl! : AppAssets.epiStatic,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (_, __, ___) => Icon(
          Icons.face_retouching_natural_rounded,
          size: size * 0.6,
          color: AppColors.primary,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: size,
      height: size,
      fit: fit,
      placeholder: (context, url) => SizedBox(
        width: size,
        height: size,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary.withValues(alpha: 0.6),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Icon(
        Icons.face_retouching_natural_rounded,
        size: size * 0.6,
        color: AppColors.primary,
      ),
    );
  }
}
