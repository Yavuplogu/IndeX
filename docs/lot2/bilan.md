# Lot 2 — Catalogue complet, associations et persistance

Date : 24 octobre 2026. État : implémenté et testé sur Linux x64. Le Lot 3 n'est
pas engagé. Aucun commit/push automatique et aucun fichier source corrigé implicitement.

## Corpus intégré et résultats

La branche `main` a été intégrée par avance rapide sur `work`, de `e4b982a` vers
`e8d8222` (« Added full TXT anfd journal »), avant l'implémentation. Les travaux des
Lots 0–1 sont conservés. Les 716 TXT et le CSV complet viennent de cette révision.
Les corrections utilisateur du commit `a332d3f` (« TXT/journal update ») ont ensuite
été intégrées par avance rapide. Les six MP3 initiaux sont restés inchangés.

Le [rapport complet](catalogue-report.json) et le manifeste
`assets/catalogue.sqlite.manifest.json` décrivent le catalogue généré :

| Élément | Résultat |
|---|---:|
| Entrées CSV / fichiers TXT fournis | 716 / 716 |
| Épisodes structurés dans SQLite | 716 |
| TXT conservé en quarantaine (identité invalide) | 0 |
| Épisodes structurés à vérifier | 0 |
| Épisodes avec un résumé textuel | 603 |
| Épisodes sans résumé (« Aucune donnée ») | 113 |
| Blocs de sources / morceaux | 1 896 / 614 |
| Enregistrements de provenance (journal, lignes, TXT) | 1 433 |
| Liens MP3 / données personnelles dans le seed | 0 / 0 |

Les données manquantes dans les sources ne sont pas inventées. Ce catalogue est un
**artefact intermédiaire du Lot 2**, pas une distribution V1 validée : il n'a pas encore
d'index FTS5, d'interface ni d'intégration dans des packages Windows/Android.

### Anomalies corrigées dans les sources

Les cinq anomalies précédemment conservées pour examen sont résolues dans le
commit utilisateur `a332d3f`, intégré le 24 octobre 2026. Le catalogue a été
régénéré en version `corpus-2026-10-24-lot2-r2` à partir de ces sources corrigées.

| Source | Correction vérifiée et résultat |
|---|---|
| 1998-04-25, Pier Paolo Pasolini | Extension `.mp3` rétablie dans le CSV et le TXT : identité `mr_x_1998_04_25.mp3` valide, épisode intégré au catalogue. |
| 2014-02-22, Robert Levinson | Date française corrigée en `22/02/2014`, cohérente avec DATE ISO. |
| 2014-04-12, Rwanda | Date française corrigée en `12/04/2014` : `broadcast_date=2014-04-12`. |
| 2014-05-31, Grèce | Dates française et ISO corrigées en `31/05/2014` et `2014-05-31`, cohérentes avec le CSV. |
| 2014-06-14, Boko Haram | Extension `.txt` rétablie dans le nom du fichier déclaré par le CSV, désormais identique au fichier découvert. |

Le nouveau rapport contient **0 erreur, 0 TXT en quarantaine et 0 fiche à vérifier**,
pour **716 épisodes structurés**. Les **29 avertissements** restants correspondent
à 23 messages historiques du journal et à 6 fiches contenant U+0085 préservé.
Les 23 messages source accompagnent `Statut=RESOLU` : ils ne sont pas assimilés à une
erreur d'écoute ni à un échec de lecture ID3 effectué par IndeX.
`CORRESPONDANCE ID3=CONFIRMEE` est historique sur les 716 lignes ; seuls les six
MP3 présents ont pu être relus localement durant les tests.

Les tests du corpus vérifient les identités et dates corrigées ainsi que l'absence
des anciennes divergences CSV/TXT. Les protections contre les données invalides
restent couvertes par les tests synthétiques ; aucune correction automatique des
sources n'a été ajoutée.

## Modules et contrats

| API | Rôle |
|---|---|
| `JournalParser.parse(bytes)` | CSV strict `;`, BOM, guillemets échappés, champs multilignes, colonnes par nom et diagnostics |
| `CatalogPlanner.plan(inputs, journalBytes: ...)` | Préparation pure, contrôles d'identité, fusion documentaire et provenance |
| `MatchingEngine.match(episodes, audios)` | Décisions globales, priorités, doublons et preuves COMM |
| `loadTxtDirectory`, `scanAudioDirectory` | Adaptateurs natifs, sans suivi de liens symboliques, lectures bornées |
| `CatalogStore.importPlan` | Transaction, import incrémental, versions et journal des anomalies |
| `CatalogStore.importReference(path)` | Chargement/mise à jour à partir du seul SQLite de référence, sans CSV/TXT externes |
| `CatalogStore.applyAudioScan`, `recordManualLink` | Liens locaux, preuves, choix manuels et indisponibilité |
| `buildCatalog` / `bin/build_catalogue.dart` | Génération reproductible d'un SQLite et de son manifeste |

Le cœur pur reste exporté par `index_core.dart`. `index_io.dart` contient les accès
aux fichiers et le builder ; `index_storage.dart` expose le stockage SQLite natif.
Ces adaptateurs sont séparés des règles métiers et de la future interface Flutter.

### CSV et fusion documentaire

Parser strict sans dépendance CSV supplémentaire : UTF-8 avec/sans BOM, CR/LF, `;`,
guillemets doublés et sauts de ligne dans les champs. Les dix en-têtes fondamentaux
sont requis ; les trois colonnes d'indicateurs et tout autre champ supplémentaire
sont conservés. En-têtes répétés, encodage invalide ou structure incohérente bloquent
l'import avant modification du catalogue, au lieu de passer silencieusement en mode
« sans CSV ». Une ligne vide encadrée de guillemets est une ligne incomplète, pas une
ligne physique blanche à ignorer. Limites : 16 Mio, 10 000 lignes de données.

Les quatre statuts ID3 sont conservés séparément du statut général et de la vérification
locale. Les titres, descriptions, sources et musiques proviennent du TXT. Le journal
fournit les variantes de noms et sa provenance ; ses indicateurs OK/VIDE ne remplacent
jamais le contenu documentaire. Les doublons historiques sont mis à l'écart avant
l'insertion dans la table canonique, pas résolus par une contrainte UNIQUE choisissant
un premier candidat. Sans CSV, l'import des seuls TXT demeure possible.

Les entrées d'identité valide mais portant des erreurs documentaires restent consultables
avec `needs_review=1` et leurs données brutes. Une identité invalide ou ambiguë reste
dans `source_records`, sans création d'identifiant artificiel. Les noms et contenus source
ne sont jamais modifiés. Les noms Unicode découverts sont conservés décodés, sans `%20`
introduit par les URI techniques.

### Association et limites des confirmations

Ordre : preuve COMM résolue > nom historique > nom courant connu du catalogue > titre
normalisé provisoire. La règle A/A/B retient A selon l'addendum ; A/A/B/B reste ambigu.
Une preuve ID3 inconnue ou contradictoire et une lecture ID3 invalide bloquent les replis.
Deux fichiers vers la même fiche, ou plusieurs fiches correspondant à une preuve,
ne produisent aucune nouvelle association automatique.

Un nom exact historique/catalogue peut confirmer une correspondance **par nom**, sans
fabriquer une confirmation ID3 locale : `local_verification_status=ABSENTE`. Avec un
journal `NON_VERIFIEE` ou `CONFLIT`, ce repli reste provisoire. Une preuve COMM relue
peut confirmer localement l'association sans changer le statut historique du CSV.
Les ressemblances de titre restent toujours provisoires et ne sont pas écrites comme
liens confirmés. Aucune association sur la date seule.

Les rapports de scan conservent les décisions, commentaires trouvés, trames retenues,
commentaires écartés et raisons. Les choix manuels ne sont pas remplacés par un scan.
Les déplacements d'un MP3 confirmé actualisent sa référence locale sans changer son
`episode_id`. Un scan complet peut marquer un fichier absent comme indisponible, sans
effacer son lien ; un dossier inaccessible/incomplètement parcouru n'entraîne pas de
marquage massif d'absence. Aucun scan ne renomme ni ne réécrit un fichier.

## SQLite et conservation des données

Choix retenu : `sqlite3` **3.7.1**, accès direct avec migrations SQL explicites. La couche
Drift candidate au Lot 0 n'est pas ajoutée tant que son abstraction n'est pas utile.
Package MIT, archive officielle vérifiée par SHA-256 :
`144132790ec1947fad9f3ddceffd0af2ab80a1f0d1e81a4d094ee6707ec3df0b`.
Les native assets et leurs vérifications standard restent activés. Sur cet hôte, le
moteur exécuté est **SQLite 3.54.0** ; FTS5 a été sondé, pas encore intégré au catalogue.
`crypto` 3.0.7 (BSD-3-Clause) devient une dépendance de production pour les empreintes.
SDK, autres dépendances et résolutions transitives restent épinglés dans le dépôt.

Schéma `user_version=2`, `application_id=0x49445831` :

- Référence : épisodes, alias, sources littéraires, musiques, versions de catalogue.
- Provenance : import_runs, import_issues, source_records.
- Local : local_audio_links et rapports audio_scan_runs/items.
- Réserve personnelle : user_episode_state, avec contraintes de position, statut et
  favori. Le lecteur et les commandes métier de suivi ne sont pas implémentés ici.

Migrations v0→v1→v2 atomiques, clés étrangères actives, WAL et synchronous FULL pour la
base de travail. Base étrangère ou version future refusée ; une erreur de migration
revient à la version précédente. Les imports ne font aucun DELETE massif des fiches
absentes d'un lot partiel et ne touchent pas aux tables personnelles.

Empreintes des sources et champs structurés pour le réimport : une entrée inchangée
n'est pas réécrite et conserve son horodatage. Un chemin TXT changé actualise sa
provenance et ajoute un alias. Les nouvelles tentatives ont leur journal, mais un corpus
identique réutilise son snapshot de sources (`snapshot_run_id`) plutôt que recopier
tous les octets. Une annulation ou exception annule le lot transactionnel tout entier.
Un arrêt SIGKILL a également été testé : dernier catalogue validé intact et réimport
possible après réouverture. Le journal peut conserver une tentative au dernier état
`running` après cet arrêt ; ce n'est pas une confirmation de fin ni une suppression.
La qualification d'une session abandonnée dans l'interface reste à définir ultérieurement.

`importReference` ouvre le seed **en lecture seule**, contrôle schéma/intégrité/provenance,
reconstruit le plan depuis les sources intégrées et vérifie son empreinte avant application.
Limites : fichier de 64 Mio, au plus 10 001 sources et 48 Mio de données source, métadonnées
et types contrôlés. Un seed personnel, altéré, futur ou de provenance incohérente est
refusé. Le seed et la base de travail doivent être des fichiers distincts. Les liens,
états personnels et overrides utilisateur de la cible ne sont pas remplacés ; une
modification de référence concurrente avec un ajout/modification utilisateur est signalée.
Cette API n'est pas un mécanisme de synchronisation personnelle par copie de SQLite.

## Génération et vérifications reproductibles

Depuis la racine, après `. /workspace/toolchains/activate-flutter.sh` dans cet environnement :

```sh
dart pub get --enforce-lockfile
bash tools/lot2/check.sh
dart run bin/build_catalogue.dart --output assets/catalogue.sqlite --version corpus-2026-10-24-lot2-r2 --generated-at 2026-10-24T00:00:00Z --report docs/lot2/catalogue-report.json --replace
```

Le script de contrôle utilise ensuite le cache hors ligne, vérifie le lockfile, le
formatage de lib/test/bin, l'analyse statique avec infos fatales et tous les tests.
L'état de l'analyseur reste sous `.dart_tool`, sans modifier HOME. Les téléchargements
de préparation des dépendances sont distincts de l'utilisation de l'application hors ligne.

Le builder charge uniquement CSV/TXT, jamais les MP3 ; il refuse d'écrire une sortie
dans les sources. Une base temporaire est construite et contrôlée (`integrity_check`,
`foreign_key_check`), fermée et consolidée sans WAL avant installation de l'artefact.
Le manifeste donne sa taille et son SHA-256. Le timestamp fourni est un **paramètre
de génération reproductible**, pas une mesure de l'heure réelle d'exécution.
Deux générations sur les mêmes entrées produisent des octets SQLite identiques.

**152 tests Dart**, sur Linux x64 : les 84 du Lot 1 et les tests CSV, planification,
priorités/ambiguïtés globales, historique ID3 distinct, réimport, overrides, annulation,
panne injectée, SIGKILL natif, migrations, seed malformé/refusé, chargement et mise à
jour depuis SQLite, corpus complet et génération déterministe. Les six MP3 réels
produisent six associations confirmées `id3_comment` au catalogue complet. Les fixtures
synthétiques sont créées en mémoire ou dans des répertoires temporaires, sans ajouter
d'audio au dépôt. Les tests de sources du Lot 1 vérifient toujours leurs SHA-256.

## Limites restantes

FTS5 et sa synchronisation avec les imports seront le Lot 3. Le catalogue intermédiaire
déclare explicitement `search_index=false`. Aucun résultat de recherche ni package GUI
Windows/Android ne doit être annoncé fonctionnel à ce stade. Les tests natifs cibles,
SAF et cycle de vie restent non exécutés. Le test SIGKILL est POSIX et serait signalé
comme ignoré sous Windows, jamais présenté comme une recette Windows réussie.

Les migrations et la conservation du suivi sont testées au niveau stockage ; la
sauvegarde périodique de lecture, les favoris interactifs, la fusion JSON et le renommage
restent aux lots prévus. Les avertissements historiques et les 113 résumés absents
restent documentés ; la résolution des cinq anomalies ne complète pas les données manquantes.
