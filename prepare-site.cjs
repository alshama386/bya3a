const fs = require('fs');
const path = require('path');
const root = __dirname;
const manifest = require('./flat-files.json');
for (const [flat, original] of Object.entries(manifest)) {
  if (flat.startsWith('brand/')) {
    const target = path.join(root, 'public', 'brand', flat.slice(6));
    fs.mkdirSync(path.dirname(target), {recursive: true});
    fs.copyFileSync(path.join(root, flat), target);
  } else if (flat !== original) {
    const target = path.join(root, original);
    fs.mkdirSync(path.dirname(target), {recursive: true});
    fs.copyFileSync(path.join(root, flat), target);
  }
}
console.log('BYA3A: restored Next.js routes and public assets for build.');
