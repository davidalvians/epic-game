import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:epic_admin/features/users/widgets/guru_table.dart';
import 'package:epic_admin/features/users/widgets/murid_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _filterStatus = '';

  // Opsi filter per tab
  static const _muridFilterOptions = [
    {'label': 'Semua Status', 'value': ''},
    {'label': 'Aktif', 'value': 'active'},
    {'label': 'Suspended', 'value': 'suspended'},
  ];

  static const _guruFilterOptions = [
    {'label': 'Semua Status', 'value': ''},
    {'label': 'Approved', 'value': 'approved'},
    {'label': 'Pending', 'value': 'pending'},
    {'label': 'Rejected', 'value': 'rejected'},
    {'label': 'Suspended', 'value': 'suspended'},
  ];

  List<Map<String, String>> get _currentFilterOptions =>
      _tabController.index == 0 ? _muridFilterOptions : _guruFilterOptions;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Reset filter saat pindah tab
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _filterStatus = '';
        });
      }
    });

    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background Glow Effects (Luxury Glow Backdrop)
        Positioned(
          top: -120,
          right: -80,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF2563EB).withOpacity(0.07),
                  const Color(0xFF2563EB).withOpacity(0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -150,
          left: -120,
          child: Container(
            width: 480,
            height: 480,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF8B5CF6).withOpacity(0.06),
                  const Color(0xFF8B5CF6).withOpacity(0),
                ],
              ),
            ),
          ),
        ),

        // Content Area
        Positioned.fill(
          child: SizedBox.expand(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Dashboard',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF64748B),
                              ),
                        ),
                        const Icon(Icons.chevron_right, size: 14, color: Color(0xFF64748B)),
                        Text(
                          'Manajemen User',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AdminColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Manajemen User',
                      style: (isMobile
                              ? Theme.of(context).textTheme.headlineMedium
                              : Theme.of(context).textTheme.headlineLarge)
                          ?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad),
                SizedBox(height: isMobile ? 16 : 24),

                // ── Custom TabBar ─────────────────────────────────────────
                Container(
                  width: isMobile ? double.infinity : 320,
                  constraints: const BoxConstraints(maxWidth: 360),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.all(4),
                    labelColor: AdminColors.primary,
                    unselectedLabelColor: const Color(0xFF64748B),
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.school_rounded, size: 16),
                            SizedBox(width: 8),
                            Text('Murid'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.supervisor_account_rounded, size: 16),
                            SizedBox(width: 8),
                            Text('Guru'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad),
                SizedBox(height: isMobile ? 16 : 24),

                // ── Search & Filter Bar ───────────────────────────────────
                Container(
                  padding: EdgeInsets.all(isMobile ? 14 : 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: isMobile
                      ? Column(
                          children: [
                            // Search Field
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: _tabController.index == 0
                                    ? 'Cari nama, ID, atau kelas...'
                                    : 'Cari nama, ID, atau sekolah...',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 18),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AdminColors.primary, width: 1.5),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: AnimatedBuilder(
                                    animation: _tabController,
                                    builder: (context, _) {
                                      final validValues = _currentFilterOptions.map((o) => o['value']!).toList();
                                      final currentFilter = validValues.contains(_filterStatus) ? _filterStatus : '';

                                      return Container(
                                        height: 44,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: currentFilter,
                                            isExpanded: true,
                                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                                            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                            items: _currentFilterOptions
                                                .map((opt) => DropdownMenuItem<String>(
                                                      value: opt['value']!,
                                                      child: Text(opt['label']!),
                                                    ))
                                                .toList(),
                                            onChanged: (val) => setState(() => _filterStatus = val ?? ''),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                if (_searchQuery.isNotEmpty || _filterStatus.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    height: 44,
                                    width: 44,
                                    decoration: BoxDecoration(
                                      color: AdminColors.primary.withOpacity(0.08),
                                      border: Border.all(color: AdminColors.primary.withOpacity(0.2)),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.filter_list_off_rounded, color: AdminColors.primary, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                          _filterStatus = '';
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            // Search Field
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: _tabController.index == 0
                                      ? 'Cari nama, ID, atau kelas murid...'
                                      : 'Cari nama, ID, atau sekolah guru...',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                        )
                                      : null,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AdminColors.primary, width: 1.5),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Filter Dropdown
                            AnimatedBuilder(
                              animation: _tabController,
                              builder: (context, _) {
                                final validValues = _currentFilterOptions.map((o) => o['value']!).toList();
                                final currentFilter = validValues.contains(_filterStatus) ? _filterStatus : '';

                                return DropdownMenu<String>(
                                  key: ValueKey(_tabController.index),
                                  initialSelection: currentFilter,
                                  width: 200,
                                  inputDecorationTheme: InputDecorationTheme(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: AdminColors.primary, width: 1.5),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                  ),
                                  onSelected: (value) => setState(() => _filterStatus = value ?? ''),
                                  dropdownMenuEntries: _currentFilterOptions
                                      .map((opt) => DropdownMenuEntry<String>(
                                            value: opt['value']!,
                                            label: opt['label']!,
                                          ))
                                      .toList(),
                                );
                              },
                            ),

                            const SizedBox(width: 16),

                            // Tombol reset filter
                            AnimatedOpacity(
                              opacity: (_searchQuery.isNotEmpty || _filterStatus.isNotEmpty) ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Tooltip(
                                message: 'Reset Pencarian & Filter',
                                child: Container(
                                  height: 48,
                                  width: 48,
                                  decoration: BoxDecoration(
                                    color: AdminColors.primary.withOpacity(0.06),
                                    border: Border.all(color: AdminColors.primary.withOpacity(0.2), width: 1.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.filter_list_off_rounded, color: AdminColors.primary, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _filterStatus = '';
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad),
                SizedBox(height: isMobile ? 16 : 24),

                // ── Tab Views (Tables) ────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      MuridTable(
                        searchQuery: _searchQuery,
                        filterStatus: _filterStatus,
                      ),
                      GuruTable(
                        searchQuery: _searchQuery,
                        filterStatus: _filterStatus,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutQuad),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
