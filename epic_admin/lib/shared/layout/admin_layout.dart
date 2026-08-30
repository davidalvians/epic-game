import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:epic_admin/shared/layout/admin_bottom_navbar.dart';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AdminColors.background,
      drawer: isDesktop
          ? null
          : const Drawer(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: SafeArea(
                child: AdminSidebar(),
              ),
            ),
      bottomNavigationBar: isDesktop ? null : const AdminBottomNavBar(),
      body: Row(
        children: [
          if (isDesktop) const AdminSidebar(),
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
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 28.0 : 16.0,
                      vertical: isDesktop ? 24.0 : 12.0,
                    ),
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
