const fs = require('fs');
const path = require('path');
const os = require('os');
const https = require('https');

function getRequest(url, accessToken) {
  return new Promise((resolve, reject) => {
    const parsedUrl = new URL(url);
    const options = {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
      }
    };
    
    const req = https.request(parsedUrl, options, (res) => {
      let responseBody = '';
      res.on('data', (chunk) => responseBody += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(responseBody));
        } catch (e) {
          reject(new Error(`Failed to parse JSON: ${responseBody}`));
        }
      });
    });
    
    req.on('error', reject);
    req.end();
  });
}

async function run() {
  try {
    const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
    if (!fs.existsSync(configPath)) {
      throw new Error(`Config file not found at ${configPath}`);
    }
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    const accessToken = config.tokens && config.tokens.access_token;
    if (!accessToken) {
      throw new Error("No access token found in firebase-tools.json");
    }
    
    console.log("Using access token from config to fetch users...");
    const usersRes = await getRequest('https://firestore.googleapis.com/v1/projects/epic-app1/databases/(default)/documents/users', accessToken);
    const users = usersRes.documents || [];
    console.log(`\n=== USERS (Total: ${users.length}) ===`);
    
    const roles = {};
    for (const uDoc of users) {
      const fields = uDoc.fields || {};
      const uid = uDoc.name.split('/').pop();
      const role = fields.role ? fields.role.stringValue : 'no-role';
      const name = fields.namaLengkap ? fields.namaLengkap.stringValue : (fields.nama ? fields.nama.stringValue : 'No Name');
      const email = fields.email ? fields.email.stringValue : 'No Email';
      const sekolah = fields.sekolah ? fields.sekolah.stringValue : 'No School';
      
      roles[role] = (roles[role] || 0) + 1;
      console.log(`* ${name} (${email}) - Role: ${role}, School: ${sekolah}, UID: ${uid}`);
    }
    console.log("Roles breakdown:", roles);
    
    console.log("\nFetching classes...");
    const classRes = await getRequest('https://firestore.googleapis.com/v1/projects/epic-app1/databases/(default)/documents/kelas', accessToken);
    const classes = classRes.documents || [];
    console.log(`=== CLASSES (Total: ${classes.length}) ===`);
    for (const cDoc of classes) {
      const fields = cDoc.fields || {};
      const cid = cDoc.name.split('/').pop();
      const name = fields.namaKelas ? fields.namaKelas.stringValue : (fields.nama ? fields.nama.stringValue : 'No Name');
      const guruUid = fields.guruUid ? fields.guruUid.stringValue : (fields.guruId ? fields.guruId.stringValue : 'No Guru');
      const school = fields.sekolah ? fields.sekolah.stringValue : 'No School';
      console.log(`* Class: ${name} (ID: ${cid}) - Taught by Guru UID: ${guruUid}, School: ${school}`);
    }

    console.log("\nFetching artworks...");
    const artworksRes = await getRequest('https://firestore.googleapis.com/v1/projects/epic-app1/databases/(default)/documents/artworks', accessToken);
    const artworks = artworksRes.documents || [];
    console.log(`=== ARTWORKS (Total: ${artworks.length}) ===`);
    for (const aDoc of artworks.slice(0, 5)) {
      const fields = aDoc.fields || {};
      const aid = aDoc.name.split('/').pop();
      const status = fields.status ? fields.status.stringValue : 'no-status';
      const uid = fields.uid ? fields.uid.stringValue : 'no-uid';
      const kelasId = fields.kelasId ? fields.kelasId.stringValue : 'no-kelasId';
      const date = fields.createdAt ? (fields.createdAt.timestampValue || fields.createdAt.stringValue) : 'no-date';
      console.log(`* Artwork: ${aid} - Status: ${status}, Student UID: ${uid}, Class ID: ${kelasId}, Date: ${date}`);
    }

  } catch (e) {
    console.error("Error:", e.message || e);
  }
}

run();
