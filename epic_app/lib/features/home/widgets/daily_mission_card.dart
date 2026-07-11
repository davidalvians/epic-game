import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:epic_app/core/constants/app_assets.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:epic_app/data/models/misi_harian_model.dart';
import 'package:epic_app/data/repositories/misi_harian_repository.dart';

/// Controller misi harian.
class DailyMissionController extends GetxController {
  final RxList<MisiHarianModel> missions = <MisiHarianModel>[].obs;
  final RxBool isLoading = true.obs;

  final MisiHarianRepository _repo = MisiHarianRepository();
  final SessionController _session = Get.find<SessionController>();

  @override
  void onInit() {
    super.onInit();
    loadMisi();
  }

  Future<void> loadMisi() async {
    isLoading.value = true;
    try {
      final uid = _session.currentUser.value?.uid;
      if (uid == null) return;

      final loadedMissions = await _repo.getMisiHariIni(uid);
      missions.assignAll(loadedMissions);
    } catch (e) {
      debugPrint('⚠️ Error loading missions in controller: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> claimMisiReward(String misiId) async {
    try {
      final uid = _session.currentUser.value?.uid;
      if (uid == null) return;

      final reward = await _repo.claimReward(uid: uid, misiId: misiId);
      if (reward > 0) {
        // Reload list
        await loadMisi();
        // Force refresh user profile
        await _session.refreshUser();
        
        Get.snackbar(
          'Selamat! 🎉',
          'Kamu berhasil mengklaim reward +$reward Poin!',
          backgroundColor: const Color(0xFFD1FAE5),
          colorText: const Color(0xFF065F46),
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error claimMisiReward: $e');
    }
  }
}

/// Kartu Misi Harian yang muncul di halaman beranda.
/// Terhubung ke Firestore dan menampilkan progress nyata.
class DailyMissionCard extends StatelessWidget {
  const DailyMissionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DailyMissionController());

    return Obx(() {
      if (controller.isLoading.value) {
        return _buildSkeleton();
      }

      final missions = controller.missions;
      if (missions.isEmpty) {
        return _buildEmpty();
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFDF4E7),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF94A3B8).withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: const Color(0xFF94A3B8).withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: missions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final m = missions[index];
                final progressRatio = m.progressPersen;
                
                return Row(
                  children: [
                    // Emoji / Icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: m.isCompleted
                            ? const Color(0xFFE6FDF0)
                            : const Color(0xFFFFF8F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: m.isCompleted
                              ? const Color(0xFFBBF7D0)
                              : const Color(0xFFFFE4D6),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        m.emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Judul & Deskripsi & Progress
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  m.judul,
                                  style: TextStyle(
                                    fontFamily: 'FredokaOne',
                                    fontSize: 12,
                                    color: const Color(0xFF1E293B),
                                    decoration: m.isClaimed
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Reward badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: m.isClaimed
                                      ? const Color(0xFFF1F5F9)
                                      : const Color(0xFFFFECE0),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: m.isClaimed
                                        ? const Color(0xFFE2E8F0)
                                        : const Color(0xFFFFD0B3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.stars_rounded,
                                      color: m.isClaimed
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFFFF7A00),
                                      size: 9,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '+${m.reward}',
                                      style: TextStyle(
                                        fontFamily: 'FredokaOne',
                                        fontSize: 9,
                                        color: m.isClaimed
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFFEA580C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            m.deskripsi,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final maxWidth = constraints.maxWidth;
                                    final progressWidth = maxWidth * progressRatio;
                                    return Container(
                                      height: 6,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      alignment: Alignment.centerLeft,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        width: progressWidth,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(3),
                                          gradient: LinearGradient(
                                            colors: m.isCompleted
                                                ? const [Color(0xFF22C55E), Color(0xFF10B981)]
                                                : const [Color(0xFFFF7A00), Color(0xFFFF9F43)],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                m.progressLabel,
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Action / Claim Button with animated chest
                    _buildActionButton(context, controller, m),
                  ],
                );
              },
            ),
          ],
        ),
      );
    });
  }

  Widget _buildActionButton(BuildContext context, DailyMissionController controller, MisiHarianModel m) {
    return _AnimatedChestButton(
      mission: m,
      onClaim: () => controller.claimMisiReward(m.misiId),
    );
  }

  Widget _buildSkeleton() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFDF4E7), width: 1.5),
      ),
      child: const Row(
        children: [
          Icon(Icons.local_fire_department_rounded,
              color: Color(0xFFCBD5E1), size: 32),
          SizedBox(width: 16),
          Text(
            'Belum ada misi hari ini',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}


class _AnimatedChestButton extends StatefulWidget {
  final MisiHarianModel mission;
  final VoidCallback onClaim;

  const _AnimatedChestButton({
    required this.mission,
    required this.onClaim,
  });

  @override
  State<_AnimatedChestButton> createState() => _AnimatedChestButtonState();
}

class _AnimatedChestButtonState extends State<_AnimatedChestButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.mission.canClaim) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedChestButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mission.canClaim) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mission;

    if (m.isClaimed) {
      // Claimed State: Open chest with checkmark badge
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Image.asset(
            AppAssets.chestOpen,
            width: 36,
            height: 36,
            fit: BoxFit.contain,
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 8,
              ),
            ),
          ),
        ],
      );
    }

    if (m.canClaim) {
      // Completed, ready to claim: Animated closed chest that jiggles & bounces
      return GestureDetector(
        onTap: widget.onClaim,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            double rotation = 0.0;
            double bounce = 0.0;

            // 0.0 - 0.3: Jiggle/shake
            if (t < 0.3) {
              final progress = t / 0.3;
              rotation = sin(progress * 4 * pi) * 0.15; // 2 shakes
            }
            // 0.3 - 0.6: Bounce
            else if (t >= 0.3 && t < 0.6) {
              final progress = (t - 0.3) / 0.3;
              bounce = -sin(progress * pi) * 6.0;
            }
            // 0.6 - 1.0: Rest/pause

            return Transform.translate(
              offset: Offset(0, bounce),
              child: Transform.rotate(
                angle: rotation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Image.asset(
                    AppAssets.chestClosed,
                    width: 38,
                    height: 38,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    // In Progress / Inactive State: Static desaturated closed chest
    return Opacity(
      opacity: 0.5,
      child: Image.asset(
        AppAssets.chestClosed,
        width: 36,
        height: 36,
        fit: BoxFit.contain,
      ),
    );
  }
}
