/// Repère de version affiché dans Réglages.
///
/// L'app est distribuée par TestFlight à partir de builds déclenchés à la
/// main : sans ce repère, impossible de savoir depuis l'écran si un correctif
/// est réellement embarqué ou si l'appareil tourne encore sur l'ancien binaire.
/// À incrémenter à chaque changement dont on veut pouvoir confirmer la
/// présence sur l'appareil.
const kBuildMarker = 'r7 · sauvegardes et imports sécurisés';
