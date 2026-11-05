# IndeX

Série actuelle **0.7.01** (bêta, décision du 5 novembre 2026) ; numéro mineur réservé automatiquement à
chaque construction Windows distribuable. [Politique et compteur](tools/versioning/README.md).

[Lot 5 : architecture et lecteur](docs/lot5/bilan.md).
[Lot 5 bis : renommage, contrôles et recette Windows](docs/lot5bis/bilan.md).
[Lot 5 ter : transfert JSON et recette Windows](docs/lot5ter/bilan.md).

Projet d'application documentaire et de lecture locale pour Windows et Android,
en français, avec catalogue et écoute locale hors ligne. Le téléchargement d’un
MP3 manquant est facultatif et contacte le serveur source uniquement sur clic.

**État : Lot 6D validé fonctionnellement par l’utilisateur en 0.7.01 ; distribution à publier sur demande.**
Le dernier 6C est validé par l’utilisateur le 4 novembre.
Depuis le 5 novembre, Android utilise l’identifiant définitif `fr.index.app` :
installer la nouvelle application puis transférer le suivi par JSON et rechoisir
le dossier MP3 ; sauvegarder les MP3 privés avant de retirer l’ancienne. Le 6D ajoute un mode
release AOT signé, ses contrôles et son dossier de recette, sans publication.
[Bilan 6D](docs/lot6/bilan-6D.md), [guide de signature/distribution](docs/lot6/DISTRIBUTION_ANDROID.md)
et [fiche de recette](docs/lot6/RECETTE_6D.md). La recette et la mise à jour signée de 0.7.01 sont validées sur les appareils
consignés. La clé durable doit être conservée et les versions suivantes retestées.
Téléchargement SAF et transfert JSON disponibles ; renommage réservé à Windows.
L’emplacement « IndeX · MP3 » est retiré à partir de 0.7.01, sans accès
de récupération. Les MP3 utilisent le dossier visible choisi par l’utilisateur. Windows reste validé ; sa Release GitHub reste distincte.
Workflows manuels uniquement ; **Verification Android Lot 6D → Run workflow** :
mode diagnostic par défaut, ou release après configuration des secrets.
Compteur/verrou partagé Windows/Android, aucun déclenchement sur push.

L'application Flutter Windows portable reprend l'interface Éditorial, le catalogue,
la recherche FTS5 et les dossiers/associations. Le cœur Dart reste partagé. Le dernier build Windows du Lot 4 a été testé par l’utilisateur sans problème
apparent ni crash. Le Lot 5 ajoute le lecteur natif et Android ; leur qualification
sur les deux cibles reste distincte des tests Linux. La recette et les limites
sont détaillées dans le bilan du Lot 5.

Depuis le 28 octobre, le lecteur Windows utilise **just_audio + just_audio_windows**
(WinRT MediaPlayer), en remplacement de MCI. Android conserve MediaPlayer, désormais possédé par un service média ;
la lecture écran éteint et les commandes système du 6C sont validées par l’utilisateur.

Les derniers ajustements ajoutent une archive avec un unique lanceur visible,
une lettrine corrigée sur deux lignes, la navigation entre correspondances dans
les onglets et des alignements/couleurs harmonisés. Le dossier utilisateur et les
MP3 restent aux emplacements choisis. Au premier démarrage, `IndeX/user` est
présélectionné pour les données (modifiable). Les ouvertures suivantes vont
directement à la bibliothèque après chargement ; le scan automatique des MP3
peut être désactivé dans Paramètres. Leur dossier et la récursivité se règlent
dans Fichiers et associations, avec statistiques détaillées et ouverture du
dossier MP3 dans l’Explorateur. Le compteur sous filtres affiche visibles / total
du catalogue, sans rappel. Le diagnostic s’ouvre dans un panneau flottant ;
les associations peuvent être retirées après confirmation, avec suppression du
favori et du suivi de l’épisode, sans toucher au MP3. L’ouverture du dossier utilise l’API Windows avec le chemin cible.

Lorsqu’un MP3 manque, **Télécharger** remplace Écouter si le journal contient une
URL valide. Le dossier MP3 configuré est utilisé, ou demandé. Progression et
annulation sont affichées ; après réception et association, **Écouter** réapparaît.
Aucun MP3 n’est ajouté à la distribution.

Le panneau **À propos** présente la version du build et les fonctionnalités ;
son lien GitHub reste factice pour le moment. Dans Paramètres, décochez
**Scanner le dossier MP3 à chaque ouverture** pour désactiver le scan automatique.

Les données et MP3 situés dans IndeX suivent désormais le déplacement du dossier
entier, application fermée. Ouvrir une fois la mise à jour avant déplacement pour
convertir les anciens profils ; les dossiers extérieurs gardent leurs chemins.

- [Lot 4 : comportement, contrôles exécutés et validation Windows restante](docs/lot4/bilan.md)
- [Application Flutter Windows et construction portable](apps/index_windows/README.md)
- [Mode d'emploi Windows](docs/lot4/UTILISATION_WINDOWS.md)

La dernière révision de la maquette Éditorial, claire et sombre, a été validée le
25 octobre 2026 comme référence visuelle du Lot 4. Elle inclut les commandes de
fenêtre, les cadres Sources/Musiques révisés, la lettrine et les entrées des futurs
parcours de renommage et de transfert JSON dans Paramètres. Le lecteur HTML reste simulé.

- [Spécifications complémentaires Windows — Lot 4](docs/lot4/specifications.md)
- [Interface Éditorial validée pour le Lot 4 — HTML autonome et utilisation](docs/ui/README.md)
- [Lot 3 : recherche FTS5, extraits et validation](docs/lot3/bilan.md)
- [Lot 2 : catalogue, import, associations, migrations et anomalies](docs/lot2/bilan.md)
- [Rapport du corpus complet](docs/lot3/catalogue-report.json)
- [SQLite documentaire prérempli](assets/catalogue.sqlite)
- [Lot 1 : API, validation, dépendances et limites](docs/lot1/bilan.md)
- [Audit, architecture, dépendances, risques et recette](docs/lot0/conception.md)
- [Journal des décisions](docs/lot0/decisions.md)
- [Règle actuelle : association par noms du journal, sans COMM](docs/regle-association-noms-journal.md)
- [Résultats observés sur Linux](docs/lot0/audit-resultats.json)
- [Versions et licences des packages inspectés](docs/lot0/dependances-observees.json)
- [Cahier des charges V1.4 fourni](docs/Cahier_des_charges_IndeX_Codex_V1.4.md)

Depuis la décision du 26 octobre 2026, l'association utilise exclusivement le nom
MP3 d'origine puis le nom système du journal intégré au SQLite. Comparaison exacte
avec NFC et casse ignorée, ambiguïtés/doublons refusés, aucun repli par titre ni
lecture COMM. Les choix manuels et le suivi sont préservés ; un nom conforme ne
certifie pas le contenu audio. L'[ancienne règle COMM](docs/regle-association-COMM.md)
reste archivée pour les audits antérieurs.

## Vérifier les Lots 1 à 4

Avec Flutter 3.47.7 / Dart 3.13.5 activés, depuis la racine :

```sh
dart pub get --enforce-lockfile
bash tools/lot4/check.sh
```

Dans l'environnement cloud préparé, activer d'abord le SDK avec
`. /workspace/toolchains/activate-flutter.sh`. Le script de vérification réutilise
ensuite les dépendances hors ligne, contrôle le formatage, l'analyse et les tests.
L’import, la recherche et le scan restent sans réseau et ne modifient pas les
fichiers fournis. Le service de téléchargement explicite utilise HTTP/HTTPS ; les
tests emploient un serveur local, sans télécharger le corpus distant.
Les tests sont validés sur Linux uniquement ; voir le bilan pour les limites natives.

## Régénérer le catalogue documentaire

```sh
dart run bin/build_catalogue.dart --output assets/catalogue.sqlite --version corpus-2026-10-26-noms-journal-r3 --generated-at 2026-10-26T00:00:00Z --report docs/lot3/catalogue-report.json --replace
```

Le catalogue préindexé actuel (schéma v4) contient **716 épisodes**, dont 603 avec
résumé, 1896 références et 614 musiques. Les onze noms corrigés sur `main` sont
intégrés, sans changement d'identité. Le rapport conserve les 29 avertissements historiques, sans
erreur, quarantaine, divergence de nom TXT ni fiche à vérifier.
Le SQLite n'embarque aucun MP3 ni donnée personnelle. `--replace` remplace uniquement
l'artefact généré. Le Lot 4 l'intègre aux assets Flutter ; le CSV n'est pas nécessaire
chez l'utilisateur.

## Rechercher depuis Dart

```dart
import 'package:index_core/index_storage.dart';

final store = CatalogStore.open('ma-base.sqlite');
try {
  store.importReference('assets/catalogue.sqlite');
  final results = SqliteSearchEngine(store.database).search('guerre froide');
  // results : identité, titre, date, extrait en texte brut, score et disponibilité.
} finally {
  store.close();
}
```

Les termes sont combinés avec AND ; accents et casse sont neutralisés, sans
recherche sémantique ni syntaxe FTS avancée. Le titre est prioritaire. Voir le
[bilan Lot 3](docs/lot3/bilan.md) pour les filtres et les limites.

## Reproduire les sondes du Lot 0

Cette section est historique : `tools/lot0/audit.py` vise l'échantillon initial de
six lignes et ne valide pas le corpus complet actuel. Utiliser les tests des Lots 1–3
et le générateur ci-dessus pour les 716 entrées ; ne pas supprimer des données pour
faire passer une sonde historique.

Depuis la racine du dépôt, avec Python 3.11+ :

```sh
python3 -m venv /tmp/index-lot0-venv
/tmp/index-lot0-venv/bin/python -m pip install -r tools/lot0/requirements.txt
/tmp/index-lot0-venv/bin/python tools/lot0/audit.py > /tmp/index-lot0-resultats.json
```

Sous Windows, utiliser un venv local hors dépôt et son `Scripts/python.exe` ; la
sonde d'arrêt forcé utilise `selectors` sur un tube POSIX et doit être adaptée
pour une exécution Windows. Elle a été exécutée **sur Linux seulement**.
Les trois sondes SQLite écrivent dans des bases temporaires ; le corpus est lu
sans modification et ses SHA-256 sont comparés avant/après. Le résultat JSON va
sur stdout, les résultats des tests sur stderr ; tout échec retourne un code non nul.
Ce script d'audit n'est ni le parseur de production ni le générateur du catalogue.

Pour revérifier les archives des dépendances (accès de développement à pub.dev) :

```sh
python3 tools/lot0/verify_dependencies.py
```

L’application ne contacte aucun serveur automatiquement. Depuis la décision du
30 octobre, Télécharger utilise uniquement sur demande l’URL MP3 du journal intégré.
Le fichier reçu est contrôlé puis associé à la fiche, sans écraser une cible.
Les autres URL documentaires ne sont pas ouvertes automatiquement. Les MP3 déjà présents sont
des fixtures existantes : ne pas en ajouter, dupliquer ou supprimer pendant l'audit.
Seul le SQLite documentaire sera embarqué dans les futures distributions.


## Licence du code et validation Android

Le code original d’IndeX est sous **GNU GPL v3 uniquement** (`GPL-3.0-only`) :
[texte intégral](LICENSE) et [périmètre/exclusions](LICENSE_SCOPE.md).
Aucune licence n’est attribuée ici aux MP3, à la documentation ou aux contenus
documentaires du catalogue. Les éléments tiers conservent leurs propres licences.

L’utilisateur valide **0.7.01**, y compris la mise à jour signée, sur Pixel 9/10
et OnePlus 15 sous Android 17, et Galaxy S21 sous Android 14. Voir la
[recette consignée](docs/lot6/RECETTE_6D.md). La publication GitHub reste distincte.
Le bouton GitHub d’À propos ouvre le dépôt dans le navigateur uniquement sur clic.


## Compteurs de construction

Versionnement centralisé sur `main` : politique et compteur dans
`tools/versioning/`. Les constructions manuelles y ajoutent un commit de réservation.
Le premier build après migration intégrera les dernières valeurs de l’ancienne
branche et la supprimera dans la même transaction ; aucun compteur remis à zéro.
Le code compilé reste le commit sélectionné au lancement, consigné séparément du
commit de compteur. Voir [la procédure et les protections](tools/versioning/README.md).


Suppression facultative des MP3 écoutés sur Windows/Android : **Paramètres →
Fichiers audio**, aperçu filtrable et confirmation explicite, suivi et favoris
conservés. Voir [le fonctionnement et la recette](docs/suppression-mp3-ecoutes.md).
Cette fonction est postérieure au build 0.7.01 validé sur téléphone.
