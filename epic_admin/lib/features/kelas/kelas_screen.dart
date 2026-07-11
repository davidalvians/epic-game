import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';

class KelasScreen extends StatelessWidget {
  const KelasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Dashboard', style: Theme.of(context).textTheme.labelSmall),
                    const Icon(Icons.chevron_right, size: 14, color: AdminColors.onSurfaceVariant),
                    Text('Manajemen Kelas', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AdminColors.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Manajemen Kelas',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Buat Kelas Baru', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 32),
        
        // Grid Kelas
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 350,
              mainAxisSpacing: 24,
              crossAxisSpacing: 24,
              childAspectRatio: 1.1,
            ),
            itemCount: 6,
            itemBuilder: (context, index) {
              return _ClassCard(index: index);
            },
          ),
        ),
      ],
    );
  }
}

class _ClassCard extends StatefulWidget {
  final int index;
  const _ClassCard({required this.index});

  @override
  State<_ClassCard> createState() => _ClassCardState();
}

class _ClassCardState extends State<_ClassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _isHovered ? -5 : 0, 0),
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AdminColors.outlineVariant.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: AdminColors.primary.withOpacity(_isHovered ? 0.15 : 0.02),
              blurRadius: _isHovered ? 15 : 10,
              offset: Offset(0, _isHovered ? 8 : 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section (Gradient bg)
            Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AdminColors.primary.withOpacity(0.8),
                    AdminColors.primaryContainer.withOpacity(0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kelas ${10 + widget.index}-A',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'EPIC-X${823 + widget.index}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Aktif', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            // Bottom Section (Info)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _InfoRow(icon: Icons.person, label: 'Guru', value: 'Ahmad Fauzi'),
                  const SizedBox(height: 12),
                  _InfoRow(icon: Icons.groups, label: 'Total Murid', value: '${30 + widget.index} Siswa'),
                  const SizedBox(height: 12),
                  _InfoRow(icon: Icons.star, label: 'Rata-rata Nilai', value: '${85 + widget.index}.5', isScore: true),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AdminColors.primary),
                        foregroundColor: AdminColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Lihat Detail', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isScore;

  const _InfoRow({required this.icon, required this.label, required this.value, this.isScore = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AdminColors.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminColors.onSurfaceVariant))),
        if (isScore)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AdminColors.gradeA.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(value, style: const TextStyle(color: AdminColors.gradeA, fontWeight: FontWeight.bold)),
          )
        else
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
