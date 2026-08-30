import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epic_admin/core/services/auth_service.dart';
import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:epic_admin/core/theme/admin_sizes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminHeader extends StatelessWidget {
  final VoidCallback onMenuPressed;

  const AdminHeader({super.key, required this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final currentRoute = GoRouterState.of(context).uri.path;
    final user = FirebaseAuth.instance.currentUser;

    String pageTitle = 'Admin Panel';
    if (currentRoute == '/') {
      pageTitle = 'Dasbor';
    } else if (currentRoute.startsWith('/users/murid/')) {
      pageTitle = 'Detail Murid';
    } else if (currentRoute.startsWith('/users/guru/')) {
      pageTitle = 'Detail Guru';
    } else if (currentRoute.startsWith('/users')) {
      pageTitle = 'Pengguna';
    } else if (currentRoute.startsWith('/verifikasi/')) {
      pageTitle = 'Review Verifikasi';
    } else if (currentRoute.startsWith('/verifikasi')) {
      pageTitle = 'Verifikasi Guru';
    } else if (currentRoute.startsWith('/kelas/')) {
      pageTitle = 'Detail Kelas';
    } else if (currentRoute.startsWith('/kelas')) {
      pageTitle = 'Manajemen Kelas';
    } else if (currentRoute.startsWith('/ai-monitoring')) {
      pageTitle = 'AI Monitoring';
    } else if (currentRoute.startsWith('/konten')) {
      pageTitle = 'Konten Game';
    } else if (currentRoute.startsWith('/laporan')) {
      pageTitle = 'Laporan & Ekspor';
    } else if (currentRoute.startsWith('/settings')) {
      pageTitle = 'Pengaturan';
    }

    final bool isSubDetailRoute = currentRoute.startsWith('/users/murid/') ||
        currentRoute.startsWith('/users/guru/') ||
        (currentRoute.startsWith('/verifikasi/') && currentRoute != '/verifikasi') ||
        (currentRoute.startsWith('/kelas/') && currentRoute != '/kelas') ||
        currentRoute.startsWith('/konten/instrumen/') ||
        currentRoute.startsWith('/konten/onboarding/') ||
        currentRoute.startsWith('/konten/template/') ||
        currentRoute.startsWith('/konten/misi/');

    return Container(
      height: isDesktop ? AdminSizes.headerHeight : 60,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!isDesktop)
            if (isSubDetailRoute)
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AdminColors.textPrimary),
                tooltip: 'Kembali',
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    if (currentRoute.startsWith('/users')) {
                      context.go('/users');
                    } else if (currentRoute.startsWith('/verifikasi')) {
                      context.go('/verifikasi');
                    } else if (currentRoute.startsWith('/kelas')) {
                      context.go('/kelas');
                    } else if (currentRoute.startsWith('/konten')) {
                      context.go('/konten');
                    } else {
                      context.go('/');
                    }
                  }
                },
              )
            else
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: AdminColors.textPrimary),
                tooltip: 'Buka Menu',
                onPressed: onMenuPressed,
              ),
          if (!isDesktop) const SizedBox(width: 8),

          // Logo and Title
          if (!isDesktop)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Icon(Icons.shield_rounded, color: Colors.white, size: 18),
              ),
            ),
          if (!isDesktop) const SizedBox(width: 10),

          Text(
            isDesktop ? 'EPIC Admin Panel' : pageTitle,
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),

          // Pending verification notification icon with live counter
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('guru_verifikasi')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              final pendingCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: AdminColors.textSecondary, size: 22),
                    tooltip: 'Verifikasi Pending',
                    onPressed: () => context.go('/verifikasi'),
                  ),
                  if (pendingCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AdminColors.danger,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),

          // Admin Profile Avatar with Popup Menu
          PopupMenuButton<String>(
            tooltip: 'Profil Admin',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) async {
              if (value == 'settings') {
                context.go('/settings');
              } else if (value == 'logout') {
                await AuthService().signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (user?.displayName != null && user!.displayName!.trim().isNotEmpty)
                          ? user.displayName!
                          : 'Admin EPIC',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      user?.email ?? 'admin@epic.com',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 6),
                    const Divider(color: Color(0xFFE2E8F0)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_rounded, size: 18, color: Color(0xFF475569)),
                    SizedBox(width: 10),
                    Text('Pengaturan Sistem'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: Color(0xFFEF4444)),
                    SizedBox(width: 10),
                    Text('Keluar', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AdminColors.primary.withOpacity(0.3), width: 1.5),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFEFF6FF),
                backgroundImage: (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                    ? NetworkImage(user.photoURL!)
                    : null,
                child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                    ? const Icon(Icons.person, size: 18, color: AdminColors.primary)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
