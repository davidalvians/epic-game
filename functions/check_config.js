const admin = require('firebase-admin');
admin.initializeApp({
  projectId: 'epic-app1'
});
const db = admin.firestore();

async function checkConfig() {
  try {
    const doc = await db.collection('app_config').doc('system_settings').get();
    if (!doc.exists) {
      console.log('Document does not exist!');
    } else {
      console.log('Document data:', doc.data());
    }
  } catch (err) {
    console.error('Error reading document:', err);
  }
}
checkConfig();
