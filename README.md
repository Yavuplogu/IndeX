# IndeX

Version de départ **0.6.0** (bêta, Lot 5 bis) ; numéro mineur réservé automatiquement à
chaque construction Windows distribuable. [Politique et compteur](tools/versioning/README.md).

[Lot 5 : architecture et lecteur](docs/lot5/bilan.md).
[Lot 5 bis : renommage, contrôles et recette Windows](docs/lot5bis/bilan.md).

Projet d'application documentaire et de lecture locale pour Windows et Android,
en français, avec catalogue et écoute locale hors ligne. Le téléchargement d’un
MP3 manquant est facultatif et contacte le serveur source uniquement sur clic.

**État : Lot 5 bis lancé — renommage global Windows ; Android en pause.**
Décision du 27 octobre 2026 : conserver le socle partagé et tous les objectifs
fonctionnels du futur portage Android. Voir l’[avenant au cahier des charges](docs/Cahier_des_charges_IndeX_Codex_V1.4.md#avenant-du-27-octobre-2026--priorité-windows-android-en-pause).
Le code Android existant est conservé ; le workflow APK se lance uniquement à la
main. Le Lot 5 bis est lancé le 31 octobre ; le Lot 5 ter reste non lancé.

L'application Flutter Windows portable reprend l'interface Éditorial, le catalogue,
la recherche FTS5 et les dossiers/associations. Le cœur Dart reste partagé. Le dernier build Windows du Lot 4 a été testé par l’utilisateur sans problème
apparent ni crash. Le Lot 5 ajoute le lecteur natif et Android ; leur qualification
sur les deux cibles reste distincte des tests Linux. La recette et les limites
sont détaillées dans le bilan du Lot 5.

Depuis le 28 octobre, le lecteur Windows utilise **just_audio + just_audio_windows**
(WinRT MediaPlayer), en remplacement de MCI. Android conserve son moteur et reste
en pause ; la réactivité native doit être confirmée sur Windows.

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
