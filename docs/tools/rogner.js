// Prépare les captures d'écran brutes de l'appareil pour le dépôt.
//
//   node docs/tools/rogner.js <dossier source> <dossier de destination> [largeur]
//
// La source porte les captures telles que l'émulateur les rend, et un
// barres.txt : la hauteur de la barre d'état, puis l'ordonnée où commence
// la barre de navigation, en pixels. Les deux sont retirées : l'heure, le
// réseau et la batterie n'ont rien à faire sur une page de présentation.
//
// Chaque image est ensuite réduite à 720 points de large, ou à la largeur
// donnée en troisième argument pour un écran à l'horizontale, et écrite en
// JPEG : une capture brute pèse un mégaoctet et demi, la version réduite
// quinze fois moins, sans différence visible à la taille où la page
// l'affiche. Le travail se fait dans un canvas de Chrome sans affichage,
// pour ne dépendre d'aucune bibliothèque d'image.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const [, , source, dest, largeur] = process.argv;
const CHROME =
  process.env.CHROME ||
  'C:/Program Files/Google/Chrome/Application/chrome.exe';
const LARGEUR = Number(largeur) || 720;

const [haut, bas] = fs
  .readFileSync(path.join(source, 'barres.txt'), 'utf8')
  .trim()
  .split(/\s+/)
  .map(Number);

fs.mkdirSync(dest, { recursive: true });
const temp = fs.mkdtempSync(path.join(require('os').tmpdir(), 'rogner-'));

for (const nom of fs.readdirSync(source).filter((f) => f.endsWith('.png'))) {
  const png = fs.readFileSync(path.join(source, nom)).toString('base64');
  const page = path.join(temp, 'page.html');
  fs.writeFileSync(
    page,
    `<!doctype html><body><script>
const img = new Image();
img.onload = () => {
  const h = ${bas} - ${haut};
  const echelle = ${LARGEUR} / img.width;
  const c = document.createElement('canvas');
  c.width = ${LARGEUR};
  c.height = Math.round(h * echelle);
  const g = c.getContext('2d');
  g.imageSmoothingQuality = 'high';
  g.drawImage(img, 0, ${haut}, img.width, h, 0, 0, c.width, c.height);
  document.body.textContent = c.toDataURL('image/jpeg', 0.9);
};
img.src = 'data:image/png;base64,${png}';
</script></body>`,
  );
  const dom = execFileSync(
    CHROME,
    [
      '--headless=new',
      '--disable-gpu',
      '--virtual-time-budget=5000',
      '--dump-dom',
      'file:///' + page.replace(/\\/g, '/'),
    ],
    { maxBuffer: 64 * 1024 * 1024 },
  ).toString();
  const donnees = dom.match(/data:image\/jpeg;base64,([A-Za-z0-9+/=]+)/);
  if (!donnees) throw new Error('Échec du rognage : ' + nom);
  const sortie = path.join(dest, nom.replace(/\.png$/, '.jpg'));
  fs.writeFileSync(sortie, Buffer.from(donnees[1], 'base64'));
  console.log('  ' + path.basename(sortie) + '  ' +
    (fs.statSync(sortie).size / 1024).toFixed(0) + ' Ko');
}
fs.rmSync(temp, { recursive: true, force: true });
