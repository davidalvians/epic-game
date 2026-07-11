import 'package:flutter/material.dart';

/// Riwayat Permainan — Menampilkan histori game yang pernah dimainkan.
/// Data akan diambil dari Firestore setelah sistem game terimplementasi.
class GameHistoryScreen extends StatelessWidget {
  const GameHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0),
      appBar: AppBar(
        title: const Text(
          'Riwayat Permainan',
          style: TextStyle(
            fontFamily: 'FredokaOne',
            fontSize: 20,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 56,
                  color: Color(0xFFCBD5E1),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Belum Ada Riwayat',
                style: TextStyle(
                  fontFamily: 'FredokaOne',
                  fontSize: 22,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Riwayat permainanmu akan muncul\ndi sini setelah kamu bermain.',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
