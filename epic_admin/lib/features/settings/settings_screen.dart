import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epic_admin/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _gameTabController;

  // Global Controllers
  late TextEditingController _heartsCtrl;
  late TextEditingController _recoveryCtrl;
  late TextEditingController _durationCtrl;

  // Version Control Controllers
  late TextEditingController _latestVerCtrl;
  late TextEditingController _minReqVerCtrl;
  late TextEditingController _updateUrlCtrl;
  late TextEditingController _releaseNotesCtrl;
  bool _forceUpdate = false;

  // Game config state
  final Map<String, Map<int, Map<String, dynamic>>> _gameConfigs = {
    'Batik': {
      1: {'multiplier': '1.0', 'minGrade': 'C'},
      2: {'multiplier': '1.2', 'minGrade': 'B'},
      3: {'multiplier': '1.5', 'minGrade': 'B'},
      4: {'multiplier': '2.0', 'minGrade': 'A'},
    },
    'Keris': {
      1: {'multiplier': '1.0', 'minGrade': 'C'},
      2: {'multiplier': '1.2', 'minGrade': 'B'},
      3: {'multiplier': '1.5', 'minGrade': 'B'},
      4: {'multiplier': '2.0', 'minGrade': 'A'},
    },
    'Anyaman': {
      1: {'multiplier': '1.0', 'minGrade': 'C'},
      2: {'multiplier': '1.2', 'minGrade': 'B'},
      3: {'multiplier': '1.5', 'minGrade': 'B'},
      4: {'multiplier': '2.0', 'minGrade': 'A'},
    },
  };

  // Controllers for multipliers to prevent cursor reset bug
  final Map<String, Map<int, TextEditingController>> _multiplierControllers = {};

  bool _isSaving = false;
  bool _isLoading = true;
  String _latencyStr = '-';
  bool _isFirebaseConnected = false;

  @override
  void initState() {
    super.initState();
    _gameTabController = TabController(length: 3, vsync: this);

    _heartsCtrl = TextEditingController(text: '5');
    _recoveryCtrl = TextEditingController(text: '15');
    _durationCtrl = TextEditingController(text: '60');

    _latestVerCtrl = TextEditingController(text: '1.0.0');
    _minReqVerCtrl = TextEditingController(text: '1.0.0');
    _updateUrlCtrl = TextEditingController(text: 'https://github.com/davidalvians/epic-game/releases/latest/download/epic.apk');
    _releaseNotesCtrl = TextEditingController(text: 'Pembaruan fitur terbaru dan peningkatan performa.');

    _gameConfigs.forEach((game, levels) {
      _multiplierControllers[game] = {};
      levels.forEach((level, config) {
        _multiplierControllers[game]![level] = TextEditingController(text: config['multiplier']);
      });
    });

    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('system_settings')
          .get(const GetOptions(source: Source.serverAndCache));

      stopwatch.stop();
      if (mounted) {
        setState(() {
          _latencyStr = '${stopwatch.elapsedMilliseconds} ms';
          _isFirebaseConnected = true;
        });
      }

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final maxNyawa = data['maxNyawa'] ?? 3;
        final timerDurationSec = data['timerDurationSec'] ?? 900;
        final recoveryTimeMin = data['recoveryTimeMin'] ?? 15;

        // Load level configs if they exist in firestore
        if (data['levelConfigs'] != null) {
          final dbLevelConfigs = data['levelConfigs'] as Map<dynamic, dynamic>;
          dbLevelConfigs.forEach((gameKey, levelData) {
            if (_gameConfigs.containsKey(gameKey)) {
              final levels = levelData as Map<dynamic, dynamic>;
              levels.forEach((lvlKey, config) {
                final lvl = int.tryParse(lvlKey.toString());
                if (lvl != null && _gameConfigs[gameKey]!.containsKey(lvl)) {
                  final val = config as Map<dynamic, dynamic>;
                  _gameConfigs[gameKey]![lvl] = {
                    'multiplier': (val['multiplier'] ?? _gameConfigs[gameKey]![lvl]!['multiplier']).toString(),
                    'minGrade': (val['minGrade'] ?? _gameConfigs[gameKey]![lvl]!['minGrade']).toString(),
                  };
                }
              });
            }
          });
        }

        if (mounted) {
          setState(() {
            _heartsCtrl.text = maxNyawa.toString();
            _recoveryCtrl.text = recoveryTimeMin.toString();
            _durationCtrl.text = (timerDurationSec / 60).round().toString();

            _latestVerCtrl.text = data['latestVersion']?.toString() ?? '1.0.0';
            _minReqVerCtrl.text = data['minRequiredVersion']?.toString() ?? '1.0.0';
            _updateUrlCtrl.text = data['downloadUrl']?.toString() ?? 'https://github.com/davidalvians/epic-game/releases/latest/download/epic.apk';
            _releaseNotesCtrl.text = data['releaseNotes']?.toString() ?? 'Pembaruan fitur terbaru dan peningkatan performa.';
            _forceUpdate = data['forceUpdate'] == true;

            // Re-populate controller texts
            _gameConfigs.forEach((game, levels) {
              levels.forEach((level, config) {
                _multiplierControllers[game]![level]?.text = config['multiplier'];
              });
            });
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      if (mounted) {
        setState(() {
          _isFirebaseConnected = false;
          _latencyStr = 'Error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _gameTabController.dispose();
    _heartsCtrl.dispose();
    _recoveryCtrl.dispose();
    _durationCtrl.dispose();
    _latestVerCtrl.dispose();
    _minReqVerCtrl.dispose();
    _updateUrlCtrl.dispose();
    _releaseNotesCtrl.dispose();
    _multiplierControllers.forEach((game, levels) {
      levels.forEach((level, ctrl) {
        ctrl.dispose();
      });
    });
    super.dispose();
  }

  void _saveAllSettings() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Simpan Perubahan?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Apakah Anda yakin ingin menyimpan seluruh konfigurasi sistem ini? Perubahan akan langsung berdampak pada seluruh pengguna aktif.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _performSave();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Ya, Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performSave() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final maxNyawa = int.tryParse(_heartsCtrl.text) ?? 3;
      final recoveryTimeMin = int.tryParse(_recoveryCtrl.text) ?? 15;
      final timerDurationSec = (int.tryParse(_durationCtrl.text) ?? 15) * 60;

      // Update _gameConfigs from controller values
      _gameConfigs.forEach((game, levels) {
        levels.forEach((level, config) {
          final ctrl = _multiplierControllers[game]![level]!;
          config['multiplier'] = ctrl.text;
        });
      });

      // Prepare level configs map to store
      final levelConfigsToSave = <String, Map<String, dynamic>>{};
      _gameConfigs.forEach((game, levels) {
        levelConfigsToSave[game] = {};
        levels.forEach((level, config) {
          levelConfigsToSave[game]![level.toString()] = {
            'multiplier': double.tryParse(config['multiplier']) ?? 1.0,
            'minGrade': config['minGrade'],
          };
        });
      });

      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('system_settings')
          .set({
        'maxNyawa': maxNyawa,
        'recoveryTimeMin': recoveryTimeMin,
        'timerDurationSec': timerDurationSec,
        'levelConfigs': levelConfigsToSave,
        'poinMultiplier': 1.0,
        'latestVersion': _latestVerCtrl.text.trim(),
        'minRequiredVersion': _minReqVerCtrl.text.trim(),
        'forceUpdate': _forceUpdate,
        'downloadUrl': _updateUrlCtrl.text.trim(),
        'releaseNotes': _releaseNotesCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Seluruh konfigurasi sistem berhasil disimpan!', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            width: 380,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan konfigurasi: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            width: 380,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AdminColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AdminColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'Memuat konfigurasi sistem...',
                      style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
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
                    'Konfigurasi Sistem',
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
                    'Kelola nilai batasan global pengguna dan parameter penilaian level game digital murid.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.normal),
                  ),
                ],
              ).animate().fadeIn(duration: 350.ms),
              SizedBox(height: isMobile ? 16 : 28),

              // Responsive Layout Grid
              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column (Global settings & version cards) - 360px
                        SizedBox(
                          width: 360,
                          child: Column(
                            children: [
                              _buildGlobalSettingsCard(isMobile),
                              const SizedBox(height: 24),
                              _buildVersionControlCard(isMobile),
                              const SizedBox(height: 24),
                              _buildStatusCard(isMobile),
                            ],
                          ),
                        ),
                        const SizedBox(width: 28),

                        // Right Column (Game configurations) - Expanded
                        Expanded(
                          child: Column(
                            children: [
                              _buildGameConfigurationsCard(isMobile),
                              const SizedBox(height: 28),
                              _buildSaveButton(),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildGlobalSettingsCard(isMobile),
                        const SizedBox(height: 20),
                        _buildVersionControlCard(isMobile),
                        const SizedBox(height: 20),
                        _buildGameConfigurationsCard(isMobile),
                        const SizedBox(height: 20),
                        _buildStatusCard(isMobile),
                        const SizedBox(height: 24),
                        _buildSaveButton(),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalSettingsCard(bool isMobile) {
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
              Icon(Icons.settings_suggest_rounded, color: Color(0xFF2563EB), size: 18),
              SizedBox(width: 8),
              Text(
                'BATASAN GLOBAL',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A), letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Nyawa Maksimal
          _buildSettingInput(
            label: 'Nyawa Maksimal',
            icon: Icons.favorite_rounded,
            iconColor: const Color(0xFFEF4444),
            controller: _heartsCtrl,
          ),
          const SizedBox(height: 16),

          // Waktu Pemulihan Nyawa
          _buildSettingInput(
            label: 'Pemulihan Nyawa (Menit)',
            icon: Icons.hourglass_top_rounded,
            iconColor: const Color(0xFFF59E0B),
            controller: _recoveryCtrl,
          ),
          const SizedBox(height: 16),

          // Durasi Maksimal Pengerjaan
          _buildSettingInput(
            label: 'Durasi Pengerjaan (Menit)',
            icon: Icons.timer_rounded,
            iconColor: const Color(0xFF10B981),
            controller: _durationCtrl,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _buildVersionControlCard(bool isMobile) {
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
              Icon(Icons.system_update_rounded, color: Color(0xFF8B5CF6), size: 18),
              SizedBox(width: 8),
              Text(
                'PEMBARUAN APLIKASI',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A), letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Versi Terbaru
          _buildSettingInput(
            label: 'Versi Terbaru (e.g. 1.0.0)',
            icon: Icons.rocket_launch_rounded,
            iconColor: const Color(0xFF8B5CF6),
            controller: _latestVerCtrl,
          ),
          const SizedBox(height: 14),

          // Versi Minimal Wajib
          _buildSettingInput(
            label: 'Versi Minimal Wajib',
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFF3B82F6),
            controller: _minReqVerCtrl,
          ),
          const SizedBox(height: 14),

          // Switch Force Update
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Wajibkan Update (Force)',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pengguna wajib update sebelum main',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Switch(
                  value: _forceUpdate,
                  activeThumbColor: const Color(0xFF8B5CF6),
                  onChanged: (val) {
                    setState(() {
                      _forceUpdate = val;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Catatan Rilis
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Catatan Rilis (Changelog)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _releaseNotesCtrl,
                maxLines: 3,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Tuliskan fitur baru...',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _buildStatusCard(bool isMobile) {
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
              Icon(Icons.dns_rounded, color: Color(0xFF64748B), size: 18),
              SizedBox(width: 8),
              Text(
                'INFO SISTEM & STATUS',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A), letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildStatusRow('Versi App', 'v1.0.0-admin', Colors.blue),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildStatusRow('Database Latency', _latencyStr, _isFirebaseConnected ? Colors.green : Colors.grey),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildStatusRow('Wilayah Server', 'Asia-Southeast', Colors.purple),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildStatusRow(
            'Koneksi Firebase',
            _isFirebaseConnected ? 'Terkoneksi' : 'Belum Terkoneksi',
            _isFirebaseConnected ? Colors.green : Colors.red,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 350.ms);
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildGameConfigurationsCard(bool isMobile) {
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
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.gamepad_rounded, color: Color(0xFF2563EB), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'KONFIGURASI GAME & LEVEL',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A), letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 38,
                  width: double.infinity,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _gameTabController,
                    isScrollable: false,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFF64748B),
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5),
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    splashFactory: NoSplash.splashFactory,
                    indicatorPadding: EdgeInsets.zero,
                    indicator: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    tabs: const [
                      Tab(text: 'BATIK'),
                      Tab(text: 'KERIS'),
                      Tab(text: 'ANYAMAN'),
                    ],
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.gamepad_rounded, color: Color(0xFF2563EB), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'KONFIGURASI GAME & LEVEL',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A), letterSpacing: 0.5),
                    ),
                  ],
                ),
                // Compact Pill Tab Bar Selector
                Container(
                  height: 38,
                  width: 270,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _gameTabController,
                    isScrollable: false,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFF64748B),
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5),
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    splashFactory: NoSplash.splashFactory,
                    indicatorPadding: EdgeInsets.zero,
                    indicator: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    tabs: const [
                      Tab(text: 'BATIK'),
                      Tab(text: 'KERIS'),
                      Tab(text: 'ANYAMAN'),
                    ],
                  ),
                ),
              ],
            ),
          SizedBox(height: isMobile ? 18 : 28),

          // Tab views wrapping level forms
          SizedBox(
            height: isMobile ? 480 : 380,
            child: _gameConfigs.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AdminColors.primary),
                        SizedBox(height: 16),
                        Text(
                          'Memuat konfigurasi game...',
                          style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _gameTabController,
                    children: [
                      _buildLevelsTabContent('Batik', const Color(0xFFF97316), isMobile),
                      _buildLevelsTabContent('Keris', const Color(0xFF8B5CF6), isMobile),
                      _buildLevelsTabContent('Anyaman', const Color(0xFF10B981), isMobile),
                    ],
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _buildLevelsTabContent(String gameName, Color dotColor, bool isMobile) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(4, (index) {
        final level = index + 1;
        final isLast = level == 4;
        return Column(
          children: [
            _buildLevelConfigRow(gameName, level, dotColor, isMobile),
            if (!isLast) Divider(height: isMobile ? 20 : 32, color: const Color(0xFFF1F5F9)),
          ],
        );
      }),
    );
  }

  Widget _buildLevelConfigRow(String game, int level, Color dotColor, bool isMobile) {
    final config = _gameConfigs[game]![level]!;
    final multiplierCtrl = _multiplierControllers[game]![level]!;

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
              ),
              const SizedBox(width: 8),
              Text(
                'Level $level',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: _buildInlineInput(
                  label: 'Multiplier',
                  controller: multiplierCtrl,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: _buildInlineDropdown(
                  label: 'Min Grade',
                  currentValue: config['minGrade'],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        config['minGrade'] = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Level Indicator
        Container(
          width: 110,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
              ),
              const SizedBox(width: 10),
              Text(
                'Level $level',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Multiplier Input
        Expanded(
          flex: 4,
          child: _buildInlineInput(
            label: 'Multiplier Skor',
            controller: multiplierCtrl,
          ),
        ),
        const SizedBox(width: 28),

        // Min Grade Dropdown
        Expanded(
          flex: 5,
          child: _buildInlineDropdown(
            label: 'Syarat Lulus (Grade Minimal)',
            currentValue: config['minGrade'],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  config['minGrade'] = val;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSettingInput({
    required String label,
    required IconData icon,
    required Color iconColor,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF64748B), letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 13.5),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInlineInput({required String label, required TextEditingController controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 12.5),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 9),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineDropdown({required String label, required String currentValue, required ValueChanged<String?> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 12.5),
              items: const [
                DropdownMenuItem(value: 'S', child: Text('Grade S')),
                DropdownMenuItem(value: 'A', child: Text('Grade A')),
                DropdownMenuItem(value: 'B', child: Text('Grade B')),
                DropdownMenuItem(value: 'C', child: Text('Grade C')),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveAllSettings,
        icon: _isSaving
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_rounded, size: 18),
        label: const Text('Simpan Seluruh Konfigurasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}
