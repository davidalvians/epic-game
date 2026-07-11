import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GradeDistributionChart extends StatefulWidget {
  const GradeDistributionChart({super.key});

  @override
  State<GradeDistributionChart> createState() => _GradeDistributionChartState();
}

class _GradeDistributionChartState extends State<GradeDistributionChart> {
  int touchedIndex = -1;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('artworks').snapshots(),
      builder: (context, snapshot) {
        int countS = 0;
        int countA = 0;
        int countB = 0;
        int countC = 0;
        int countD = 0;
        int countE = 0;
        int total = 0;

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data != null) {
              final String grade = (data['grade'] ?? '-').toString().toUpperCase();
              total++;
              if (grade == 'S') countS++;
              else if (grade == 'A') countA++;
              else if (grade == 'B') countB++;
              else if (grade == 'C') countC++;
              else if (grade == 'D') countD++;
              else if (grade == 'E') countE++;
              else total--; // Don't count pending/unrated in grade distribution
            }
          }
        }

        final double pctS = total > 0 ? (countS / total * 100) : 0;
        final double pctA = total > 0 ? (countA / total * 100) : 0;
        final double pctB = total > 0 ? (countB / total * 100) : 0;
        final double pctC = total > 0 ? (countC / total * 100) : 0;
        final double pctD = total > 0 ? (countD / total * 100) : 0;
        final double pctE = total > 0 ? (countE / total * 100) : 0;

        return Container(
          height: 420, // Equal height constraint for aligned bottom row
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AdminColors.outlineVariant.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Distribusi Grade Karya',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AdminColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Penilaian tingkat kelulusan gambar siswa',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AdminColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Stack(
                  children: [
                    PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                touchedIndex = -1;
                                return;
                              }
                              touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 4,
                        centerSpaceRadius: _isLoaded ? 65 : 10,
                        sections: _buildSections(total, countS, countA, countB, countC, countD, countE),
                      ),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOutCubic,
                    ),
                    Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 600),
                        opacity: _isLoaded ? 1.0 : 0.0,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$total',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AdminColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Karya',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AdminColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  _Indicator(color: AdminColors.gradeS, text: 'Grade S (${pctS.toStringAsFixed(0)}%)', isSquare: false),
                  _Indicator(color: AdminColors.gradeA, text: 'Grade A (${pctA.toStringAsFixed(0)}%)', isSquare: false),
                  _Indicator(color: AdminColors.gradeB, text: 'Grade B (${pctB.toStringAsFixed(0)}%)', isSquare: false),
                  _Indicator(color: AdminColors.gradeC, text: 'Grade C (${pctC.toStringAsFixed(0)}%)', isSquare: false),
                  _Indicator(color: AdminColors.gradeD, text: 'Grade D (${pctD.toStringAsFixed(0)}%)', isSquare: false),
                  _Indicator(color: AdminColors.gradeE, text: 'Grade E (${pctE.toStringAsFixed(0)}%)', isSquare: false),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  List<PieChartSectionData> _buildSections(int total, int s, int a, int b, int c, int d, int e) {
    if (total == 0) {
      return [
        PieChartSectionData(
          color: Colors.grey.shade200,
          value: 100,
          title: '',
          radius: 16.0,
        ),
      ];
    }

    const double radius = 16.0;
    const double activeRadius = 22.0;

    return [
      PieChartSectionData(
        color: AdminColors.gradeS,
        value: s.toDouble(),
        title: s > 0 ? '$s' : '',
        radius: touchedIndex == 0 ? activeRadius : radius,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: AdminColors.gradeA,
        value: a.toDouble(),
        title: a > 0 ? '$a' : '',
        radius: touchedIndex == 1 ? activeRadius : radius,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: AdminColors.gradeB,
        value: b.toDouble(),
        title: b > 0 ? '$b' : '',
        radius: touchedIndex == 2 ? activeRadius : radius,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: AdminColors.gradeC,
        value: c.toDouble(),
        title: c > 0 ? '$c' : '',
        radius: touchedIndex == 3 ? activeRadius : radius,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: AdminColors.gradeD,
        value: d.toDouble(),
        title: d > 0 ? '$d' : '',
        radius: touchedIndex == 4 ? activeRadius : radius,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: AdminColors.gradeE,
        value: e.toDouble(),
        title: e > 0 ? '$e' : '',
        radius: touchedIndex == 5 ? activeRadius : radius,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ];
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.color,
    required this.text,
    required this.isSquare,
  });
  final Color color;
  final String text;
  final bool isSquare;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AdminColors.textSecondary,
                fontSize: 10.5,
              ),
        )
      ],
    );
  }
}
