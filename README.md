# IndeX

Projet d'application documentaire et de lecture locale pour Windows et Android,
en français et entièrement hors ligne à l'utilisation.

**État : code du Lot 4 implémenté ; qualification Windows en attente.**
L'application Flutter Windows portable reprend l'interface Éditorial, le catalogue,
la recherche FTS5 et les dossiers/associations. Le cœur Dart reste partagé. Les
contrôles Linux passent ; le workflow de construction et de recette Windows est
préparé. Aucun binaire Windows qualifié ni application Android ne sont encore livrés.

Les derniers logs Windows (`logs_109499819369.zip`) s'arrêtent sur deux tests
Flutter de chemins : leurs valeurs attendues mélangent les séparateurs `/` et
`\`, alors que l'application affiche des chemins Windows natifs avec espaces.
La construction des chemins de test est corrigée ; la vérification Windows doit
être relancée avant qualification du paquet (voir le bilan).

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
les associations peuvent être retirées après confirmation, sans toucher aux MP3
ni au suivi. L’ouverture du dossier utilise l’API Windows avec le chemin cible.

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
Le cœur Dart n'effectue aucun accès réseau et ne modifie pas les fichiers fournis.
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

L'application future n'effectuera aucun accès réseau. Les URL documentaires ne
seront ni téléchargées ni ouvertes automatiquement. Les MP3 déjà présents sont
des fixtures existantes : ne pas en ajouter, dupliquer ou supprimer pendant l'audit.
Seul le SQLite documentaire sera embarqué dans les futures distributions.
