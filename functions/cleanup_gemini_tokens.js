/**
 * Script Cleanup: Hapus field geminiAccessToken & geminiTokenExpiresAt dari semua dokumen user.
 * 
 * Jalankan SEKALI setelah deploy gemini_token_service.dart yang baru.
 * 
 * Cara jalankan:
 *   cd functions
 *   node cleanup_gemini_tokens.js
 * 
 * Pastikan file .env atau Application Default Credentials sudah dikonfigurasi.
 */

const admin = require("firebase-admin");
admin.initializeApp({
  projectId: "epic-app1",
});

const db = admin.firestore();

async function cleanupGeminiTokens() {
  console.log("🔍 Mencari dokumen user dengan field geminiAccessToken...");

  // Ambil semua user yang memiliki field geminiAccessToken
  const snapshot = await db
    .collection("users")
    .where("geminiAccessToken", "!=", null)
    .get();

  if (snapshot.empty) {
    console.log("✅ Tidak ada dokumen yang perlu dibersihkan.");
    return;
  }

  console.log(`🗑️  Ditemukan ${snapshot.docs.length} dokumen, memulai cleanup...`);

  // Proses dalam batch (maks 500 per batch)
  const BATCH_SIZE = 500;
  let batchCount = 0;

  for (let i = 0; i < snapshot.docs.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = snapshot.docs.slice(i, i + BATCH_SIZE);

    chunk.forEach((doc) => {
      batch.update(doc.ref, {
        geminiAccessToken: admin.firestore.FieldValue.delete(),
        geminiTokenExpiresAt: admin.firestore.FieldValue.delete(),
      });
    });

    await batch.commit();
    batchCount++;
    console.log(`  ✅ Batch ${batchCount}: ${chunk.length} dokumen dibersihkan`);
  }

  console.log(`\n✅ Cleanup selesai! Total ${snapshot.docs.length} dokumen diperbarui.`);
  console.log("Token OAuth tidak lagi tersimpan di Firestore.");
}

cleanupGeminiTokens()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("❌ Error saat cleanup:", err);
    process.exit(1);
  });
