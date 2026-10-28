# Analyse de CleanMyMac 5.7.2

Source examinée : `/Applications/CleanMyMac_5.app`, identifiant
`com.macpaw.CleanMyMac5`, exécutable universel x86_64/arm64.

## Observations

- Le binaire principal SHA-256
  `b10ca6ef86f19998d1a26a112ad71bd8c1537efc869f9422819413686f4563ac`
  contient une tranche arm64. REA `inspect_macho` :
  `ev_b0694b530f669071bf024c2e6f37c4296fb63b0992aee807f9f28dc3fd19a9e4`.
- Le paquet contient des frameworks distincts, notamment
  `SystemJunkScanning`, `DownloadsScanning`, `TrashJunkScanning`,
  `ApplicationsModule`, `MalwareScanning` et `SpaceLensScanning`.
- Dans `SystemJunkScanning` SHA-256
  `d8c4978cb7f47437694fe778c7cab4a02f0fddadebe9dd7e0cc21993ac73690f`,
  REA/Hopper relève `CMCacheScanTask scan`, `contentOfCachesDirectoryURL` et
  des méthodes de recherche et de mesure des fichiers. Références :
  `ev_bfbf8a26ae1a6aab7a90834eb8941aec9f69293ef3d74acefea1c8644a98fa47`,
  `ev_4d65225fbe7b519d4da7b9ce5f3cce03d91d6e729431b706009f6d33d4d107d7`,
  `ev_528730d498c05276bc5361bebdb6b63b58d200664172f60197bcb73b9d379829`.
  Le pseudocode montre une énumération du dossier de caches, des prédicats
  d’ignorance et un résultat de scan. Il s’agit de reconstruction statique,
  pas d’une observation en exécution.

## Limites et choix de conception

REA indique que le fournisseur Ghidra est indisponible : `GHIDRA_INSTALL_DIR`
non configuré, Ghidra 12.1.x et Java absents. Le binaire universel doit aussi
être aminci pour l’import Ghidra. L’analyse native utilisée ici est donc celle
de Hopper via REA ; aucune analyse Ghidra n’est revendiquée.

Les noms de frameworks indiquent des domaines fonctionnels, mais n’établissent
pas à eux seuls leur comportement. Les règles « 30 jours », la sélection vide,
les contrôles avant déplacement et le recours à la Corbeille sont des choix
propres à MacClair, pas des comportements attribués à CleanMyMac.

## Analyse complémentaire des modules

REA a examiné les frameworks natifs de la version installée avec Hopper. Les références ci-dessous désignent les éléments de preuve REA ; elles corroborent l’existence de composants, sans certifier leur comportement complet.

| Section observée dans l’interface | Éléments REA | État de MacClair |
| --- | --- | --- |
| Entretien intelligent | `SmartCareModule` : `ev_006c7d92672e1d2b628c335193bcccdf5bf1e51b248de59f8ad2efbb396aada9` | Synthèse locale seulement |
| Nettoyage | `SystemJunkScanning` et `CleaningCore` : `ev_cdc0ee485a085f1477c1040a0b0958fdf31d64da586865e2b92a2ac82b323e17` | Caches et journaux en lecture seule ; anciens installateurs vers la Corbeille |
| Protection | `ProtectionModule` : `ev_e91c0513279b77f6aa433faac64ab4dd8132df7fca7a9d57e49eaf5d2e9e28f6` ; `MalwareScanning` : `ev_5ca9f509ca56801517b500aa1a6e7ffeea6ed460adab2de5123ff747a9558959` | État de protections macOS ; aucun moteur antimalware |
| Performances | `PerformanceModule` : `ev_dd3760b2ccdcc48f1e784c965c334080a8d7a4b94c1fb259d3b31410d0d0c0b3` | Indicateurs et inventaire des agents de démarrage |
| Applications | `ApplicationsModule` : désinstallation `ev_cb8078e3a3e1f61472a7d289bb7537cd81eb28306a604a08ea35a8f8f5feee24`, mises à jour `ev_15b6196108a80545d3b89db761ec8b5ba5df19dd7295f68a704236084fb885af`, résidus `ev_fb25427416f1f51e808da6717b27a383f263e3f6f9cc29466debc1a115fb3633` | Inventaire uniquement |
| Mes fichiers inutiles | `OrganizeModule` : doublons `ev_1da8e57409c258076a65ccfff4f1001c884a7a43f9a2fc1ce15db4f86173abbf`, images similaires `ev_82cad409d02b8dad666dac180c598c389bd0b7f37adf5dfcc5b8a4d98ecd9806` | Gros fichiers, doublons exacts, suggestions d’images ressemblantes, anciens installateurs |
| Télescope | `SpaceLensScanning` : `ev_ae25983436b5ae6e35b17d9c3ab6d9e2627802e237c5a519be72d90816b2cf54` | Classement en taille et fichiers cachés du dossier choisi, limité |
| Nettoyage cloud | `CloudStorageScanning` : iCloud `ev_39c490ae9994242e094e69a91b8cee4e48019d0fe0dc37e6d67a3cacb5fee5f8`, autres fournisseurs `ev_3994965cc41604ae1b9e489baa01db90a8bd81d8b5e29084560438f0bc6ac981` | Détection de dossiers locaux uniquement |

L’interface de CleanMyMac affiche aussi « Mes outils » et « Mon activité », ainsi que des sous fonctions telles que fichiers IA inutiles, pièces jointes Mail, confidentialité, permissions des applications, entretien du navigateur et e-mails. MacClair les signale explicitement comme indisponibles quand elles ne sont pas implémentées.

`CleaningCore` contient à la fois un mécanisme de suppression directe et `MoveToTrashFileRemover` (`ev_f5a842faadeba106322aa6a4dccc6abaf9da81cff39b721df6f546373cadd5d8`). Le choix de n’utiliser que la Corbeille dans MacClair est indépendant du fonctionnement de CleanMyMac.

L’interface de MacClair est une création originale en SwiftUI. Son illustration a été générée pour ce projet. Aucun code, graphisme ou service propriétaire de MacPaw n’a été incorporé.
