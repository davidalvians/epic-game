import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:epic_admin/core/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    // Dapatkan rute saat ini dari GoRouter state
    final String currentRoute = GoRouterState.of(context).uri.toString();

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AdminColors.surface.withOpacity(0.8),
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Brand
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AdminColors.primary, AdminColors.primaryContainer],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AdminColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/logo/epic_logo_v2.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EPIC',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AdminColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Ecocultural Pattern\nInnovation Creator',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 0.5,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Navigation
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _NavItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Dasbor',
                  isActive: currentRoute == '/',
                  onTap: () => context.go('/'),
                ),
                _NavItem(
                  icon: Icons.group_outlined,
                  label: 'Manajemen Pengguna',
                  isActive: currentRoute.startsWith('/users'),
                  onTap: () => context.go('/users'),
                ),
                _NavItem(
                  icon: Icons.school_outlined,
                  label: 'Manajemen Kelas',
                  isActive: currentRoute.startsWith('/kelas'),
                  onTap: () => context.go('/kelas'),
                ),
                _NavItem(
                  icon: Icons.verified_user_outlined,
                  label: 'Verifikasi Guru',
                  isActive: currentRoute.startsWith('/verifikasi'),
                  onTap: () => context.go('/verifikasi'),
                ),
                _NavItem(
                  icon: Icons.smart_toy_outlined,
                  label: 'Pemantauan AI',
                  isActive: currentRoute.startsWith('/ai-monitoring'),
                  onTap: () => context.go('/ai-monitoring'),
                ),
                _NavItem(
                  icon: Icons.extension_outlined,
                  label: 'Manajemen Konten',
                  isActive: currentRoute.startsWith('/konten'),
                  onTap: () => context.go('/konten'),
                ),
                _NavItem(
                  icon: Icons.assessment_outlined,
                  label: 'Laporan',
                  isActive: currentRoute.startsWith('/laporan'),
                  onTap: () => context.go('/laporan'),
                ),
              ],
            ),
          ),
          
          // Bottom Actions
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Divider(),
                _NavItem(
                  icon: Icons.settings_outlined,
                  label: 'Pengaturan',
                  isActive: currentRoute.startsWith('/settings'),
                  onTap: () => context.go('/settings'),
                ),
                _NavItem(
                  icon: Icons.logout,
                  label: 'Keluar',
                  isActive: false,
                  isError: true,
                  onTap: () async {
                    await AuthService().signOut();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isError;
  final Widget? trailing;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isError = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? AdminColors.error : (isActive ? AdminColors.primary : AdminColors.onSurfaceVariant);
    final bgColor = isActive ? AdminColors.primaryContainer.withOpacity(0.15) : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: AdminColors.surfaceContainerLow,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
