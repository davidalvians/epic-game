import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:epic_app/firebase_options.dart';
import 'package:epic_app/data/services/local_storage_service.dart';
import 'package:epic_app/data/services/storage_service.dart';
import 'package:epic_app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientasi ke portrait saja
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set style status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  bool firebaseSuccess = false;
  // Inisialisasi Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Aktifkan Offline Persistence dengan batas cache 100 MB
    // (menghindari storage device penuh jika data artwork terus bertambah)
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 100 * 1024 * 1024, // 100 MB
    );
    
    // Aktifkan Firebase App Check
    // - Debug mode: pakai DebugProvider (cetak debug token ke console)
    // - Production (release): pakai PlayIntegrity (Android) / DeviceCheck (iOS)
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.deviceCheck,
    );

    debugPrint('✅ Firebase + App Check berhasil diinisialisasi');
    firebaseSuccess = true;
  } catch (e) {
    debugPrint('⚠️ Firebase init error: $e');
  }

  if (!firebaseSuccess) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_off_rounded,
                      color: Colors.red,
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Koneksi Gagal',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Gagal menghubungkan ke server Firebase. Harap periksa koneksi internet Anda atau coba beberapa saat lagi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF475569),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        SystemNavigator.pop();
                      },
                      icon: const Icon(Icons.exit_to_app_rounded, size: 20),
                      label: const Text(
                        'Keluar Aplikasi',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  // Inisialisasi service lokal
  await Get.putAsync(() => LocalStorageService().init());
  Get.put(StorageService());

  runApp(const EpicApp());
}

