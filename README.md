# IndeX

Projet d'application documentaire et de lecture locale pour Windows et Android,
en français et entièrement hors ligne à l'utilisation.

**État : Lot 3 implémenté et testé sur Linux.** Le package Dart `index_core` fournit les parseurs,
les associations MP3–TXT, la persistance SQLite et la recherche FTS5. Le corpus complet comporte
716 TXT et 716 entrées CSV ; six MP3 servent aux tests. Aucune application GUI
n'est encore livrée. La validation des distributions Windows/Android reste à effectuer.

- [Lot 3 : recherche FTS5, extraits et validation](docs/lot3/bilan.md)
- [Lot 2 : catalogue, import, associations, migrations et anomalies](docs/lot2/bilan.md)
- [Rapport du corpus complet](docs/lot3/catalogue-report.json)
- [SQLite documentaire prérempli](assets/catalogue.sqlite)
- [Lot 1 : API, validation, dépendances et limites](docs/lot1/bilan.md)
- [Audit, architecture, dépendances, risques et recette](docs/lot0/conception.md)
- [Journal des décisions](docs/lot0/decisions.md)
- [Règle adoptée : deux commentaires COMM concordants et association MP3–TXT](docs/regle-association-COMM.md)
- [Résultats observés sur Linux](docs/lot0/audit-resultats.json)
- [Versions et licences des packages inspectés](docs/lot0/dependances-observees.json)
- [Cahier des charges V1.4 fourni](docs/Cahier_des_charges_IndeX_Codex_V1.4.md)

La règle COMM adoptée ci-dessus prévaut sur le rejet systématique des commentaires
contradictoires décrit dans la V1.4 archivée : une seule paire d'identifiant concordante
suffit à écarter les autres commentaires isolés. Les ambiguïtés entre plusieurs paires
ou plusieurs fichiers restent bloquantes. La résolution COMM et l'association globale
aux fiches sont implémentées, sans transformer un statut CSV en vérification ID3 locale.

## Vérifier les Lots 1 à 3

Avec Dart 3.13.5 (fourni par Flutter 3.47.7) activé, depuis la racine :

```sh
dart pub get --enforce-lockfile
bash tools/lot3/check.sh
```

Dans l'environnement cloud préparé, activer d'abord le SDK avec
`. /workspace/toolchains/activate-flutter.sh`. Le script de vérification réutilise
ensuite les dépendances hors ligne, contrôle le formatage, l'analyse et les tests.
Le cœur Dart n'effectue aucun accès réseau et ne modifie pas les fichiers fournis.
Les tests sont validés sur Linux uniquement ; voir le bilan pour les limites natives.

## Régénérer le catalogue documentaire

```sh
dart run bin/build_catalogue.dart --output assets/catalogue.sqlite --version corpus-2026-10-24-lot3 --generated-at 2026-10-24T00:00:00Z --report docs/lot3/catalogue-report.json --replace
```

Le catalogue préindexé du Lot 3 contient **716 épisodes**, dont 603 avec résumé
textuel. Après intégration des corrections sources, il ne reste aucune erreur, fiche
à vérifier ou identité en quarantaine ; les 29 avertissements sont détaillés dans le bilan. Le SQLite n'embarque aucun MP3 ni donnée personnelle. `--replace` remplace
explicitement l'artefact généré, jamais les sources. L'intégration dans les applications
et les tests d'installation vierge restent aux lots suivants.

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
