import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:epic_admin/core/theme/admin_sizes.dart';
import 'package:flutter/material.dart';

class AdminHeader extends StatelessWidget {
  final VoidCallback onMenuPressed;

  const AdminHeader({super.key, required this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Container(
      height: AdminSizes.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.menu, color: AdminColors.textPrimary),
              onPressed: onMenuPressed,
            ),
          if (!isDesktop) const SizedBox(width: 16),
          // Title (Dynamic based on route, or hardcoded for now)
          Text(
            'Admin Panel',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // Notifications
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AdminColors.textSecondary),
            onPressed: () {},
          ),
          const SizedBox(width: 16),
          // Profile
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AdminColors.border),
            ),
            child: const CircleAvatar(
              radius: 16,
              backgroundColor: AdminColors.background,
              child: Icon(Icons.person, size: 20, color: AdminColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
