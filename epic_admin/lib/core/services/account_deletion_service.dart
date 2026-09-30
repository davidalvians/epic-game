import 'package:cloud_functions/cloud_functions.dart';

/// Satu-satunya pintu penghapusan akun dari admin panel.
///
/// Seluruh pembersihan Firestore, Storage, relasi kelas, progres permainan,
/// dan Firebase Authentication dikerjakan oleh Cloud Function dengan Admin SDK.
class AccountDeletionService {
  AccountDeletionService._();

  static Future<void> deleteUser(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      throw const AccountDeletionException('UID akun tidak ditemukan.');
    }

    try {
      await FirebaseFunctions.instance
          .httpsCallable(
            'adminDeleteUser',
            options: HttpsCallableOptions(
              timeout: const Duration(minutes: 9),
            ),
          )
          .call<void>({'uid': normalizedUid});
    } on FirebaseFunctionsException catch (error) {
      throw AccountDeletionException(
        error.message ??
            'Penghapusan belum selesai dan aman untuk dicoba kembali.',
      );
    }
  }
}

class AccountDeletionException implements Exception {
  final String message;

  const AccountDeletionException(this.message);

  @override
  String toString() => message;
}
