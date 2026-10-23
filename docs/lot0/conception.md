# Lot 0 — Audit de faisabilité et conception IndeX V1

Date : 23 octobre 2026. Statut : **conception proposée, aucun module applicatif créé**.

## 1. Conclusion et périmètre

La V1 est techniquement réalisable avec un catalogue SQLite prérempli, Flutter/Dart
partagé et des adaptateurs natifs Windows/Android. La faisabilité du corpus fourni
et de FTS5 sur l'hôte Linux est démontrée ; la faisabilité des distributions et des
accès au stockage sur les deux cibles reste à démontrer. Ce document ne vaut pas
validation Windows/Android ni livraison d'une base complète.

La demande utilisateur autorise uniquement le **Lot 0** : lecture intégrale de la
V1.4, audit, architecture, choix de dépendances et stratégie de tests. Le document
joint décrit les exigences et des consignes de collaboration ; ses lots ultérieurs
ne sont pas des instructions d'exécution immédiate. Aucun renommage, module Flutter,
générateur de production, synchronisation applicative ou packaging n'est effectué.

Livrables actuels : ce document, le journal des décisions, README, AGENTS, copie
inchangée du cahier des charges, rapports JSON et sondes reproductibles isolées dans
`tools/lot0`. Pas de commit ni de publication automatique.

## 2. Corpus effectivement examiné

Révision initiale : `a7d6fde951ecd08f72841d0ef5543ab0cfafb7ac`.
Le dépôt était propre avant intervention. Lecture des six TXT complets, des six
enregistrements CSV et des tags ID3 des six MP3 ; les fichiers audio n'ont pas été
écoutés intégralement ni décodés intégralement. SHA-256 de tous les fichiers sources
comparés avant/après la sonde : aucun changement. Les valeurs détaillées et empreintes
sont dans [audit-resultats.json](audit-resultats.json).

| Identifiant historique | Durée indicative | Références | Morceaux |
|---|---:|---:|---:|
| mr_x_2007_05_26.mp3 | 39,7 min | 3 | 0 |
| mr_x_2009_05_09.mp3 | 36,8 min | 6 | 0 |
| mr_x_2009_05_16.mp3 | 38,2 min | 8 | 0 |
| mr_x_2009_05_23.mp3 | 38,3 min | 4 | 0 |
| mr_x_2013_04_27.mp3 | 38,1 min | 0 | 2 |
| mr_x_2013_11_23.mp3 | 38,2 min | 1 | 2 |

Observations vérifiées :

- Six lignes CSV et six couples MP3/TXT, sans fichier manquant, doublon d'identifiant
  ou divergence titre/date/URL entre CSV et TXT dans cet échantillon.
- CSV à séparateur `;`, UTF-8 BOM ; **13 colonnes**, pas 10. Les trois colonnes
  supplémentaires sont `DESCRIPTION DE L'EPISODE`, `LIVRES ET SOURCES`,
  `MUSIQUES DIFFUSÉES`. Elles contiennent des indicateurs `OK`/`VIDE`, pas les contenus.
  Import par **nom d'en-tête**, pas par nombre/position rigide ; conserver les extras.
- Les six TXT sont UTF-8 BOM, ont les neuf rubriques attendues et des descriptions
  de 1 289 à 1 957 caractères. Total : 22 blocs de référence et 4 blocs musicaux.
  « Aucune donnée » ne crée aucun livre/morceau. Les sources comprennent aussi des
  listes d'épisodes connexes, souvent extérieurs à l'échantillon : pas des manquants
  du journal, et pas de nouvelles fiches à inventer.
- Les TXT des 16 et 23 mai 2009 comportent chacun trois U+0085 (NEL), bien encodés
  en UTF-8. Préserver le brut et signaler ; pas de conversion automatique d'encodage.
  Le futur parseur doit utiliser des délimiteurs de rubriques explicites et préserver
  les sauts de ligne internes ; `splitlines()` peut transformer NEL involontairement.
- Tous les MP3 ont des ID3v2.3, deux commentaires concordants `COMM::eng`/`COMM::fra`
  avec l'identifiant historique ; cinq ont un troisième commentaire non pertinent.
  Aucune COMM contradictoire dans l'échantillon. Les quatre états du journal ne sont
  donc **pas** couverts par ces seules fixtures, toutes déclarées `CONFIRMEE`.
- Le nom réel du Masque de fer n'a pas le ` - ` annoncé dans certains exemples de
  la V1.4. La cible de renommage sera exactement le `TITRE SYSTEME` réel, après contrôles.
- Les MP3 existants sont déjà versionnés ; aucun MP3 supplémentaire ne doit être
  ajouté et aucun ne doit être inclus dans les assets de l'application.

**Limite de données :** six épisodes ne constituent pas le corpus complet promis.
La recette de catalogue complet exigera le CSV intégral et tous les TXT correspondants,
sans nécessité de charger les plus de 30 Go de MP3 dans Codex. Pas besoin de ces données
supplémentaires pour clore le Lot 0 ; elles seront nécessaires avant la release complète.

## 3. Architecture cible

```text
Préparation release (développement/CI seulement)
CSV complet + TXT -> validation/staging -> catalogue.sqlite + manifeste + rapport
                                         | asset des deux packages, aucun MP3
Premier lancement                        v
copie atomique dans le stockage privé -> base de travail SQLite
                                         |
UI Flutter FR -> cas d'utilisation -> domaine pur Dart -> interfaces
                                         |
                   persistance / recherche / lecteur / fichiers / suivi / fusion
                                         |
                   Windows natif         | Android Kotlin/SAF
```

Frontières proposées pour les futurs lots, **répertoires non créés aujourd'hui** :

| Composant | Responsabilités |
|---|---|
| `domain` | Identité, statuts, règles de matching, causalité, validation des commandes ; aucune I/O |
| `data/parsers` | TXT/CSV/ID3, diagnostics et conservation du brut |
| `data/storage` | Drift/SQLite, migrations, chargement asset, transactions et sauvegardes |
| `services/import`, `services/search` | Scan incrémental, matching, anomalies, FTS5 |
| `services/audio`, `services/listening` | Lecture locale, checkpoint, reprise, statuts, favoris |
| `services/sync` | JSON, validation, aperçu, fusion, restauration |
| `services/rename` | Plan global, collisions, exécution par fichier et réconciliation |
| `platform` | Chemins Windows, URI/permissions SAF Android, sélecteurs et fichiers |
| `ui` | Bibliothèque, résultats, détail, lecteur, résolutions et paramètres français |
| `tools/catalog_builder` | Génération déterministe en CI, sans MP3 requis |

L'UI n'accède pas directement à SQLite ou aux fichiers. Scans, parsing et FTS lourds
sur worker/isolate ; taille des tags/images et concurrence bornées. Toute I/O audio
reçoit une référence typée (`WindowsPath`, `AndroidDocumentUri`, `PrivateCopy`), jamais
une conversion naïve d'URI `content://` en `File` Dart. Les moteurs restent substituables.

## 4. Catalogue, identité et stockage

### Identité stable

Proposition : `episode_id = "mrx:" + original_name_canonical`, par exemple
`mrx:mr_x_2013_04_27.mp3`. Canonicalisation versionnée : NFC, retrait des seuls espaces
parasites/guillemets extérieurs, comparaison ASCII sans casse pour le format historique
connu `mr_x_....mp3` ; conserver systématiquement la valeur brute. Rejeter séparateurs,
parcours `..` et identifiants invalides. Pas d'identité dérivée de la date seule ou du titre.
Ne pas écraser deux identifiants distincts par une normalisation agressive.

Les entrées sources contradictoires restent en staging avec diagnostic ; seules les
identités validées entrent dans la table canonique unique. Si un identifiant est corrigé
plus tard, conserver son ID publié et ajouter un alias explicite ; ne pas perdre le suivi.

### Schéma logique et séparation

Une base privée de travail favorise les transactions atomiques entre catalogue local,
suivi et journal. Elle provient au premier démarrage d'une copie de l'asset prérempli :

- Référence : `catalog_versions`, `episodes`, `episode_aliases`, `literary_sources`,
  `music_tracks`, variantes de noms CSV et texte brut avec empreintes/provenance.
- Index : `episodes_fts(title, description, sources_text, music_text)`.
- Local : `local_audio_links`, `scan_runs/issues`, `user_imports/overrides`, préférences.
- Personnel : `listening_state`, `favorites`, `sync_device`, versions par champ,
  `sync_imports`, conflits et sauvegardes logiques avant fusion.
- Renommage : `rename_runs/items` avec intention, avant/après, empreinte et état durable.

Clés étrangères activées ; pas de suppression en cascade du suivi lors d'une mise à jour
du catalogue. Aucun chemin d'un poste de développement dans l'asset ; références des
sources par noms relatifs seulement. Durée locale séparée de la durée transférée.

Asset en lecture seule ; copie dans un fichier temporaire, contrôle du manifeste,
`integrity_check`, version, FTS, puis installation atomique. Séparer `schema_version`
et `catalog_version`. Sur mise à jour, attacher/lire le nouveau catalogue, préparer un
diff puis upsert transactionnel des seules données de référence ; préserver suivis,
alias, liens audio et ajouts utilisateur. Un épisode retiré est archivé, pas effacé avec
son suivi. Une fiche utilisateur modifiée est conservée en override avec conflit visible.
Jamais de remplacement global de la base de travail existante par le nouvel asset.

Le builder futur produira dans un ordre stable le SQLite, un manifeste (version,
SHA-256 des sources, couverture, schéma) et un rapport d'écarts. L'horodatage de build
sera fourni explicitement pour la reproductibilité ; pas de dépendance à l'heure courante
dans le contenu de référence. Les cas manquants ne seront pas annoncés « complets ».

### Recherche

FTS5 `unicode61 remove_diacritics 2`, `bm25` pondéré (titre 10, description 1,
sources 2, musique 1 ; à mesurer sur le corpus complet), `snippet` et filtres relationnels.
Inclure les musiques, exigées par CAT-02 mais absentes du modèle FTS minimal suggéré.
Index maintenu dans la même transaction que les fiches (triggers sur une projection
agrégée), commande de reconstruction et contrôle d'intégrité. Les requêtes utilisateur
sont tokenisées en mode texte littéral ; guillemets et opérateurs FTS ne sont pas passés
tels quels. SQL paramétré **et** neutralisation de MATCH : ce sont deux protections distinctes.
Pas de promesse de lemmatisation ou de recherche sémantique avec `unicode61`.

## 5. Dépendances : décision et niveau de preuve

Archives officielles pub.dev téléchargées avec TLS, SHA-256 comparés aux métadonnées,
licences et sources critiques inspectées. Versions et empreintes dans
[dependances-observees.json](dependances-observees.json). Versions publiées récemment
ou ancienneté d'une release ne suffisent pas à prouver la maintenance future.

| Besoin | Candidat / décision | Licence du package | Validation restante |
|---|---|---|---|
| UI | Flutter stable/Dart, SDK exact à épingler au démarrage Lot 1 | BSD-3-Clause pour Flutter, inventaire SDK à produire | SDK absent ; choisir une paire compatible Dart ≥3.10 et Flutter ≥3.38 |
| SQL/migrations | drift **2.35.2** + sqlite3 **3.7.1** | MIT ; SQLite domaine public | Résolution commune et tests binaires x64 Windows / arm64 Android |
| Ancien moteur Flutter | **Ne pas ajouter** sqlite3_flutter_libs **0.6.0+eol** | MIT | README le déclare obsolète avec sqlite3 3.x |
| Audio | media_kit **1.2.6** + media_kit_libs_audio **1.0.7** | MIT pour les wrappers | libmpv/FFmpeg : examiner licences/configuration exactes des binaires redistribués, notices, taille et lecture offline |
| Métadonnées | audio_metadata_reader **1.8.1** : refusé pour COMM multiples | MIT | Usage éventuel pour durée/titres seulement, après test ; lecteur COMM dédié préféré |
| Sélecteurs Windows | file_selector **1.1.0** | BSD-3-Clause | Windows natif, annulation et noms Unicode |
| Répertoire privé | path_provider **2.1.6** | BSD-3-Clause | Chemins réels, mises à jour et erreurs de stockage |
| SAF Android | Pont Kotlin minimal vers API système | Code du projet ; Android SDK | Persistable permissions, document IDs, flux/FD, renommage et export JSON sur appareil |
| Tests | flutter_test / integration_test du SDK ; Python + mutagen **1.47.0** pour audit | SDK ; mutagen GPL-2.0-or-later | Mutagen n'est pas distribué avec l'application |

Preuve COMM : dans l'archive 1.8.1, `lib/src/parsers/tags/id3v2.dart`,
`processFrame()` ne possède aucun handler `COMM` ; le cas par défaut fait
`metadata.customMetadata[frameId] = ...`. Les répétitions s'écrasent et le contenu est
traité en Latin-1 brut. La simple présence de `List<Comment>` dans le modèle ne prouve
donc rien. Le helper `readMetadata()` n'expose pas ces commentaires non plus. C'est une
**incompatibilité déduite de la source**, pas un test Dart exécuté sur les MP3.
Lot 1 : lecteur ID3 en lecture seule avec toutes les COMM (langue, description,
encodage, contenu), ID3v2.3 et 2.4, bornes, désynchronisation et tags malformés ; versions
non prises en charge signalées explicitement sans association hasardeuse. Pas de fork
complet de la bibliothèque ni de réécriture de tags.

Preuve SQLite : `sqlite3` 3.7.1 déclare `SQLITE_ENABLE_FTS5` dans ses options de
compilation et fournit des cibles Android/Windows. Cela ne démontre pas que chaque
artefact final possède effectivement FTS5 : exécuter CREATE/MATCH dans les packages livrés.
Le package utilise des native assets et des téléchargements de build vérifiés, pas
`sqlite3_flutter_libs`. Aucun téléchargement ne devra se produire au runtime final.

Preuve audio : `media_kit` possède du code pour les URI Android `content://` via FD.
Cela ne valide ni les fournisseurs SAF, ni le seek, ni la persistance après redémarrage.
Les wrappers MIT n'établissent pas la licence de toutes les bibliothèques natives ;
ce point reste une porte de validation avant distribution, avec alternative lecteur
natif Windows/Android derrière la même interface si le bundle ne convient pas.

Pas de `pubspec.yaml` ni de lockfile créés : leur résolution serait prématurée sans SDK
et sans projet. Avant modules métier : épingler SDK, résoudre ces versions, lancer
un spike natif isolé puis conserver le lockfile et l'inventaire transitif des licences.

Sources consultées : archives versionnées liées dans le JSON, README et code de ces
archives. Références officielles pour les prochains spikes :
[SAF](https://developer.android.com/training/data-storage/shared/documents-files),
[DocumentsContract](https://developer.android.com/reference/android/provider/DocumentsContract),
[FTS5](https://sqlite.org/fts5.html),
[WAL](https://sqlite.org/wal.html),
[synchronous](https://sqlite.org/pragma.html#pragma_synchronous),
[Flutter Windows](https://docs.flutter.dev/platform-integration/windows/building).
Ces liens sont des références de développement, jamais des URLs appelées par l'application.

## 6. Accès aux MP3 et Android

Windows : dossier explicitement choisi, récursivité optionnelle, chemins Unicode,
gestion des fichiers verrouillés, disparus et volumes amovibles.

Android : choix principal **SAF avec autorisation URI persistante** par dossier,
via `ACTION_OPEN_DOCUMENT_TREE`, `takePersistableUriPermission`, parcours DocumentFile /
DocumentsContract. Le pont expose flux et descripteurs seekables, capacités, identifiants
et URI opaques ; il ne prétend pas que l'URI est un chemin de disque. Tester sélection
sur stockage interne et carte SD, reboot, révocation, fichier déplacé/supprimé et fournisseur
sans seek. Aucune permission générale d'accès à tous les fichiers n'est requise pour SAF.
Un fournisseur réseau n'est pas une source fiable offline : lecture vérifiée en mode avion,
et copie privée proposée explicitement si nécessaire, jamais automatique de toute la collection.

La copie privée optionnelle doit vérifier l'espace libre, afficher son coût et être
annulable avec nettoyage du temporaire. Une collection de 30 Go demande potentiellement
30 Go supplémentaires ; ne pas en faire le chemin normal. La désinstallation efface
base et copies privées : expliquer l'export du suivi avant désinstallation.

`file_selector` sait sélectionner des documents/dossiers mais son README ne garantit
pas la gestion complète des droits persistants ; l'enregistrement Android d'un nouveau
document n'y est pas supporté. Utiliser `ACTION_CREATE_DOCUMENT` pour JSON et
`ACTION_OPEN_DOCUMENT` pour l'import, sans inventer de chemin réel.

Matching futur : COMM unique cohérente > nom historique > nom `TITRE SYSTEME` connu >
titre normalisé provisoire. Un conflit fort interdit les replis automatiques. Statut
historique du CSV et vérification du MP3 local sont séparés. Un fichier inaccessible
ne doit pas provoquer l'effacement de tous les liens ni la perte du suivi.

Lecture en arrière-plan prolongée Android : non promise par la seule présence du lecteur.
Tester cycle de vie et audio focus ; si retenue pour V1, intégrer service média/notification
et persistance des checkpoints. Sans ce service, mettre en pause et sauvegarder lors
du passage en arrière-plan afin de ne pas continuer sans checkpoint fiable.

## 7. Suivi d'écoute durable

Proposition : SQLite privé WAL, `foreign_keys=ON`, `synchronous=FULL`, écrivain sérialisé,
transactions courtes et contrôle des erreurs disque plein. Position enregistrée toutes
les 5 secondes de lecture effective et immédiatement à pause, seek confirmé, changement
d'épisode, interruption audio et transitions de cycle de vie quand elles surviennent.
Le stockage suspendu ou défaillant doit afficher un état d'erreur, pas une fausse sauvegarde.
Ne pas attendre uniquement la fermeture ; ne pas copier naïvement le `.sqlite` sans son WAL
pour une sauvegarde (utiliser l'API backup ou un snapshot cohérent).

Lier position/favori/statut à `episode_id`. Reprise au dernier commit valable, position
bornée par durée locale fiable sans écraser aveuglément la durée de l'autre appareil.
Une durée transférée reste indicative. La borne de perte visée est 5 secondes en lecture
active **si les commits réussissent**, pas une garantie contre toute panne matérielle.

Règles proposées : `NON_ECOUTE` -> `EN_COURS` après progression effectivement jouée,
pas à la simple ouverture. Fin automatique après seuil `(position/durée >= 0,95 OU
reste <= 60 s)` **et au moins 10 secondes de lecture continue sans seek dans cette
zone**, ou événement de fin précédé de cette lecture. Un seek seul ne termine jamais
l'épisode. Le statut `ECOUTE` reste jusqu'à action manuelle, même en réécoute. Un reset
confirmé met atomiquement statut NON_ECOUTE, position 0 et completed_at null et produit
un changement causal explicite. Favori indépendant. Seuil et garde de lecture testés
avec horloge virtuelle ; comportement sur durée inconnue : pas de seuil automatique.

## 8. JSON portable et fusion sûre

Contrat proposé (schéma JSON formel à écrire au lot correspondant) :

```json
{
  "format": "index-listening-sync",
  "schema_version": 1,
  "export_id": "UUID-aleatoire",
  "exported_at": "2026-10-23T12:00:00Z",
  "source_device_id": "UUID-local-pseudonyme",
  "episodes": [{
    "episode_id": "mrx:mr_x_2013_04_27.mp3",
    "position_ms": 125000,
    "duration_ms": 2288600,
    "listening_status": "EN_COURS",
    "is_favorite": false,
    "last_played_at": "2026-10-23T11:59:55Z",
    "completed_at": null,
    "field_meta": {
      "position": {"change_id": "A:12", "vv": {"A": 12}},
      "status": {"change_id": "A:7", "vv": {"A": 7}},
      "favorite": {"change_id": "A:13", "vv": {"A": 13}}
    }
  }]
}
```

L'exemple abrège les device IDs dans les marqueurs ; les valeurs réelles sont les UUID
pseudonymes d'installation. Compteur monotone local durable dans SQLite, incrémenté
transactionnellement ; jamais réutilisé après restauration. Une installation restaurée
sur un autre appareil crée un nouvel ID d'écrivain pour éviter les compteurs concurrents.

Pour chaque champ (position, statut, favori), vecteur de versions :

1. Vecteurs égaux et valeurs égales : aucune écriture. Même version avec valeur
   différente : fichier incohérent, rejet avant fusion.
2. Un vecteur domine strictement l'autre : garder sa valeur, quelle que soit la date
   ou la valeur numérique de la position. Pas de stratégie `max(position_ms)`.
3. Vecteurs incomparables : conflit présenté « Conserver cet appareil » / « Utiliser
   le fichier ». Une résolution jointe prend le maximum composante par composante,
   puis un nouveau compteur local ; réexporter diffuse la résolution.

Dates informatives, jamais arbitre silencieux. `false`, position zéro et NON_ECOUTE
sont de vraies écritures, jamais des suppressions de lignes. Conserver leurs marqueurs
sans purge de causalité tant que les anciens exports doivent rester compatibles.
Un fichier ancien ne ressuscite ainsi pas un favori retiré dont il est l'ancêtre.
Un changement concurrent reste un conflit, même avec horloges très différentes.

Statut et position fusionnent indépendamment, puis validation d'invariants : un reset
concurrent avec une progression doit produire un choix explicite et cohérent pour le
groupe concerné, pas l'état hybride NON_ECOUTE/position non nulle. Les métadonnées liées
(`completed_at`, `last_played_at`, durée indicative) suivent leur champ propriétaire.
Un favori modifié indépendamment ne doit pas perturber ces décisions.

Validation avant aperçu : maximum proposé **10 Mio**, 10 000 épisodes, profondeur 16,
64 appareils par vecteur, chaînes bornées (ID 256 caractères), entiers non négatifs
≤ 2^53-1 et position/durée ≤ 7 jours. Ces limites sont des paramètres documentés V1,
à ajuster explicitement si le corpus futur l'exige. Refuser clés JSON dupliquées,
NaN/Infinity, booléens employés comme nombres, épisodes dupliqués, enums inconnues,
versions incompatibles et données interdites. Pas de SQL, code ou chemin interprété.
Lecture limitée avant décodage ; listes bornées même si le fichier est petit.

Champs autorisés en liste blanche : aucun chemin, URI, MP3, URL ou texte documentaire.
Épisodes inconnus gardés en quarantaine de suivi bornée, jamais liés arbitrairement,
puis rattachés uniquement si le même ID arrive dans un catalogue ultérieur.

Import : valider -> calculer un aperçu sur une révision locale -> choisir les conflits
-> confirmer -> reprendre la révision sous verrou -> snapshot logique cohérent du suivi
et métadonnées -> transaction SQLite unique. Si le suivi a changé entre aperçu et
confirmation (lecture en cours), refaire l'aperçu plutôt qu'écraser. Échec : rollback.
Garder le snapshot pour une restauration manuelle ultérieure, sans toucher aux liens audio.
Enregistrer `export_id` et empreinte canonique du contenu ; même ID/contenu réimporté :
aucun effet ; même ID/contenu différent : rejet. Les marqueurs assurent aussi l'idempotence
si un même état est réexporté avec un nouvel export_id. L'export ne modifie pas le suivi.

Un transfert Windows -> Android ne change que le récepteur. Pour le retour, nouvel
export Android -> import Windows. Aucun réseau automatique. Le JSON est du texte personnel
non chiffré, pas une preuve d'authenticité : confirmation et validation ne prouvent pas
l'identité de l'émetteur. Expliquer cela simplement dans l'aide, sans compte ni secret.

## 9. Renommage global facultatif

Aucun fichier n'est renommé au Lot 0. Fonction future séparée du scan et de la fusion :

1. Plan déterministe pour toutes les associations localement sûres, cible exacte CSV
   embarquée, même dossier ; exclure correspondances provisoires et contradictions.
   Un fichier déjà conforme reste inchangé ; un autre nom déjà descriptif est conservé
   et signalé, sans conversion forcée. Le cas nominal transforme les noms historiques.
2. Vérifier noms Windows réservés, caractères interdits, longueur totale, points/espaces
   finaux, Unicode/casse, collisions entre cibles et avec tous les fichiers existants,
   droits fournisseur et fichiers ouverts. Cible non sûre : ignorer, jamais improviser.
3. Afficher bilan global puis bouton de confirmation explicite ; annuler ne modifie rien.
4. Revérifier la source et la cible après confirmation. Sérialiser le run ; écrire
   l'intention durable avant chaque renommage. Utiliser une primitive sans remplacement
   Windows, pas `rename` POSIX qui peut écraser. Ne pas renommer un fichier en lecture.
5. Android : vérifier capacité DocumentsContract et politique de collision du fournisseur,
   récupérer l'URI effectivement retournée. Un flag de capacité seul ne prouve pas la
   garantie d'absence d'écrasement ; désactiver si cette garantie n'est pas éprouvée.
6. Après succès, transaction de mise à jour du lien et du journal ; vérifier empreinte
   des octets avant/après. Au redémarrage, réconcilier les intentions pendantes avec
   source/cible et empreinte. Si les deux existent, si aucun n'existe ou si une empreinte
   diffère, signaler pour résolution ; ne jamais supprimer arbitrairement.

Pas d'atomicité globale promise. Les cycles/collisions sont ignorés au premier jet,
pas résolus par une cascade risquée. Rapports persistants succès/échecs/ignorés ; les
identités, suivis et favoris restent identiques. Aucune copie/transcodage/réécriture ID3.

## 10. Stratégie de tests et portes de validation

### Résultats exécutés au Lot 0

Environnement : Linux x64, Python 3.12.14, SQLite 3.53.1 ; Mutagen 1.47.0 installé
uniquement dans `/tmp/index-lot0/python`. Commandes réellement exécutées :

```sh
python3 -m pip install --target /tmp/index-lot0/python mutagen==1.47.0 --disable-pip-version-check
PYTHONPATH=/tmp/index-lot0/python python3 tools/lot0/audit.py > /tmp/index-lot0/audit.json
python3 tools/lot0/verify_dependencies.py
```

- **3 tests exécutés, 3 réussis** : FTS5 avec accents, pondération titre et texte réel
  comprenant les deux morceaux ; rollback transactionnel après erreur de contrainte ;
  processus tué avec transaction pendante, réouverture conservant le dernier commit
  (10 000 ms, pas 15 000 ms) et `integrity_check=ok`.
- Audit corpus réussi : concordances réelles CSV/TXT/COMM sur 6 épisodes, dates,
  fichiers présents et non altérés. Ces assertions sont distinctes des 3 tests SQLite.
- 10 archives pub.dev vérifiées (SHA-256 et extraits de licence) ; revue source pour
  COMM, FTS5, URI audio et capacités du sélecteur.
- **Non exécutés** : Flutter/Dart, builds Windows/Android, écoute/seek réels, SAF,
  suivi applicatif, export/import, migrations applicatives et renommage. Le téléchargement
  du manifeste du SDK Dart depuis `storage.googleapis.com` a reçu un refus proxy HTTP 403 ;
  aucune vérification TLS ou somme d'archive n'a été désactivée pour contourner ce refus.

La sonde est intentionnellement limitée aux formats réels connus, pas un parseur robuste
de production ni un générateur SQLite. L'arrêt du processus teste SQLite après commit,
pas une coupure d'alimentation réelle ni un chronomètre applicatif de cinq secondes.

### Matrice de recette à implémenter dans les lots suivants

| Domaine | Tests indispensables | Cible / porte |
|---|---|---|
| Parsing | BOM/sans BOM, invalid UTF-8, ordre variable, rubriques absentes/répétées/erronées, NEL, description intégrale, auteur vide, multiples musiques | Unitaires Dart, Lot 1 |
| ID3 | Toutes les COMM de la fixture, langues/descriptions multiples, contradictions, encodages, v2.3/2.4, absence, troncatures, tags énormes bornés | Dart + oracle Mutagen indépendant, Lot 1 |
| Matching | Priorités strictes, nom historique/CSV sans TXT, titre provisoire, doublons, conflit fort bloquant le repli, quatre statuts journal | Unitaires et intégration, Lot 2 |
| Catalogue | CSV 10/13 colonnes, absents/ambiguïtés, staging, génération reproductible, intégrité/FTS, absence de chemins de dev et de MP3 | Builder, Lots 2–3 |
| Migrations | Vn -> Vn+1, retrait/ajout/correction, interruption, overrides, conservation exacte liens/favoris/suivi, relecture de vieux JSON | SQLite intégration, Lot 2 puis recette |
| Recherche | Accents/casse/apostrophes, plusieurs mots, source/musique, vide, syntaxe malveillante, snippets, classement attendu | Dart et **FTS5 des deux binaires** |
| Lecture/reprise | Play/pause/seek, durée inconnue/changée, fichier disparu, kill avant/après checkpoint, disque plein, arrière-plan/audio focus | Windows + Android réel, Lot 5 |
| Statuts/favoris | Seuil, seek seul, réécoute, reset confirmé, favoris indépendants, rescan/rename/migration | Domaine + intégration UI |
| Fusion | Ancêtre/concurrent/résolu, favori et progression indépendants, reset concurrent, retrait, horloges décalées, imports répétés et même ID altéré | Unitaires avec permutations, Lot 5 ter |
| JSON hostile | Tronqué, types/duplicats, versions futures, taille/profondeur/vecteurs excessifs, inconnus, permission refusée, échec au milieu de transaction | Unitaires/fuzz borné + intégration |
| Transferts | Windows -> Android -> Windows, données divergentes, perte de permission, restauration et chemins locaux inchangés | Deux cibles réelles, mode avion |
| Renommage | Copies temporaires, collisions casse/Unicode, fichiers existants/ouverts, droits refusés, changement depuis aperçu, crash à chaque frontière | Windows + SAF éprouvé, Lot 5 bis |
| Packages | Asset SQLite présent, aucun MP3, installation vierge sans TXT/CSV ni réseau, FTS5 et détails complets, mise à jour conservatrice | Windows x64 + Android arm64, Lot 6 |
| Confidentialité | Observation réseau/mode avion, aucune URL audio appelée, manifests/permissions et dépendances natives audités | Packages release, Lot 6 |

Tests de fusion : propriétés d'idempotence, non-perte de champs indépendants et
convergence après diffusion d'une résolution explicite. Génération de séquences avec
3 appareils, retours d'exports anciens et horloges inversées ; ne pas seulement tester
deux copies identiques. Fault injection aux frontières commit/fichier/URI ; snapshots
comparés avant/après échec. Ne pas simuler SAF par des chemins Linux et appeler cela
une validation Android.

Plateformes proposées : Windows 10/11 x64 (toolchain Visual Studio C++ sur runner Windows),
Android minSdk proposé 23, cible SDK supportée/exigée au moment de distribution ; appareil
arm64 réel avec stockage interne et SD si disponible, émulateur pour CI complémentaire.
La matrice minSdk/NDK/Gradle exacte sera fixée après résolution des dépendances, pas déduite
de la seule version annoncée d'un plugin. Mesurer recherche/import et taille APK sur
corpus complet ; budget initial recherche <200 ms à chaud sur appareil de référence,
à publier avec appareil et quantiles, jamais comme mesure obtenue au Lot 0.

## 11. Risques et suite proposée

| Priorité | Risque | Traitement / condition de sortie |
|---|---|---|
| Haute | Corpus complet absent | Obtenir CSV intégral + tous les TXT avant catalogue release ; échantillon clairement étiqueté |
| Haute | COMM perdues dans le package candidat | Lecteur dédié, oracle indépendant, fixtures adverses avant association automatique |
| Haute | SAF/seek/rename variables selon fournisseur | Pont natif, tests appareil/reboot, désactivation du renommage si garantie insuffisante |
| Haute | Concurrence de suivi et resets pendant fusion | Vecteurs par champ, invariants, aperçu révisé, transaction et snapshot |
| Haute | Décalage FS/SQLite après crash | Intentions persistantes et réconciliation, aucune promesse d'atomicité globale |
| Haute | FTS5 et audio seulement déclarés par les packages | Spikes exécutables puis tests des distributions Windows/Android |
| Haute | Licences libmpv/FFmpeg et droits de redistribution du corpus | Inventaire exact des binaires/notices et autorisation du catalogue avant diffusion publique |
| Moyenne | Perte de progression/disque plein/arrière-plan | Checkpoints, FULL, gestion des erreurs, tests de kill ; service média si écoute de fond retenue |
| Moyenne | Normalisations destructrices et écarts CSV/TXT | Brut préservé, version de normalisation, staging et diagnostics |
| Moyenne | Contenu JSON trompeur ou excessif | Bornes/validation, confirmation ; aucune authenticité prétendue |
| Moyenne | Mise à jour écrasant l'utilisateur | Diff catalogue séparé, migrations et sauvegardes testées |
| Moyenne | Empreintes coûteuses sur 30 Go | Scan progressif hors UI, cache d'empreintes ; hash complet ciblé avant opération destructive |

Ordre de travail proposé après revue du Lot 0 :

1. **Lot 1** : épingler toolchain, spike COMM/FTS5 et accès SAF/lecture local minimal
   sur cibles, puis parseurs purs et fixtures ; aucun GUI complet. Les spikes de
   plateforme réduisent les risques avant d'investir les autres lots.
2. **Lots 2–3** : identités, staging, builder SQLite, migrations et recherche, avec
   protection du futur suivi dès le schéma initial.
3. **Lots 4–5** : interface Windows, lecteur/suivi durable, Android et cycle de vie.
4. **Lots 5 bis / 5 ter** : renommage contrôlé et fusion JSON, chacun avec faute injectée
   et essais natifs ; ne pas les repousser hors de la V1.
5. **Lot 6** : corpus complet, licences, signatures, installation vierge, mise à jour,
   tests hors ligne et transferts bidirectionnels sur les distributions finales.

Le Lot 0 peut être revu maintenant ; les preuves de plateformes restent des portes
explicites des prochains lots. **Aucun passage au Lot 1 n'est engagé.**
