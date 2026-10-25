# Journal des décisions — Lot 0 — 23 octobre 2026

Ces décisions sont proposées pour revue avant le Lot 1. Aucun module applicatif
n'est créé. La demande courante limite le travail au Lot 0 ; les étapes ultérieures
décrites dans le cahier des charges ne constituent pas une autorisation de les exécuter.
La décision D14 ci-dessous a été explicitement adoptée par l'utilisateur après l'audit.
Les décisions D15–D17 enregistrent ensuite le Lot 1 explicitement lancé ; les mentions
d'environnement et de modules absents des décisions initiales décrivent l'état historique.
Les décisions D18–D22 concernent le Lot 2 ; D23–D24 concernent le Lot 3,
explicitement lancé le 24 octobre 2026.

| Réf. | Décision | Motif / réserve |
|---|---|---|
| D01 | Flutter/Dart partagé, adaptateurs Windows et Android | Socle proposé par la V1.4 ; validations natives encore à exécuter. |
| D02 | Asset `catalogue.sqlite` prérempli, copie privée de travail, migrations par diff | Recherche immédiate sans corpus externe ; aucun MP3 dans les packages. |
| D03 | Drift 2.35.2 + sqlite3 3.7.1 comme candidats de persistance | Migrations et SQLite natif avec FTS5 ; ne pas ajouter sqlite3_flutter_libs 0.6.0+eol. |
| D04 | Identité stable fondée sur le nom historique normalisé | Indépendance chemins, renommages, dates/titres et mises à jour du catalogue. |
| D05 | Lecteur COMM dédié au Lot 1 | audio_metadata_reader 1.8.1 ne conserve pas toutes les COMM ; preuve par revue de source, sans test Dart. |
| D06 | SAF Android par pont Kotlin minimal, URI persistantes par défaut | Évite de dupliquer plus de 30 Go ; copie privée facultative et explicitement demandée. |
| D07 | media_kit 1.2.6 + libs audio 1.0.7 comme candidats, pas validation finale | API locale/URI documentée ; essais réels et licences des binaires natifs obligatoires. |
| D08 | SQLite WAL + synchronous FULL, checkpoint de lecture cible 5 s | Perte bornée au dernier commit confirmé ; pas de dépendance à l'événement de fermeture. |
| D09 | Fusion JSON par champ avec vecteurs de versions causales | Résiste au décalage d'horloge, aux retraits de favoris et remises à zéro. |
| D10 | Renommage journalisé par fichier après aperçu et confirmation | Pas de transaction atomique globale entre SQLite et le système de fichiers. |
| D11 | CSV par noms de colonnes, colonnes supplémentaires conservées | Les données réelles ont 13 colonnes, pas les 10 annoncées. |
| D12 | Tolérance encadrée des écarts documentaires et rapport d'anomalies | Six fixtures, noms sans tiret, caractères U+0085, références connexes hors échantillon. |
| D13 | Tests Linux distincts des portes de validation Windows/Android | L'environnement courant ne dispose ni de Flutter/Dart ni d'appareil cible. |
| D14 | Deux COMM concordantes suffisent à retenir un identifiant historique et à écarter les autres commentaires isolés | Décision utilisateur du 23 octobre 2026 ; plusieurs identifiants ayant chacun une paire restent ambigus. Le résultat alimente le matching `id3_comment`, avec preuve et diagnostic conservés. Voir l'[addendum normatif](../regle-association-COMM.md). |
| D15 | Package racine Dart `index_core`, SDK Dart 3.13.5 / Flutter 3.47.7 épinglés | Cœur partagé sans UI, sans stockage et sans dart:io ; adaptateur fichier exporté séparément. |
| D16 | Lecteur COMM dédié borné, résolution séparée du matching ; oracle `ID3(load_v1=False)` | Les cinq commentaires ID3v1 synthétisés par Mutagen au Lot 0 ne sont pas des COMM physiques supplémentaires. Chaque MP3 réel possède deux COMM physiques. |
| D17 | unorm_dart 0.3.3 en production, test 1.31.1 et crypto 3.0.7 en développement, lockfile versionné | Licences et SHA-256 officiels vérifiés. Parsing sans réseau et sans réécriture du corpus ; analyse et tests reproductibles via `tools/lot1/check.sh`. |
| D18 | sqlite3 3.7.1 directement, migrations SQL explicites ; Drift différé | Aucun besoin de couche réactive UI au Lot 2. SQLite 3.54.0 exécuté sur Linux ; checksums native assets conservés. crypto 3.0.7 utilisé en production pour les empreintes. |
| D19 | Corpus 716/716 intégré sans correction implicite | État initial avant D22 : 715 identités structurées, une quarantaine sans extension historique, quatre fiches à vérifier ; données et diagnostics conservés. Voir le [bilan Lot 2](../lot2/bilan.md). |
| D20 | Seed documentaire déterministe, sans MP3, liens ni données personnelles | Artefact intermédiaire dans assets ; import depuis SQLite possible sans sources externes. FTS5 et packaging restent aux lots suivants. |
| D21 | Schéma v2, transactions WAL/FULL, sources dédupliquées par snapshot, choix manuels et suivi préservés | Rollback/annulation/SIGKILL et migration v1→v2 testés ; un catalogue absent/inaccessible n'entraîne pas de suppression. |
| D22 | Corrections utilisateur `a332d3f` intégrées et seed régénéré en `corpus-2026-10-24-lot2-r2` | 716 épisodes, aucune erreur/quarantaine/fiche à vérifier ; 29 avertissements historiques ou U+0085 conservés. Sources corrigées par l’utilisateur, sans correction implicite du moteur. |
| D23 | Lot 3 : FTS5 externe, migration v3, triggers sur `episodes` | Titre/description/sources/musique indexés atomiquement ; migration des fiches existantes, reconstruction et contrôle FTS avec comparaison du contenu. |
| D24 | Requêtes littérales AND, unicode61 remove_diacritics 2, BM25 10/1/2/1 | Bornes et paramètres SQL ; extraits en texte brut, filtres relationnels. Aucune lemmatisation/sémantique annoncée ; Windows/Android restent à qualifier. |
| D25 | Interface Éditorial validée pour le Lot 4 le 25 octobre 2026 | HTML autonome de référence, apparence claire/sombre dans Paramètres, catalogue compact, sources/musiques structurées et lecteur compact. Audio et suivi simulés ; aucune validation native implicite. Voir la [référence UI](../ui/README.md). |
| D26 | Dernière révision Éditorial confirmée comme référence du Lot 4 le 25 octobre 2026 | Remplace la présentation antérieure : commandes de fenêtre, sous-titre du logo, suppression de Fiche précédente, titres des références/morceaux en en-tête, valeur vide « Aucune donnée », fond des épisodes connexes harmonisé, lettrine et police du lecteur. Les aperçus renommage/JSON sont dans Paramètres ; leurs implémentations restent aux Lots 5 bis/5 ter. Voir les [ajustements validés](../ui/README.md#ajustements-validés--25-octobre-2026). |
| D27 | Compléments Windows du Lot 4 adoptés le 25 octobre 2026 | Archive portable, dossier utilisateur choisi, MP3 facultatifs avec report explicite et nouvelle demande au démarrage, sauvegarde confirmée avant fermeture et checkpoints conservés. Recherche configurable par champ. Voir les [spécifications](../lot4/specifications.md). |
| D28 | Renommage et transfert limités aux règles utilisateur | Conversion unique nom historique → TITRE SYSTEME. Transfert manuel du suivi, sans audio ni chemins locaux, export dans exports/ du dossier utilisateur avec nom explicite sans espaces. Implémentations réelles maintenues aux Lots 5 bis/5 ter. |
| D29 | Lot 4 explicitement lancé : Flutter Windows séparé, cœur Dart conservé | Éditorial raccordé à SQLite/FTS5, dossiers et scan, suivi manuel durable ; lecteur réel et Android maintenus au Lot 5. |
| D30 | Données portables choisies, pointeur minimal à côté de l'exécutable, verrou OS et backup SQLite avant fermeture | Pas de profil vide en cas d'indisponibilité ; sauvegardes dernière/précédente et copie contrôlée du dossier, sans suppression de l'ancien. |
| D31 | Schéma v4 pour réglages locaux, seed v3 accepté et recherche configurable par champ | Réglages séparés du catalogue de référence ; no seed personnel ; import et FTS conservés. |
| D32 | file_selector 1.1.0 et window_manager 0.5.2 épinglés ; archive Windows sans installateur | Licences/archives vérifiées ; CI Windows prépare tests natifs, runtime app-local et archive. Linux validé, recette Windows non exécutée ici. Voir le [bilan Lot 4](../lot4/bilan.md). |

Les versions observées sont des versions d'audit, pas un `pubspec.lock` résolu.
L'implémentation devra d'abord résoudre l'ensemble avec un SDK Flutter/Dart épinglé,
conserver le lockfile et les sommes des artefacts, puis franchir les essais natifs.
