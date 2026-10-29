# Contribuer à MacClair

Merci d'être là. MacClair est une petite application macOS — environ 4 400 lignes de Swift, aucune
dépendance, un seul script de compilation — donc pas de semaine d'échauffement : vous pouvez
changer quelque chose de réel dans la première heure.

**English :** [CONTRIBUTING.md](CONTRIBUTING.md).

Vous débutez ? Prenez une issue marquée [`good first issue`](https://github.com/n-khd/MacClair/labels/good%20first%20issue)
et dites bonjour dedans. Personne ne trouvera la question déplacée.

## Comment aider, par ordre d'utilité

1. **Traduire.** L'interface est en français et en anglais ; une troisième langue, c'est surtout un
   fichier. Voir [docs/TRANSLATING.md](docs/TRANSLATING.md). Aucun code Swift nécessaire.
2. **Signaler un bug reproductible.** Une version, une version de macOS et les trois clics qui
   déclenchent le problème valent mieux qu'un paragraphe. Utilisez le formulaire d'issue.
3. **Tester sur votre Mac.** Un macOS 15, un Mac Intel, un compte non administrateur, un disque aux
   permissions bizarres : ce sont des cas que le mainteneur ne peut pas couvrir seul.
4. **Écrire du code.** Filtres, tri, tests, accessibilité, performance sur les gros dossiers.
5. **Améliorer la documentation.** Si une phrase de ce fichier vous a perdu, elle perdra la
   personne suivante.

## Première pull request en 20 minutes

```sh
# 1. Récupérer le code
gh repo clone n-khd/MacClair    # ou git clone https://github.com/n-khd/MacClair.git
cd MacClair

# 2. Compiler et lancer les tests (macOS 14+, Xcode ou les outils en ligne de commande avec Swift 6)
./test.sh                 # tests de fumée : scanner, sécurité Corbeille, audits, helper MCP
./build-app.sh            # produit dist/MacClair.app
open dist/MacClair.app

# 3. Branche, modification, tests, push
git checkout -b fix/doublons-dossiers-caches
./test.sh
git commit -m "fix: ignorer les dossiers caches dans le regroupement des doublons"
gh pr create --fill      # ou la pull request depuis le navigateur
```

La compilation locale est signée ad hoc et n'inclut pas Sparkle : c'est normal. La CI compile et
teste votre branche sur `macos-14` ; une CI rouge bloque la fusion, une CI verte ne remplace pas la
lecture du diff.

## Ce que lance la CI

`.github/workflows/ci.yml`, à chaque pull request :

| Étape | Commande | Ce qu'un échec signifie |
|---|---|---|
| Tests de fumée | `./test.sh` | Une régression dans le scanner, la sécurité Corbeille, un audit ou le MCP |
| Compilation | `./build-app.sh` | L'application ne compile plus sur un runner macOS propre |

`compile-check.yml` compile d'autres configurations ; `screenshots.yml` régénère les captures de la
documentation — inutile de les lancer.

## Carte du code

| Chemin | Rôle |
|---|---|
| `Sources/MacClair/Scanner.swift` | Inventaire des caches, journaux et vieux installateurs ; `Cleaner` le lance et déplace les éléments |
| `Sources/MacClair/SafeTrash.swift` | La porte de sécurité. Tout déplacement passe par `capture` → `validate` → `moveToTrash` |
| `Sources/MacClair/Insights.swift` | Gros fichiers, doublons, applications installées, instantanés système et sécurité |
| `Sources/MacClair/Audits.swift` | Répartition du stockage et éléments de démarrage — lecture seule |
| `Sources/MacClair/PrivacyAudits.swift` | Caches Safari / Chrome / Firefox, Mail Downloads — lecture seule |
| `Sources/MacClair/DeveloperAudits.swift` | Résidus Xcode, Docker et gestionnaires de paquets |
| `Sources/MacClair/ImageAudits.swift` | Détection d'images similaires, tolérante aux rotations |
| `Sources/MacClair/Uninstaller.swift` | Planificateur application + résidus, avec sa propre liste blanche |
| `Sources/MacClair/ModernContentView.swift` | Toute l'interface (SwiftUI) |
| `Sources/MacClair/Theme.swift` | Couleurs, panneaux, jauges, boutons — le système de design |
| `Sources/MacClair/CosmicOrb3DView.swift` | L'orbe SceneKit |
| `Sources/MacClair/Activity.swift` | Historique local des déplacements et de l'espace libéré |
| `Sources/MacClair/Updater.swift` | Sparkle, compilé seulement si le framework est présent |
| `Sources/MacClairMCP/main.swift` | Serveur MCP embarqué (stdio JSON-RPC) |
| `Sources/MacClairSnapshot/main.swift` | Génère les captures d'écran des README |

Flux de données et invariants à respecter : [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Règles non négociables

Ce sont le produit lui-même, pas des détails d'implémentation. Une pull request qui en casse une
sera renvoyée, même si la fonctionnalité est séduisante.

1. **Rien n'est effacé définitivement.** Tout passe par la Corbeille macOS, via `SafeTrash`.
2. **Les déplacements restent dans `~/Downloads`** et ne touchent que des fichiers ordinaires. Les
   liens symboliques, dossiers cachés, paquets (`*.app`), composants Git internes et tout ce qui
   sort de ce périmètre sont refusés.
3. **L'utilisateur confirme.** Aucun nettoyage automatique ou en arrière-plan, jamais. Le serveur
   MCP ne peut déplacer un fichier qu'après un jeton préparé *et* le chemin exact confirmé.
4. **Analyses en lecture seule.** Un inventaire peut signaler et refuser ; il ne modifie jamais ce
   qu'il lit.
5. **Aucun réseau, aucune télémétrie, aucun compte.** La seule requête sortante de l'application
   est la vérification de mise à jour Sparkle, signée.
6. **Les erreurs sont remontées, pas avalées.** Un dossier illisible est affiché avec son chemin —
   un résultat partiel est annoncé comme partiel.

## Conventions

- Chaîne d'outils Swift 6, compilée en `-swift-version 5` ; cible `macOS 14+`. Pas de dépendance :
  aucun paquet SwiftPM n'est ajouté sans une issue préalable.
- **Localisation :** les chaînes françaises sont les clés. Quand vous ajoutez du texte d'interface,
  ajoutez la paire dans `Resources/en.lproj/Localizable.strings`. Ne traduisez jamais les chemins,
  identifiants de bundle ni noms de fichiers.
- **Les tests sont de simples exécutables**, pas du XCTest : `Tests/<Suite>Smoke.swift` avec une
  `@main struct` qui lève une erreur en cas d'échec, compilée par la boucle de `test.sh`. Pour
  ajouter une suite : le fichier, plus une ligne dans cette boucle. Toujours des dossiers
  temporaires, jamais un vrai dossier personnel.
- Préférez des valeurs typées (`CleanupItem`, `TrashCandidate`) aux dictionnaires et aux tuples.
- Un commentaire explique *pourquoi* (une vérification de sécurité, une bizarrerie de macOS), pas
  *ce que* fait la ligne suivante.

## Commits et pull requests

- Branches : `fix/…`, `feat/…`, `docs/…`, `i18n/…`.
- Messages : `fix: …`, `feat: …`, `docs: …`, `i18n: …`, un changement logique par commit. Français
  ou anglais, les deux vont.
- Une pull request = un sujet. Un nettoyage sans rapport va dans une autre PR.
- Remplissez le modèle de pull request : ce qui change, comment vous avez testé, la liste de
  contrôle sécurité.
- Pas de CLA, aucune cession de droits. Votre contribution est publiée sous licence MIT et vous
  gardez le crédit.

## Quand la compilation résiste

| Symptôme | Cause | Solution |
|---|---|---|
| La CI reste en file 10 à 15 min puis affiche « cancelled » | Capacité des runners macOS arm64 chez GitHub | Relancez le job depuis l'onglet Actions. Votre branche n'y est pour rien. |
| `xcrun: error: unable to find utility "swiftc"` | Seuls les outils en ligne de commande sont installés, ou `xcode-select` pointe ailleurs | `xcode-select --install`, ou `sudo xcode-select -s /Applications/Xcode.app` |
| `error: package manifest requires Swift 6.0` | Xcode antérieur à 16 | Mettez Xcode à jour, ou lancez `./test.sh`, qui appelle `swiftc` directement sans lire `Package.swift` |
| `Sparkle absent : compilation sans mise à jour automatique` | Normal en local | L'updater n'est compilé que si `vendor/Sparkle.framework` existe |
| L'application s'ouvre dans la mauvaise langue | La préférence `macclair.language` est conservée | **MacClair › Langue / Language**, ou `defaults delete local.macclair.app macclair.language` |

Toujours bloqué ? Ouvrez une discussion avec la commande lancée et l'erreur complète : un échec de
compilation signalé est une contribution, pas un dérangement.

## Revue

Le mainteneur relit au mieux, en général sous une semaine. Vous pouvez recevoir « pas maintenant »
ou « hors périmètre » : c'est une question de cap du produit (voir [ROADMAP.md](ROADMAP.md)), pas
de votre travail. Si une PR reste sans réponse deux semaines, relancez dans la PR — ce n'est pas
impoli, c'est utile.

## Sécurité et comportement

- Vulnérabilité : suivez [SECURITY.md](SECURITY.md), jamais une issue publique.
- Comportement : [CODE_OF_CONDUCT.md](.github/CODE_OF_CONDUCT.md).
- Questions et idées floues : [Discussions](https://github.com/n-khd/MacClair/discussions).
