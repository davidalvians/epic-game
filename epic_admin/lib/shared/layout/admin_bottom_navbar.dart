import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epic_admin/core/services/auth_service.dart';
import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminBottomNavBar extends StatelessWidget {
  const AdminBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.path;

    // Check which primary tab is active
    int activeIndex = 0;
    if (currentRoute == '/') {
      activeIndex = 0;
    } else if (currentRoute.startsWith('/users')) {
      activeIndex = 1;
    } else if (currentRoute.startsWith('/verifikasi')) {
      activeIndex = 2;
    } else if (currentRoute.startsWith('/kelas')) {
      activeIndex = 3;
    } else {
      // If on /ai-monitoring, /konten, /laporan, /settings -> highlight "Menu Lainnya"
      activeIndex = 4;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context: context,
                index: 0,
                activeIndex: activeIndex,
                icon: Icons.dashboard_rounded,
                label: 'Dasbor',
                onTap: () => context.go('/'),
              ),
              _buildNavItem(
                context: context,
                index: 1,
                activeIndex: activeIndex,
                icon: Icons.people_rounded,
                label: 'Pengguna',
                onTap: () => context.go('/users'),
              ),
              _buildVerifikasiNavItem(
                context: context,
                index: 2,
                activeIndex: activeIndex,
                onTap: () => context.go('/verifikasi'),
              ),
              _buildNavItem(
                context: context,
                index: 3,
                activeIndex: activeIndex,
                icon: Icons.school_rounded,
                label: 'Kelas',
                onTap: () => context.go('/kelas'),
              ),
              _buildNavItem(
                context: context,
                index: 4,
                activeIndex: activeIndex,
                icon: Icons.grid_view_rounded,
                label: 'Menu',
                onTap: () => _showMenuBottomSheet(context, currentRoute),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required int activeIndex,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isActive = index == activeIndex;
    final color = isActive ? AdminColors.primary : const Color(0xFF64748B);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: AdminColors.primary.withOpacity(0.1),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: isActive ? 12 : 0, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? AdminColors.primary.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerifikasiNavItem({
    required BuildContext context,
    required int index,
    required int activeIndex,
    required VoidCallback onTap,
  }) {
    final isActive = index == activeIndex;
    final color = isActive ? AdminColors.primary : const Color(0xFF64748B);

    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('guru_verifikasi')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          final pendingCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: AdminColors.primary.withOpacity(0.1),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(horizontal: isActive ? 12 : 0, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? AdminColors.primary.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.verified_user_rounded,
                          color: color,
                          size: 22,
                        ),
                      ),
                      if (pendingCount > 0)
                        Positioned(
                          right: isActive ? 4 : -4,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AdminColors.danger,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Center(
                              child: Text(
                                pendingCount > 99 ? '99+' : '$pendingCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Verifikasi',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMenuBottomSheet(BuildContext context, String currentRoute) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pill handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Header title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AdminColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.apps_rounded, color: AdminColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Semua Fitur Admin',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 16),

              // Menu Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.2,
                children: [
                  _buildMenuCard(
                    context: context,
                    bottomSheetContext: ctx,
                    icon: Icons.smart_toy_rounded,
                    title: 'AI Monitoring',
                    subtitle: 'Skor & Re-Score',
                    color: const Color(0xFF8B5CF6),
                    isActive: currentRoute.startsWith('/ai-monitoring'),
                    onTap: () => context.go('/ai-monitoring'),
                  ),
                  _buildMenuCard(
                    context: context,
                    bottomSheetContext: ctx,
                    icon: Icons.edit_document,
                    title: 'Konten Game',
                    subtitle: 'Template & Misi',
                    color: const Color(0xFFEC4899),
                    isActive: currentRoute.startsWith('/konten'),
                    onTap: () => context.go('/konten'),
                  ),
                  _buildMenuCard(
                    context: context,
                    bottomSheetContext: ctx,
                    icon: Icons.analytics_rounded,
                    title: 'Laporan',
                    subtitle: 'Rekap & Ekspor',
                    color: const Color(0xFF059669),
                    isActive: currentRoute.startsWith('/laporan'),
                    onTap: () => context.go('/laporan'),
                  ),
                  _buildMenuCard(
                    context: context,
                    bottomSheetContext: ctx,
                    icon: Icons.settings_rounded,
                    title: 'Pengaturan',
                    subtitle: 'Sistem & Aturan',
                    color: const Color(0xFF2563EB),
                    isActive: currentRoute.startsWith('/settings'),
                    onTap: () => context.go('/settings'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Logout Row
              InkWell(
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await AuthService().signOut();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.5)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Keluar dari Admin Panel',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Color(0xFFEF4444), size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required BuildContext bottomSheetContext,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(bottomSheetContext).pop();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.1) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color : const Color(0xFFE2E8F0),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isActive ? color : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
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
    );
  }
}
