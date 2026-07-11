import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:epic_admin/core/theme/admin_sizes.dart';
import 'package:epic_admin/shared/layout/admin_header.dart';
import 'package:epic_admin/shared/layout/admin_sidebar.dart';
import 'package:flutter/material.dart';

class AdminLayout extends StatefulWidget {
  final Widget child;

  const AdminLayout({super.key, required this.child});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminColors.background,
      drawer: isDesktop ? null : const AdminSidebar(),
      body: Row(
        children: [
          if (isDesktop)
            const AdminSidebar(),
          Expanded(
            child: Column(
              children: [
                if (!isDesktop)
                  AdminHeader(
                    onMenuPressed: () {
                      _scaffoldKey.currentState?.openDrawer();
                    },
                  ),
                Expanded(
                  child: Container(
                    color: AdminColors.background,
                    padding: const EdgeInsets.all(AdminSizes.paddingPage),
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
