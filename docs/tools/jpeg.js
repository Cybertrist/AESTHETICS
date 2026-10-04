// Convertit un PNG en JPEG par un canvas de Chrome, pour passer sous la
// limite d'un mégaoctet que GitHub impose à l'aperçu social.
//
//   node docs/tools/jpeg.js <entrée.png> <sortie.jpg> [qualité]
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const [, , entree, sortie, qualite] = process.argv;
const CHROME =
  process.env.CHROME ||
  'C:/Program Files/Google/Chrome/Application/chrome.exe';

const temp = fs.mkdtempSync(path.join(require('os').tmpdir(), 'jpeg-'));
const page = path.join(temp, 'page.html');
const png = fs.readFileSync(entree).toString('base64');
fs.writeFileSync(
  page,
  `<!doctype html><body><script>
const img = new Image();
img.onload = () => {
  const c = document.createElement('canvas');
  c.width = img.width;
  c.height = img.height;
  c.getContext('2d').drawImage(img, 0, 0);
  document.body.textContent = c.toDataURL('image/jpeg', ${Number(qualite) || 0.92});
};
img.src = 'data:image/png;base64,${png}';
</script></body>`,
);
const dom = execFileSync(
  CHROME,
  ['--headless=new', '--disable-gpu', '--virtual-time-budget=5000', '--dump-dom',
    'file:///' + page.replace(/\\/g, '/')],
  { maxBuffer: 64 * 1024 * 1024 },
).toString();
fs.rmSync(temp, { recursive: true, force: true });
const donnees = dom.match(/data:image\/jpeg;base64,([A-Za-z0-9+/=]+)/);
if (!donnees) throw new Error('Échec de la conversion : ' + entree);
fs.writeFileSync(sortie, Buffer.from(donnees[1], 'base64'));
