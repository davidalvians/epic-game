import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:epic_admin/features/evaluasi/widgets/response_detail_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StudentResponsesTab extends StatelessWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> filteredResponses;
  final String searchQuery;
  final String filterCategory;
  final String filterLevel;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onLevelChanged;

  const StudentResponsesTab({
    super.key,
    required this.isLoading,
    required this.filteredResponses,
    required this.searchQuery,
    required this.filterCategory,
    required this.filterLevel,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onLevelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 820;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilterBar(
              isCompact: isCompact,
              searchQuery: searchQuery,
              filterCategory: filterCategory,
              filterLevel: filterLevel,
              onSearchChanged: onSearchChanged,
              onCategoryChanged: onCategoryChanged,
              onLevelChanged: onLevelChanged,
            ).animate().fade(duration: 250.ms),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
                child: isLoading
                    ? const Center(
                        key: ValueKey('loading'),
                        child: CircularProgressIndicator(),
                      )
                    : filteredResponses.isEmpty
                        ? const _EmptyState(key: ValueKey('empty'))
                        : isCompact
                            ? _ResponseCards(
                                key: const ValueKey('cards'),
                                responses: filteredResponses,
                              )
                            : _ResponseTable(
                                key: const ValueKey('table'),
                                responses: filteredResponses,
                              ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  final bool isCompact;
  final String searchQuery;
  final String filterCategory;
  final String filterLevel;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onLevelChanged;

  const _FilterBar({
    required this.isCompact,
    required this.searchQuery,
    required this.filterCategory,
    required this.filterLevel,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onLevelChanged,
  });

  @override
  Widget build(BuildContext context) {
    final search = TextFormField(
      initialValue: searchQuery,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E293B),
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: 'Cari nama, email, atau sekolah...',
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      onChanged: onSearchChanged,
    );

    final category = _FilterDropdown(
      icon: Icons.filter_list_rounded,
      value: filterCategory,
      items: const {
        'Semua Kategori': 'Semua Kategori',
        'keris': 'Keris Madura',
        'batik': 'Batik Madura',
        'anyaman': 'Anyaman Madura',
      },
      onChanged: onCategoryChanged,
    );
    final level = _FilterDropdown(
      icon: Icons.layers_rounded,
      value: filterLevel,
      items: const {
        'Semua Level': 'Semua Level',
        'Level 1': 'Level 1',
        'Level 2': 'Level 2',
        'Level 3': 'Level 3',
        'Level 4': 'Level 4',
      },
      onChanged: onLevelChanged,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: isCompact
          ? Column(
              children: [
                search,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: category),
                    const SizedBox(width: 10),
                    Expanded(child: level),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 12),
                SizedBox(width: 190, child: category),
                const SizedBox(width: 10),
                SizedBox(width: 155, child: level),
              ],
            ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final IconData icon;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF334155),
        fontSize: 12,
      ),
      items: items.entries
          .map((item) =>
              DropdownMenuItem(value: item.key, child: Text(item.value)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _ResponseTable extends StatelessWidget {
  final List<Map<String, dynamic>> responses;

  const _ResponseTable({super.key, required this.responses});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  dataRowMinHeight: 68,
                  dataRowMaxHeight: 76,
                  columnSpacing: 22,
                  horizontalMargin: 20,
                  headingRowHeight: 52,
                  headingRowColor:
                      WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    letterSpacing: .7,
                  ),
                  columns: const [
                    DataColumn(label: Text('NO')),
                    DataColumn(label: Text('SISWA & AKUN')),
                    DataColumn(label: Text('SEKOLAH & KELAS')),
                    DataColumn(label: Text('KATEGORI & LEVEL')),
                    DataColumn(label: Text('WAKTU')),
                    DataColumn(label: Text('PERASAAN')),
                    DataColumn(label: Text('AKSI')),
                  ],
                  rows: List.generate(responses.length, (index) {
                    final row = responses[index];
                    return DataRow(
                      color: WidgetStateProperty.all(
                        index.isEven ? Colors.white : const Color(0xFFFCFDFE),
                      ),
                      cells: _rowCells(context, row, index),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    ).animate().fade(duration: 300.ms).slideY(begin: .02, end: 0);
  }

  List<DataCell> _rowCells(
    BuildContext context,
    Map<String, dynamic> row,
    int index,
  ) {
    final name = row['nama']?.toString() ?? 'Tanpa Nama';
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    return [
      DataCell(_NumberBadge(number: index + 1)),
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AdminColors.primary.withValues(alpha: .1),
              child: Text(
                initial,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle),
                  Text(
                    '@${row['username']} · ${row['email']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _metaStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      DataCell(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row['sekolah']?.toString() ?? '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _titleStyle),
              Text('Kelas ${row['kelas'] ?? '-'}', style: _metaStyle),
            ],
          ),
        ),
      ),
      DataCell(_CategoryBadge(label: row['kategori_level']?.toString() ?? '-')),
      DataCell(Text(row['tanggal']?.toString() ?? '-', style: _bodyStyle)),
      DataCell(
        Tooltip(
          message: row['emotikon_note']?.toString() ?? '',
          child: Text(row['emotikon']?.toString() ?? '-', style: _bodyStyle),
        ),
      ),
      DataCell(
        _DetailButton(
          onPressed: () => ResponseDetailDialog.show(context, row),
        ),
      ),
    ];
  }
}

class _ResponseCards extends StatelessWidget {
  final List<Map<String, dynamic>> responses;

  const _ResponseCards({super.key, required this.responses});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: responses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final row = responses[index];
        final name = row['nama']?.toString() ?? 'Tanpa Nama';
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _NumberBadge(number: index + 1),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: _titleStyle),
                        Text(
                          '@${row['username']} · ${row['email']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _metaStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(row['emotikon']?.toString() ?? '-',
                  style: const TextStyle(fontSize: 14)),
              const Divider(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _CategoryBadge(
                      label: row['kategori_level']?.toString() ?? '-'),
                  _Info(
                    icon: Icons.school_outlined,
                    text:
                        '${row['sekolah'] ?? '-'} · Kelas ${row['kelas'] ?? '-'}',
                  ),
                  _Info(
                    icon: Icons.schedule_rounded,
                    text: row['tanggal']?.toString() ?? '-',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: _DetailButton(
                  onPressed: () => ResponseDetailDialog.show(context, row),
                ),
              ),
            ],
          ),
        );
      },
    ).animate().fade(duration: 300.ms);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_rounded, size: 52, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          const Text(
            'Belum ada respons',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Coba ubah pencarian atau filter yang digunakan.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  final int number;

  const _NumberBadge({required this.number});

  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF3F8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$number',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF475569),
          ),
        ),
      );
}

class _CategoryBadge extends StatelessWidget {
  final String label;

  const _CategoryBadge({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7DF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFB45309),
            fontWeight: FontWeight.w800,
            fontSize: 10,
          ),
        ),
      );
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Info({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 5),
          Flexible(child: Text(text, style: _metaStyle)),
        ],
      );
}

class _DetailButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _DetailButton({required this.onPressed});

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.visibility_outlined, size: 16),
        label: const Text('Lihat Detail'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
}

const _titleStyle = TextStyle(
  fontWeight: FontWeight.w700,
  color: Color(0xFF1E293B),
  fontSize: 13,
);
const _metaStyle = TextStyle(fontSize: 11, color: Color(0xFF64748B));
const _bodyStyle = TextStyle(fontSize: 12, color: Color(0xFF475569));
