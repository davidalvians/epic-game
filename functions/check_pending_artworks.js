const admin = require("firebase-admin");
admin.initializeApp({
  projectId: "epic-app1"
});
const db = admin.firestore();

async function checkPending() {
  try {
    console.log("Querying artworks...");
    const snapshot = await db.collection("artworks")
      .limit(10)
      .get();
      
    if (snapshot.empty) {
      console.log("No artworks found in collection.");
      return;
    }
    
    snapshot.forEach(doc => {
      const data = doc.data();
      console.log(`\nArtwork ID: ${doc.id}`);
      console.log(`- Status: ${data.status}`);
      console.log(`- Kategori: ${data.kategori}, Level: ${data.level}`);
      console.log(`- User: ${data.uid}`);
      console.log(`- Poin: ${data.poinDapat}, SkorAI: ${data.skorAI}`);
      console.log(`- Feedback: ${data.feedback}`);
      console.log(`- Pending Rescore Reason: ${data.pendingRescoreReason}`);
      console.log(`- Error: ${data.error || data.errorMessage}`);
    });
  } catch (e) {
    console.error("Error:", e);
  }
}

checkPending();
