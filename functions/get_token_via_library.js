const { UserRefreshClient } = require('google-auth-library');
const fs = require('fs');
const path = require('path');
const os = require('os');

const CLIENT_ID = '763842602717-n5s7cc27m7381ui7g7io1f0jo1248o4t.apps.googleusercontent.com';
const CLIENT_SECRET = 'd-23S4547qfT24e5261u724e';

async function main() {
  try {
    const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
    if (!fs.existsSync(configPath)) {
      throw new Error(`Config file not found at ${configPath}`);
    }
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    const refreshToken = config.tokens && config.tokens.refresh_token;
    if (!refreshToken) {
      throw new Error("No refresh token found");
    }

    const client = new UserRefreshClient(
      CLIENT_ID,
      CLIENT_SECRET,
      refreshToken
    );

    const creds = await client.refreshAccessToken();
    console.log("SUCCESS");
    console.log("Access token starts with:", creds.credentials.access_token.substring(0, 10));
  } catch (e) {
    console.error("Error exchanging token:", e);
  }
}

main();
