import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Topbar extends StatelessWidget implements PreferredSizeWidget {
  const Topbar({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = (user?.displayName != null && user!.displayName!.trim().isNotEmpty)
        ? user.displayName!
        : 'Admin EPIC';
    final email = (user?.email != null && user!.email!.trim().isNotEmpty)
        ? user.email!
        : 'Administrator';
    final photoUrl = user?.photoURL;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AdminColors.surface.withOpacity(0.7),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          // Search Bar
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                height: 44,
                decoration: BoxDecoration(
                  color: AdminColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                decoration: InputDecoration(
                  hintText: 'Cari apa saja...',
                  prefixIcon: const Icon(Icons.search, color: AdminColors.onSurfaceVariant),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              ),
            ),
          ),
          
          // Right section (Actions & Profile)
          Row(
            children: [
              // Notifications
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AdminColors.onSurfaceVariant),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              // Security Status
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminColors.gradeA.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.security, size: 20, color: AdminColors.gradeA),
              ),
              const SizedBox(width: 24),
              // Divider
              Container(
                height: 32,
                width: 1,
                color: AdminColors.outlineVariant.withOpacity(0.2),
              ),
              const SizedBox(width: 24),
              // Profile
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        email,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AdminColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    backgroundColor: AdminColors.primaryContainer.withOpacity(0.2),
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                        ? NetworkImage(photoUrl)
                        : null,
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? const Icon(Icons.person, color: AdminColors.primary)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(72);
}
