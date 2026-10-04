// Une image fixe d'un schéma animé, à un instant donné : pour vérifier un
// SVG sans attendre qu'il tourne. Chrome charge le SVG, saute à l'instant
// voulu, et capture.
//
//   node docs/tools/image.js <schema.svg> <sortie.png> <secondes>
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');

const [, , entree, sortie, instant] = process.argv;
const CHROME = process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const svg = fs.readFileSync(entree, 'utf8');
const [, l, h] = svg.match(/viewBox="0 0 (\d+) (\d+)"/);
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'image-'));
const page = path.join(temp, 'page.html');
fs.writeFileSync(page, `<!doctype html><meta charset="utf-8"><style>*{margin:0}body{background:#0D1117}</style>${svg}
<script>const s=document.querySelector('svg');s.pauseAnimations();s.setCurrentTime(${Number(instant) || 0});</script>`);
execFileSync(CHROME, ['--headless=new', '--disable-gpu', '--hide-scrollbars', `--window-size=${l},${h}`,
  `--screenshot=${path.resolve(sortie)}`, 'file:///' + page.split('\\').join('/')], { stdio: 'ignore' });
fs.rmSync(temp, { recursive: true, force: true });
console.log(`  ${path.basename(sortie)}  à ${instant}s`);
