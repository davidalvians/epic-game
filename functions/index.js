const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();
const db = admin.firestore();
/**
 * ====== ARCHITECTURE NOTES ======
 * 
 * GEMINI API QUOTA & AUTHENTICATION:
 * 
 * Per-User Token Model (Core Design):
 * - Frontend (epic_app) stores user's Google OAuth accessToken in Firestore collection 'user_gemini_tokens'
 * - Each scoring request uses the STUDENT's personal quota, not admin/server quota
 * - This respects individual free tier limits and provides per-user accountability
 * 
 * Two Scoring Paths:
 * 1. STUDENT INITIAL SCORE (epic_app):
 *    - Uses per-user token via Frontend → Direct Gemini API call
 *    - Function: aiService.evaluateArtwork() → HTTP Bearer token
 * 
 * 2. ADMIN RE-SCORE (epic_admin):
 *    - Uses SAME per-user token fetched from Firestore
 *    - Function: rescoreArtwork() → callGeminiAPIWithUserToken() → HTTP Bearer token
 *    - Student quota is consumed, not admin quota
 * 
 * 3. SANDBOX TESTING (epic_admin - instrument testing):
 *    - Uses GEMINI_API_KEY from Google Secret Manager
 *    - Function: testSandboxScoring() → callGeminiAPI() → API Key
 *    - Isolated from production quota/token management
 * 
 * Quota Exhaustion Handling:
 * - HTTP 429 responses trigger "pending" status with reason
 * - Frontend auto-retries pending artworks when user opens gallery
 * - Backend persists user token expiry to handle re-authentication
 * 
 * ==============================
 */

// Helper: cek apakah user adalah admin (menggunakan koleksi 'admins')
async function isAdmin(uid) {
  if (!uid) return false;
  try {
    const doc = await db.collection("admins").doc(uid).get();
    if (!doc.exists) return false;
    const data = doc.data();
    return data && data.role === "admin" && data.isActive === true;
  } catch (e) {
    console.error("isAdmin check failed:", e);
    return false;
  }
}

const ACCOUNT_DELETION_JOBS = "account_deletion_jobs";

async function deleteQueryDocuments(query) {
  let deletedCount = 0;
  // Firestore pagination terminates when the next batch is empty.
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const snapshot = await query.limit(400).get();
    if (snapshot.empty) break;

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deletedCount += snapshot.size;
  }
  return deletedCount;
}

async function deleteStoragePrefix(prefix) {
  try {
    await admin.storage().bucket().deleteFiles({prefix, force: true});
  } catch (error) {
    // deleteFiles may report a missing prefix as an error on some emulators.
    if (error && error.code !== 404) throw error;
  }
}

function storagePathFromUrl(downloadUrl) {
  if (!downloadUrl || typeof downloadUrl !== "string") return null;
  try {
    if (downloadUrl.startsWith("gs://")) {
      const withoutScheme = downloadUrl.slice(5);
      const slashIndex = withoutScheme.indexOf("/");
      return slashIndex >= 0 ? withoutScheme.slice(slashIndex + 1) : null;
    }

    const parsed = new URL(downloadUrl);
    const marker = "/o/";
    const markerIndex = parsed.pathname.indexOf(marker);
    if (markerIndex < 0) return null;
    return decodeURIComponent(parsed.pathname.slice(markerIndex + marker.length));
  } catch (_) {
    return null;
  }
}

async function deleteStorageUrl(downloadUrl) {
  const path = storagePathFromUrl(downloadUrl);
  if (!path) return;
  try {
    await admin.storage().bucket().file(path).delete({ignoreNotFound: true});
  } catch (error) {
    if (error && error.code !== 404) throw error;
  }
}

async function updateDocumentsInChunks(documents, buildUpdate) {
  for (let start = 0; start < documents.length; start += 400) {
    const batch = db.batch();
    const chunk = documents.slice(start, start + 400);
    chunk.forEach((doc) => {
      const update = buildUpdate(doc);
      if (update) batch.update(doc.ref, update);
    });
    await batch.commit();
  }
}

async function detachStudentFromClasses(uid, userData) {
  const classIds = new Set(
    Array.isArray(userData.kelasIds) ? userData.kelasIds : [],
  );
  const membershipSnapshot = await db
    .collection("kelas")
    .where("muridIds", "array-contains", uid)
    .get();
  membershipSnapshot.docs.forEach((doc) => classIds.add(doc.id));

  await updateDocumentsInChunks(membershipSnapshot.docs, (doc) => {
    const data = doc.data() || {};
    const exitedMurids = Array.isArray(data.exitedMurids) ?
      data.exitedMurids.filter((entry) => !entry || entry.uid !== uid) : [];
    return {
      muridIds: admin.firestore.FieldValue.arrayRemove(uid),
      exitedMurids,
    };
  });

  for (const classId of classIds) {
    await db
      .recursiveDelete(
        db.collection("leaderboard_kelas")
          .doc(classId)
          .collection("members")
          .doc(uid),
      );
  }
}

async function deleteTeacherClasses(uid) {
  const classesSnapshot = await db
    .collection("kelas")
    .where("guruUid", "==", uid)
    .get();

  for (const classDoc of classesSnapshot.docs) {
    const classData = classDoc.data() || {};
    const studentIds = Array.isArray(classData.muridIds) ?
      classData.muridIds.filter((value) => typeof value === "string") : [];

    const studentRefs = [];
    for (const studentId of studentIds) {
      const studentRef = db.collection("users").doc(studentId);
      const studentSnapshot = await studentRef.get();
      if (studentSnapshot.exists) studentRefs.push(studentSnapshot);
    }
    await updateDocumentsInChunks(studentRefs, () => ({
      kelasIds: admin.firestore.FieldValue.arrayRemove(classDoc.id),
    }));

    const artworksSnapshot = await db
      .collection("artworks")
      .where("kelasId", "==", classDoc.id)
      .get();
    for (let start = 0; start < artworksSnapshot.docs.length; start += 400) {
      const batch = db.batch();
      const chunk = artworksSnapshot.docs.slice(start, start + 400);
      for (const artworkDoc of chunk) {
        const artwork = artworkDoc.data() || {};
        if (artwork.deletedByMurid === true) {
          await deleteStorageUrl(artwork.imageUrl);
          batch.delete(artworkDoc.ref);
        } else {
          batch.update(artworkDoc.ref, {kelasId: null});
        }
      }
      await batch.commit();
    }

    await db.recursiveDelete(
      db.collection("leaderboard_kelas").doc(classDoc.id),
    );
    await db.recursiveDelete(classDoc.ref);
  }
}

async function purgeUserData(uid, actorUid, source) {
  const jobRef = db.collection(ACCOUNT_DELETION_JOBS).doc(uid);
  await jobRef.set({
    uid,
    actorUid,
    source,
    status: "running",
    startedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  try {
    const userRef = db.collection("users").doc(uid);
    const userSnapshot = await userRef.get();
    const userData = userSnapshot.exists ? userSnapshot.data() || {} : {};

    // Jalankan kedua pembersihan agar retry tetap lengkap meskipun dokumen
    // profil induk sudah lebih dahulu hilang pada implementasi lama.
    await deleteTeacherClasses(uid);
    await detachStudentFromClasses(uid, userData);

    await deleteQueryDocuments(
      db.collection("artworks").where("uid", "==", uid),
    );
    await deleteQueryDocuments(
      db.collection("student_evaluations").where("studentId", "==", uid),
    );
    await deleteQueryDocuments(
      db.collection("guru_verifikasi").where("uid", "==", uid),
    );
    await deleteQueryDocuments(
      db.collection("usernames").where("uid", "==", uid),
    );

    const username = String(userData.username || "").trim().toLowerCase();
    if (username) {
      await db.collection("usernames").doc(username).delete();
    }

    await db.recursiveDelete(db.collection("leaderboard_global").doc(uid));
    await db.recursiveDelete(db.collection("scores").doc(uid));
    await db.recursiveDelete(userRef);

    await Promise.all([
      deleteStoragePrefix(`artworks/${uid}/`),
      deleteStoragePrefix(`avatars/${uid}/`),
      deleteStoragePrefix(`guru_bukti/${uid}/`),
      deleteStoragePrefix(`evaluations/${uid}/`),
    ]);

    try {
      await admin.auth().deleteUser(uid);
    } catch (error) {
      if (!error || error.code !== "auth/user-not-found") throw error;
    }

    await jobRef.set({
      status: "complete",
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      error: admin.firestore.FieldValue.delete(),
    }, {merge: true});

    return {success: true, uid};
  } catch (error) {
    console.error(`Account deletion failed for ${uid}:`, error);
    await jobRef.set({
      status: "failed",
      error: error && error.message ? error.message : String(error),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    throw error;
  }
}

exports.deleteOwnAccount = functions
  .runWith({timeoutSeconds: 540, memory: "1GB", enforceAppCheck: true})
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Silakan login kembali sebelum menghapus akun.",
      );
    }

    const authTime = Number(context.auth.token.auth_time || 0);
    const ageSeconds = Math.floor(Date.now() / 1000) - authTime;
    if (!authTime || ageSeconds > 600) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Login ulang diperlukan sebelum menghapus akun.",
      );
    }

    try {
      return await purgeUserData(
        context.auth.uid,
        context.auth.uid,
        "self_service",
      );
    } catch (_) {
      throw new functions.https.HttpsError(
        "internal",
        "Penghapusan akun belum selesai. Silakan coba lagi atau hubungi admin.",
      );
    }
  });

exports.adminDeleteUser = functions
  .runWith({timeoutSeconds: 540, memory: "1GB"})
  .https.onCall(async (data, context) => {
    if (!context.auth || !(await isAdmin(context.auth.uid))) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Hanya admin aktif yang dapat menghapus akun.",
      );
    }

    const uid = String(data && data.uid || "").trim();
    if (!uid) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "UID akun wajib diisi.",
      );
    }
    if (uid === context.auth.uid) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Admin tidak dapat menghapus akun yang sedang digunakan.",
      );
    }

    try {
      return await purgeUserData(uid, context.auth.uid, "admin_panel");
    } catch (_) {
      throw new functions.https.HttpsError(
        "internal",
        "Penghapusan belum selesai dan dapat dicoba ulang dengan aman.",
      );
    }
  });

function requireAuthenticated(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Sesi login tidak ditemukan.",
    );
  }
  return context.auth.uid;
}

function cleanDeviceText(value, fallback) {
  const normalized = String(value || "").trim();
  return normalized ? normalized.slice(0, 120) : fallback;
}

exports.registerDeviceSession = functions
  .runWith({enforceAppCheck: true})
  .https.onCall(async (data, context) => {
    const uid = requireAuthenticated(context);
    const deviceId = cleanDeviceText(data && data.deviceId, "");
    if (!deviceId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "ID perangkat wajib diisi.",
      );
    }

    const deviceName = cleanDeviceText(data && data.deviceName, "Perangkat");
    const userRef = db.collection("users").doc(uid);
    const sessionRef = userRef.collection("security_sessions").doc(deviceId);
    let revoked = false;

    await db.runTransaction(async (transaction) => {
      const [snapshot, sessionSnapshot] = await Promise.all([
        transaction.get(userRef),
        transaction.get(sessionRef),
      ]);
      if (!snapshot.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Profil pengguna tidak ditemukan.",
        );
      }

      const user = snapshot.data() || {};
      const revokedIds = Array.isArray(user.revokedDeviceIds) ?
        user.revokedDeviceIds.map(String) : [];
      const savedSession = sessionSnapshot.exists ?
        sessionSnapshot.data() || {} : {};
      if (savedSession.revoked === true || revokedIds.includes(deviceId)) {
        revoked = true;
        return;
      }

      const now = admin.firestore.Timestamp.now();
      const locationParts = [user.kabupaten, user.provinsi]
        .map((value) => String(value || "").trim())
        .filter(Boolean);
      const location = locationParts.length ?
        locationParts.join(", ") : "Lokasi profil belum diisi";
      const devices = Array.isArray(user.devices) ?
        user.devices.filter((entry) => entry && typeof entry === "object") : [];
      const deviceEntry = {
        id: deviceId,
        nama: deviceName,
        lokasi: location,
        lastSeenAt: now,
      };
      const deviceIndex = devices.findIndex((entry) => entry.id === deviceId);
      if (deviceIndex >= 0) devices[deviceIndex] = deviceEntry;
      else devices.push(deviceEntry);

      const history = Array.isArray(user.loginHistory) ?
        user.loginHistory.filter((entry) => entry && typeof entry === "object") : [];
      const provider = context.auth.token.firebase &&
        context.auth.token.firebase.sign_in_provider || "unknown";
      const last = history.length ? history[0] : null;
      const isDuplicate = last && last.deviceId === deviceId &&
        last.occurredAt && typeof last.occurredAt.toMillis === "function" &&
        now.toMillis() - last.occurredAt.toMillis() < 5 * 60 * 1000;
      if (!isDuplicate) {
        history.unshift({
          deviceId,
          device: deviceName,
          metode: provider === "google.com" ? "Google Sign-In" : provider,
          occurredAt: now,
        });
      }
      if (history.length > 20) history.length = 20;

      transaction.set(sessionRef, {
        ...deviceEntry,
        revoked: false,
        updatedAt: now,
      }, {merge: true});
      transaction.update(userRef, {devices, loginHistory: history});
    });

    return {revoked};
  });

exports.revokeDeviceSession = functions
  .runWith({enforceAppCheck: true})
  .https.onCall(async (data, context) => {
    const uid = requireAuthenticated(context);
    const deviceId = cleanDeviceText(data && data.deviceId, "");
    if (!deviceId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "ID perangkat wajib diisi.",
      );
    }

    const userRef = db.collection("users").doc(uid);
    const sessionRef = userRef.collection("security_sessions").doc(deviceId);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(userRef);
      if (!snapshot.exists) return;
      const user = snapshot.data() || {};
      const devices = Array.isArray(user.devices) ?
        user.devices.filter((entry) => entry && entry.id !== deviceId) : [];
      const revokedIds = Array.isArray(user.revokedDeviceIds) ?
        user.revokedDeviceIds.map(String) : [];
      if (!revokedIds.includes(deviceId)) revokedIds.push(deviceId);
      transaction.update(userRef, {
        devices,
        revokedDeviceIds: revokedIds.slice(-100),
      });
      transaction.set(sessionRef, {
        id: deviceId,
        revoked: true,
        revokedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    });
    return {success: true};
  });

exports.unregisterDeviceSession = functions
  .runWith({enforceAppCheck: true})
  .https.onCall(async (data, context) => {
    const uid = requireAuthenticated(context);
    const deviceId = cleanDeviceText(data && data.deviceId, "");
    if (!deviceId) return {success: true};

    const userRef = db.collection("users").doc(uid);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(userRef);
      if (!snapshot.exists) return;
      const user = snapshot.data() || {};
      const devices = Array.isArray(user.devices) ?
        user.devices.filter((entry) => entry && entry.id !== deviceId) : [];
      transaction.update(userRef, {devices});
    });
    return {success: true};
  });

exports.clearLoginHistory = functions
  .runWith({enforceAppCheck: true})
  .https.onCall(async (data, context) => {
    const uid = requireAuthenticated(context);
    await db.collection("users").doc(uid).update({loginHistory: []});
    return {success: true};
  });

/**
 * Helper: Hitung grade dari skor — threshold WAJIB identik dengan artwork_model.dart (Dart/client).
 * S: 90-100 | A: 80-89 | B: 70-79 | C: 60-69 | D: 50-59 | E: 0-49
 */
function calculateGrade(skor) {
  if (skor == null || isNaN(skor)) return "-";
  if (skor >= 90) return "S";
  if (skor >= 80) return "A";
  if (skor >= 70) return "B";
  if (skor >= 60) return "C";
  if (skor >= 50) return "D";
  return "E";
}

// Konfigurasi Nodemailer
const smtpHost = process.env.SMTP_HOST || "";
const smtpPort = parseInt(process.env.SMTP_PORT || "465");
const smtpUser = process.env.SMTP_USER || functions.config().email?.user || "";
const smtpPass = process.env.SMTP_PASS || functions.config().email?.pass || "";
const smtpSecure = process.env.SMTP_SECURE === "true" || smtpPort === 465;

let transporter = null;
const isDummyCreds = smtpUser === "your_email@gmail.com" || smtpPass === "your_app_password" || !smtpUser || !smtpPass;

if (!isDummyCreds) {
  if (smtpHost) {
    transporter = nodemailer.createTransport({
      host: smtpHost,
      port: smtpPort,
      secure: smtpSecure,
      auth: {
        user: smtpUser,
        pass: smtpPass,
      },
    });
  } else {
    transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: smtpUser,
        pass: smtpPass,
      },
    });
  }
}


/**
 * Helper: Build strict scoring prompt from instrument data.
 * Menggunakan kriteria dinamis dari Firestore instrument.
 */
function buildScoringPrompt(instrumentData, waktuPengerjaan, scoringMetadata = null) {
  const instructions = instrumentData.systemInstruction || instrumentData.konteksBudaya || "Seni budaya Madura.";
  const materiMatematika = instrumentData.materiMatematika || "Konsep matematika dasar.";

  let criteriaBuffer = "";
  const criteria = instrumentData.criteria;
  if (Array.isArray(criteria) && criteria.length > 0) {
    criteria.forEach((c, i) => {
      criteriaBuffer += `${i + 1}. ${c.name} (Bobot: ${c.weight}%)\n`;
    });
  } else {
    // Fallback ke flat fields
    if (instrumentData.kriteria1) criteriaBuffer += `1. ${instrumentData.kriteria1} (Bobot: ${instrumentData.bobot1 || 40}%)\n`;
    if (instrumentData.kriteria2) criteriaBuffer += `2. ${instrumentData.kriteria2} (Bobot: ${instrumentData.bobot2 || 30}%)\n`;
    if (instrumentData.kriteria3) criteriaBuffer += `3. ${instrumentData.kriteria3} (Bobot: ${instrumentData.bobot3 || 30}%)\n`;
    if (!criteriaBuffer) criteriaBuffer = "1. Ketepatan Konsep (Bobot: 40%)\n2. Kreativitas (Bobot: 30%)\n3. Estetika (Bobot: 30%)\n";
  }

  const instrumentLevel = Number(instrumentData.level);
  const usesAnyamanColorRubric = String(instrumentData.kategori || "").toLowerCase() === "anyaman" &&
    instrumentLevel >= 1 && instrumentLevel <= 4;
  const levelSpecificRubric = usesAnyamanColorRubric ? `
RUBRIK KHUSUS ANYAMAN LEVEL ${instrumentLevel} (WAJIB):
- Nilai kualitas POLA WARNA dari ritme, pengulangan, keseimbangan, dan hubungan warna antarbilah; bentuk grid bawaan aplikasi bukan bukti kreativitas siswa.
- Satu warna yang dipakai seragam tanpa variasi atau motif: skor kualitas pola warna 5-30 dan kreativitas warna 0-20. Nilai kelengkapan tetap sesuai bidang yang terisi; jangan memberikan satu angka total yang sama untuk semua karya satu warna.
- Dua atau lebih warna yang ditempatkan acak tidak otomatis kreatif. Bedakan skor berdasarkan tingkat keteraturan, pengulangan, keseimbangan, dan bagian yang telah diselesaikan.
- Skor 60-79 membutuhkan pola warna yang sengaja disusun, berulang, cukup seimbang, dan rapi.
- Skor 80-89 membutuhkan komposisi warna yang jelas harmonis/kontras, pola yang berkembang, seimbang, dan hampir seluruh bilah rapi.
- Skor 90-100 hanya untuk karya yang sangat orisinal, kompleks tetapi teratur, harmonis, lengkap, dan nyaris tanpa kesalahan; kategori ini harus sangat jarang.
- Bedakan penilaian setiap kriteria. Jangan memberi skor kreativitas tinggi hanya karena seluruh bilah telah diwarnai.
` : "";
  const objectiveData = usesAnyamanColorRubric && scoringMetadata ? `
DATA OBJEKTIF DARI GRID (lebih akurat daripada perkiraan gambar):
- Jumlah warna yang benar-benar digunakan: ${Number(scoringMetadata.uniqueColorCount) || 0}
- Persentase bilah yang terisi: ${Math.round((Number(scoringMetadata.fillPercentage) || 0) * 100)}%
- Persentase warna dominan: ${Math.round((Number(scoringMetadata.dominantColorRatio) || 0) * 100)}%
- Keseimbangan distribusi warna: ${Math.round((Number(scoringMetadata.colorBalance) || 0) * 100)}%
- Kekayaan variasi warna: ${Math.round((Number(scoringMetadata.colorRichness) || 0) * 100)}%
- Konsistensi pengulangan pola: ${Math.round((Number(scoringMetadata.patternConsistency) || 0) * 100)}%
- Skor pola objektif: ${Number(scoringMetadata.objectivePatternScore) || 0}/100
- Skor kreativitas objektif: ${Number(scoringMetadata.objectiveCreativityScore) || 0}/100
- Skor kelengkapan objektif: ${Number(scoringMetadata.objectiveCompletenessScore) || 0}/100
Gunakan data ini sebagai fakta. Jangan menaikkan nilai hanya karena bidang penuh, dan jangan menyamakan karya satu warna, karya acak, serta pola yang sengaja disusun.
` : "";

  return `Anda adalah juri kurator seni etnomatematika Madura yang profesional, jujur, namun mendidik dan komunikatif kepada anak SD (menyapa dengan panggilan "kamu").

WAKTU PENGERJAAN: ${waktuPengerjaan || 0} detik. (Beri toleransi dan apresiasi sewajarnya sesuai waktu pengerjaan).

PROMPT/INSTRUKSI SISTEM:
${instructions}

MATERI MATEMATIKA:
${materiMatematika}

KRITERIA PENILAIAN:
${criteriaBuffer}
${levelSpecificRubric}
${objectiveData}

INSTRUKSI PENILAIAN YANG WAJIB DIIKUTI:
- Analisis gambar karya siswa yang diberikan dengan SANGAT SEKSAMA dan OBJEKTIF.
- JANGAN selalu memuji dan JANGAN pernah mengatakan "karyamu bagus/sempurna" jika nilai akhir di bawah 80.
- Jika gambar KOSONG, SEMUA PUTIH, atau TIDAK ADA karya nyata yang terdeteksi: berikan skor 0-5.
- Jika konsep matematika SALAH (misalnya, warna tidak mengikuti aturan, pola tidak konsisten, simetri rusak): WAJIB berikan nilai sangat rendah (1-20) pada kriteria tersebut.
- Jika karya SANGAT JELEK, tidak rapi, atau acak-acakan: skor maksimal hanya 40.
- Jika karya CUKUP (ada usaha tapi banyak kesalahan): skor 41-60.
- Jika karya BAIK (konsep benar tapi kurang sempurna): skor 61-79.
- Jika karya SANGAT BAIK (konsep benar, rapi, kreatif): skor 80-89.
- Jika karya SEMPURNA (jarang sekali): skor 90-100.
- Jangan gunakan sistem poin minus. Hanya nilai rentang 0-100.
- Hitung total skor akhir (0-100) berdasarkan bobot kriteria di atas secara matematis.
- Tentukan grade: S (90-100), A (80-89), B (70-79), C (60-69), D (50-59), E (0-49).
- Feedback harus memuat 3 bagian dalam 2-3 kalimat yang ramah namun JUJUR:
  1. Apresiasi: Bagian goresan atau perpaduan warna yang sudah baik (jika ada).
  2. Koreksi Jujur: Kesalahan konsep atau letak objek yang salah secara spesifik.
  3. Saran Perbaikan: Langkah nyata untuk meningkatkan karya pada percobaan berikutnya.

PENTING: Berikan respons dalam format JSON berikut SAJA:
{
  "skor": <skor_total_bulat_0_100>,
  "grade": "<S/A/B/C/D/E>",
  "nilaiKriteria": [<skor kriteria 1>, <skor kriteria 2>, <skor kriteria 3>],
  "feedback": "<Teks feedback gabungan apresiasi, koreksi, dan saran>"
}

Hanya berikan JSON, tanpa teks atau format markdown tambahan lainnya.`;
}

const { GoogleGenerativeAI } = require("@google/generative-ai");

// CATATAN ARSITEKTUR:
// getUserGeminiAccessToken() dihapus karena menyimpan token OAuth di Firestore tidak aman.
// Server (Cloud Functions) selalu menggunakan Server API Key dari .env (GEMINI_API_KEY).
// Scoring per-user quota ditangani di client-side (mobile app) langsung via GeminiTokenService.

const scoringSchema = {
  type: "object",
  properties: {
    skor: { type: "integer" },
    // Grade enum sesuai calculateGrade() — identik dengan client Dart (artwork_model.dart)
    grade: { type: "string", enum: ["S", "A", "B", "C", "D", "E"] },
    nilaiKriteria: {
      type: "array",
      items: { type: "integer" },
    },
    feedback: { type: "string" }
  },
  required: ["skor", "grade", "nilaiKriteria", "feedback"]
};

/**
 * Helper: Ambil data instrumen default jika tidak ditemukan di Firestore.
 */
function getDefaultInstrument(kategori, level) {
  const key = `${kategori.toLowerCase()}_${level}`;
  switch (key) {
    case "batik_1":
      return {
        kategori, level, modelAI: "gemini-2.5-flash",
        konteksBudaya: "Batik Madura memiliki motif khas dengan pola geometris berulang. Level ini mengajarkan pola garis berulang.",
        materiMatematika: "Pola bilangan, pengulangan, dan barisan sederhana.",
        criteria: [
          { name: "Ketepatan pola pengulangan (garis teratur, berulang dengan ritme konsisten)", weight: 40 },
          { name: "Penggunaan warna (minimal 2 warna, kontras, sesuai estetika Madura)", weight: 30 },
          { name: "Kreativitas dan kerapihan (variasi dalam pola, garis bersih)", weight: 30 }
        ]
      };
    case "batik_2":
      return {
        kategori, level, modelAI: "gemini-2.5-flash-lite",
        konteksBudaya: "Batik Madura memiliki sifat simetri cermin pada banyak motifnya. Level ini mengajarkan simetri.",
        materiMatematika: "Simetri cermin (refleksi), sumbu simetri, dan pencerminan bangun datar.",
        criteria: [
          { name: "Ketepatan simetri cermin (sisi kanan = refleksi sisi kiri)", weight: 40 },
          { name: "Kelengkapan motif (motif terisi penuh, tidak ada bagian kosong)", weight: 30 },
          { name: "Estetika keseluruhan (warna harmonis, detail rapi)", weight: 30 }
        ]
      };
    case "batik_3":
      return {
        kategori, level, modelAI: "gemini-2.5-flash-lite",
        konteksBudaya: "Motif geometri khas Madura: gentongan, tanjung bumi, bangkalan. Level ini menggunakan bangun datar.",
        materiMatematika: "Bangun datar: persegi, segitiga, lingkaran, belah ketupat. Minimal 3 jenis.",
        criteria: [
          { name: "Penggunaan bangun datar (minimal 3 jenis, tepat bentuk)", weight: 40 },
          { name: "Komposisi motif Madura (menyerupai motif tradisional)", weight: 30 },
          { name: "Kerapihan dan kombinasi warna (warna khas Madura: merah, kuning, hijau)", weight: 30 }
        ]
      };
    case "batik_4":
      return {
        kategori, level, modelAI: "gemini-2.5-flash",
        konteksBudaya: "Batik Madura asli — siswa bebas berkreasi dengan identitas budaya Madura.",
        materiMatematika: "Gabungan semua konsep: pola, simetri, bangun datar, transformasi.",
        criteria: [
          { name: "Orisinalitas dan kreativitas desain (ide unik, bukan copy)", weight: 40 },
          { name: "Penerapan konsep matematika (minimal 2 konsep terlihat)", weight: 30 },
          { name: "Representasi budaya Madura (warna khas, elemen budaya)", weight: 30 }
        ]
      };
    case "anyaman_1":
      return {
        kategori, level, modelAI: "gemini-2.5-flash-lite",
        konteksBudaya: "Anyaman tradisional Madura - Belajar menyusun kombinasi warna dasar.",
        materiMatematika: "Pengenalan pola warna. Warnai grid 8x8 secara bebas menggunakan minimal 2 warna berbeda untuk membentuk motif anyaman.",
        criteria: [
          { name: "Penggunaan warna (minimal menggunakan 2 warna berbeda pada grid)", weight: 40 },
          { name: "Kreativitas gambar (keindahan motif anyaman yang dibentuk)", weight: 30 },
          { name: "Kerapihan pengisian grid", weight: 30 }
        ]
      };
    case "anyaman_2":
      return {
        kategori, level, modelAI: "gemini-2.5-flash-lite",
        konteksBudaya: "Anyaman Madura tersusun dari bilah-bilah yang saling bersilang untuk membentuk pola geometris yang teratur.",
        materiMatematika: "Pola spasial dan orientasi. Warnai pola 6x6 blok anyaman; setiap blok terdiri dari 4 bilah persegi panjang dengan arah vertikal dan horizontal yang bergantian.",
        criteria: [
          { name: "Kualitas pola warna anyaman (ritme, pengulangan, dan keseimbangan antarbilah)", weight: 35 },
          { name: "Kreativitas komposisi warna (variasi, harmoni, kontras, dan orisinalitas)", weight: 40 },
          { name: "Kerapihan dan kelengkapan pewarnaan setiap bilah", weight: 25 }
        ]
      };
    case "anyaman_3":
      return {
        kategori, level, modelAI: "gemini-2.5-flash-lite",
        konteksBudaya: "Anyaman Madura dapat disusun dari bilah-bilah diagonal yang berulang membentuk motif geometris menyerupai spiral dan persegi bertingkat.",
        materiMatematika: "Pola geometri diagonal, rotasi, pengulangan, dan keseimbangan. Warnai setiap bilah untuk membentuk komposisi warna yang teratur dan kreatif.",
        systemInstruction: "Anda adalah juri Anyaman Level 3. Nilai kualitas pola warna pada susunan bilah diagonal, kreativitas komposisi warna, serta kerapihan dan kelengkapan bilah secara terpisah. Tidak ada syarat jumlah warna minimum. Satu warna seragam tanpa variasi atau motif mendapat skor kualitas pola 5-30 dan kreativitas warna 0-20, sedangkan kelengkapan dinilai sesuai bidang yang terisi; jangan memberikan satu angka total yang sama untuk semua karya satu warna. Dua atau lebih warna yang ditempatkan acak tidak otomatis kreatif. Nilai 80 ke atas hanya untuk komposisi yang sengaja disusun, harmonis atau kontras, seimbang, lengkap, dan rapi; nilai 90-100 harus sangat jarang.",
        criteria: [
          { name: "Kualitas pola warna anyaman diagonal (ritme, pengulangan, dan keseimbangan antarbilah)", weight: 35 },
          { name: "Kreativitas komposisi warna (variasi, harmoni, kontras, dan orisinalitas)", weight: 40 },
          { name: "Kerapihan dan kelengkapan pewarnaan setiap bilah", weight: 25 }
        ]
      };
    case "anyaman_4":
      return {
        kategori, level, modelAI: "gemini-2.5-flash",
        konteksBudaya: "Motif Kelarai Bunga Api menyusun bilah-bilah anyaman horizontal dan vertikal secara bertingkat hingga membentuk komposisi geometris yang memancar dari pusat.",
        materiMatematika: "Pola geometri ortogonal, pengulangan, keseimbangan, dan hubungan spasial. Warnai setiap bidang Kelarai Bunga Api untuk membentuk komposisi warna yang teratur dan kreatif.",
        systemInstruction: "Anda adalah juri Anyaman Level 4 dengan motif Kelarai Bunga Api. Nilai kualitas pola warna pada susunan bilah horizontal dan vertikal yang bertingkat, kreativitas komposisi warna, serta kerapihan dan kelengkapan setiap bidang secara terpisah. Tidak ada syarat jumlah warna minimum. Satu warna seragam tanpa variasi atau motif mendapat skor kualitas pola 5-30 dan kreativitas warna 0-20, sedangkan kelengkapan dinilai sesuai bidang yang terisi; jangan memberikan satu angka total yang sama untuk semua karya satu warna. Dua atau lebih warna yang ditempatkan acak tidak otomatis kreatif. Nilai 80 ke atas hanya untuk komposisi yang sengaja disusun, harmonis atau kontras, seimbang, lengkap, dan rapi; nilai 90-100 harus sangat jarang.",
        criteria: [
          { name: "Kualitas pola warna Kelarai Bunga Api (ritme, pengulangan, keseimbangan, dan hubungan antarbidang)", weight: 35 },
          { name: "Kreativitas komposisi warna (variasi, harmoni, kontras, dan orisinalitas)", weight: 40 },
          { name: "Kerapihan dan kelengkapan pewarnaan setiap bidang anyaman", weight: 25 }
        ]
      };
    case "keris_1":
      return {
        kategori, level, modelAI: "gemini-2.5-flash-lite",
        konteksBudaya: "Gagang keris Madura memiliki ukiran khas yang mencerminkan keberanian dan ketangguhan budaya Madura.",
        materiMatematika: "Geometri dasar: garis lurus, garis lengkung, dan pola sederhana.",
        criteria: [
          { name: "Kerapian dan ketepatan garis", weight: 40 },
          { name: "Kreativitas penggunaan warna", weight: 30 },
          { name: "Kelengkapan mengisi kanvas", weight: 30 }
        ]
      };
    case "keris_2":
      return {
        kategori, level, modelAI: "gemini-2.5-flash-lite",
        konteksBudaya: "Bilah keris Madura biasanya memiliki luk (kelok) berjumlah ganjil yang melambangkan filosofi kehidupan dan kesempurnaan.",
        materiMatematika: "Pola berulang, garis berkelok (luk), dan estetika keseimbangan.",
        criteria: [
          { name: "Ketepatan luk bilah keris (ganjil/kelok berulang)", weight: 40 },
          { name: "Kerapian hiasan pola berulang", weight: 30 },
          { name: "Keharmonisan komposisi & estetika warna", weight: 30 }
        ]
      };
    case "keris_3":
      return {
        kategori, level, modelAI: "gemini-2.5-flash",
        konteksBudaya: "Warangka keris berfungsi sebagai pelindung dan lambang status sosial dengan ukiran geometris yang khas.",
        materiMatematika: "Geometri & kombinasi minimal 3 jenis bangun datar berbeda.",
        criteria: [
          { name: "Penggunaan bangun datar (minimal 3 jenis, tepat bentuk)", weight: 40 },
          { name: "Kombinasi dan keselarasan bangun datar", weight: 30 },
          { name: "Kerapian dan komposisi warna khas Madura", weight: 30 }
        ]
      };
    case "keris_4":
      return {
        kategori, level, modelAI: "gemini-2.5-flash",
        konteksBudaya: "Keris Madura lengkap (gagang, bilah, warangka) mencerminkan mahakarya budaya Madura yang bernilai tinggi.",
        materiMatematika: "Gabungan semua konsep matematika: pola, geometri, keselarasan proporsi.",
        criteria: [
          { name: "Kelengkapan struktur keris (gagang, bilah, warangka)", weight: 40 },
          { name: "Kreativitas & orisinalitas desain", weight: 30 },
          { name: "Representasi budaya Madura (warna & motif)", weight: 30 }
        ]
      };
    default:
      return {
        kategori, level, modelAI: "gemini-2.5-flash-lite",
        konteksBudaya: "Seni budaya Madura dan matematika.",
        materiMatematika: "Konsep matematika dasar.",
        criteria: [
          { name: "Ketepatan konsep", weight: 40 },
          { name: "Kreativitas", weight: 30 },
          { name: "Estetika", weight: 30 }
        ]
      };
  }
}

function normalizeInstrumentData(instrumentData, kategori, level) {
  const merged = { ...(instrumentData || {}), kategori, level };
  const numericLevel = Number(level);
  if (String(kategori).toLowerCase() !== "anyaman" ||
      numericLevel < 1 || numericLevel > 4) {
    return merged;
  }

  const normalized = JSON.stringify(merged).toLowerCase();
  const usesLegacyValues = normalized.includes("grid 12x12") ||
    normalized.includes("grid 14x14") ||
    normalized.includes("minimal 4 warna") ||
    normalized.includes("minimal menggunakan 4 warna") ||
    normalized.includes("lebih dari 3 warna") ||
    normalized.includes("anyaman bebas") ||
    normalized.includes("asisten simetri") ||
    normalized.includes("nilai akhir maksimal 55") ||
    normalized.includes("skor 10-30 pada kualitas pola");
  if (!usesLegacyValues) return merged;

  const latestDefault = getDefaultInstrument(kategori, level);
  return {
    ...merged,
    ...latestDefault,
    modelAI: merged.modelAI || latestDefault.modelAI,
    systemInstruction: latestDefault.systemInstruction || "",
  };
}

function applyAnyamanHybridScoring(geminiResult, instrumentData, scoringMetadata) {
  const aiScore = Math.max(0, Math.min(100,
    typeof geminiResult.skor === "number"
      ? Math.round(geminiResult.skor)
      : parseInt(geminiResult.skor) || 0));
  const level = Number(instrumentData.level);
  const isSupportedAnyaman = String(instrumentData.kategori || "").toLowerCase() === "anyaman" &&
    level >= 1 && level <= 4;
  if (!isSupportedAnyaman || !scoringMetadata) {
    const rawCriteria = Array.isArray(geminiResult.nilaiKriteria)
      ? geminiResult.nilaiKriteria
      : [];
    const storedCriteria = Array.isArray(instrumentData.criteria)
      ? instrumentData.criteria
      : [];
    const fallbackWeights = level === 1 ? [40, 30, 30] : [35, 40, 25];
    const weights = [0, 1, 2].map((index) => {
      const weight = Number(storedCriteria[index]?.weight);
      return Number.isFinite(weight) && weight >= 0
        ? weight
        : fallbackWeights[index];
    });
    const criteriaScores = [0, 1, 2].map((index) => {
      const score = Number(rawCriteria[index]);
      return Number.isFinite(score)
        ? Math.max(0, Math.min(100, Math.round(score)))
        : aiScore;
    });
    const totalWeight = weights.reduce((total, weight) => total + weight, 0);
    const resolvedScore = isSupportedAnyaman && rawCriteria.length >= 3 && totalWeight > 0
      ? Math.round(criteriaScores.reduce(
        (total, criterionScore, index) => total + criterionScore * weights[index], 0) / totalWeight)
      : aiScore;
    return {
      score: resolvedScore,
      grade: calculateGrade(resolvedScore),
      feedback: geminiResult.feedback || "Karya sudah dinilai oleh AI.",
      details: {
        objectiveRulesApplied: false,
        scoreBeforeCriteriaWeighting: aiScore,
        aiCriteriaScores: criteriaScores,
        criteriaWeights: weights,
      },
    };
  }

  const clampScore = (value, fallback = 0) => {
    const parsed = Number(value);
    return Number.isFinite(parsed)
      ? Math.max(0, Math.min(100, Math.round(parsed)))
      : fallback;
  };
  const objectiveScores = [
    clampScore(scoringMetadata.objectivePatternScore),
    clampScore(scoringMetadata.objectiveCreativityScore),
    clampScore(scoringMetadata.objectiveCompletenessScore),
  ];
  const rawCriteria = Array.isArray(geminiResult.nilaiKriteria)
    ? geminiResult.nilaiKriteria
    : [];
  const aiCriteriaScores = [0, 1, 2].map((index) =>
    clampScore(rawCriteria[index], aiScore));
  const hybridCriteriaScores = [0, 1, 2].map((index) =>
    Math.round(objectiveScores[index] * 0.75 + aiCriteriaScores[index] * 0.25));
  const fallbackWeights = level === 1 ? [40, 30, 30] : [35, 40, 25];
  const storedCriteria = Array.isArray(instrumentData.criteria)
    ? instrumentData.criteria
    : [];
  const weights = [0, 1, 2].map((index) => {
    const weight = Number(storedCriteria[index]?.weight);
    return Number.isFinite(weight) && weight >= 0
      ? weight
      : fallbackWeights[index];
  });
  const totalWeight = weights.reduce((total, weight) => total + weight, 0);
  let score = totalWeight > 0
    ? Math.round(hybridCriteriaScores.reduce(
      (total, criterionScore, index) => total + criterionScore * weights[index], 0) / totalWeight)
    : 0;

  const objectiveNotes = [];
  const uniqueColorCount = Number(scoringMetadata.uniqueColorCount);
  const fillPercentage = Number(scoringMetadata.fillPercentage);
  if (Number.isFinite(uniqueColorCount) && uniqueColorCount <= 1) {
    objectiveNotes.push("Komposisi masih menggunakan satu warna sehingga variasi dan kreativitas warnanya belum terlihat kuat.");
  }
  if (Number.isFinite(fillPercentage)) {
    if (fillPercentage <= 0) {
      score = 0;
      objectiveNotes.push("Bidang anyaman belum diwarnai.");
    } else if (fillPercentage < 0.10) {
      score = Math.min(score, 15);
      objectiveNotes.push("Bilah yang diwarnai masih sangat sedikit.");
    } else if (fillPercentage < 0.25) {
      score = Math.min(score, 30);
      objectiveNotes.push("Bilah yang diwarnai masih kurang dari seperempat pola.");
    } else if (fillPercentage < 0.50) {
      score = Math.min(score, 50);
      objectiveNotes.push("Bilah yang diwarnai belum mencapai setengah pola.");
    } else if (fillPercentage < 0.75) {
      score = Math.min(score, 70);
      objectiveNotes.push("Pewarnaan pola belum cukup lengkap.");
    }
  }

  const aiFeedback = geminiResult.feedback || "Karya sudah dinilai oleh AI.";
  return {
    score,
    grade: calculateGrade(score),
    feedback: objectiveNotes.length > 0
      ? `${aiFeedback} ${objectiveNotes.join(" ")}`
      : aiFeedback,
    details: {
      objectiveRulesApplied: true,
      scoringVersion: scoringMetadata.scoringVersion || "anyaman_hybrid_v2",
      scoreBeforeObjectiveRules: aiScore,
      aiCriteriaScores,
      objectiveCriteriaScores: objectiveScores,
      hybridCriteriaScores,
      criteriaWeights: weights,
      uniqueColorCount: Number.isFinite(uniqueColorCount) ? uniqueColorCount : null,
      fillPercentage: Number.isFinite(fillPercentage) ? fillPercentage : null,
      dominantColorRatio: scoringMetadata.dominantColorRatio,
      colorBalance: scoringMetadata.colorBalance,
      colorRichness: scoringMetadata.colorRichness,
      patternConsistency: scoringMetadata.patternConsistency,
      transitionRatio: scoringMetadata.transitionRatio,
    },
  };
}


/**
 * Helper: Panggil Gemini API dengan image base64 dan prompt.
 * Menggunakan @google/generative-ai SDK dengan API key dari .env atau config.
 */
async function callGeminiAPI(imageBase64, prompt, modelName) {
  // Gunakan process.env (modern .env) atau fallback ke functions.config() (legacy)
  const apiKey = process.env.GEMINI_API_KEY || functions.config().gemini?.apikey;
  if (!apiKey) {
    throw new Error("Gemini API key tidak dikonfigurasi. Tambahkan GEMINI_API_KEY ke file functions/.env lalu deploy ulang.");
  }

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({
    model: modelName || "gemini-2.5-flash-lite",
    generationConfig: {
      temperature: 0.2,
      responseMimeType: "application/json",
      responseSchema: scoringSchema,
    },
  });

  const result = await model.generateContent([
    { text: prompt },
    {
      inlineData: {
        mimeType: "image/jpeg",
        data: imageBase64,
      },
    },
  ]);

  const text = result.response.text().trim();
  
  // Bersihkan markdown code block jika ada
  let cleaned = text;
  if (cleaned.startsWith("```json")) cleaned = cleaned.substring(7);
  if (cleaned.startsWith("```")) cleaned = cleaned.substring(3);
  if (cleaned.endsWith("```")) cleaned = cleaned.substring(0, cleaned.length - 3);
  cleaned = cleaned.trim();

  try {
    return JSON.parse(cleaned);
  } catch (e) {
    console.error("JSON parse failed. Raw text:", text, "Cleaned text:", cleaned);
    throw new Error(`JSON parse error: ${e.message}. Raw text: ${text}`);
  }
}

// callGeminiAPIWithUserToken() dihapus.
// Server tidak lagi menyimpan atau membaca OAuth token user dari Firestore.
// Semua operasi server menggunakan callGeminiAPI() dengan Server API Key.


/**
 * Helper: Fetch gambar dari URL dan konversi ke base64.
 */
async function fetchImageAsBase64(imageUrl) {
  const https = require("https");
  const http = require("http");
  
  return new Promise((resolve, reject) => {
    const protocol = imageUrl.startsWith("https") ? https : http;
    protocol.get(imageUrl, (res) => {
      const chunks = [];
      res.on("data", (chunk) => chunks.push(chunk));
      res.on("end", () => {
        const buffer = Buffer.concat(chunks);
        resolve(buffer.toString("base64"));
      });
      res.on("error", reject);
    }).on("error", reject);
  });
}



// calculateGrade is declared once at the top of the file.

/**
 * 1. Cloud Function: Trigger saat Guru Diverifikasi (Notifikasi Email)
 */
exports.onGuruVerified = functions.firestore
  .document("guru_verifikasi/{requestId}")
  .onUpdate(async (change, _context) => {
    const newValue = change.after.data();
    const previousValue = change.before.data();

    // Pastikan status berubah
    if (previousValue.status !== newValue.status) {
      const guruUid = newValue.guruUid;

      try {
        const userDoc = await db.collection("users").doc(guruUid).get();
        if (!userDoc.exists) {
          console.log(`[onGuruVerified] User doc not found for UID: ${guruUid}`);
          return;
        }

        const userData = userDoc.data();
        const guruEmail = userData.email;
        const guruNama = userData.namaLengkap || userData.nama || 'Guru';

        if (newValue.status === "approved") {
          const mailOptions = {
            from: "Admin EPIC <noreply@epic.com>",
            to: guruEmail,
            subject: "✅ Verifikasi Guru Disetujui — EPIC App",
            html: `
              <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; background: #f8fafc; border-radius: 12px;">
                <div style="background: #2563EB; padding: 20px; border-radius: 8px 8px 0 0; text-align: center;">
                  <h1 style="color: white; margin: 0; font-size: 24px;">EPIC App</h1>
                  <p style="color: #BFDBFE; margin: 4px 0 0;">Ecocultural Pattern Innovation Creator</p>
                </div>
                <div style="background: white; padding: 32px; border-radius: 0 0 8px 8px; border: 1px solid #E2E8F0;">
                  <h2 style="color: #0F172A; margin-top: 0;">Selamat, ${guruNama}! 🎉</h2>
                  <p style="color: #475569; line-height: 1.6;">
                    Akun Anda telah <strong>disetujui sebagai Guru</strong> di aplikasi EPIC.
                    Sekarang Anda dapat:
                  </p>
                  <ul style="color: #475569; line-height: 2;">
                    <li>✅ Membuat dan mengelola kelas</li>
                    <li>✅ Memantau perkembangan murid</li>
                    <li>✅ Melihat karya dan skor murid</li>
                    <li>✅ Berbagi kode kelas ke murid</li>
                  </ul>
                  <p style="color: #64748B; font-size: 14px; margin-top: 24px; padding-top: 16px; border-top: 1px solid #E2E8F0;">
                    Jika Anda tidak merasa mendaftar sebagai guru di EPIC, abaikan email ini.
                  </p>
                </div>
              </div>
            `,
          };

          if (transporter) {
            await transporter.sendMail(mailOptions);
            console.log(`[onGuruVerified] Email persetujuan berhasil dikirim ke ${guruEmail} untuk ${guruNama}`);
          } else {
            console.log(`[onGuruVerified] (MOCK APPROVED) Email persetujuan ke ${guruEmail} untuk ${guruNama}`);
          }

        } else if (newValue.status === "rejected") {
          const catatanAdmin = newValue.catatanAdmin || 'Dokumen yang dilampirkan kurang lengkap atau tidak sesuai.';
          const mailOptions = {
            from: "Admin EPIC <noreply@epic.com>",
            to: guruEmail,
            subject: "⚠️ Peninjauan Verifikasi Guru — EPIC App",
            html: `
              <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; background: #f8fafc; border-radius: 12px;">
                <div style="background: #DC2626; padding: 20px; border-radius: 8px 8px 0 0; text-align: center;">
                  <h1 style="color: white; margin: 0; font-size: 24px;">EPIC App</h1>
                  <p style="color: #FCA5A5; margin: 4px 0 0;">Ecocultural Pattern Innovation Creator</p>
                </div>
                <div style="background: white; padding: 32px; border-radius: 0 0 8px 8px; border: 1px solid #E2E8F0;">
                  <h2 style="color: #0F172A; margin-top: 0;">Halo, ${guruNama}</h2>
                  <p style="color: #475569; line-height: 1.6;">
                    Terima kasih telah mengajukan permohonan verifikasi sebagai Guru di aplikasi EPIC. 
                    Setelah dilakukan peninjauan terhadap dokumen bukti mengajar yang Anda unggah, mohon maaf permohonan Anda saat ini <strong>belum dapat disetujui</strong>.
                  </p>
                  <div style="background: #FEF2F2; border-left: 4px solid #EF4444; padding: 16px; margin: 20px 0; border-radius: 4px;">
                    <strong style="color: #991B1B; display: block; margin-bottom: 4px;">Catatan Peninjau / Alasan:</strong>
                    <p style="color: #7F1D1D; margin: 0; line-height: 1.5;">${catatanAdmin}</p>
                  </div>
                  <p style="color: #475569; line-height: 1.6;">
                    Silakan masuk kembali ke aplikasi EPIC untuk mengunggah ulang bukti mengajar yang sah dan mengajukan kembali permohonan verifikasi Anda.
                  </p>
                  <p style="color: #64748B; font-size: 14px; margin-top: 24px; padding-top: 16px; border-top: 1px solid #E2E8F0;">
                    Jika Anda memiliki pertanyaan, silakan hubungi admin aplikasi melalui email bantuan di halaman status verifikasi aplikasi Anda.
                  </p>
                </div>
              </div>
            `,
          };

          if (transporter) {
            await transporter.sendMail(mailOptions);
            console.log(`[onGuruVerified] Email penolakan berhasil dikirim ke ${guruEmail} untuk ${guruNama}`);
          } else {
            console.log(`[onGuruVerified] (MOCK REJECTED) Email penolakan ke ${guruEmail} untuk ${guruNama}. Alasan: ${catatanAdmin}`);
          }
        }
      } catch (error) {
        console.error("Error memproses trigger email:", error);
      }
    }
  });

/**
 * 2. Cloud Function: Re-Score AI (Gemini) — REAL SCORING
 * Menggunakan Gemini Vision API dengan instrumen dari Firestore.
 */
exports.rescoreArtwork = functions
  .runWith({ timeoutSeconds: 120, memory: "512MB", secrets: ["GEMINI_API_KEY"] })
  .https.onCall(async (data, context) => {
    // Hanya user terautentikasi bisa memanggil
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Request tidak memiliki token otentikasi."
      );
    }

    if (!(await isAdmin(context.auth.uid))) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Hanya administrator yang boleh melakukan penilaian ulang."
      );
    }

    const artworkId = data.artworkId;
    if (!artworkId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Harap sertakan artworkId."
      );
    }

    let artworkRef = null;
    try {
      // Ambil data artwork
      artworkRef = db.collection("artworks").doc(artworkId);
      const artworkDoc = await artworkRef.get();

      if (!artworkDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Karya tidak ditemukan.");
      }

      const artworkData = artworkDoc.data();
      const uid = artworkData.uid;

      // Otorisasi: hanya pemilik karya atau admin yang boleh memanggil re-score
      const callerUid = context.auth.uid;
      if (callerUid !== uid) {
        const callerIsAdmin = await isAdmin(callerUid);
        if (!callerIsAdmin) {
          throw new functions.https.HttpsError("permission-denied", "Hanya pemilik karya atau admin yang boleh melakukan re-score.");
        }
      }

      const kategori = artworkData.kategori || "batik";
      const level = parseInt(artworkData.level) || 1;
      const imageUrl = artworkData.imageUrl || artworkData.gambarUrl;
      const waktuPengerjaan = artworkData.waktuPengerjaan || 0;

      if (!imageUrl) {
        throw new functions.https.HttpsError("failed-precondition", "Artwork tidak memiliki URL gambar.");
      }

      // Ambil instrumen penilaian dari Firestore
      const instrumentDoc = await db
        .collection("app_config")
        .doc("game_settings")
        .collection("instruments")
        .doc(`${kategori}_${level}`)
        .get();

      const storedInstrument = instrumentDoc.exists ? instrumentDoc.data() : getDefaultInstrument(kategori, level);
      const instrumentData = normalizeInstrumentData(storedInstrument, kategori, level);
      const modelName = instrumentData?.modelAI || "gemini-2.5-flash-lite";

      // Build prompt dari instrumen
      const prompt = buildScoringPrompt(instrumentData, waktuPengerjaan);

      // Fetch gambar dan konversi ke base64
      console.log(`Fetching image for artwork ${artworkId}: ${imageUrl.substring(0, 80)}...`);
      const imageBase64 = await fetchImageAsBase64(imageUrl);

      // Admin re-score selalu menggunakan Server API Key.
      // Per-user quota ditangani di client-side (mobile app) saat murid scoring pertama kali.
      console.log(`[rescoreArtwork] Calling Gemini (${modelName}) for artwork ${artworkId} using Server API Key...`);
      const geminiResult = await callGeminiAPI(imageBase64, prompt, modelName);

      const resolvedResult = applyAnyamanHybridScoring(
        geminiResult,
        instrumentData,
        null
      );
      const finalSkor = resolvedResult.score;
      const finalGrade = resolvedResult.grade;
      const finalFeedback = resolvedResult.feedback;

      console.log(`Gemini result for ${artworkId}: skor=${finalSkor}, grade=${finalGrade}`);

      // Hitung multiplier & poin
      let multiplier = 1.0;
      if (level === 2) multiplier = 1.5;
      else if (level === 3) multiplier = 2.0;
      else if (level >= 4) multiplier = 3.0;

      const poinDapat = Math.round(finalSkor * multiplier);

      // Gunakan Firestore transaction untuk update atomik
      const result = await db.runTransaction(async (transaction) => {
        // --- Semua READ dulu ---
        let userDoc = null;
        let userRef = null;
        let progressDoc = null;
        let progressRef = null;

        if (uid) {
          userRef = db.collection("users").doc(uid);
          userDoc = await transaction.get(userRef);

          if (userDoc.exists) {
            progressRef = db.collection("users").doc(uid).collection("game_progress").doc(kategori);
            progressDoc = await transaction.get(progressRef);
          }
        }

        // --- Semua WRITE setelah ---

        // Update artwork dengan hasil Gemini
        transaction.update(artworkRef, {
          skorAI: finalSkor,
          grade: finalGrade,
          poinDapat: poinDapat,
          feedback: finalFeedback,
          detailPenilaian: resolvedResult.details,
          status: "dinilai",
          modelUsed: modelName,
          scoredAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Update user progress & poin
        if (uid && userRef && userDoc && userDoc.exists && progressRef && progressDoc) {
          let levels = {};
          if (progressDoc.exists && progressDoc.data() != null) {
            levels = progressDoc.data().levels || {};
          }

          const levelKey = `${level}`;
          const currentBestSkor = (levels[levelKey] && levels[levelKey].bestSkor) || 0;
          const currentBestPoin = (levels[levelKey] && levels[levelKey].bestPoin) || 0;

          if (finalSkor > currentBestSkor) {
            levels[levelKey] = {
              bestSkor: finalSkor,
              bestPoin: poinDapat,
              unlocked: true,
              completedAt: admin.firestore.Timestamp.now(),
            };

            // Unlock level berikutnya jika skor >= 60
            if (finalSkor >= 60 && level < 4) {
              const nextLevelKey = `${level + 1}`;
              const nextLevelData = levels[nextLevelKey] || {};
              levels[nextLevelKey] = { ...nextLevelData, unlocked: true };
            }

            transaction.set(progressRef, {
              kategori: kategori,
              levels: levels,
              updatedAt: admin.firestore.Timestamp.now(),
            }, { merge: true });
          }

          if (poinDapat > currentBestPoin) {
            const selisihPoin = poinDapat - currentBestPoin;
            transaction.update(userRef, {
              poin: admin.firestore.FieldValue.increment(selisihPoin),
              gameSelesai: admin.firestore.FieldValue.increment(1),
            });
          }
        }

        return { finalSkor, finalGrade, poinDapat, finalFeedback };
      });

      return {
        success: true,
        message: "Re-score AI berhasil dilakukan",
        skor: result.finalSkor,
        grade: result.finalGrade,
        poinDapat: result.poinDapat,
        feedback: result.finalFeedback,
        modelUsed: modelName,
      };

    } catch (error) {
      console.error("Error rescoreArtwork:", error);
      // Jika Gemini quota habis, tandai karya sebagai pending (akan di-retry otomatis atau manual)
      if (error && error.message && error.message.startsWith("QUOTA_EXCEEDED")) {
        try {
          if (artworkRef) {
            await artworkRef.update({
              status: "pending",
              pendingRescoreAt: admin.firestore.FieldValue.serverTimestamp(),
              pendingRescoreReason: error.message,
            });
          }
        } catch (uErr) {
          console.error("Failed marking pending:", uErr);
        }

        return {
          success: true,
          pending: true,
          message: "Gemini quota exceeded: artwork marked as pending. Will be auto-retried or can be manually re-scored by admin.",
        };
      }

      throw new functions.https.HttpsError("internal", error.message || String(error));
    }
  });

/**
 * 3. Cloud Function: Test Sandbox AI (untuk Admin Panel)
 * Menilai gambar dari base64 tanpa menyimpan ke database.
 * Digunakan oleh fitur "Test Sandbox" di halaman instrumen penilaian.
 */
exports.testSandboxScoring = functions
  .runWith({ timeoutSeconds: 120, memory: "512MB", secrets: ["GEMINI_API_KEY"] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Tidak terautentikasi.");
    }

    const callerIsAdmin = await isAdmin(context.auth.uid);
    if (!callerIsAdmin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Hanya administrator yang boleh melakukan pengetesan sandbox."
      );
    }

    const { imageBase64, instrumentId, criteriaList, systemInstruction, modelAI } = data;

    if (!imageBase64) {
      throw new functions.https.HttpsError("invalid-argument", "imageBase64 diperlukan.");
    }

    try {
      // Buat instrumen sementara dari parameter yang dikirim
      const tempInstrument = {
        konteksBudaya: systemInstruction || "Seni budaya Madura.",
        materiMatematika: "Konsep matematika sesuai level.",
        criteria: Array.isArray(criteriaList) ? criteriaList : [],
      };

      // Jika ada instrument ID, coba ambil dari Firestore
      if (instrumentId) {
        const instrDoc = await db
          .collection("app_config")
          .doc("game_settings")
          .collection("instruments")
          .doc(instrumentId)
          .get();

        if (instrDoc.exists) {
          const instrData = instrDoc.data();
          const [instrumentCategory = "", instrumentLevel = "1"] = instrumentId.split("_");
          const normalizedInstrument = normalizeInstrumentData(
            instrData,
            instrumentCategory,
            Number(instrumentLevel) || 1
          );
          tempInstrument.kategori = normalizedInstrument.kategori;
          tempInstrument.level = normalizedInstrument.level;
          tempInstrument.konteksBudaya = normalizedInstrument.konteksBudaya || tempInstrument.konteksBudaya;
          tempInstrument.materiMatematika = normalizedInstrument.materiMatematika || tempInstrument.materiMatematika;
          tempInstrument.systemInstruction = normalizedInstrument.systemInstruction || systemInstruction || "";
          if (Array.isArray(normalizedInstrument.criteria) && normalizedInstrument.criteria.length > 0) {
            tempInstrument.criteria = normalizedInstrument.criteria;
          }
        }
      }

      const prompt = buildScoringPrompt(tempInstrument, 0);
      const modelName = modelAI || "gemini-2.5-flash-lite";

      console.log(`Sandbox test with model ${modelName}, criteria count: ${tempInstrument.criteria.length}`);
      const geminiResult = await callGeminiAPI(imageBase64, prompt, modelName);

      const resolvedResult = applyAnyamanHybridScoring(
        geminiResult,
        tempInstrument,
        null
      );
      const finalSkor = resolvedResult.score;
      const finalGrade = resolvedResult.grade;
      const finalFeedback = resolvedResult.feedback || "Penilaian AI selesai.";

      return {
        success: true,
        skor: finalSkor,
        grade: finalGrade,
        feedback: finalFeedback,
        modelUsed: modelName,
        detailPenilaian: resolvedResult.details,
      };

    } catch (error) {
      console.error("Error testSandboxScoring:", error);
      if (error.message && error.message.startsWith("QUOTA_EXCEEDED")) {
        throw new functions.https.HttpsError("resource-exhausted", error.message);
      }
      throw new functions.https.HttpsError("internal", error.message);
    }
  });

/**
 * 4. Cloud Function: Evaluate Artwork (untuk Mobile App)
 * Menilai gambar karya dari base64. Mendukung per-user quota dengan fallback ke Server API Key.
 */
exports.evaluateArtwork = functions
  .runWith({
    timeoutSeconds: 120,
    memory: "512MB",
    enforceAppCheck: true,
    secrets: ["GEMINI_API_KEY"],
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Request tidak memiliki token otentikasi."
      );
    }

    const { imageBase64, kategori, level, waktuPengerjaan, scoringMetadata } = data;
    if (!imageBase64 || !kategori || !level) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Harap sertakan imageBase64, kategori, dan level."
      );
    }

    try {
      const uid = context.auth.uid;

      // Ambil instrumen penilaian dari Firestore
      const instrumentDoc = await db
        .collection("app_config")
        .doc("game_settings")
        .collection("instruments")
        .doc(`${kategori}_${level}`)
        .get();

      const storedInstrument = instrumentDoc.exists ? instrumentDoc.data() : getDefaultInstrument(kategori, level);
      const instrumentData = normalizeInstrumentData(storedInstrument, kategori, level);
      const modelName = instrumentData?.modelAI || "gemini-2.5-flash-lite";

      const prompt = buildScoringPrompt(instrumentData, waktuPengerjaan || 0, scoringMetadata);

      // Client fallback ke Cloud Function → gunakan Server API Key.
      // Catatan: Path utama scoring murid dilakukan di client-side (kuota murid sendiri).
      // Cloud Function hanya dipanggil jika client-side scoring gagal (token null/expired).
      console.log(`[evaluateArtwork] Calling Gemini (${modelName}) for user ${uid} using Server API Key (client fallback)...`);
      const geminiResult = await callGeminiAPI(imageBase64, prompt, modelName);

      const hybridResult = applyAnyamanHybridScoring(
        geminiResult,
        instrumentData,
        scoringMetadata
      );
      const finalSkor = hybridResult.score;
      const finalGrade = hybridResult.grade;
      const finalFeedback = hybridResult.feedback;

      return {
        success: true,
        skor: finalSkor,
        grade: finalGrade,
        feedback: finalFeedback,
        modelUsed: modelName,
        detailPenilaian: hybridResult.details,
      };

    } catch (error) {
      console.error("Error evaluateArtwork function:", error);
      throw new functions.https.HttpsError("internal", error.message || String(error));
    }
  });

/**
 * 5. Cloud Function: Transcribe Audio (untuk Evaluasi Siswa)
 * Menerima audio base64 (format m4a/mp4/aac) dan mentranskripsikannya ke bahasa Indonesia menggunakan Gemini.
 */
exports.transcribeAudio = functions
  .runWith({
    timeoutSeconds: 60,
    memory: "512MB",
    enforceAppCheck: true,
    secrets: ["GEMINI_API_KEY"],
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Request tidak memiliki token otentikasi."
      );
    }

    const { audioBase64, mimeType } = data;
    if (!audioBase64) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Harap sertakan audioBase64."
      );
    }

    try {
      const apiKey = process.env.GEMINI_API_KEY || functions.config().gemini?.apikey;
      if (!apiKey) {
        throw new Error("Gemini API key tidak dikonfigurasi.");
      }

      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({
        model: "gemini-2.5-flash-lite",
      });

      const prompt = "Dengarkan rekaman audio suara anak sekolah dasar berikut ini. Transkripsikan apa yang diucapkan secara akurat ke dalam teks bahasa Indonesia. Berikan HANYA teks transkripnya saja tanpa tanda kutip, tanpa kata pengantar, tanpa penjelasan, dan tanpa format markdown apa pun. Jika suara kurang jelas, tulis apa yang terdengar sebaik mungkin.";

      const result = await model.generateContent([
        { text: prompt },
        {
          inlineData: {
            mimeType: mimeType || "audio/mp4",
            data: audioBase64,
          },
        },
      ]);

      const transcript = result.response.text().trim();
      return {
        success: true,
        transcript: transcript,
      };
    } catch (error) {
      console.error("Error transcribeAudio function:", error);
      throw new functions.https.HttpsError("internal", error.message || String(error));
    }
  });
