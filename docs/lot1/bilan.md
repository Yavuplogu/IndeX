# Lot 1 — Parseur TXT, lecteur ID3 et résolution COMM

Ce bilan décrit l'état à la fin du Lot 1. Le [Lot 2](../lot2/bilan.md) a depuis ajouté
le corpus complet, le matching et SQLite ; les limites marquées « lots ultérieurs »
ci-dessous constituent le relevé historique de cette étape.

Statut : implémenté et vérifié sur **Linux x64**, avec Dart 3.13.5 fourni par Flutter
3.47.7. Aucun build Windows/Android ni essai sur appareil cible n'a été effectué.
Le Lot 2 n'est pas engagé. Aucun commit ni push automatique.

## Périmètre livré

Le dépôt racine est un package Dart `index_core`, utilisable par les futures
applications Flutter. Aucune application Flutter, interface, base SQLite, scan de
bibliothèque ou export JSON n'a été créé.

| Entrée publique | Fonction |
|---|---|
| `TxtParser.parse(bytes)` | Fiche structurée, source exacte, rubriques et diagnostics |
| `Id3Reader.parse(bytes)` | Lecture des COMM d'un préfixe ID3v2.3/v2.4 en mémoire |
| `Id3Reader.read(TagByteSource)` | Lecture bornée du préfixe de tag, sans charger l'audio |
| `FileTagSource(File)` | Adaptateur `dart:io` en lecture seule, fermeture garantie |
| `CommResolver.resolve(tag)` | Identifiant historique retenu, preuve, candidats et commentaires écartés |
| `canonicalOriginalName(text)` | NFC et normalisation prudente d'un nom complet MP3 |

Importer `package:index_core/index_core.dart` pour le cœur sans `dart:io` et
`package:index_core/index_io.dart` pour l'adaptateur de fichier. Le futur pont SAF
Android pourra fournir `TagByteSource` sans transformer une URI en chemin local.

## Contrat TXT

- UTF-8 strict, avec/sans BOM ; encodage divergent rejeté avec diagnostic et octets
  disponibles. Entrée limitée à 2 Mio avant décodage ; une entrée excessive n'est
  pas recopiée dans le résultat.
- Neuf rubriques extraites ; ordre variable. Rubriques répétées : toutes conservées,
  aucun choix implicite pour la valeur structurée. Champs indispensables absents ou
  vides, noms historiques invalides et incohérences de dates : erreurs explicites.
- Dates civiles vérifiées, sans normalisation silencieuse par DateTime. En cas de
  divergence, `broadcastDate` reste null.
- `sourceBytes` conserve les octets d'origine ; `rawText` conserve le texte décodé sans
  BOM ; `TxtSection.rawContent` conserve contenu, CR/LF, NEL et séparateurs finaux.
  Les getters de présentation (`description`, etc.) enlèvent les espaces de bord,
  sans modifier les paragraphes internes. Le futur stockage peut conserver les deux.
- Les rubriques connues sont des délimiteurs exacts. Une rubrique majuscule inconnue
  autonome ou proche d'un libellé connu est signalée et conservée ; pas de correction
  automatique. Une phrase comme « CIA : un rôle... » reste dans la description. Une
  rubrique inconnue sans valeur peut être ambiguë avec du texte : diagnostic et
  source brute permettent l'examen humain.
- Sources brutes conservées, y compris listes d'épisodes connexes. Structuration limitée
  aux libellés explicites Référence/Auteur/Éditeur, champs absents laissés null ; texte
  libre non interprété. « Aucune donnée » ne crée aucune fausse référence.
- Musiques séparées par blocs ; groupes incomplets acceptés. Un attribut répété sans
  ligne blanche déclenche un nouveau groupe avec diagnostic, sans écraser sa valeur
  précédente. Texte non structuré conservé. URLs extraites comme texte, jamais appelées.

`hasErrors` indique si une intervention est nécessaire ; une fiche partiellement lisible
reste accessible avec ses diagnostics, sans être annoncée valide.

## Contrat ID3 et règle COMM

Les trames COMM physiques sont conservées séparément, même si leur langue et description
sont identiques. Chaque commentaire expose indice dans le tag, langue, description,
texte, encodage et octets de charge utile après retrait des préfixes de format et de
la désynchronisation. Les images et autres données audio ne sont pas décodées.

Supports : ID3v2.3 (Latin-1/UTF-16 avec BOM), ID3v2.4 (également UTF-16BE/UTF-8),
tailles big-endian/syncsafe, désynchronisation globale v2.3/par trame v2.4,
groupement, DLI, en-têtes étendus sans CRC/restrictions et footer v2.4 cohérent.
Limites par défaut : tag total 16 Mio, charge COMM 256 Kio, 4 096 trames.

Les versions/révisions inconnues, COMM compressées/chiffrées, CRC/restrictions d'en-tête
étendu non pris en charge, textes invalides et troncatures produisent une erreur explicite.
**Une lecture partielle n'autorise ni confirmation ni repli par nom**. Les commentaires
déjà lus restent disponibles pour diagnostic. L'absence de tag ID3v2 est un état distinct ;
le commentaire ID3v1 seul n'est pas une preuve COMM utilisée par ce lecteur.

La résolution suit l'[addendum adopté](../regle-association-COMM.md) :

- Un seul identifiant soutenu par au moins deux trames : `pair`, preuve `comm_pair_v1`.
  Les autres identifiants isolés sont écartés et tracés.
- Un seul identifiant sans contradiction : `unique`, preuve `comm_unique_v1`.
- Plusieurs paires ou identifiants isolés contradictoires : `conflict`.
- Aucun candidat : `noCandidate` ; seul cet état autorise les replis par nom ultérieurs.
- Lecture inexploitable ou répétition d'un même indice de trame : `blocked`.

Le résultat contient `originalName`, `supportingFrames`, `ignored` (avec raison),
`candidates`, `evidenceRule` et `allowsFilenameFallback`. Il ne contient pas encore de
`matching_status` confirmé : le Lot 2 devra contrôler les doublons MP3/TXT et retrouver
la fiche/catalogue correspondant exactement à cet identifiant. Les tests réels prouvent
la concordance des identifiants extraits, pas un moteur de matching global déjà livré.

## Correction de l'observation ID3 du Lot 0

L'audit initial utilisait Mutagen avec son comportement par défaut, qui synthétise une
entrée `COMM:ID3v1 Comment:eng` à partir du commentaire ID3v1 de fin de fichier. Les cinq
commentaires supplémentaires figurant dans `docs/lot0/audit-resultats.json` n'étaient donc
pas des troisièmes trames COMM physiques dans les tags ID3v2. Cette distinction avait été
incorrectement décrite dans l'audit initial ; les octets des fichiers ont permis de la vérifier.

Les **six MP3 ont chacun deux COMM physiques** concordantes en anglais/français. Cinq
ont en plus un commentaire ID3v1 séparé, qui n'est jamais compté comme une nouvelle voix.
Le rapport historique reste inchangé ; l'oracle du Lot 1 utilise explicitement
`ID3(load_v1=False)` dans Mutagen 1.47.0. Aucun filtrage arbitraire d'une vraie trame COMM
nommée « ID3v1 Comment » n'est introduit dans le lecteur : un test synthétique la conserve.
Les cas A/A/B ou A/A/texte sont exercés par des octets synthétiques, hors corpus source.

## Dépendances et reproductibilité

- SDK observés : Flutter 3.47.7, révision `abaf9c523780a608bd46686fd5e53740a07077f8`,
  Dart 3.13.5 ; épinglés par `.flutter-version`/`.dart-version` et minimum SDK pubspec.
- Production : **unorm_dart 0.3.3**, pur Dart, sans dépendance transitive et sans I/O,
  licence MIT. SHA-256 d'archive officielle vérifié :
  `b4f4d2aff27d65a5fc37f400d4c09e55d7535359315acbe3b895a9add4de3a23`.
- Développement : **test 1.31.1** et **crypto 3.0.7**, BSD-3-Clause. Archives et licences
  vérifiées avant ajout. `crypto` sert aux empreintes des fixtures et ne fait pas partie
  des dépendances de production. `pubspec.lock` contient les versions et SHA-256 résolus,
  y compris les dépendances transitives de test.
- Mutagen 1.47.0 reste un oracle Python de développement, hors application, comme au Lot 0.

Depuis la racine, après activation du SDK (dans cet environnement :
`. /workspace/toolchains/activate-flutter.sh`) :

```sh
dart pub get --enforce-lockfile
bash tools/lot1/check.sh
```

Le script relit le lockfile **hors ligne**, vérifie le formatage, analyse le code avec
informations fatales, puis lance les tests. Il place l'état et le cache de l'analyseur
dans `.dart_tool` ignoré par Git : `--cache` seul ne déplace pas le fichier UUID de
l'analyseur ; `ANALYZER_STATE_LOCATION_OVERRIDE` est également nécessaire dans cette
machine dont le répertoire personnel est en lecture seule. Aucune modification de HOME.

Sous Windows, les mêmes commandes Dart sont utilisables après activation du SDK et
installation des dépendances ; le helper bash est une commodité Linux. Aucune exécution
Windows n'est revendiquée ici.

L'oracle indépendant est versionné dans `test/fixtures/id3-oracle.json`. Pour le
régénérer explicitement avec Mutagen 1.47.0 disponible :

```sh
PYTHONPATH=<répertoire-contenant-mutagen> python3 tools/lot1/generate_id3_oracle.py
```

Ce générateur ne modifie que l'oracle JSON et contrôle les SHA-256 des MP3 avant/après.
Les tests Dart normaux ne nécessitent pas Python.

## Résultats et limites

84 tests Dart réussis sur Linux x64 : UTF-8/BOM/CRLF/NEL, paragraphes, rubriques
absentes/répétées/erronées, dates, sources/musiques, encodages et structure ID3, troncatures,
bornes, groupement/DLI/footer, désynchronisation, erreurs de fichiers, règle COMM et
indépendance de l'ordre. Une sonde déterministe de 400 entrées arbitraires/malformées
est comprise dans ces tests ; ce n'est pas une certification exhaustive du format.

Les six couples réels sont comparés à l'oracle indépendant et aux descriptions/nombres
de références/musiques du Lot 0. SHA-256 des MP3/TXT vérifiés avant/après et comparés aux
empreintes d'origine. Aucun CSV/TXT/MP3 modifié, renommé ou ajouté. Analyse statique sans
problème et formatage contrôlé. Les essais ayant échoué avant correction ne sont pas
présentés comme des validations.

Restent aux lots ultérieurs : lecture du journal CSV de production, association globale
avec conflits inter-fichiers, SQLite/FTS5, catalogue complet, UI, lecteur audio, suivi,
fusion JSON, renommage et validations natives Windows/Android/SAF. Les spikes natifs
proposés lors du Lot 0 n'ont pas été exécutés ; le SDK Android et un runner Windows
restent nécessaires pour ces portes de validation. Aucun support de ces plateformes
n'est déduit du seul succès des tests Dart sur Linux.
