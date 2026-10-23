# Journal des décisions — Lot 0 — 23 octobre 2026

Ces décisions sont proposées pour revue avant le Lot 1. Aucun module applicatif
n'est créé. La demande courante limite le travail au Lot 0 ; les étapes ultérieures
décrites dans le cahier des charges ne constituent pas une autorisation de les exécuter.

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

Les versions observées sont des versions d'audit, pas un `pubspec.lock` résolu.
L'implémentation devra d'abord résoudre l'ensemble avec un SDK Flutter/Dart épinglé,
conserver le lockfile et les sommes des artefacts, puis franchir les essais natifs.
