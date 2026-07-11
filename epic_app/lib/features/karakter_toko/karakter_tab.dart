import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/data/models/character_model.dart';
import 'package:epic_app/data/models/user_model.dart';
import 'package:epic_app/core/constants/app_assets.dart';
import 'package:epic_app/shared/widgets/user_avatar_widget.dart';
import 'package:epic_app/features/karakter_toko/toko_controller.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';

class KarakterTab extends StatelessWidget {
  const KarakterTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(TokoController());
    final session = Get.find<SessionController>();

    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double bottomNavHeight = 72 + (bottomPadding > 0 ? bottomPadding : 12);

    return Container(
      color: AppColors.light,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              flex: 55,
              child: _buildActiveCharacterSection(controller, session),
            ),
            // ── Daftar Karakter (Dimiliki & Belum) ───────────────────────
            Expanded(
              flex: 45,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      'Koleksi Avatar',
                      style: TextStyle(
                        fontFamily: 'FredokaOne',
                        fontSize: 20,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 140,
                      child: Obx(() {
                        if (controller.isLoading.value) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                        }
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          physics: const BouncingScrollPhysics(),
                          itemCount: controller.characters.length,
                          itemBuilder: (context, index) {
                            final character = controller.characters[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: SizedBox(
                                width: 112,
                                child: _buildCharacterCard(character, controller, session),
                              ),
                            );
                          },
                        );
                      }),
                    ),
                    const Spacer(),
                    Obx(() {
                      final previewChar = controller.selectedPreviewChar.value;
                      final user = session.currentUser.value;
                      if (previewChar == null || user == null) return const SizedBox.shrink();
                      return Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, bottomNavHeight - 53),
                        child: _buildCentralActionButton(controller, user, previewChar),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCharacterSection(TokoController controller, SessionController session) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.light,
      ),
      child: Obx(() {
        final user = session.currentUser.value;
        if (user == null) return const SizedBox.shrink();

        final previewChar = controller.selectedPreviewChar.value;
        final previewName = previewChar?.nama ?? (user.karakterAktif == 'epi_default' ? 'Epi Si Cerdas' : user.karakterAktif.capitalizeFirst!);

        return Column(
          children: [
            const SizedBox(height: 12),
            // Header Row (Nama Karakter & Poin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      previewName,
                      style: const TextStyle(
                        fontFamily: 'FredokaOne',
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB800), Color(0xFFFF7A00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB700).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${user.poin} Poin',
                          style: const TextStyle(
                            fontFamily: 'FredokaOne',
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Karakter
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 10),
                child: _FloatingCharacter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                    child: () {
                      if (previewChar?.id == 'epi_default') {
                        return Image.asset(
                          AppAssets.epiBody,
                          key: const ValueKey('epi_default'),
                          height: double.infinity,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        );
                      } else if (previewChar?.id == 'ipeh_default') {
                        return Image.asset(
                          AppAssets.ipehBody,
                          key: const ValueKey('ipeh_default'),
                          height: double.infinity,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        );
                      } else if (previewChar != null) {
                        return CharacterImageWidget(
                          imageUrl: previewChar.imageUrl,
                          size: double.infinity,
                          fit: BoxFit.contain,
                          key: ValueKey(previewChar.id),
                        );
                      } else {
                        return Image.asset(
                          AppAssets.epiBody,
                          key: const ValueKey('none'),
                          height: double.infinity,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        );
                      }
                    }(),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildCentralActionButton(TokoController controller, UserModel user, CharacterModel character) {
    final isOwned = controller.isOwned(character.id);
    final isActive = user.karakterAktif == character.id;
    final canUnlock = user.poin >= character.poinUnlock;

    Widget btnContent;
    LinearGradient? btnGradient;
    Color? btnColor;
    VoidCallback? onPressed;
    Color shadowColor = Colors.transparent;
    BoxBorder border;

    if (isActive) {
      btnColor = const Color(0xFFF0FDF4); // Soft pastel green
      border = Border.all(color: const Color(0xFFDCFCE7), width: 1.5);
      btnContent = const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 20),
          SizedBox(width: 8),
          Text(
            'Karakter Aktif',
            style: TextStyle(
              fontFamily: 'FredokaOne',
              fontSize: 15,
              color: Color(0xFF15803D),
              letterSpacing: 0.5,
            ),
          ),
        ],
      );
    } else if (isOwned) {
      btnGradient = const LinearGradient(
        colors: [Color(0xFFE63946), Color(0xFFFF6B35)], // Red Madura to Orange Sate
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      shadowColor = const Color(0xFFE63946);
      border = Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5);
      onPressed = () => controller.pakaiKarakter(character.id);
      btnContent = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          const Text(
            'Gunakan Sekarang',
            style: TextStyle(
              fontFamily: 'FredokaOne',
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      );
    } else if (canUnlock) {
      btnGradient = const LinearGradient(
        colors: [Color(0xFF2EC4B6), Color(0xFF06D6A0)], // Hijau Berani to Success
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      shadowColor = const Color(0xFF06D6A0);
      border = Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5);
      onPressed = () => controller.unlockKarakter(character);
      btnContent = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.stars_rounded, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          Text(
            'Buka dengan ${character.poinUnlock} Poin',
            style: const TextStyle(
              fontFamily: 'FredokaOne',
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      );
    } else {
      btnColor = const Color(0xFFF1F5F9); // Very light grey
      border = Border.all(color: const Color(0xFFE2E8F0), width: 1.5);
      btnContent = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_rounded, color: Color(0xFF94A3B8), size: 18),
          const SizedBox(width: 8),
          Text(
            'Butuh ${character.poinUnlock} Poin (Poinmu: ${user.poin})',
            style: const TextStyle(
              fontFamily: 'FredokaOne',
              fontSize: 14,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.3,
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: btnGradient,
        color: btnColor,
        borderRadius: BorderRadius.circular(26),
        border: border,
        boxShadow: [
          if (onPressed != null) ...[
            BoxShadow(
              color: shadowColor.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: -2,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.15),
              blurRadius: 4,
              spreadRadius: 1,
              offset: const Offset(0, -2),
            ),
          ]
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(26),
          splashColor: Colors.white.withValues(alpha: 0.25),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Center(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: btnContent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterCard(
    CharacterModel character,
    TokoController controller,
    SessionController session,
  ) {
    return _CharacterCardWidget(
      character: character,
      controller: controller,
      session: session,
    );
  }
}

class _CharacterCardWidget extends StatefulWidget {
  final CharacterModel character;
  final TokoController controller;
  final SessionController session;

  const _CharacterCardWidget({
    required this.character,
    required this.controller,
    required this.session,
  });

  @override
  State<_CharacterCardWidget> createState() => _CharacterCardWidgetState();
}

class _CharacterCardWidgetState extends State<_CharacterCardWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final character = widget.character;
    final controller = widget.controller;
    final session = widget.session;

    return Obx(() {
      final isOwned = controller.isOwned(character.id);
      final isActiveEquipped = session.currentUser.value?.karakterAktif == character.id;
      final isCurrentlyPreviewed = controller.selectedPreviewChar.value?.id == character.id;

      // Color Palette based on states
      final Color cardBgColor = !isOwned ? const Color(0xFFF8FAFC) : Colors.white;
      
      // Tier Badge config
      Color badgeBg;
      Color badgeText;
      String badgeLabel;

      if (character.poinUnlock == 0) {
        badgeBg = const Color(0xFFECFDF5);
        badgeText = const Color(0xFF059669);
        badgeLabel = 'GRATIS';
      } else {
        switch (character.tier.toLowerCase()) {
          case 'uncommon':
            badgeBg = const Color(0xFFF3E8FF);
            badgeText = const Color(0xFF7C3AED);
            badgeLabel = 'LANGKA';
            break;
          case 'rare':
            badgeBg = const Color(0xFFFCE7F3);
            badgeText = const Color(0xFFDB2777);
            badgeLabel = 'S. LANGKA';
            break;
          case 'legendary':
            badgeBg = const Color(0xFFFEF3C7);
            badgeText = const Color(0xFFD97706);
            badgeLabel = 'LEGENDA';
            break;
          default:
            badgeBg = const Color(0xFFE0F2FE);
            badgeText = const Color(0xFF0284C7);
            badgeLabel = 'UMUM';
        }
      }

      return GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) {
          _pressController.reverse();
          controller.selectPreviewChar(character);
        },
        onTapCancel: () => _pressController.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isCurrentlyPreviewed
                    ? const Color(0xFFFFB700)
                    : (isOwned ? const Color(0xFFE2E8F0) : const Color(0xFFE2E8F0).withValues(alpha: 0.5)),
                width: isCurrentlyPreviewed ? 2.5 : 1.5,
              ),
              boxShadow: [
                if (isCurrentlyPreviewed)
                  BoxShadow(
                    color: const Color(0xFFFFB700).withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isOwned ? 0.04 : 0.01),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Inner card layout
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Column(
                    children: [
                      // Tier Badge at top
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badgeLabel,
                              style: TextStyle(
                                fontFamily: 'FredokaOne',
                                fontSize: 8,
                                color: badgeText,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (isActiveEquipped)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF059669), // Green checkmark for active/equipped
                              size: 16,
                            )
                          else if (isCurrentlyPreviewed)
                            const Icon(
                              Icons.visibility_rounded, // Yellow eye for previewed
                              color: Color(0xFFFFB700),
                              size: 14,
                            )
                          else if (!isOwned)
                            const Icon(
                              Icons.lock_rounded,
                              color: Color(0xFF94A3B8),
                              size: 12,
                            )
                          else
                            const SizedBox(width: 16),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Character Image + Backdrop Circle (Expanded to make it much bigger)
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Glowing soft background circle
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: isCurrentlyPreviewed
                                      ? [const Color(0xFFFFEFA8).withValues(alpha: 0.85), const Color(0x00FFEFA8)]
                                      : (isOwned
                                          ? [const Color(0xFFE0F2FE).withValues(alpha: 0.75), const Color(0x00E0F2FE)]
                                          : [const Color(0xFFF1F5F9).withValues(alpha: 0.5), const Color(0x00F1F5F9)]),
                                  stops: const [0.5, 1.0],
                                ),
                              ),
                            ),
                            // Character Image in the center without floating pedestal shadow
                            Positioned.fill(
                              child: Transform.scale(
                                scale: 1.45,
                                child: CharacterImageWidget(
                                  imageUrl: character.imageUrl,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Character Name
                      Text(
                        character.nama,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'FredokaOne',
                          fontSize: 12,
                          color: isOwned ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                // Lock overlay if not owned (more subtle, doesn't darken the whole card)
                if (!isOwned)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _FloatingCharacter extends StatefulWidget {
  final Widget child;
  const _FloatingCharacter({required this.child});

  @override
  State<_FloatingCharacter> createState() => _FloatingCharacterState();
}

class _FloatingCharacterState extends State<_FloatingCharacter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    // Skala dasar di-set ke 1.4 agar karakter membesar memotong padding transparan bawaan gambar
    _animation = Tween<double>(begin: 1.4, end: 1.45).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: const Offset(0, 20), // Geser sedikit ke bawah agar kepala tidak menabrak header
          child: Transform.scale(
            scale: _animation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
