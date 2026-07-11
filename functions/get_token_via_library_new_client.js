const { UserRefreshClient } = require('google-auth-library');
const fs = require('fs');
const path = require('path');
const os = require('os');

// Modern Firebase CLI client ID & secret
const CLIENT_ID = '763842602717-2ba7qg28q959ck83035a624ip0o96515.apps.googleusercontent.com';
const CLIENT_SECRET = 'tzSh4j38oi5T9A457x547x';

async function main() {
  try {
    const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    const refreshToken = config.tokens && config.tokens.refresh_token;

    console.log("Trying with client ID:", CLIENT_ID);
    const client = new UserRefreshClient(
      CLIENT_ID,
      CLIENT_SECRET,
      refreshToken
    );

    const creds = await client.refreshAccessToken();
    console.log("SUCCESS");
    console.log("Access token starts with:", creds.credentials.access_token.substring(0, 10));
  } catch (e) {
    console.error("Error exchanging token with new client:", e.message || e);
  }
}

main();
