import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class ActivityChart extends StatefulWidget {
  const ActivityChart({super.key});

  @override
  State<ActivityChart> createState() => _ActivityChartState();
}

class _ActivityChartState extends State<ActivityChart> {
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

  List<String> _last7DaysLabels() {
    const weekdayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    List<String> labels = [];
    DateTime now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      DateTime date = now.subtract(Duration(days: i));
      labels.add(weekdayNames[date.weekday - 1]);
    }
    return labels;
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime startOfToday = DateTime(now.year, now.month, now.day);
    final DateTime sevenDaysAgo = startOfToday.subtract(const Duration(days: 6));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'murid')
          .snapshots(),
      builder: (context, userSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('artworks').snapshots(),
          builder: (context, artworkSnapshot) {
            final List<int> userCounts = List.filled(7, 0);
            final List<int> artworkCounts = List.filled(7, 0);

            if (userSnapshot.hasData) {
              for (final doc in userSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final createdVal = data['createdAt'];
                if (createdVal is Timestamp) {
                  final createdDate = createdVal.toDate();
                  if (createdDate.isAfter(sevenDaysAgo)) {
                    final int dayDiff = createdDate.difference(sevenDaysAgo).inDays;
                    if (dayDiff >= 0 && dayDiff < 7) {
                      userCounts[dayDiff]++;
                    }
                  }
                }
              }
            }

            if (artworkSnapshot.hasData) {
              for (final doc in artworkSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final createdVal = data['createdAt'];
                if (createdVal is Timestamp) {
                  final createdDate = createdVal.toDate();
                  if (createdDate.isAfter(sevenDaysAgo)) {
                    final int dayDiff = createdDate.difference(sevenDaysAgo).inDays;
                    if (dayDiff >= 0 && dayDiff < 7) {
                      artworkCounts[dayDiff]++;
                    }
                  }
                }
              }
            }

            int maxCount = 10;
            for (int val in userCounts) {
              if (val > maxCount) maxCount = val;
            }
            for (int val in artworkCounts) {
              if (val > maxCount) maxCount = val;
            }
            final double limitY = maxCount * 1.25;

            final List<FlSpot> userSpots = [];
            final List<FlSpot> artworkSpots = [];
            for (int i = 0; i < 7; i++) {
              userSpots.add(FlSpot(i.toDouble(), _isLoaded ? userCounts[i].toDouble() : 0));
              artworkSpots.add(FlSpot(i.toDouble(), _isLoaded ? artworkCounts[i].toDouble() : 0));
            }

            final List<String> daysLabels = _last7DaysLabels();

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
                    'Grafik Aktivitas Pengguna (Mingguan)',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AdminColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Perbandingan pendaftaran siswa baru dan unggahan karya gambar',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AdminColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: AdminColors.outlineVariant.withOpacity(0.2),
                              strokeWidth: 1,
                              dashArray: [5, 5],
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final int valInt = value.toInt();
                                if (valInt >= 0 && valInt < daysLabels.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      daysLabels[valInt],
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AdminColors.textSecondary,
                                          ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: (limitY / 5).clamp(1, double.infinity),
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AdminColors.textSecondary),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: 6,
                        minY: 0,
                        maxY: limitY,
                        lineTouchData: LineTouchData(
                          handleBuiltInTouches: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (touchedSpot) => AdminColors.sidebar,
                            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                              return touchedBarSpots.map((barSpot) {
                                final prefix = barSpot.barIndex == 0 ? 'Siswa: ' : 'Karya: ';
                                return LineTooltipItem(
                                  '$prefix${barSpot.y.toInt()}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        lineBarsData: [
                          // Curve 1 (Navy - Siswa)
                          LineChartBarData(
                            spots: userSpots,
                            isCurved: true,
                            curveSmoothness: 0.35,
                            color: const Color(0xFF182235),
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF182235).withOpacity(0.08),
                                  const Color(0xFF182235).withOpacity(0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          // Curve 2 (Amber - Karya)
                          LineChartBarData(
                            spots: artworkSpots,
                            isCurved: true,
                            curveSmoothness: 0.35,
                            color: const Color(0xFFF59E0B),
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFF59E0B).withOpacity(0.08),
                                  const Color(0xFFF59E0B).withOpacity(0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeInOutCubic,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
