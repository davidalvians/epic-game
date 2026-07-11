import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class PopularGamesChart extends StatefulWidget {
  const PopularGamesChart({super.key});

  @override
  State<PopularGamesChart> createState() => _PopularGamesChartState();
}

class _PopularGamesChartState extends State<PopularGamesChart> {
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    // Delay slightly to trigger the rising bars animation on load
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
        int batikCount = 0;
        int kerisCount = 0;
        int anyamanCount = 0;

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data != null) {
              final String kategori = (data['kategori'] ?? '').toString().toLowerCase();
              if (kategori == 'batik') {
                batikCount++;
              } else if (kategori == 'keris') {
                kerisCount++;
              } else if (kategori == 'anyaman') {
                anyamanCount++;
              }
            }
          }
        }

        final double maxCount = math.max(10, math.max(batikCount, math.max(kerisCount, anyamanCount)).toDouble());
        final double limitY = maxCount * 1.25;

        return Container(
          height: 420, // Equal height constraint for aligned middle row
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
                'Karya Seni Terpopuler',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AdminColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Berdasarkan jumlah karya seni siswa yang disubmit',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AdminColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: limitY,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) => AdminColors.onSurface,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${rod.toY.round()}',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            const style = TextStyle(
                              color: AdminColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            );
                            String text = '';
                            switch (value.toInt()) {
                              case 0:
                                text = 'Batik';
                                break;
                              case 1:
                                text = 'Keris';
                                break;
                              case 2:
                                text = 'Anyaman';
                                break;
                            }
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(text, style: style),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      BarChartGroupData(
                        x: 0,
                        barRods: [
                          BarChartRodData(
                            toY: _isLoaded ? batikCount.toDouble() : 0,
                            color: const Color(0xFF2563EB),
                            width: 14,
                            borderRadius: BorderRadius.circular(10),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: limitY,
                              color: const Color(0xFFE2E8F0).withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 1,
                        barRods: [
                          BarChartRodData(
                            toY: _isLoaded ? kerisCount.toDouble() : 0,
                            color: const Color(0xFF64748B),
                            width: 14,
                            borderRadius: BorderRadius.circular(10),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: limitY,
                              color: const Color(0xFFE2E8F0).withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 2,
                        barRods: [
                          BarChartRodData(
                            toY: _isLoaded ? anyamanCount.toDouble() : 0,
                            color: const Color(0xFFF59E0B),
                            width: 14,
                            borderRadius: BorderRadius.circular(10),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: limitY,
                              color: const Color(0xFFE2E8F0).withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutBack,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
