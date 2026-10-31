# Lot 5 bis — renommage global contrôlé Windows

Lancement explicite le **31 octobre 2026**, après retour utilisateur « Tout fonctionne
correctement » sur le dernier build. Version autorisée **0.6.0**, puis 0.6.1, etc.
Android reste en pause, JSON/Lot 5 ter non lancé. Aucun nouveau package runtime.

## Décisions et livrable

- Cœur partagé `Mp3Renamer`, callback de plateforme `RenameFile` ; adaptateur Windows
  `renameMp3` sur le canal existant `index/local_folders`. Android/SAF devra implémenter
  ce contrat et ses propres contrôles de permissions ; aucune qualification Android.
- Source d’autorité : noms du journal intégré à SQLite. Analyse fraîche du dossier,
  récursivité choisie dans Fichiers. Même matching exact NFC/casse que le scan,
  aucun COMM/ID3 exploité pour l’association. Un nom ne certifie pas le contenu audio.
- Conversion exclusive nom historique → TITRE SYSTEME. Noms déjà conformes inchangés,
  inconnus, doublons, exclusions, autres choix manuels, fichiers utilisés par le lecteur,
  noms Windows invalides/réservés et chemins trop longs exclus et expliqués.
- Aperçu en lecture seule pour les MP3, liste sélectionnable avant/après et comptes ;
  aucune conversion avant le bouton de confirmation globale. Un bouton explicite
  met en pause/libère la piste en conservant son suivi, puis recalcule l’aperçu. Nouveau contrôle complet
  des associations au moment de confirmer, empreinte et métadonnées revérifiées.
- Publication dans le même dossier via MoveFileExW(WRITE_THROUGH), sans REPLACE_EXISTING,
  sans copie intervolume. Refus natif d’une cible concurrente, source régulière uniquement.
  Collision prévisible en NFC/casse, y compris avec fichiers non sélectionnés.
- Empreintes SHA-256 en flux, sans charger un MP3 entier en mémoire : lecture à l’aperçu,
  avant tentative et après déplacement/récupération. Cette sûreté implique plusieurs
  lectures et peut prendre plusieurs minutes sur un grand dossier/disque lent.
- Schéma utilisateur **v6**, migration transactionnelle v5 → v6 ; seed documentaire
  livré **v4 inchangé**. Pas de régénération documentaire ni changement d’identité.
  `rename_runs` / `rename_items` dans la base utilisateur (et donc ses sauvegardes).
- Journal avant tentative, puis état moving durable avant l’appel natif. Une réussite
  met à jour le chemin/nom local et les diagnostics dans la transaction qui marque
  succeeded. Préserver lien manuel, état d’écoute, favori et identifiant documentaire.
- Arrêt applicatif normal attend le travail avant sauvegarde. Résultat natif incertain :
  arrêter le lot, réconcilier et marquer les éléments non tentés skipped ; pas de
  prétendue transaction globale sur le disque, pas de rollback automatique des MP3.

## Interruption et portabilité

Au démarrage, après migration/réévaluation des chemins portables et avant tout scan,
réconciliation du journal : source absente + cible régulière à l’empreinte attendue →
réparer le lien ; source intacte + cible absente → tentative non effectuée. Deux noms,
fichier changé, absence des deux ou disque inaccessible → blocked, aucune mutation de
fichier. Les scans/nouvelles opérations de renommage restent bloqués tant que le
résultat est ambigu. Le panneau permet une nouvelle tentative de réconciliation et
montre les erreurs. Les éléments planned ne sont pas exécutés automatiquement : il
faut refaire l’aperçu puis confirmer. Les historiques suivent les chemins internes si
l’ensemble du dossier IndeX est déplacé, comme les associations existantes.

Les permissions et changements externes peuvent faire échouer un élément après
l’aperçu ; l’erreur est conservée et aucun fichier cible n’est remplacé. La vérification
ne protège pas contre un autre programme malveillant modifiant les fichiers au même
instant ; elle vise les changements et interruptions ordinaires. Garder une copie de
ses MP3 reste possible ; IndeX n’en crée pas une seconde collection.

## Tests et recette

Tests automatisés sur copies temporaires uniquement : aperçu sans effet et annulation,
confirmation UI, vrai MP3 témoin dont les empreintes restent identiques, suivi/favoris,
lien manuel, idempotence, collisions/casse/doublons, récursivité, exclusion explicite,
source modifiée, cible apparue après aperçu, refus de permission simulé, fichier
chargé, interruption simulée après mouvement et réouverture SQLite, résultat ambigu.
Le smoke test Windows ajoute les appels natifs : succès, refus d’écrasement et refus
de changer de dossier. Les tests de version vérifient 0.6.0 → 0.6.1 et la conservation
du compteur 0.5 dans un dépôt Git temporaire, sans réservation réelle de distribution.

La compilation et la recette natives Windows doivent encore être exécutées par la CI,
puis sur le paquet : droits réels/antivirus, lecteur WinRT chargé, chemins accentués,
source sur support amovible, fermeture/coupure et réouverture, grande collection.
Les contrôles Linux ne constituent pas une qualification Windows. Android non testé.

## Vérifications exécutées le 31 octobre

Sur Linux avec Flutter 3.47.7 / Dart 3.13.5 :

```sh
. /workspace/toolchains/activate-flutter.sh
bash tools/lot4/check.sh
dart test test/mp3_rename_test.dart --reporter expanded
```

Suite complète : **215 tests du cœur, 52 tests Flutter et 6 tests Python réussis**,
analyses statiques et formatage conformes. Puis ajout du scénario explicite de
migration v5 → v6 (tous les champs du suivi et le lien manuel préservés) : suite
ciblée **11 tests réussis**, dont ce nouveau test, soit **216 tests distincts du cœur**
vérifiés au total. La syntaxe du script d’empaquetage modifié est contrôlée avec
PowerShell 7.5.4. Aucun MP3 du dépôt modifié, aucune réservation de numéro CI réelle,
aucune compilation/recette native Windows revendiquée. Le test Flutter couvre
également la libération explicite du lecteur, avec maintien de la reprise, puis le
renommage confirmé. Le test de session couvre la récupération d’un journal après
déplacement de toute la racine portable, sans scan préalable.
