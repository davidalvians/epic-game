const admin = require("firebase-admin");
admin.initializeApp({
  projectId: "epic-app1"
});
const db = admin.firestore();

async function check() {
  try {
    const uid = "zVCG97MGTeP2NndgA7D3IWjgJNe2";
    console.log("Checking admin document for UID:", uid);
    
    const adminDoc = await db.collection("admins").doc(uid).get();
    if (adminDoc.exists) {
      console.log("Found admin doc:", adminDoc.data());
    } else {
      console.log("Admin doc not found!");
    }

    const userDoc = await db.collection("users").doc(uid).get();
    if (userDoc.exists) {
      console.log("Found user doc:", userDoc.data());
    } else {
      console.log("User doc not found!");
    }
  } catch (e) {
    console.error("Error:", e);
  }
}

check();
