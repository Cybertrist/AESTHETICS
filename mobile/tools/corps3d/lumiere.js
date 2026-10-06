// Réglages de la composition (lumière, volume, fibres, coutures).
export const LUMIERE = {
  ilotMm: 16, // îlots de région plus petits que ce carré supprimés
  majoriteMm: 3.5,
  flouMm: 6,
  coussinFlouMm: 5, coussinFlouPasses: 2,
  coussinMinMm: 3, coussinMaxMm: 28, coussinPart: 0.7, coussinHauteur: 1.3,
  masqueMinPx: 30,
  ouvertureMm: 2.5,
  epaisseurMinMm: 4, // demi-largeur minimale d une région
  fibrePasMm: 2.2, fibrePasPx: 2.6, // écart des fibres : en mm, et au moins en pixels de sortie
  shader: {
    lumiere1: [-0.25, 0.65, 0.75], fort1: 0.72,
    lumiere2: [0.45, 0.1, 0.9], fort2: 0.18,
    ambiant: 0.30, albedo: 0.78,
    satin: 0.04, satinExp: 12,
    coussinPente: 1.0,
    aoForce: 0.8, aoRayonMm: 22,
    fibreForce: 0.22,
    traitMm: 1.0, traitForce: 1.0,
    ombreBord: 0.18, rimForce: 0.9,
    gamma: 1.0,
  },
};
