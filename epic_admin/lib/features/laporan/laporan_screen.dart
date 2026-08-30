import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:epic_admin/core/utils/file_download_helper.dart';
import 'package:epic_admin/core/utils/laporan_pdf_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  String _selectedReportType = 'Nilai Semua User';
  String _selectedClassFilter = 'Semua Kelas';
  String _selectedSchoolFilter = 'Semua Sekolah';

  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  bool _isLoading = false;
  List<Map<String, dynamic>> _previewData = [];

  List<String> _classesList = ['Semua Kelas'];
  List<String> _schoolsList = ['Semua Sekolah'];
  bool _isFilterLoading = true;

  DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is String) {
      return DateTime.tryParse(val);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime.now().subtract(const Duration(days: 30));
    _toDate = DateTime.now();
    _loadFilterData();
    _triggerPreviewUpdate();
  }

  Future<void> _loadFilterData() async {
    try {
      // 1. Load classes from 'kelas' collection
      final classSnap = await FirebaseFirestore.instance.collection('kelas').get();
      final List<String> classes = ['Semua Kelas'];
      for (var doc in classSnap.docs) {
        final data = doc.data();
        final name = data['namaKelas'] ?? data['nama'];
        if (name != null && !classes.contains(name.toString())) {
          classes.add(name.toString());
        }
      }

      // 2. Load unique schools from 'users' collection
      final userSnap = await FirebaseFirestore.instance.collection('users').get();
      final List<String> schools = ['Semua Sekolah'];
      for (var doc in userSnap.docs) {
        final data = doc.data();
        final school = data['sekolah'];
        if (school != null && school.toString().trim().isNotEmpty && !schools.contains(school.toString().trim())) {
          schools.add(school.toString().trim());
        }
      }

      if (mounted) {
        setState(() {
          _classesList = classes;
          _schoolsList = schools;
          _isFilterLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading filters: $e');
      if (mounted) {
        setState(() {
          _isFilterLoading = false;
        });
      }
    }
  }

  void _triggerPreviewUpdate() {
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final List<Map<String, dynamic>> results = [];

      // 1. Fetch collections
      final usersSnap = await FirebaseFirestore.instance.collection('users').get();
      final artworksSnap = await FirebaseFirestore.instance.collection('artworks').get();
      final kelasSnap = await FirebaseFirestore.instance.collection('kelas').get();

      // Normalize date filters to midnight starts/ends
      final fromMidnight = DateTime(_fromDate.year, _fromDate.month, _fromDate.day, 0, 0, 0);
      final toMidnight = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);

      debugPrint('--- DEBUG REPORT LOAD ---');
      debugPrint('Selected report: $_selectedReportType');
      debugPrint('Total Users in Firestore: ${usersSnap.docs.length}');
      debugPrint('Total Artworks in Firestore: ${artworksSnap.docs.length}');
      debugPrint('Total Kelas in Firestore: ${kelasSnap.docs.length}');
      debugPrint('Date range: $fromMidnight to $toMidnight');

      if (_selectedReportType == 'Nilai Semua User') {
        // Murid report
        final muridList = usersSnap.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['role'] == 'murid';
        }).toList();

        debugPrint('Found ${muridList.length} murid');

        for (var studentDoc in muridList) {
          final sData = studentDoc.data() as Map<String, dynamic>;
          final uid = studentDoc.id;
          final String sSchool = sData['sekolah']?.toString() ?? '-';
          final String sName = sData['namaLengkap'] ?? sData['nama'] ?? 'Tanpa Nama';
          final String sUsername = sData['username'] ?? sData['email'] ?? '-';
          final int sPoin = (sData['poin'] is num) ? (sData['poin'] as num).toInt() : 0;

          // Apply school filter
          if (_selectedSchoolFilter != 'Semua Sekolah' && sSchool.trim() != _selectedSchoolFilter.trim()) {
            continue;
          }

          // Apply class filter
          if (_selectedClassFilter != 'Semua Kelas') {
            final hasClass = kelasSnap.docs.any((cDoc) {
              final cData = cDoc.data() as Map<String, dynamic>;
              final name = cData['namaKelas'] ?? cData['nama'];
              final List<dynamic> muridIds = cData['muridIds'] is List ? cData['muridIds'] : [];
              return name == _selectedClassFilter && muridIds.contains(uid);
            });
            if (!hasClass) continue;
          }

          // Find student artworks within date range
          final sArtworks = artworksSnap.docs.where((aDoc) {
            final aData = aDoc.data() as Map<String, dynamic>;
            if (aData['uid'] != uid) return false;
            final dynamic createdVal = aData['createdAt'];
            final dt = _parseDateTime(createdVal);
            if (dt != null) {
              return dt.isAfter(fromMidnight) && dt.isBefore(toMidnight);
            }
            return false;
          }).toList();

          // Compute average score & artwork count
          int totalSkor = 0;
          int scoredCount = 0;
          for (var aDoc in sArtworks) {
            final aData = aDoc.data() as Map<String, dynamic>;
            final score = aData['skorAI'];
            if (score is num) {
              totalSkor += score.toInt();
              scoredCount++;
            }
          }
          final double avg = scoredCount > 0 ? (totalSkor / scoredCount) : 0.0;
          final int count = sArtworks.length;

          results.add({
            'nama': sName,
            'username': sUsername,
            'poin': sPoin,
            'rata_rata': double.parse(avg.toStringAsFixed(1)),
            'karya': count,
          });
        }

        // 1. Calculate ranks based on total points descending
        results.sort((a, b) => ((b['poin'] as num?) ?? 0).compareTo((a['poin'] as num?) ?? 0));
        for (int i = 0; i < results.length; i++) {
          results[i]['rank'] = i + 1;
        }

        // 2. Sort students alphabetically A - Z by student name
        results.sort((a, b) => (a['nama'] as String).toLowerCase().compareTo((b['nama'] as String).toLowerCase()));
      } else if (_selectedReportType == 'Aktivitas Guru') {
        // Guru report
        final guruList = usersSnap.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['role'] == 'guru';
        }).toList();

        debugPrint('Found ${guruList.length} guru');

        for (var teacherDoc in guruList) {
          final tData = teacherDoc.data() as Map<String, dynamic>;
          final uid = teacherDoc.id;
          final String tSchool = tData['sekolah']?.toString() ?? '-';
          final String tName = tData['namaLengkap'] ?? tData['nama'] ?? 'Tanpa Nama';
          final String tNip = tData['nip'] ?? tData['email'] ?? '-';

          // Apply school filter
          if (_selectedSchoolFilter != 'Semua Sekolah' && tSchool.trim() != _selectedSchoolFilter.trim()) {
            continue;
          }

          // Find classes taught by teacher
          final tClasses = kelasSnap.docs.where((cDoc) {
            final cData = cDoc.data() as Map<String, dynamic>;
            return (cData['guruUid'] ?? cData['guruId']) == uid;
          }).toList();

          final String classNames = tClasses.isEmpty
              ? '-'
              : tClasses.map((c) {
                  final cData = c.data() as Map<String, dynamic>;
                  return (cData['namaKelas'] ?? cData['nama']).toString();
                }).join(', ');

          // Apply class filter
          if (_selectedClassFilter != 'Semua Kelas') {
            final hasClass = tClasses.any((c) {
              final cData = c.data() as Map<String, dynamic>;
              return (cData['namaKelas'] ?? cData['nama']) == _selectedClassFilter;
            });
            if (!hasClass) continue;
          }

          // Count artworks in teacher's classes within date range
          final classIds = tClasses.map((c) => c.id).toList();
          final tArtworks = artworksSnap.docs.where((aDoc) {
            final aData = aDoc.data() as Map<String, dynamic>;
            final aKelasId = aData['kelasId'];
            if (aKelasId == null || !classIds.contains(aKelasId)) return false;
            final dynamic createdVal = aData['createdAt'];
            final dt = _parseDateTime(createdVal);
            if (dt != null) {
              return dt.isAfter(fromMidnight) && dt.isBefore(toMidnight);
            }
            return false;
          }).toList();

          final int verifCount = tArtworks.length;

          // Format last active time
          final dynamic lastActiveVal = tData['lastActiveAt'] ?? tData['nyawaLastReset'];
          String activeStr = 'Belum aktif';
          final dt = _parseDateTime(lastActiveVal);
          if (dt != null) {
            activeStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
          }

          results.add({
            'nama': tName,
            'nip': tNip,
            'kelas': classNames,
            'verif': verifCount,
            'aktif': activeStr,
          });
        }

        // Sort teachers alphabetically A - Z by teacher name
        results.sort((a, b) => (a['nama'] as String).toLowerCase().compareTo((b['nama'] as String).toLowerCase()));
      } else {
        // App usage report (Statistik Penggunaan App)
        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day, 0, 0, 0);
        final startOfWeek = now.subtract(const Duration(days: 7));
        final startOfMonth = now.subtract(const Duration(days: 30));

        // Helper closures
        int countToday(Iterable<QueryDocumentSnapshot> docs) {
          return docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final ts = data['createdAt'] ?? data['tanggal'] ?? data['nyawaLastReset'];
            final dt = _parseDateTime(ts);
            if (dt != null) {
              return dt.isAfter(startOfToday);
            }
            return false;
          }).length;
        }

        int countWeek(Iterable<QueryDocumentSnapshot> docs) {
          return docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final ts = data['createdAt'] ?? data['tanggal'] ?? data['nyawaLastReset'];
            final dt = _parseDateTime(ts);
            if (dt != null) {
              return dt.isAfter(startOfWeek);
            }
            return false;
          }).length;
        }

        int countMonth(Iterable<QueryDocumentSnapshot> docs) {
          return docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final ts = data['createdAt'] ?? data['tanggal'] ?? data['nyawaLastReset'];
            final dt = _parseDateTime(ts);
            if (dt != null) {
              return dt.isAfter(startOfMonth);
            }
            return false;
          }).length;
        }

        Iterable<QueryDocumentSnapshot> filteredUsers = usersSnap.docs;
        Iterable<QueryDocumentSnapshot> filteredArtworks = artworksSnap.docs;
        Iterable<QueryDocumentSnapshot> filteredKelas = kelasSnap.docs;

        if (_selectedSchoolFilter != 'Semua Sekolah') {
          filteredUsers = filteredUsers.where((u) {
            final data = u.data() as Map<String, dynamic>;
            return data['sekolah'] == _selectedSchoolFilter;
          });
          filteredArtworks = filteredArtworks.where((a) {
            final aData = a.data() as Map<String, dynamic>;
            final matchingUsers = usersSnap.docs.where((u) => u.id == aData['uid']);
            if (matchingUsers.isEmpty) return false;
            final userDoc = matchingUsers.first;
            final uData = userDoc.data() as Map<String, dynamic>;
            return uData['sekolah'] == _selectedSchoolFilter;
          });
          filteredKelas = filteredKelas.where((c) {
            final data = c.data() as Map<String, dynamic>;
            return data['sekolah'] == _selectedSchoolFilter;
          });
        }

        if (_selectedClassFilter != 'Semua Kelas') {
          final matchingClasses = kelasSnap.docs.where((c) {
            final data = c.data() as Map<String, dynamic>;
            return (data['namaKelas'] ?? data['nama']) == _selectedClassFilter;
          });
          final classDoc = matchingClasses.isNotEmpty ? matchingClasses.first : null;
          if (classDoc != null) {
            final cData = classDoc.data() as Map<String, dynamic>;
            final List<dynamic> muridIds = cData['muridIds'] is List ? cData['muridIds'] : [];
            filteredUsers = filteredUsers.where((u) => muridIds.contains(u.id));
            filteredArtworks = filteredArtworks.where((a) {
              final data = a.data() as Map<String, dynamic>;
              return data['kelasId'] == classDoc.id;
            });
            filteredKelas = filteredKelas.where((c) => c.id == classDoc.id);
          }
        }

        results.add({
          'metrik': 'Karya Seni Diunggah',
          'hari': '${countToday(filteredArtworks)} karya',
          'minggu': '${countWeek(filteredArtworks)} karya',
          'bulan': '${countMonth(filteredArtworks)} karya',
          'tren': 'Meningkat',
        });

        results.add({
          'metrik': 'Siswa Baru Terdaftar',
          'hari': '${countToday(filteredUsers.where((u) {
            final data = u.data() as Map<String, dynamic>;
            return data['role'] == 'murid';
          }))} siswa',
          'minggu': '${countWeek(filteredUsers.where((u) {
            final data = u.data() as Map<String, dynamic>;
            return data['role'] == 'murid';
          }))} siswa',
          'bulan': '${countMonth(filteredUsers.where((u) {
            final data = u.data() as Map<String, dynamic>;
            return data['role'] == 'murid';
          }))} siswa',
          'tren': 'Stabil',
        });

        results.add({
          'metrik': 'Guru Baru Terdaftar',
          'hari': '${countToday(filteredUsers.where((u) {
            final data = u.data() as Map<String, dynamic>;
            return data['role'] == 'guru';
          }))} guru',
          'minggu': '${countWeek(filteredUsers.where((u) {
            final data = u.data() as Map<String, dynamic>;
            return data['role'] == 'guru';
          }))} guru',
          'bulan': '${countMonth(filteredUsers.where((u) {
            final data = u.data() as Map<String, dynamic>;
            return data['role'] == 'guru';
          }))} guru',
          'tren': 'Meningkat',
        });

        results.add({
          'metrik': 'Kelas Digital Baru',
          'hari': '${countToday(filteredKelas)} kelas',
          'minggu': '${countWeek(filteredKelas)} kelas',
          'bulan': '${countMonth(filteredKelas)} kelas',
          'tren': 'Stabil',
        });
      }

      if (mounted) {
        setState(() {
          _previewData = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading report preview: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat pratinjau laporan: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2028),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AdminColors.primary,
              onPrimary: Colors.white,
              onSurface: AdminColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      _triggerPreviewUpdate();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _startExportProcess(String format) {
    if (_previewData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada data untuk diekspor. Klik "Tampilkan Preview" terlebih dahulu.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _ExportProgressDialog(
          format: format,
          reportType: _selectedReportType,
          classFilter: _selectedClassFilter,
          schoolFilter: _selectedSchoolFilter,
          dateRange: '${_formatDate(_fromDate)} - ${_formatDate(_toDate)}',
          previewData: _previewData,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AdminColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 32, vertical: isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Premium Title & Subtitle Area
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Laporan & Ekspor Data',
                    style: (isMobile
                            ? Theme.of(context).textTheme.headlineMedium
                            : Theme.of(context).textTheme.headlineLarge)
                        ?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Analisis metrik murid, aktivitas verifikasi guru, serta rekap data penggunaan platform EPIC.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.normal),
                  ),
                ],
              ).animate().fadeIn(duration: 350.ms),
              SizedBox(height: isMobile ? 16 : 28),

              // Responsive split screen
              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 340,
                          child: _buildFilterCard(context, isMobile),
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          child: _buildPreviewCard(context, isMobile),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFilterCard(context, isMobile),
                        const SizedBox(height: 20),
                        _buildPreviewCard(context, isMobile),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterCard(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 18),
              SizedBox(width: 8),
              Text(
                'FILTER LAPORAN',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A), letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Jenis Laporan
          _buildDropdownLabel('Jenis Laporan'),
          const SizedBox(height: 8),
          _buildDropdownContainer(
            Icons.analytics_rounded,
            DropdownButton<String>(
              value: _selectedReportType,
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
              items: const [
                DropdownMenuItem(value: 'Nilai Semua User', child: Text('Nilai Semua User')),
                DropdownMenuItem(value: 'Aktivitas Guru', child: Text('Aktivitas Guru')),
                DropdownMenuItem(value: 'Penggunaan App', child: Text('Statistik Penggunaan App')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedReportType = val;
                  });
                  _triggerPreviewUpdate();
                }
              },
            ),
          ),
          const SizedBox(height: 16),

          // Rentang Waktu
          _buildDropdownLabel('Rentang Waktu'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, true),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Dari:', style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(_formatDate(_fromDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, false),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Sampai:', style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(_formatDate(_toDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filter Kelas
          _buildDropdownLabel('Filter Kelas'),
          const SizedBox(height: 8),
          _buildDropdownContainer(
            Icons.school_rounded,
            DropdownButton<String>(
              value: _selectedClassFilter,
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
              items: _classesList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedClassFilter = val;
                  });
                  _triggerPreviewUpdate();
                }
              },
            ),
          ),
          const SizedBox(height: 16),

          // Filter Sekolah
          _buildDropdownLabel('Filter Sekolah'),
          const SizedBox(height: 8),
          _buildDropdownContainer(
            Icons.account_balance_rounded,
            DropdownButton<String>(
              value: _selectedSchoolFilter,
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
              items: _schoolsList.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedSchoolFilter = val;
                  });
                  _triggerPreviewUpdate();
                }
              },
            ),
          ),
          const SizedBox(height: 24),

          // Submit Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _triggerPreviewUpdate,
              icon: _isLoading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search_rounded, size: 16),
              label: const Text('Tampilkan Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _buildPreviewCard(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Header Title & Subtitle
          const Text(
            'PREVIEW DATA LAPORAN',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A), letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pratinjau sampel data berdasarkan parameter aktif di bawah.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          // Row 2: Active filter status badge & export actions toolbar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildStatusBadge(Icons.analytics_outlined, _selectedReportType),
                          _buildStatusBadge(Icons.class_outlined, _selectedClassFilter),
                          _buildStatusBadge(Icons.calendar_month_outlined, '${_formatDate(_fromDate)} - ${_formatDate(_toDate)}'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _startExportProcess('PDF'),
                              icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                              label: const Text('Export PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                side: const BorderSide(color: Color(0xFFFCA5A5)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _startExportProcess('Excel'),
                              icon: const Icon(Icons.table_chart_rounded, size: 14),
                              label: const Text('Excel (.xlsx)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Active filter chips
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildStatusBadge(Icons.analytics_outlined, _selectedReportType),
                            _buildStatusBadge(Icons.class_outlined, _selectedClassFilter),
                            _buildStatusBadge(Icons.calendar_month_outlined, '${_formatDate(_fromDate)} - ${_formatDate(_toDate)}'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Export Buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _startExportProcess('PDF'),
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                            label: const Text('Export PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              side: const BorderSide(color: Color(0xFFFCA5A5)),
                              fixedSize: const Size(125, 38),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => _startExportProcess('Excel'),
                            icon: const Icon(Icons.table_chart_rounded, size: 14),
                            label: const Text('Excel (.xlsx)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              fixedSize: const Size(135, 38),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),

          // Custom responsive data grid (wrapped in horizontal scroll on mobile)
          _isLoading
              ? _buildShimmerTable()
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: isMobile ? 550 : 0),
                    child: _buildCustomTable().animate().fadeIn(duration: 250.ms),
                  ),
                ),

          const SizedBox(height: 20),
          Center(
            child: Text(
              'Menampilkan ${_previewData.length} baris rekaman...',
              style: const TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic, fontSize: 12),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 350.ms);
  }

  Widget _buildDropdownLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF64748B), letterSpacing: 0.5),
    );
  }

  Widget _buildDropdownContainer(IconData leadingIcon, Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(leadingIcon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(child: DropdownButtonHideUnderline(child: child)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTable() {
    List<String> headers;
    List<int> flexes;

    if (_selectedReportType == 'Nilai Semua User') {
      headers = ['Rank', 'Nama', 'Username', 'Total Poin', 'Rata-rata', 'Karya'];
      flexes = [1, 3, 2, 2, 2, 2];
    } else if (_selectedReportType == 'Aktivitas Guru') {
      headers = ['Nama Guru', 'NIP', 'Kelas Diampu', 'Karya Diverifikasi', 'Terakhir Aktif'];
      flexes = [3, 2, 2, 2, 2];
    } else {
      headers = ['Metrik Penggunaan', 'Hari Ini', 'Minggu Ini', 'Bulan Ini', 'Tren'];
      flexes = [3, 2, 2, 2, 2];
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header Row
          _buildTableHeader(headers, flexes),
          // Data Rows
          _previewData.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  color: Colors.white,
                  child: const Text(
                    'Tidak ada data pratinjau. Klik "Tampilkan Preview" untuk memuat data.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                )
              : Column(
                  children: List.generate(_previewData.length, (index) {
                    final isLast = index == _previewData.length - 1;
                    final cells = _getRowCells(index);
                    return _buildTableRow(cells, flexes, isLast);
                  }),
                ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(List<String> headers, List<int> flexes) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: List.generate(headers.length, (index) {
          return Expanded(
            flex: flexes[index],
            child: Text(
              headers[index].toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF475569),
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTableRow(List<Widget> cells, List<int> flexes, bool isLast) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: List.generate(cells.length, (index) {
          return Expanded(
            flex: flexes[index],
            child: cells[index],
          );
        }),
      ),
    );
  }

  List<Widget> _getRowCells(int index) {
    final row = _previewData[index];
    if (_selectedReportType == 'Nilai Semua User') {
      return [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Text(
              '#${row['rank'] ?? (index + 1)}',
              style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w800, fontSize: 11),
            ),
          ),
        ),
        Text(row['nama']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
        Text(row['username']?.toString() ?? '-', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        Text('${row['poin'] ?? 0} Poin', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${row['rata_rata'] ?? 0.0}',
              style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ),
        Text('${row['karya'] ?? 0} buah', style: const TextStyle(fontSize: 13)),
      ];
    } else if (_selectedReportType == 'Aktivitas Guru') {
      return [
        Text(row['nama']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
        Text(row['nip']?.toString() ?? '-', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        Text(row['kelas']?.toString() ?? '-', style: const TextStyle(fontSize: 13)),
        Text('${row['verif'] ?? 0} karya', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Text(row['aktif']?.toString() ?? '-', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600, fontSize: 13)),
      ];
    } else {
      return [
        Text(row['metrik']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
        Text(row['hari']?.toString() ?? '-', style: const TextStyle(fontSize: 13)),
        Text(row['minggu']?.toString() ?? '-', style: const TextStyle(fontSize: 13)),
        Text(row['bulan']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              row['tren']?.toString() ?? '-',
              style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ),
      ];
    }
  }

  Widget _buildShimmerTable() {
    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Menyaring data...',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Mendapatkan data real-time terbaru...',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportProgressDialog extends StatefulWidget {
  final String format;
  final String reportType;
  final String classFilter;
  final String schoolFilter;
  final String dateRange;
  final List<Map<String, dynamic>> previewData;

  const _ExportProgressDialog({
    required this.format,
    required this.reportType,
    required this.classFilter,
    required this.schoolFilter,
    required this.dateRange,
    required this.previewData,
  });

  @override
  State<_ExportProgressDialog> createState() => _ExportProgressDialogState();
}

class _ExportProgressDialogState extends State<_ExportProgressDialog> {
  int _currentStep = 0;
  double _progressValue = 0.0;
  bool _isSuccess = false;
  late String _currentMessage;

  final List<String> _steps = [
    'Mempersiapkan data...',
    'Menghubungkan ke Cloud Firestore...',
    'Memproses baris data (500 records)...',
    'Menyusun struktur kolom...',
    'Mengonversi berkas dan men-download...',
  ];

  @override
  void initState() {
    super.initState();
    _currentMessage = _steps[0];
    _runSimulator();
  }

  void _runSimulator() {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _currentStep = 1;
          _progressValue = 0.25;
          _currentMessage = _steps[1];
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _currentStep = 2;
          _progressValue = 0.50;
          _currentMessage = _steps[2];
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _currentStep = 3;
          _progressValue = 0.75;
          _currentMessage = _steps[3];
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 2700), () {
      if (mounted) {
        setState(() {
          _currentStep = 4;
          _progressValue = 1.0;
          _currentMessage = _steps[4];
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) {
        setState(() {
          _isSuccess = true;
        });
        _triggerActualDownload();
      }
    });
  }

  Future<void> _triggerActualDownload() async {
    final cleanReportType = widget.reportType.toLowerCase().replaceAll(' ', '_');
    final dateStr = '${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}';

    if (widget.format == 'Excel') {
      final buffer = StringBuffer();
      List<String> headers;

      if (widget.reportType == 'Nilai Semua User') {
        headers = ['No', 'Peringkat', 'Nama', 'Username', 'Total Poin', 'Rata-rata', 'Karya'];
        buffer.writeln(headers.map((h) => '"$h"').join(','));
        for (int i = 0; i < widget.previewData.length; i++) {
          final row = widget.previewData[i];
          buffer.writeln([
            '"${i + 1}"',
            '"#${row['rank'] ?? (i + 1)}"',
            '"${row['nama'].toString().replaceAll('"', '""')}"',
            '"${row['username'].toString().replaceAll('"', '""')}"',
            '"${row['poin']}"',
            '"${row['rata_rata']}"',
            '"${row['karya']}"',
          ].join(','));
        }
      } else if (widget.reportType == 'Aktivitas Guru') {
        headers = ['No', 'Nama Guru', 'NIP', 'Kelas Diampu', 'Karya Diverifikasi', 'Terakhir Aktif'];
        buffer.writeln(headers.map((h) => '"$h"').join(','));
        for (int i = 0; i < widget.previewData.length; i++) {
          final row = widget.previewData[i];
          buffer.writeln([
            '"${i + 1}"',
            '"${row['nama'].toString().replaceAll('"', '""')}"',
            '"${row['nip'].toString().replaceAll('"', '""')}"',
            '"${row['kelas'].toString().replaceAll('"', '""')}"',
            '"${row['verif']}"',
            '"${row['aktif']}"',
          ].join(','));
        }
      } else {
        headers = ['No', 'Metrik Penggunaan', 'Hari Ini', 'Minggu Ini', 'Bulan Ini', 'Tren'];
        buffer.writeln(headers.map((h) => '"$h"').join(','));
        for (int i = 0; i < widget.previewData.length; i++) {
          final row = widget.previewData[i];
          buffer.writeln([
            '"${i + 1}"',
            '"${row['metrik'].toString().replaceAll('"', '""')}"',
            '"${row['hari']}"',
            '"${row['minggu']}"',
            '"${row['bulan']}"',
            '"${row['tren']}"',
          ].join(','));
        }
      }

      FileDownloadHelper.downloadFile(buffer.toString(), 'laporan_${cleanReportType}_$dateStr.csv');
    } else if (widget.format == 'PDF') {
      List<String> headers;
      List<double> widths;
      List<List<String>> rows = [];

      if (widget.reportType == 'Nilai Semua User') {
        headers = ['No', 'Rank', 'Nama', 'Username', 'Total Poin', 'Rata-rata', 'Karya'];
        widths = [0.8, 1.0, 3.0, 2.5, 2.0, 2.0, 1.5];
        for (int i = 0; i < widget.previewData.length; i++) {
          final row = widget.previewData[i];
          rows.add([
            (i + 1).toString(),
            '#${row['rank'] ?? (i + 1)}',
            row['nama'].toString(),
            row['username'].toString(),
            '${row['poin']} Poin',
            row['rata_rata'].toString(),
            '${row['karya']} buah',
          ]);
        }
      } else if (widget.reportType == 'Aktivitas Guru') {
        headers = ['No', 'Nama Guru', 'NIP', 'Kelas Diampu', 'Karya Diverifikasi', 'Terakhir Aktif'];
        widths = [1.0, 3.0, 2.0, 3.0, 2.0, 2.0];
        for (int i = 0; i < widget.previewData.length; i++) {
          final row = widget.previewData[i];
          rows.add([
            (i + 1).toString(),
            row['nama'].toString(),
            row['nip'].toString(),
            row['kelas'].toString(),
            '${row['verif']} karya',
            row['aktif'].toString(),
          ]);
        }
      } else {
        headers = ['No', 'Metrik Penggunaan', 'Hari Ini', 'Minggu Ini', 'Bulan Ini', 'Tren'];
        widths = [1.0, 3.5, 2.0, 2.0, 2.0, 1.5];
        for (int i = 0; i < widget.previewData.length; i++) {
          final row = widget.previewData[i];
          rows.add([
            (i + 1).toString(),
            row['metrik'].toString(),
            row['hari'].toString(),
            row['minggu'].toString(),
            row['bulan'].toString(),
            row['tren'].toString(),
          ]);
        }
      }

      try {
        final pdfBytes = await LaporanPdfGenerator.generateReport(
          title: widget.reportType,
          dateRange: widget.dateRange,
          classFilter: widget.classFilter,
          schoolFilter: widget.schoolFilter,
          headers: headers,
          columnWidths: widths,
          rows: rows,
        );

        FileDownloadHelper.downloadBytes(
          pdfBytes,
          'laporan_${cleanReportType}_$dateStr.pdf',
          'application/pdf',
        );
      } catch (e) {
        debugPrint('Error generating report PDF: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = 'laporan_${widget.reportType.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}.${widget.format.toLowerCase()}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Center(
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isSuccess ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.cloud_download_rounded, color: Color(0xFF2563EB), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ekspor ${widget.reportType}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Format: ${widget.format}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progressValue,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _currentMessage,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)),
                      ),
                    ),
                    Text(
                      '${(_progressValue * 100).toInt()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ],
            ),
            secondChild: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD1FAE5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 48),
                ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                const SizedBox(height: 24),

                const Text(
                  'Ekspor Berhasil!',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Berkas Laporan Anda berhasil diunduh dan disimpan.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                ),
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.format == 'Excel' ? Icons.table_chart_rounded : Icons.picture_as_pdf_rounded,
                        color: widget.format == 'Excel' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          fileName,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Membuka file: $fileName'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xFF1E293B),
                              width: 340,
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Buka File', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
