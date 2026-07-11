import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:epic_app/core/constants/app_colors.dart';
import 'package:epic_app/core/constants/app_fonts.dart';
import 'package:epic_app/core/utils/epic_snackbar.dart';
import 'package:epic_app/core/routes/app_routes.dart';
import 'package:epic_app/shared/controllers/session_controller.dart';

class KeamananAkunScreen extends StatefulWidget {
  const KeamananAkunScreen({super.key});

  @override
  State<KeamananAkunScreen> createState() => _KeamananAkunScreenState();
}

class _KeamananAkunScreenState extends State<KeamananAkunScreen> {
  String _currentDeviceId = '';
  final SessionController _sessionController = Get.find<SessionController>();

  @override
  void initState() {
    super.initState();
    _loadCurrentDeviceId();
  }

  Future<void> _loadCurrentDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentDeviceId = prefs.getString('epic_device_unique_id') ?? '';
    });
  }

  // Action: remote logout/kick device
  void _kickDevice(String id, String name) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Keluarkan Perangkat?', style: TextStyle(fontFamily: 'FredokaOne')),
        content: Text('Apakah Anda yakin ingin mengeluarkan perangkat "$name" dari jauh? Sesi login di perangkat tersebut akan langsung berakhir.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Batal', style: TextStyle(fontFamily: 'FredokaOne', color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _processKickDevice(id, name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Keluarkan', style: TextStyle(fontFamily: 'FredokaOne')),
          ),
        ],
      ),
    );
  }

  void _processKickDevice(String id, String name) async {
    // Show spinner
    Get.dialog(
      const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      barrierDismissible: false,
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final db = FirebaseFirestore.instance;
        final doc = await db.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          List<Map<String, dynamic>> devices = [];
          if (data['devices'] is List) {
            devices = List<Map<String, dynamic>>.from(
                (data['devices'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
          }
          devices.removeWhere((d) => d['id'] == id);

          await db.collection('users').doc(user.uid).update({
            'devices': devices,
          });
        }
      }
      Get.back(); // dismiss spinner
      EpicSnackbar.success(
        'Berhasil Dikeluarkan 📱',
        'Perangkat "$name" berhasil dikeluarkan dari akunmu.',
      );
    } catch (e) {
      Get.back(); // dismiss spinner
      EpicSnackbar.error('Gagal', 'Terjadi kesalahan saat mengeluarkan perangkat: $e');
    }
  }

  // Action: clear login history
  void _clearHistory() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Hapus Riwayat Login?', style: TextStyle(fontFamily: 'FredokaOne')),
        content: const Text('Tindakan ini akan menghapus semua riwayat aktivitas login akun Anda dari layar ini secara permanen.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Batal', style: TextStyle(fontFamily: 'FredokaOne', color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                    'loginHistory': <Map<String, dynamic>>[],
                  });
                  EpicSnackbar.success(
                    'Riwayat Dihapus 🗑️',
                    'Semua log riwayat login akun Anda berhasil dibersihkan.',
                  );
                }
              } catch (e) {
                EpicSnackbar.error('Gagal', 'Terjadi kesalahan saat menghapus riwayat: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Hapus', style: TextStyle(fontFamily: 'FredokaOne')),
          ),
        ],
      ),
    );
  }

  // --- Step-by-Step Account Deletion Flow ---

  // Step 1: Confirmatory Dialog
  void _showDeleteAccountDialogStep1() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '⚠️ Hapus Akun EPIC?',
          style: TextStyle(fontFamily: 'FredokaOne', color: Color(0xFFEF4444)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tindakan ini sangat sensitif dan tidak dapat dibatalkan. Apakah Anda yakin ingin menghapus akun guru Anda?',
              style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Yang terhapus permanen:', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12, color: Color(0xFFEF4444))),
            const SizedBox(height: 6),
            _buildBullet('❌ Profil guru Anda'),
            _buildBullet('❌ Semua kelas yang Anda miliki'),
            _buildBullet('❌ Hubungan/data murid di kelas Anda'),
            const SizedBox(height: 12),
            const Text('Yang TIDAK terhapus:', style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12, color: Color(0xFF10B981))),
            const SizedBox(height: 6),
            _buildBullet('✅ Akun & profil murid tetap ada'),
            _buildBullet('✅ Karya gambaran & nilai murid tetap tersimpan'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Batal', style: TextStyle(fontFamily: 'FredokaOne', color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _showDeleteAccountDialogStep2();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Lanjutkan', style: TextStyle(fontFamily: 'FredokaOne')),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4),
      child: Text(
        text,
        style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  // Step 2: "HAPUS" confirmation text input
  void _showDeleteAccountDialogStep2() {
    final textCtrl = TextEditingController();
    final RxBool isValid = false.obs;

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Konfirmasi Penghapusan', style: TextStyle(fontFamily: 'FredokaOne')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Silakan ketik kata "HAPUS" di bawah ini untuk mengonfirmasi bahwa Anda memahami konsekuensi dari tindakan ini.',
              style: TextStyle(fontFamily: 'Nunito'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textCtrl,
              autofocus: true,
              onChanged: (val) {
                isValid.value = val.trim() == 'HAPUS';
              },
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Ketik HAPUS',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Batal', style: TextStyle(fontFamily: 'FredokaOne', color: Colors.grey.shade600)),
          ),
          Obx(() => ElevatedButton(
                onPressed: isValid.value
                    ? () {
                        Get.back();
                        _showDeleteAccountDialogStep3();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Verifikasi', style: TextStyle(fontFamily: 'FredokaOne')),
              )),
        ],
      ),
    );
  }

  // Step 3: Google Login ulang (verifikasi)
  void _showDeleteAccountDialogStep3() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Login Google Ulang', style: TextStyle(fontFamily: 'FredokaOne')),
        content: const Text(
          'Demi keamanan akun Anda, harap lakukan verifikasi login Google ulang untuk menyelesaikan proses penghapusan permanen.',
          style: TextStyle(fontFamily: 'Nunito'),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Batal', style: TextStyle(fontFamily: 'FredokaOne', color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Get.back();
              _executePurgeAndDeletion();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.login_rounded, size: 16),
            label: const Text('Login Google', style: TextStyle(fontFamily: 'FredokaOne')),
          ),
        ],
      ),
    );
  }

  // Backend operation: clear firestore & firebase auth user
  Future<void> _executePurgeAndDeletion() async {
    try {
      // 1. Google Re-auth
      Get.dialog(
        const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        barrierDismissible: false,
      );

      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut(); // Force account selector
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        Get.back(); // Dismiss spinner
        EpicSnackbar.error('Penghapusan Dibatalkan', 'Verifikasi masuk Google dibatalkan.');
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userAuth = FirebaseAuth.instance.currentUser;
      if (userAuth == null) {
        Get.back();
        throw Exception('Sesi autentikasi tidak ditemukan.');
      }

      // Reauthenticate
      await userAuth.reauthenticateWithCredential(credential);

      // 2. Perform Firestore Purging
      final String guruUid = userAuth.uid;
      final FirebaseFirestore db = FirebaseFirestore.instance;

      // Query classes owned by this guru
      final query = await db
          .collection('kelas')
          .where('guruUid', isEqualTo: guruUid)
          .get();

      // Clean up class references from enrolled students
      for (final doc in query.docs) {
        final List<dynamic> muridIds = doc.data()['muridIds'] ?? [];
        final batch = db.batch();
        for (final muridUid in muridIds) {
          if (muridUid is String) {
            final userRef = db.collection('users').doc(muridUid);
            batch.update(userRef, {
              'kelasIds': FieldValue.arrayRemove([doc.id]),
            });
          }
        }
        await batch.commit();
      }

      // Delete all owned classes
      final batchDeleteKelas = db.batch();
      for (final doc in query.docs) {
        batchDeleteKelas.delete(doc.reference);
      }
      await batchDeleteKelas.commit();

      // Get user document to delete reserved username
      final userDoc = await db.collection('users').doc(guruUid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final username = userDoc.data()!['username']?.toString() ?? '';
        if (username.isNotEmpty) {
          await db.collection('usernames').doc(username.toLowerCase()).delete();
        }
      }

      // Delete the guru's user profile document
      await db.collection('users').doc(guruUid).delete();

      // Delete the Firebase Auth user
      await userAuth.delete();

      Get.back(); // Dismiss spinner

      // Logout local GetX Session
      final session = Get.find<SessionController>();
      session.currentUser.value = null;
      
      Get.offAllNamed(Routes.auth);

      EpicSnackbar.success(
        'Akun Terhapus 🗑️',
        'Akun guru EPIC Anda dan seluruh kelas yang Anda miliki telah dihapus permanen.',
      );
    } catch (e) {
      Get.back(); // Dismiss spinner
      debugPrint('Error deleting account: $e');
      EpicSnackbar.error(
        'Gagal Menghapus Akun',
        e.toString().replaceAll('Exception:', '').trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Keamanan Akun',
          style: AppFonts.heading3(color: AppColors.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Section Header: SESI & PERANGKAT ---
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Text(
                '🔑  SESI & PERANGKAT',
                style: TextStyle(
                  fontFamily: 'FredokaOne',
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  letterSpacing: 1.1,
                ),
              ),
            ),

            // Card 1: Perangkat & Riwayat
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2D5C8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: [
                  // Item 1: Perangkat yang Login
                  _buildListOption(
                    icon: Icons.important_devices_rounded,
                    title: 'Perangkat yang Login',
                    subtitle: 'Lihat & kelola HP yang sedang menggunakan akunmu',
                    onTap: _showActiveDevicesModal,
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 64, endIndent: 20),
                  // Item 2: Riwayat Login
                  _buildListOption(
                    icon: Icons.history_rounded,
                    title: 'Riwayat Login',
                    subtitle: 'Kapan dan dari mana akunmu diakses',
                    onTap: _showLoginHistoryModal,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- Section Header: ZONA BERBAHAYA ---
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Text(
                '⚠️  TINDAKAN SENSITIF',
                style: TextStyle(
                  fontFamily: 'FredokaOne',
                  fontSize: 12,
                  color: Colors.red.shade700,
                  letterSpacing: 1.1,
                ),
              ),
            ),

            // Card 2: Hapus Akun
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFCA5A5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.01),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: _buildListOption(
                icon: Icons.delete_forever_rounded,
                iconColor: const Color(0xFFEF4444),
                iconBgColor: const Color(0xFFFEE2E2),
                title: 'Hapus Akun',
                titleColor: const Color(0xFFEF4444),
                subtitle: 'Hapus permanen semua data dan akun EPIC',
                onTap: _showDeleteAccountDialogStep1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListOption({
    required IconData icon,
    Color? iconColor,
    Color? iconBgColor,
    required String title,
    Color? titleColor,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor ?? const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'FredokaOne',
                      fontSize: 14,
                      color: titleColor ?? AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppFonts.caption(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 20),
          ],
        ),
      ),
    );
  }

  // --- Sub-Modals ---

  // Modal 1: Perangkat Aktif
  void _showActiveDevicesModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return Obx(() {
          final user = _sessionController.currentUser.value;
          final List<Map<String, dynamic>> devices = user?.devices ?? [];

          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '📱 Perangkat Aktif (${devices.length})',
                  style: const TextStyle(fontFamily: 'FredokaOne', fontSize: 16, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Berikut adalah perangkat yang sedang login dan mengakses akun EPIC-mu saat ini.',
                  style: AppFonts.caption(color: Colors.grey.shade500),
                ),
                const SizedBox(height: 16),
                if (devices.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32.0),
                      child: Text('Tidak ada perangkat aktif terdaftar', style: AppFonts.caption(color: Colors.grey)),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: devices.length,
                      itemBuilder: (context, idx) {
                        final dev = devices[idx];
                        final isCur = dev['id'] == _currentDeviceId;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isCur ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCur ? const Color(0xFFFFEDD5) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isCur ? Icons.phone_android_rounded : Icons.tablet_mac_rounded,
                                color: isCur ? AppColors.primary : Colors.grey,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          dev['nama'] ?? 'Perangkat',
                                          style: const TextStyle(
                                            fontFamily: 'FredokaOne',
                                            fontSize: 14,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (isCur) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Perangkat ini',
                                              style: TextStyle(
                                                fontFamily: 'FredokaOne',
                                                fontSize: 8,
                                                color: Color(0xFF16A34A),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Login: ${dev['tanggal']} • ${dev['lokasi']}',
                                      style: AppFonts.caption(color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isCur)
                                IconButton(
                                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                                  tooltip: 'Keluarkan Perangkat',
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _kickDevice(dev['id'], dev['nama']);
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        });
      },
    );
  }

  // Modal 2: Riwayat Login
  void _showLoginHistoryModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return Obx(() {
          final user = _sessionController.currentUser.value;
          final List<Map<String, dynamic>> loginHistory = user?.loginHistory ?? [];

          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '📋 Riwayat Aktivitas Login',
                      style: TextStyle(fontFamily: 'FredokaOne', fontSize: 16, color: AppColors.textPrimary),
                    ),
                    if (loginHistory.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _clearHistory();
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                        label: const Text(
                          'Hapus',
                          style: TextStyle(fontFamily: 'FredokaOne', fontSize: 12, color: Color(0xFFEF4444)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Daftar waktu dan metode akses masuk ke akun EPIC Anda.',
                  style: AppFonts.caption(color: Colors.grey.shade500),
                ),
                const SizedBox(height: 16),
                if (loginHistory.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32.0),
                      child: Column(
                        children: [
                          Icon(Icons.history_toggle_off_rounded, size: 40, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('Riwayat kosong', style: AppFonts.caption(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: loginHistory.length,
                      itemBuilder: (context, idx) {
                        final log = loginHistory[idx];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.login_rounded, color: AppColors.primary, size: 16),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${log['tanggal']} • ${log['jam']}',
                                      style: const TextStyle(
                                        fontFamily: 'FredokaOne',
                                        fontSize: 12,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'via ${log['metode']} (${log['device']})',
                                      style: AppFonts.caption(color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        });
      },
    );
  }
}
