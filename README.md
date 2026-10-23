# IndeX

Projet d'application documentaire et de lecture locale pour Windows et Android,
en français et entièrement hors ligne à l'utilisation.

**État : Lot 1 implémenté.** Le package Dart `index_core` fournit le parseur TXT,
le lecteur ID3 et la résolution de preuve COMM, avec tests. Aucune application GUI
ni persistance n'est encore livrée. Le dépôt contient un échantillon de six épisodes,
pas le catalogue complet de plusieurs centaines d'épisodes.

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
ou plusieurs fichiers restent bloquantes. La résolution COMM est implémentée au Lot 1 ;
l'association globale aux fiches et la persistance restent au Lot 2.

## Vérifier le Lot 1

Avec Dart 3.13.5 (fourni par Flutter 3.47.7) activé, depuis la racine :

```sh
dart pub get --enforce-lockfile
bash tools/lot1/check.sh
```

Dans l'environnement cloud préparé, activer d'abord le SDK avec
`. /workspace/toolchains/activate-flutter.sh`. Le script de vérification réutilise
ensuite les dépendances hors ligne, contrôle le formatage, l'analyse et les tests.
Le cœur Dart n'effectue aucun accès réseau et ne modifie pas les fichiers fournis.
Les tests sont validés sur Linux uniquement ; voir le bilan pour les limites natives.

## Reproduire les sondes du Lot 0

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
