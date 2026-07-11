import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:get/get.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/features/ranking/ranking_controller.dart';
import 'package:epic_app/features/kelas/gabung_kelas_screen.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';
import 'package:epic_app/shared/widgets/user_avatar_widget.dart';
import 'package:epic_app/data/models/score_model.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _podiumCtrl;
  late Animation<double> _podiumAnim;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _podiumCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _podiumAnim = CurvedAnimation(
      parent: _podiumCtrl,
      curve: Curves.easeOutCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _podiumCtrl.forward();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _podiumCtrl.dispose();
    super.dispose();
  }

  // Warna Medali sesuai referensi
  static const _goldColor = Color(0xFFFFD700);
  static const _silverColor = Color(0xFFC0C0C0);
  static const _bronzeColor = Color(0xFFCD7F32);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(RankingController());
    final session = Get.find<SessionController>();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0), // Sesuai referensi
      body: Obx(() {
        // Empty kelas state: murid belum ikut kelas manapun & di tab kelas
        if (controller.selectedTab.value == 1 && controller.myKelasList.isEmpty) {
          return _buildKelasEmptyState();
        }

        if (controller.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final currentUserId = session.currentUser.value?.uid;
        final currentUser = session.currentUser.value;
        final scores = controller.scores;

        final double systemBottomPadding = MediaQuery.of(context).padding.bottom;
        // Jika systemBottomPadding > 50, Scaffold sudah menyertakan tinggi bottom nav ke padding body.
        final double bottomNavTop = systemBottomPadding > 50 
            ? systemBottomPadding 
            : 72 + (systemBottomPadding > 0 ? systemBottomPadding : 12);
        final double listBottomPadding = bottomNavTop + 80;

        // Cari posisi user
        int userRank = -1;
        int userPoin = 0;
        for (int i = 0; i < scores.length; i++) {
          if (scores[i].uid == currentUserId) {
            userRank = i + 1;
            userPoin = scores[i].totalPoin;
            break;
          }
        }

        final top3 = scores.take(3).toList();
        final rest = scores.length > 3 ? scores.sublist(3) : <ScoreModel>[];

        return Stack(
          children: [
            // Konten Utama Scrollable
            CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header Papan Peringkat
                // Header Papan Peringkat & Tabs
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60, bottom: 10),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.emoji_events, color: Colors.orange, size: 28),
                            SizedBox(width: 8),
                            Text(
                              'Papan Peringkat',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B), // text-slate-800
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Tabs Global vs Kelas (hanya jika punya kelas)
                        if (controller.myKelasList.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildTabButton(
                                      title: 'Global',
                                      isSelected: controller.selectedTab.value == 0,
                                      onTap: () => controller.selectedTab.value = 0,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildTabButton(
                                      title: 'Kelas Saya',
                                      isSelected: controller.selectedTab.value == 1,
                                      onTap: () => controller.selectedTab.value = 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                        // Tampilkan nama kelas yang sedang dilihat (tab Kelas aktif)
                        if (controller.selectedTab.value == 1 && controller.myKelasList.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12, left: 20, right: 20),
                            child: controller.myKelasList.length > 1
                                // Dropdown jika ikut > 1 kelas
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: controller.selectedKelasId.value,
                                        isExpanded: true,
                                        icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary),
                                        style: const TextStyle(
                                          fontFamily: 'Nunito',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E293B),
                                        ),
                                        onChanged: (val) {
                                          if (val != null) controller.changeKelas(val);
                                        },
                                        items: controller.myKelasList.map((k) {
                                          return DropdownMenuItem<String>(
                                            value: k['id'],
                                            child: Text(k['name'] ?? ''),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  )
                                // Label nama kelas jika hanya 1 kelas
                                : Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFFFD8A8)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.class_rounded, size: 16, color: Color(0xFFEA580C)),
                                        const SizedBox(width: 8),
                                        Text(
                                          controller.myKelasList.first['name'] ?? 'Kelas Saya',
                                          style: const TextStyle(
                                            fontFamily: 'FredokaOne',
                                            fontSize: 14,
                                            color: Color(0xFFEA580C),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        
                      ],
                    ),
                  ),
                ),

                // Podium Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                    child: _buildPodiumSection(top3, currentUserId),
                  ),
                ),

                 // List Rank 4+
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: listBottomPadding,
                    ),
                    child: Column(
                      children: rest.isEmpty
                          ? [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Text(
                                  'Belum ada pemain lain',
                                  style: TextStyle(color: Colors.grey.shade400),
                                ),
                              )
                            ]
                          : List.generate(
                              rest.length,
                              (i) => _buildListItem(
                                i + 4,
                                rest[i],
                                rest[i].uid == currentUserId,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            // My Rank Glassmorphic Dock
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomNavTop + 8,
              child: _buildMyRankDock(
                currentUser?.namaPanggilan ?? currentUser?.namaLengkap ?? 'Kamu',
                currentUser?.avatarUrl,
                userRank,
                userPoin,
                onTap: () {
                  if (userRank > 3) {
                    final index = userRank - 4;
                    final targetOffset = 460.0 + (index * 68.0);
                    final maxScroll = _scrollController.position.maxScrollExtent;
                    final offset = targetOffset.clamp(0.0, maxScroll);
                    _scrollController.animateTo(
                      offset,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOutCubic,
                    );
                  } else if (userRank > 0) {
                    _scrollController.animateTo(
                      0.0,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOutCubic,
                    );
                  }
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildTabButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFEDD5) : Colors.transparent, // orange-100
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'FredokaOne',
            fontSize: 14,
            color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF94A3B8), // orange-600 vs slate-400
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // PODIUM SECTION
  // ───────────────────────────────────────────────────────────
  Widget _buildPodiumSection(List<ScoreModel> top3, String? currentUserId) {
    final first = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // #2 — Perak
        Expanded(
          child: _buildPodiumPillar(
            rank: 2,
            score: second,
            color: _silverColor,
            height: 120, // setara h-32
            avatarSize: 52,
            isMe: second?.uid == currentUserId,
          ),
        ),
        // #1 — Emas (tengah, lebih tinggi & maju)
        Expanded(
          child: Transform.translate(
            offset: const Offset(0, -16), // -mt-8
            child: _buildPodiumPillar(
              rank: 1,
              score: first,
              color: _goldColor,
              height: 160, // setara h-40
              avatarSize: 68,
              isMe: first?.uid == currentUserId,
              isChampion: true,
            ),
          ),
        ),
        // #3 — Perunggu
        Expanded(
          child: _buildPodiumPillar(
            rank: 3,
            score: third,
            color: _bronzeColor,
            height: 100, // setara h-28
            avatarSize: 52,
            isMe: third?.uid == currentUserId,
          ),
        ),
      ],
    );
  }

  Widget _buildPodiumPillar({
    required int rank,
    required ScoreModel? score,
    required Color color,
    required double height,
    required double avatarSize,
    required bool isMe,
    bool isChampion = false,
  }) {
    final name = score?.nama ?? '-';
    final poin = score?.totalPoin ?? 0;

    // Warna badge menyesuaikan peringkat
    Color badgeBgColor;
    Color badgeTextColor;
    if (rank == 1) {
      badgeBgColor = const Color(0xFFFEF3C7);
      badgeTextColor = const Color(0xFFD97706);
    } else if (rank == 2) {
      badgeBgColor = const Color(0xFFF1F5F9);
      badgeTextColor = const Color(0xFF475569);
    } else {
      badgeBgColor = const Color(0xFFFFEDD5);
      badgeTextColor = const Color(0xFFEA580C);
    }

    return AnimatedBuilder(
      animation: _podiumAnim,
      builder: (_, __) {
        final val = _podiumAnim.value;
        return Opacity(
          opacity: val,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - val)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Mahkota
                if (isChampion)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('👑', style: TextStyle(fontSize: 28)),
                  ),

                // Avatar dengan ring offset
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4), // Ring offset spacing
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFF9F0), // Sesuai background
                        border: Border.all(color: color, width: 4), // ring-4
                      ),
                      child: UserAvatarWidget(
                        avatarUrl: score?.avatarUrl,
                        name: name,
                        radius: avatarSize / 2,
                        borderColor: Colors.transparent,
                        borderWidth: 0,
                      ),
                    ),
                    // Rank Badge Lingkaran di Bawah Avatar
                    Positioned(
                      bottom: -8,
                      child: Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 14),

                // Nama
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF334155), // slate-700
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                // Poin Badge (Pill kecil)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars_rounded, size: 10, color: Color(0xFFFF7A00)),
                      const SizedBox(width: 2),
                      Text(
                        '$poin',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          color: badgeTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Balok Podium
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: double.infinity,
                  height: height * val, // Tinggi balok mengikuti animasi
                  decoration: BoxDecoration(
                    color: isChampion ? Colors.white : Colors.white,
                    gradient: isChampion 
                        ? const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.white, Color(0xFFFFFBEB)]) // amber-50 to white
                        : null,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32), // rounded-t-[2rem]
                      topRight: Radius.circular(32),
                    ),
                    border: Border(
                      top: BorderSide(color: color, width: 6), // border-t-[6px]
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0F000000), // shadow-[0_8px_30px_rgb(0,0,0,0.06)]
                        blurRadius: 30,
                        offset: Offset(0, 8),
                      )
                    ],
                  ),
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900,
                      fontSize: 64, // text-7xl
                      color: isChampion 
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.15) // amber-500/20
                          : color.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────
  // LIST ITEM (Rank 4+)
  // ───────────────────────────────────────────────────────────
  Widget _buildListItem(int rank, ScoreModel score, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFFFF7ED) : Colors.white,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: isMe ? const Color(0xFFFED7AA) : const Color(0xFFF1F5F9),
          width: isMe ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          )
        ],
      ),
      child: Row(
        children: [
          // Lingkaran Rank
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isMe ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Avatar
          UserAvatarWidget(
            avatarUrl: score.avatarUrl,
            name: score.nama,
            radius: 20,
            borderColor: Colors.transparent,
            borderWidth: 0,
          ),
          const SizedBox(width: 12),

          // Nama + Username/Sekolah
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMe ? '${score.nama} (Kamu)' : score.nama,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isMe ? const Color(0xFFD97706) : const Color(0xFF334155),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (score.username.isNotEmpty)
                  Text(
                    '@${score.username}',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      color: Color(0xFFFF7A00),
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else if (score.namaSekolah.isNotEmpty)
                  Text(
                    score.namaSekolah,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Poin
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                const Icon(Icons.stars_rounded,
                    size: 16, color: Color(0xFFFB923C)),
                const SizedBox(width: 4),
                Text(
                  '${score.totalPoin}',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // ───────────────────────────────────────────────────────────
  // DOCK PERINGKAT KAMU GLASSMORPHIC (Dock Extension)
  // ───────────────────────────────────────────────────────────
  Widget _buildMyRankDock(
    String name,
    String? avatarUrl,
    int userRank,
    int userPoin, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
            BoxShadow(
              color: const Color(0xFFFF7A00).withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.84),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    // Rank Badge Lingkaran Gradasi
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF7A00), Color(0xFFFF4D00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF7A00).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        userRank > 0 ? '#$userRank' : '—',
                        style: const TextStyle(
                          fontFamily: 'FredokaOne',
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Avatar & Label
                    Expanded(
                      child: Row(
                        children: [
                          UserAvatarWidget(
                            avatarUrl: avatarUrl,
                            name: name,
                            radius: 15,
                            borderColor: const Color(0xFFFF7A00).withValues(alpha: 0.3),
                            borderWidth: 1.5,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Peringkat Kamu',
                                      style: TextStyle(
                                        fontFamily: 'FredokaOne',
                                        fontSize: 12,
                                        color: Color(0xFFEA580C),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.touch_app_rounded,
                                      size: 11,
                                      color: const Color(0xFFFF7A00).withValues(alpha: 0.7),
                                    ),
                                  ],
                                ),
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Skor & Target
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFE8D6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded, size: 14, color: Color(0xFFFF7A00)),
                          const SizedBox(width: 4),
                          Text(
                            '$userPoin Poin',
                            style: const TextStyle(
                              fontFamily: 'FredokaOne',
                              fontSize: 11,
                              color: Color(0xFFEA580C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // KELAS EMPTY STATE
  // ───────────────────────────────────────────────────────────
  Widget _buildKelasEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7A00), Color(0xFFFF5100)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF7A00).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.class_outlined, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 24),
            const Text(
              'Belum Ikut Kelas',
              style: TextStyle(
                fontFamily: 'FredokaOne',
                fontSize: 22,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Bergabunglah ke kelas untuk melihat\nleaderboard bersama teman sekelasmu!',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7A00), Color(0xFFFF5100)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF7A00).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => Get.to(() => const GabungKelasScreen()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.group_add_rounded, color: Colors.white),
                label: const Text(
                  'Gabung Kelas Sekarang',
                  style: TextStyle(
                    fontFamily: 'FredokaOne',
                    fontSize: 15,
                    color: Colors.white,
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
