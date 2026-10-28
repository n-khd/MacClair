# Périmètre et prochaines étapes

MacClair est un projet indépendant. Sa couverture ne correspond pas encore à celle de CleanMyMac : les fonctions marquées à venir dans l’interface ne sont pas des analyses ou des protections actives. Les fonctionnalités du produit de référence varient selon son édition et sa version ; voir sa [matrice officielle](https://macpaw.com/support/cleanmymac/knowledgebase/missing-features).

## Priorités

1. **Résultats fiables et vérifiables.** Décrire les dossiers parcourus, les exclusions et erreurs ; tester les liens symboliques, les fichiers modifiés pendant l’analyse et les systèmes de fichiers volumineux. Les opérations sur les fichiers doivent rester explicites et réversibles.
2. **Nettoyage et confidentialité.** Étendre d’abord les inventaires en lecture seule, puis étudier catégorie par catégorie les risques et les possibilités de restauration avant d’autoriser une action. Les caches et Mail Downloads ne représentent pas l’ensemble des données des navigateurs ni des messages Mail.
3. **Applications et performances.** Concevoir un inventaire et une association prudente des fichiers liés aux apps ; ne pas supprimer automatiquement des données partagées. Examiner ensuite les mises à jour d’apps et les éléments de démarrage avec les API système appropriées.
4. **Protection.** Un état FileVault ou Gatekeeper ne constitue pas un antivirus. Un moteur fiable exige un choix de technologie, des sources de signatures, des mises à jour, des tests de détection et de faux positifs et une maintenance continue. Aucune détection ou surveillance malware n’est actuellement proposée.
5. **Cloud, moniteurs et autres outils.** Étudier séparément les autorisations, les données en ligne, les limites des fournisseurs et la sécurité des opérations avant de proposer synchronisation, nettoyage distant ou surveillance continue.

La parité ne peut être affirmée qu’après avoir défini une version et une édition de référence, puis validé chaque fonction par des tests représentatifs et des essais sur différentes versions de macOS. Les comportements déduits d’un binaire sont distincts des fonctionnalités observées et ne prouvent pas leur fonctionnement complet ; voir [REVERSE_ENGINEERING.md](REVERSE_ENGINEERING.md).
