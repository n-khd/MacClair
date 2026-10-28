# Contribuer à MacClair

Merci de contribuer ! Pour un changement important, ouvre d'abord une issue pour en discuter. Pour un bug, précise la version de MacClair, de macOS et les étapes permettant de le reproduire, sans partager de données personnelles.

## Développement

Sur macOS 14 ou plus récent, installe Xcode ou les outils en ligne de commande Apple avec Swift 6, puis exécute :

```sh
./test.sh
./build-app.sh
open dist/MacClair.app
```

La compilation locale est signée ad hoc et n'inclut pas nécessairement Sparkle. Crée une branche, apporte un changement ciblé, lance les tests et ouvre une pull request en décrivant le problème, la solution et les vérifications effectuées.

## Sécurité des fichiers

Les analyses doivent rester en lecture seule. Tout déplacement doit rester explicite et limité aux fichiers admissibles dans Téléchargements, avec confirmation et contrôles avant l'opération. Les tests utilisent des dossiers temporaires : ne teste jamais une modification destructive sur des données personnelles. Ajoute des tests pour les cas limites quand tu modifies le scanner ou les protections.

Pour une vulnérabilité, utilise la procédure privée décrite dans [SECURITY.md](SECURITY.md), pas une issue publique.
