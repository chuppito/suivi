# Suivi Nutrition & Corps — prototype Flutter 0.1

## Installation Codespaces
1. Créer un dépôt GitHub privé et déposer le contenu de ce dossier.
2. Ouvrir un Codespace. Installer Flutter stable et les outils Android SDK (ou utiliser GitHub Actions pour compiler sans configurer le SDK dans Codespaces).
3. Dans le terminal : `flutter create --platforms=android .` puis `flutter pub get`, `flutter analyze`, `flutter test`.
4. Pousser sur `main` ou lancer **Actions → Compiler APK Android → Run workflow**.
5. Télécharger l'artefact `suivi-nutrition-apk`. APK non signé avec votre clé personnelle (signature de développement/release Flutter par défaut) : usage de test uniquement.

## Utilisation
- **Mesures** : bouton Ajouter ; toucher une mesure pour modifier date, poids, taille ou note. Les dates approximatives de l'historique sont signalées.
- **Repas** : ajouter, photographier, saisir les valeurs estimées et les incertitudes. Toucher pour corriger ; menu pour dupliquer ou retirer la photo sans effacer les macros.
- **Compléments** : cocher les prises du jour ; icône crayon pour modifier la dose. C1000 est inactif.
- **Plus** : exporter un JSON ou restaurer un JSON (remplacement intégral).

## Limites importantes de cette version
- La reconnaissance IA n'est pas implémentée ; aucune clé ni requête réseau.
- La base alimentaire, le calcul automatique des macros, les objectifs personnalisés, le bilan hebdomadaire, les moyennes mobiles et les graphiques de taille restent à développer.
- L'export JSON ne contient pas les fichiers photos : leurs chemins locaux ne sont pas transférables. La sauvegarde complète avec photos n'est pas encore implémentée.
- Les compléments ne sont pas automatiquement intégrés au total nutritionnel ; éviter les doubles saisies.
- L'interface de modification ne valide pas encore strictement toutes les dates et plages de valeurs.
- Les photos retirées de la fiche ne sont pas encore supprimées physiquement du stockage.
- Aucun test de compilation n'a été exécuté dans cet environnement : vérifier avec `flutter analyze` et `flutter test`.
- L'historique initial n'est importé que lorsque la table de mesures est vide.

## Confidentialité
Stockage local SQLite et photos dans le répertoire privé. Attention aux sauvegardes partagées et aux copies dans les services cloud. Pas de serveur d'analyse IA dans cette version.
