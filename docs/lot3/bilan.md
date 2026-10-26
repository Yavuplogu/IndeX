# Lot 3 — Recherche documentaire FTS5

> **Actualisation du 26 octobre 2026 :** le bilan historique ci-dessous conserve
> ses résultats et règles de l'époque. Le catalogue actuel est en v4 et le scan
> utilise uniquement les noms du journal, sans COMM. Voir la
> [règle actuelle](../regle-association-noms-journal.md) et le
> [rapport actuel](../lot3/catalogue-report.json) : 716 épisodes, 29 avertissements,
> aucune erreur ni fiche à vérifier après correction du nom TXT des Hmongs.

Ce bilan conserve les résultats historiques du Lot 3. Le [Lot 4](../lot4/bilan.md)
ajoute la GUI Windows, les champs de recherche et le schéma de travail v4.

Date : 24 octobre 2026. Implémenté et testé sur Linux x64, Dart 3.13.5,
Flutter 3.47.7, SQLite 3.54.0. Le Lot 4 n'est pas engagé. Aucun commit/push automatique.

## Résultat livré

Le catalogue préindexé contient **716 épisodes**, dont 603 avec résumé, sans MP3,
lien audio local ni donnée personnelle. Aucun TXT/CSV externe n'est requis pour
le charger dans une base de travail et rechercher. Les sources sont inchangées
depuis les corrections utilisateur du commit `a332d3f`.

Le [rapport](catalogue-report.json) et le [manifeste du seed](../../assets/catalogue.sqlite.manifest.json)
décrivent la version `corpus-2026-10-24-lot3`, schéma **v3**, avec `search_index=true`.
Les comptes restent identiques au Lot 2 corrigé : aucune erreur, quarantaine ou
fiche à vérifier ; 29 avertissements historiques/U+0085 et 113 résumés absents.

## Architecture et maintenance

Aucune dépendance ajoutée : sqlite3 3.7.1 et unorm_dart 0.3.3 restent épinglés.
Le package passe à 0.3.0. L'interface pure `SearchEngine`, `SearchOptions` et
`SearchHit` sont exportées par `index_core.dart`. `SqliteSearchEngine`, exporté
par `index_storage.dart`, utilise la connexion appartenant au `CatalogStore`.

L'index externe `episodes_fts` référence les rowid de `episodes` et contient
titre, description, sources brutes agrégées et musique brute agrégée. Les colonnes
`sources_text`/`music_text` sont les projections canoniques ; les tables détaillées
sont leurs extractions. Une future édition documentaire devra actualiser aussi
ces projections dans la même transaction.

La migration v2→v3 crée et remplit FTS dans une transaction. Les bases v1 migrent
également jusqu'en v3. Les triggers d'insertion, modification documentaire et
suppression maintiennent FTS dans la transaction des épisodes, y compris les
imports et rollbacks. Les liens audio et le suivi ne réindexent pas le texte.
Un échec de migration laisse le schéma précédent intact. Si FTS5 est absent,
la migration échoue explicitement sans moteur de substitution silencieux.

L'import de référence accepte les seeds v2 et v3 en lecture seule, reconstruit
le plan depuis la provenance vérifiée et applique les données à la cible v3.
Les liens manuels, overrides et données personnelles restent préservés.

`checkIndex()` utilise FTS5 `integrity-check` avec `rank=1` pour comparer aussi
le contenu externe. Cette commande nécessite une connexion autorisant les commandes
d'écriture FTS ; une recherche ordinaire fonctionne en lecture seule.
`rebuildIndex()` reconstruit puis vérifie l'index dans une transaction propre,
sans toucher au suivi. Ne pas l'appeler dans une transaction existante.
Le builder contrôle FTS avant de fermer et publier le catalogue.

Commande de reconstruction sur une **base de travail existante** :

```sh
dart run bin/rebuild_search.dart ma-base.sqlite
```

## Comportement de recherche

- `unicode61 remove_diacritics 2` neutralise casse et accents ; requête normalisée
  NFC. Les apostrophes droites et typographiques séparent les termes.
- Plusieurs termes sont combinés avec **AND**, indépendamment de leur ordre.
  Les guillemets ne demandent pas une expression exacte. Les opérateurs FTS,
  astérisques et préfixes de colonnes ne sont pas interprétés comme une syntaxe.
  Les mots tels que `AND` saisis par l'utilisateur restent des mots recherchés.
- Chaque terme est cité et MATCH est paramétré ; aucune clause SQL n'est
  construite à partir du texte utilisateur.
- BM25 **10/1/2/1** (titre/description/sources/musique), score croissant ;
  départage stable par date décroissante puis identifiant.
- Résultats : identité stable, titre, date nullable, extrait, score et disponibilité.
  `snippet` choisit une colonne et un passage d'environ 32 tokens. L'extrait est
  du **texte brut**, sans HTML ni surlignage ; la future UI doit l'afficher comme
  du texte même lorsque la source contient des balises.
- Vide ou absence de résultat : liste vide. Les mots courants sont conservés.
  Aucune lemmatisation, synonymie, sous-chaîne ou recherche sémantique promise.
- Bornes : 512 unités UTF-16, 32 termes, 1–100 résultats, offset 0–10 000.
  Paramètres incohérents ou limites dépassées : `ArgumentError`.
- Filtres optionnels : dates inclusives, présence de sources structurées et
  disponibilité audio. Les dates inconnues sont exclues d'un intervalle demandé.
  La disponibilité reflète un lien local marqué disponible ; la recherche ne
  relit aucun fichier pour vérifier son existence.

```dart
import 'package:index_core/index_core.dart';
import 'package:index_core/index_storage.dart';

final store = CatalogStore.open('ma-base.sqlite');
try {
  store.importReference('assets/catalogue.sqlite');
  final hits = SqliteSearchEngine(store.database).search(
    'guerre froide',
    options: const SearchOptions(limit: 20, audioAvailable: false),
  );
  // hits contient les résultats et leurs extraits en texte brut.
} finally {
  store.close();
}
```

## Vérification reproductible

Après activation du SDK préparé, depuis la racine :

```sh
. /workspace/toolchains/activate-flutter.sh
bash tools/lot3/check.sh
dart run bin/build_catalogue.dart --output assets/catalogue.sqlite --version corpus-2026-10-24-lot3 --generated-at 2026-10-24T00:00:00Z --report docs/lot3/catalogue-report.json --replace
dart run bin/measure_search.dart
```

Le contrôle conserve le lockfile, utilise le cache hors ligne, vérifie formatage,
analyse statique et tous les tests. La mesure utilise le seed en lecture seule
et écrit `docs/lot3/search-measurements.json`, sans TXT/CSV/MP3 requis.

**164 tests réussis sur Linux**, analyse statique sans problème. Les 12 nouveaux
tests couvrent français (accents/NFC/casse/apostrophes), termes multiples, entrées
vides ou hostiles, classement, pagination, sources/musiques/extraits, filtres,
bornes, updates/deletes/rollback, reconstruction sans perte du suivi, migration
v2→v3, migration annulée, seed v2 préservé et recherche depuis le seed courant seul.

Les tests précédents vérifient désormais aussi FTS après SIGKILL/réouverture/reprise
et après chargement des deux générations déterministes du catalogue. Le test
SIGKILL POSIX reste ignoré sous Windows ; une recette native est nécessaire.

La [mesure locale](search-measurements.json) comporte six requêtes, 120 recherches
d'échauffement et 600 mesurées, limite 30. Sur l'hôte Linux cloud : **p50 1,620 ms,
p95 2,598 ms, maximum 5,284 ms**. Il s'agit du moteur natif sans UI ; ces chiffres
ne qualifient ni une application ni un téléphone ni une distribution Windows.

## Risques et validations restantes

FTS5 et les migrations doivent encore être exécutés dans les distributions
Windows/Android. Aucun build ni appareil cible n'a été validé dans ce lot.
Les poids BM25 proviennent du Lot 0 ; les cas de classement contrôlés ne
constituent pas une mesure exhaustive de pertinence humaine. Les termes généraux
peuvent retourner beaucoup de fiches, et unicode61 n'est pas une analyse
linguistique française.

Aucune interface, lecture audio, fusion JSON ou intégration Flutter n'est livrée
ici. Les installations propres Windows/Android sans corpus externe restent à
valider dans les packages applicatifs des lots suivants.
