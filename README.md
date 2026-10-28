# MacClair

MacClair est une application macOS libre, en français, pour examiner l’espace disque et déplacer prudemment des fichiers personnels vers la Corbeille. L’interface s’inspire de la catégorie des utilitaires de nettoyage Mac, mais le code, les textes et l’icône sont originaux. La version actuelle **ne possède pas toutes les fonctionnalités de CleanMyMac** et n’a pas subi le même niveau de validation.

![Icône MacClair](Assets/MacClair-icon.png)

## Télécharger

Trois façons, au choix :

**Homebrew** (mises à jour gérées par `brew upgrade`)

```sh
brew install --cask najmabdi7/tap/macclair
```

**DMG** — téléchargez `MacClair-<version>-macOS-arm64.dmg` depuis la page [Releases](../../releases), ouvrez l’image et glissez `MacClair` dans le dossier Applications.

**Zip** — téléchargez `MacClair-<version>-macOS-arm64.zip`, décompressez-le et déplacez `MacClair.app` dans le dossier Applications.

Ces archives sont prévues pour les Mac Apple Silicon sous macOS 14 ou plus récent. Le code source est également téléchargeable depuis la même page.

### Signature et notarisation

Les archives à partir de la version 0.5.1 (zip et DMG) sont signées avec un certificat **Developer ID Application** et **notariées par Apple** ; le ticket de notarisation est agrafé dans l’application. macOS doit donc l’ouvrir sans aucun avertissement Gatekeeper et sans réglage particulier.

Pour vérifier l’intégrité du téléchargement, comparez la somme SHA-256 de l’archive avec le fichier `SHA256SUMS` de la même release :

```sh
shasum -a 256 MacClair-0.5.2-macOS-arm64.dmg
```

Les builds sont produits par le workflow GitHub Actions `.github/workflows/release-notarized.yml` (compilation, signature Developer ID, notarisation Apple, agrafage, contrôle `spctl`, publication). L’archive 0.5.0, plus ancienne, était seulement signée ad hoc et nécessitait un contournement manuel de Gatekeeper.

## Fonctions disponibles

- Vue d’ensemble et analyses locales.
- Inventaire en lecture seule des caches et journaux du compte utilisateur, de l’état des protections macOS, des applications, des agents de démarrage, du stockage et des dossiers cloud présents localement.
- Liste des gros fichiers, des installateurs, des doublons exacts et des images ressemblantes avec noms et chemins réels.
- Préparation automatique des copies supplémentaires des doublons, avec une copie conservée par groupe et confirmation unique avant déplacement.
- Déplacement vers la Corbeille des fichiers sélectionnés, uniquement dans `~/Downloads`.
- Télescope pour examiner un dossier choisi, sans suivre les liens symboliques.

Certaines sections affichent « À venir » lorsque leur fonction n’est pas implémentée. Voir [l’analyse des fonctions](REVERSE_ENGINEERING.md) pour le périmètre actuel.

## Utiliser les doublons

1. Ouvrez **Mes fichiers inutiles** et lancez l’analyse.
2. Dans **Doublons**, cliquez sur **Nettoyer les doublons en lot…**. MacClair prépare les copies en trop et conserve une copie de chaque groupe.
3. Examinez les noms et chemins, puis confirmez le déplacement vers la Corbeille. Les groupes répartis entre plusieurs dossiers ou situés dans des projets sont ignorés par défaut.

## Sécurité et limites

MacClair n’efface aucun fichier système et n’exécute aucune commande de maintenance. Le déplacement vers la Corbeille est limité aux fichiers ordinaires dans `~/Downloads`. Avant l’opération, l’application contrôle notamment le chemin, le type de fichier, l’inode, le volume, la taille et la date de modification. Les liens symboliques, les dossiers cachés, les composants internes de dépôts Git et les paquets d’applications sont rejetés. Les caches et journaux ne sont jamais supprimés par MacClair.

Ces contrôles réduisent le risque sans garantir une sécurité absolue. L’application n’est pas auditée ni notariée et ne protège pas encore de manière atomique contre toutes les modifications concurrentes du système de fichiers. Vérifiez la sélection avant de confirmer et gardez une sauvegarde de vos données importantes.

## Compiler et tester

Prérequis : macOS 14 ou plus récent et Xcode ou les outils de ligne de commande Apple avec Swift 6. La compilation utilise le SDK macOS installé localement et cible l’architecture du Mac utilisé.

```sh
./test.sh
./build-app.sh
open dist/MacClair.app
```

L’application compilée se trouve dans `dist/MacClair.app`. Le script applique une signature ad hoc pour le développement local. Il ne réalise ni signature Developer ID ni notarisation.

## Participer

Les problèmes et propositions peuvent être ouverts dans les issues GitHub. Le code et les ressources de ce dépôt sont distribués sous [licence MIT](LICENSE). MacClair est un projet indépendant et n’est pas affilié à MacPaw.
