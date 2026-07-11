const fs = require('fs');
const path = require('path');
const os = require('os');

const adcPath = path.join(os.homedir(), 'AppData', 'Roaming', 'gcloud', 'application_default_credentials.json');
console.log("Checking ADC at:", adcPath);
if (fs.existsSync(adcPath)) {
  console.log("ADC file exists! Size:", fs.statSync(adcPath).size);
} else {
  console.log("ADC file does NOT exist.");
}
