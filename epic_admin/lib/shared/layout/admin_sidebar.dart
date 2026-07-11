import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:epic_admin/core/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.path;

    return Container(
      width: 260,
      margin: const EdgeInsets.all(16), // Floating card margin on all sides
      decoration: BoxDecoration(
        color: AdminColors.sidebar,
        borderRadius: BorderRadius.circular(24), // Melengkung di seluruh ujung
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(-8, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Profile Area
          Container(
            padding: const EdgeInsets.only(top: 32, bottom: 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.6), // Glowing blue ring
                      width: 2.0,
                    ),
                  ),
                  child: const CircleAvatar(
                    radius: 36,
                    backgroundColor: Color(0xFF222F47),
                    child: Icon(Icons.person, color: Colors.white, size: 40),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'ADMIN EPIC',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'admin@epic.com',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF64748B), // Slate-500
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),

          const Divider(
            color: Color(0xFF222F47),
            thickness: 1,
            indent: 24,
            endIndent: 24,
          ),

          // 2. Navigation Items
          Expanded(
            child: ListView(
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildSectionTitle(context, 'MENU UTAMA'),
                _NavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  isActive: currentRoute == '/',
                  onTap: () => context.go('/'),
                ),
                _NavItem(
                  icon: Icons.people_rounded,
                  label: 'Pengguna',
                  isActive: currentRoute.startsWith('/users'),
                  onTap: () => context.go('/users'),
                ),
                _NavItem(
                  icon: Icons.verified_user_rounded,
                  label: 'Verifikasi Guru',
                  isActive: currentRoute.startsWith('/verifikasi'),
                  onTap: () => context.go('/verifikasi'),
                ),
                _NavItem(
                  icon: Icons.school_rounded,
                  label: 'Kelas',
                  isActive: currentRoute.startsWith('/kelas'),
                  onTap: () => context.go('/kelas'),
                ),
                const SizedBox(height: 16),

                _buildSectionTitle(context, 'KONTEN & AI'),
                _NavItem(
                  icon: Icons.smart_toy_rounded,
                  label: 'AI Monitoring',
                  isActive: currentRoute.startsWith('/ai-monitoring'),
                  onTap: () => context.go('/ai-monitoring'),
                ),
                _NavItem(
                  icon: Icons.edit_document,
                  label: 'Konten Game',
                  isActive: currentRoute.startsWith('/konten'),
                  onTap: () => context.go('/konten'),
                ),
                const SizedBox(height: 16),

                _buildSectionTitle(context, 'LAPORAN & DETAIL'),
                _NavItem(
                  icon: Icons.analytics_rounded,
                  label: 'Laporan & Export',
                  isActive: currentRoute.startsWith('/laporan'),
                  onTap: () => context.go('/laporan'),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'Pengaturan',
                  isActive: currentRoute.startsWith('/settings'),
                  onTap: () => context.go('/settings'),
                ),
              ],
            ),
          ),

          // Logout Button
          InkWell(
            onTap: () async {
              await AuthService().signOut();
            },
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            hoverColor: const Color(0xFFEF4444).withOpacity(0.08),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFF222F47), width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Sign Out',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 8, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF475569), // Muted slate
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int? badgeCount;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeCount,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Active item gets white text/icon, hover gets white, inactive gets muted grey
    final color = widget.isActive
        ? Colors.white
        : (_isHovered ? Colors.white : const Color(0xFF94A3B8));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: widget.isActive
                ? const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: !widget.isActive
                ? (_isHovered ? AdminColors.sidebarHover : Colors.transparent)
                : null,
            borderRadius: BorderRadius.circular(16), // Capsule shape
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: color, size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: widget.isActive ? FontWeight.bold : FontWeight.w500,
                        fontSize: 14.5,
                      ),
                ),
              ),
              if (widget.badgeCount != null && widget.badgeCount! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AdminColors.danger,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.badgeCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
