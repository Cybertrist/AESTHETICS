// Recadre et agrandit une image : node recadre.js image x y l h echelle sortie.png
const { ouvrir, ecrireDataUrl } = require('./serveur');
const path = require('path');
(async () => {
  const [img, x, y, w, h, k, out] = process.argv.slice(2);
  const rel = path.relative(path.join(__dirname, '..', '..'), path.resolve(img)).split(path.sep).join('/');
  const { page, fermer } = await ouvrir('vide.html', 100, 100);
  const url = await page.evaluate(async (src, x, y, w, h, k) => {
    const im = new Image(); im.src = src; await im.decode();
    const c = document.createElement('canvas'); c.width = w * k; c.height = h * k;
    const g = c.getContext('2d'); g.imageSmoothingQuality = 'high';
    g.drawImage(im, x, y, w, h, 0, 0, w * k, h * k); return c.toDataURL();
  }, '/' + rel, +x, +y, +w, +h, +k);
  ecrireDataUrl(url, out); await fermer();
})();
