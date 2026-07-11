const fs = require('fs');
const path = require('path');
const os = require('os');

const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
console.log("Reading config from:", configPath);
try {
  if (fs.existsSync(configPath)) {
    const content = fs.readFileSync(configPath, 'utf8');
    const config = JSON.parse(content);
    console.log("User email:", config.user ? config.user.email : "no-user");
    if (config.tokens) {
      console.log("Has tokens: true");
      // Print the refresh token or write it to a temp file for auth
      const refreshToken = config.tokens.refresh_token;
      console.log("Refresh token starts with:", refreshToken ? refreshToken.substring(0, 10) : "none");
    }
  } else {
    console.log("Config file does not exist at:", configPath);
  }
} catch (e) {
  console.error("Error reading config:", e);
}
