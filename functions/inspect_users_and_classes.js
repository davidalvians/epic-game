const admin = require("firebase-admin");
admin.initializeApp({
  projectId: "epic-app1"
});
const db = admin.firestore();

async function inspectDb() {
  try {
    console.log("=== INSPECTING FIRESTORE DATA ===");

    // 1. Check users
    const usersSnap = await db.collection("users").get();
    console.log(`Total users in 'users' collection: ${usersSnap.size}`);
    
    const roles = {};
    usersSnap.forEach(doc => {
      const data = doc.data();
      const role = data.role || 'no-role';
      roles[role] = (roles[role] || 0) + 1;
      if (role === 'guru') {
        console.log(`- Guru: ${data.namaLengkap || data.nama} (uid: ${doc.id}), sekolah: ${data.sekolah}`);
      }
    });
    console.log("Roles breakdown:", roles);

    // 2. Check classes
    const classSnap = await db.collection("kelas").get();
    console.log(`\nTotal classes in 'kelas' collection: ${classSnap.size}`);
    classSnap.forEach(doc => {
      const data = doc.data();
      console.log(`- Class: ${data.namaKelas || data.nama} (id: ${doc.id}), guruUid: ${data.guruUid || data.guruId}, murid count: ${Array.isArray(data.muridIds) ? data.muridIds.length : 0}`);
    });

    // 3. Check artworks
    const artworksSnap = await db.collection("artworks").get();
    console.log(`\nTotal artworks in 'artworks' collection: ${artworksSnap.size}`);
    if (artworksSnap.size > 0) {
      const sample = artworksSnap.docs[0].data();
      console.log("- Sample artwork fields:", Object.keys(sample));
      console.log(`- Sample artwork uid: ${sample.uid}, kelasId: ${sample.kelasId}, createdAt: ${sample.createdAt ? sample.createdAt.toDate() : 'no-date'}`);
    }

  } catch (e) {
    console.error("Error inspecting database:", e);
  }
}

inspectDb();
