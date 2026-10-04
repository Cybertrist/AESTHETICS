// La version anglaise d'une figure : chaque texte de la page française est
// cherché dans anglais.json et remplacé. Un texte absent du dictionnaire
// est signalé, et la commande échoue : une figure anglaise ne garde jamais
// une phrase française par oubli.
//
//   node docs/tools/traduire.js <page.html> <page-en.html>
//   node docs/tools/traduire.js --liste <page.html>    les textes à traduire
const fs = require('fs');
const path = require('path');

const DICO = require('./anglais.json');

/// Un texte qui n'a pas besoin de traduction : un nombre, une couleur, une
/// version, et dans une page HTML un nom d'icône en minuscules. Les
/// schémas SVG n'ont pas d'icône en texte : tout mot y est vérifié.
const neutre = (s, html) =>
  !/[a-zà-ÿ]/i.test(s) || /^v\d/.test(s) || /^#[0-9A-F]{6}$/.test(s) || (html && /^[a-z0-9_]+$/.test(s));

/// Traduit un texte, ou le renvoie tel quel s'il est neutre. [manque]
/// reçoit ce qui n'est pas dans le dictionnaire.
function traduire(s, manque, html = false) {
  const t = s.trim();
  if (!t) return s;
  if (Object.prototype.hasOwnProperty.call(DICO, t)) {
    // L'espace qui précède « : » ou « ; » en français n'existe pas en
    // anglais : « chiffrée deux fois</b> : en… » devient « twice</b>: with… ».
    const en = s.replace(t, DICO[t]);
    return /^[:;]/.test(DICO[t]) ? en.replace(/^\s+/, '') : en;
  }
  if (!neutre(t, html)) manque.add(t);
  return s;
}

/// Les nœuds de texte d'une page, hors <style>, <script> et <title>.
function parcourir(html, f) {
  return html.replace(/(<(style|script|title)\b[\s\S]*?<\/\2>)|(<[^>]+>)|([^<]+)/g, (m, bloc, _n, balise, texte) =>
    texte !== undefined ? f(texte) : m);
}

if (require.main === module) {
  const args = process.argv.slice(2);
  if (args[0] === '--liste') {
    const manque = new Set();
    parcourir(fs.readFileSync(args[1], 'utf8'), (s) => traduire(s, manque, true));
    for (const s of manque) console.log(s);
    process.exit(0);
  }
  const [entree, sortie] = args;
  const manque = new Set();
  let html = parcourir(fs.readFileSync(entree, 'utf8'), (s) => traduire(s, manque, true));
  html = html.replace('<html lang="fr">', '<html lang="en">').replace(/(\d) Mo\b/g, '$1 MB');
  if (manque.size) {
    console.error(`  Absent de anglais.json (${path.basename(entree)}) :`);
    for (const s of manque) console.error('    ' + s);
    process.exit(1);
  }
  fs.writeFileSync(sortie, html);
}

module.exports = { traduire, neutre };
