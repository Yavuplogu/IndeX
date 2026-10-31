# Cahier des charges fonctionnel et technique — IndeX

**Version :** 1.4 — Document de référence destiné à OpenAI Codex  
**Statut :** spécification de développement ; fonctionnalités non encore implémentées  
**Cibles :** Windows et Android  
**Langue de l'interface :** français  

## Avenant du 27 octobre 2026 — priorité Windows, Android en pause

Décision explicite de l’utilisateur : finaliser et valider Windows avant de reprendre
le développement et la recette Android. Cet avenant modifie l’ordre de livraison
des lots ; il ne retire pas Android des cibles finales.

- Priorité actuelle : stabilisation et recette Windows du Lot 5 (lecteur réel,
  reprise, suivi durable et fermeture sûre). Les Lots 5 bis et 5 ter restent
  soumis à un lancement explicite ; leur réalisation Windows pourra précéder Android.
- Le code et les adaptateurs Android existants sont conservés. Leur développement
  et leur qualification sur appareil sont différés ; la construction APK reste
  disponible manuellement, sans exécution automatique à chaque push/PR.
- Le portage devra couvrir toutes les fonctionnalités essentielles : catalogue
  SQLite hors ligne sans MP3 embarqué, recherche et fiches, associations et
  diagnostics, lecture/reprise, statuts et favoris, export/import JSON avec fusion
  sûre, ainsi que renommage facultatif avec aperçu et confirmation. Les limites
  documentées du fournisseur de stockage Android prévues au §5.5 restent applicables.
- Les règles métier, identifiants, migrations et format JSON doivent rester communs.
  Isoler les chemins Windows, URI et permissions Android, accès aux fichiers,
  lecture native et cycle de vie derrière des interfaces de plateforme. Aucune
  nouvelle fonction essentielle ne doit dépendre uniquement d’une API Windows
  sans prévoir son adaptation Android et ses critères de recette.
- La validation Windows ne vaut pas validation Android. La reprise Android exigera
  une recette sur appareil réel, incluant droits persistants, interruptions audio
  et transferts JSON dans les deux sens ; aucun calendrier n’est fixé ici.

## Avenant du 28 octobre 2026 — versions et commandes de lecture Windows

Version publique initiale `0.5.01` : état 0 (bêta) / 1 (finale), majeur 5,
mineur sur au moins deux chiffres. Chaque nouveau build de distribution réserve
le mineur suivant, y compris après un échec ; majeur et passage en finale
uniquement sur ordre explicite. Le numéro apparaît dans l’archive et l’artefact.
Voir `tools/versioning/README.md` pour le compteur et la forme SemVer interne.

Les décisions ci-dessous priment sur les comportements antérieurs du lecteur :

- Arrêt utilisateur : position zéro et statut Non écouté, favori conservé.
  Pause et fermeture conservent la reprise. Passage manuel en Écouté avec
  confirmation, arrêt et position zéro de cet épisode ; pourcentage masqué.
- En cours : pourcentage dans le bouton, sans flèche tournante. Fond de la ligne
  rempli de gauche à droite selon position/durée, uniquement pour une écoute
  commencée ; durée inconnue non estimée, progression connue conservée localement.
- Survol du curseur : horodatage ciblé ; déplacement sans retour visuel à l’ancienne
  position lors du relâchement. Flèches gauche/droite ±10 secondes hors saisie.
  Titre du lecteur cliquable vers sa fiche, date de même police/couleur que la liste.
- Auto-suivant actif par défaut : épisodes disponibles dans l’ordre de la liste
  affichée, avec ses filtres/tris, arrêt au dernier. Aléatoire inactif par défaut :
  activation = lancement immédiat d’une autre piste disponible, puis enchaînement
  aléatoire à chaque fin, prioritaire sur auto-suivant. Désactivation sans coupure
  de la piste en cours ; un seul candidat n’est pas relancé en boucle. Modes
  conservés localement. Aucun enchaînement sur arrêt manuel ou pause.
- Filtres Fichiers et associations : fond identique aux boutons du menu latéral.

Ces règles de suivi et de lecture font partie des fonctionnalités essentielles
à conserver lors de la reprise Android, qui demeure en pause.

### Moteur Windows retenu le 28 octobre 2026

Sur autorisation explicite, remplacer MCI par `just_audio` 0.10.6 et
`just_audio_windows` 0.2.3 (WinRT MediaPlayer), derrière AudioPort. Préserver
suivi, reprise, modes de lecture et distribution portable. Aucun MP3 ni moteur
FFmpeg/libmpv ajouté ; inventorier les dépendances et notices. Mesurer la latence
sur MP3 réels sous Windows avant toute promesse de déplacement quasi instantané.
Android reste en pause avec son moteur existant ; le portage futur garde la même
interface et devra valider SAF et interruptions. Voir `docs/lot5/bilan.md`.

## 1. Vision et objectifs

Créer avec **OpenAI Codex** une application nommée **IndeX** à interface graphique (GUI) permettant de parcourir, rechercher, consulter et écouter une bibliothèque locale de plusieurs centaines d'épisodes d'un même podcast. Chaque épisode dispose d'un MP3 (environ 20 à 40 minutes) et d'une fiche TXT contenant des métadonnées documentaires.

L'application doit fonctionner **entièrement hors ligne**, sur Windows et Android, sans serveur, sans compte, sans cloud ni appel à une API Internet. Le moteur de recherche doit retourner les épisodes pertinents par rapport à une requête sur un sujet. Un clic sur un résultat ouvre une fiche détaillée, avec possibilité d'écouter le MP3 présent localement.

**Objectif de V1 :** catalogue documentaire préchargé et recherche textuelle locale disponible dès le premier lancement, y compris sans fichier MP3 ; **évolution possible :** recherche sémantique locale, sans dépendance réseau. L'analyse automatique des paroles des MP3 n'est **pas** au périmètre V1.

## 2. Exigences fondamentales

- **OFF-01 :** 100 % hors ligne lors de l'importation, de la recherche, de la consultation et de l'écoute. Les URLs présentes dans les TXT sont de simples métadonnées : ne jamais les appeler ou télécharger automatiquement.
- **MULTI-01 :** versions Windows et Android, avec une base de code largement partagée.
- **DATA-01 :** lecture des fichiers sources sans altération ni modification des tags ID3. Exception explicite : renommage facultatif, global et contrôlé des MP3 sur demande de l’utilisateur, conformément au §5.5 ; aucune action implicite lors d’un scan.
- **DATA-02 :** conservation intégrale des descriptions et des références ; traçabilité des imports et des anomalies.
- **UX-01 :** interface en français, adaptée à la souris et au tactile, navigation accessible et états d'erreur compréhensibles.
- **QUAL-01 :** architecture modulaire, tests automatisés, gestion explicite des erreurs et migrations de base de données.
- **PRIV-01 :** aucune télémétrie ni transmission de données.
- **CAT-01 :** les distributions Windows et Android embarquent un **catalogue SQLite complet et prérempli**, généré à partir du `journal.csv` complet et des TXT du corpus, sans inclure de MP3.
- **CAT-02 :** titre, date, résumé intégral, sources et musiques consultables et recherchables **dès le premier lancement**, même sans dossier sélectionné.
- **CAT-03 :** le seul choix indispensable pour écouter les fichiers disponibles est celui du dossier/de la collection MP3 accessible sur l’appareil ; le CSV et les TXT ne sont **pas requis chez l’utilisateur final**.
- **PLAY-01 :** mémoriser localement progression de lecture, état non écouté/en cours/écouté et favoris, indépendamment des noms et chemins MP3 ; préserver ces données lors des mises à jour du catalogue.
- **RENAME-01 :** proposer un bouton de renommage global des MP3 reconnus, avec prévisualisation et contrôles préalables ; sans altérer l’audio ni les tags ID3, sans intervention épisode par épisode.
- **SYNC-01 :** proposer une synchronisation **manuelle** entre IndeX sur Windows et Android par export/import d’un fichier JSON portable ; aucune synchronisation automatique ni serveur n’est nécessaire.
- **SYNC-02 :** exporter uniquement les données personnelles de suivi des épisodes (statut, position de lecture, favoris et métadonnées de fusion) ; ne jamais exporter les MP3, chemins locaux ni le catalogue documentaire complet.
- **SYNC-03 :** fusionner les données importées sans écraser aveuglément les données de l’appareil cible ; prévoir contrôle, aperçu, résolution des conflits et restauration en cas d’échec.
- **CAT-04 :** conserver la capacité d’importer des TXT ou un catalogue révisé pour des épisodes nouveaux et de reconstituer le catalogue, sans écraser les liens audio locaux.

## 3. Données sources et format TXT

Des couples de fichiers **MP3** et **TXT** sont présents dans une bibliothèque locale, éventuellement organisée en sous-dossiers. Le nom courant du MP3 peut être soit un nom descriptif dérivé du titre, soit son nom historique au téléchargement. Le nom courant du TXT n'est pas un identifiant fiable.

Le fichier TXT de référence contient les rubriques :

```text
TITRE : 'Le Masque de fer' israélien
DATE DE DIFFUSION : 27/04/2013
DATE ISO : 2013-04-27
FICHIER MP3 D'ORIGINE : mr_x_2013_04_27.mp3
PAGE DE L'EMISSION : http://rendezvousavecmrx.free.fr/page/detail_emission.php?cle_emission=674
URL MP3 : http://rendezvousavecmrx.free.fr/audio/mr_x_2013_04_27.mp3

DESCRIPTION DE L'EPISODE :
[plusieurs paragraphes, à conserver intégralement]

LIVRES ET SOURCES :
Aucune donnée

MUSIQUES DIFFUSÉES :
Artiste : Yael Naim
Morceau : Paris
Album : Yael Naim
Label : Wagram (2010)

Artiste : John Barry
Morceau : Diamonds are forever
Album : Diamonds are forever (BOF)
Label : Capitol Music (2003)
```

### 3.1 Règles de parsing

1. Prendre en charge **UTF-8 avec ou sans BOM** ; si un encodage divergent est détecté, produire un diagnostic explicite plutôt que corrompre silencieusement le texte.
2. Reconnaître les libellés des rubriques et leurs contenus ; préserver l'intégralité de la description, y compris accents, sauts de ligne et ponctuation.
3. Extraire `TITRE`, `DATE DE DIFFUSION`, `DATE ISO`, `FICHIER MP3 D'ORIGINE`, `PAGE DE L'EMISSION`, `URL MP3`, `DESCRIPTION DE L'EPISODE`, `LIVRES ET SOURCES`, `MUSIQUES DIFFUSÉES`.
4. Vérifier la cohérence de `DATE ISO` et `DATE DE DIFFUSION` lorsqu'elles sont toutes deux renseignées ; signaler les divergences.
5. Interpréter « Aucune donnée » comme absence de sources, **pas** comme un titre de livre.
6. Préserver le texte brut des sources ; ne structurer auteur/titre/éditeur que lorsque le format le permet sans ambiguïté.
7. Dans `MUSIQUES DIFFUSÉES`, créer un enregistrement par groupe `Artiste`/`Morceau`/`Album`/`Label`, même lorsque certains attributs sont manquants.
8. Conserver les URLs comme texte facultatif, sans accès réseau ; ne pas les utiliser comme identité primaire.
9. Isoler la logique de parsing dans un module indépendant de l'interface et tester des rubriques absentes, répétées, mal orthographiées, vides ou dans un ordre variable.

## 4. Règle déterminante : association MP3 ↔ TXT

**Attention : le champ `FICHIER MP3 D'ORIGINE` désigne le nom historique du MP3, pas nécessairement son nom actuel sur disque.**

Exemple fourni :

- `TITRE` : `Vietnam, l'impossible ? Episode 1/3`
- MP3 renommé : `Vietnam, l'impossible Episode 1-3.mp3`
- MP3 historique : `mr_x_2006_05_19.mp3`
- TXT : `FICHIER MP3 D'ORIGINE : mr_x_2006_05_19.mp3`
- MP3 : commentaire ID3 `Comment = mr_x_2006_05_19.mp3`

**Exemple réel vérifié sur le MP3 de référence :**

- MP3 présent : `2013-04-27 - 'Le Masque de fer' israélien.mp3`
- TXT : `FICHIER MP3 D'ORIGINE : mr_x_2013_04_27.mp3`
- ID3v2.3 : `COMM::eng = mr_x_2013_04_27.mp3`, `COMM::fra = mr_x_2013_04_27.mp3`.
- Il existe également `COMM:ID3v1 Comment:eng`, dont le contenu est **autre chose** qu'un nom de MP3 ; ne pas retenir systématiquement le premier commentaire.
- Le titre ID3 diffère légèrement du titre TXT (guillemets) : **ne pas** s'appuyer sur une identité exacte des titres.

### 4.1 Algorithme d'association (ordre strict)

**A — Correspondance forte, prioritaire :**

1. Extraire et normaliser prudemment le champ TXT `FICHIER MP3 D'ORIGINE` (espaces parasites, guillemets d'encadrement éventuels ; conserver la valeur brute en base).
2. Lire **toutes** les trames ID3 `COMM` du MP3, quelles que soient leur langue et leur description ; sélectionner les contenus ressemblant à un nom de fichier `.mp3` et comparer à l'identifiant historique du TXT.
3. Si une correspondance unique et non conflictuelle est trouvée, associer les fichiers avec `matching_method = id3_comment` et un statut confirmé.

**B — Repli :** si A échoue parce que les commentaires sont absents ou inutilisables, comparer le **nom actuel** du MP3 au nom d'origine déclaré par le TXT. Une correspondance unique reçoit `matching_method = original_filename`.

**C — Dernier repli :** comparer le titre TXT au nom courant du MP3 après une normalisation contrôlée des caractères Windows (`\\ / : * ? " < > |`), espaces, ponctuation et Unicode ; cette méthode est **provisoire** (`matching_method = normalized_title`) et doit être vérifiable avant validation définitive.

**D — Échec / conflit :** mettre le fichier en file d'attente pour association manuelle. **Ne jamais associer arbitrairement** si plusieurs MP3 ou plusieurs TXT correspondent au même identifiant historique, ou si deux commentaires d'un MP3 indiquent des noms incompatibles.

Conserver la méthode, le statut, les valeurs trouvées, et une raison explicite en cas d'échec. Ne pas inférer une correspondance à partir de la date seule. Un même MP3 ne peut pas être associé automatiquement à plusieurs épisodes distincts.

### 4.2 Fichier de référence des correspondances : `journal.csv`

Un **fichier CSV dédié, fourni à Codex en complément des fichiers de test MP3/TXT**, contient les correspondances déjà établies entre les épisodes, les noms actuels des MP3 et les fichiers TXT. Le fichier de référence est `journal.csv` ; l'échantillon fourni a été nommé `journal(1).csv`. Ce journal est destiné à faciliter le développement, les tests et, facultativement, l'import du catalogue. Il ne remplace **ni** les TXT pour leurs descriptions complètes **ni** la vérification locale des métadonnées ID3 dans l'application finale.

**Format réellement fourni :** CSV UTF-8 avec BOM possible, séparateur `;`, première ligne d'en-têtes. Colonnes dans leur ordre actuel :

| Colonne | Signification / règle |
|---|---|
| `FICHIER MP3 D'ORIGINE` | Nom historique du fichier, identifiant de rapprochement avec le TXT et le commentaire ID3. |
| `TITRE SYSTEME` | Nom actuel du MP3, tel qu'il apparaît sur le système de fichiers Windows (avec extension). |
| `TITRE WEB` | Titre éditorial ; ne constitue pas un identifiant unique fiable. |
| `DATE DE DIFFUSION` | Date de diffusion, au format ISO `AAAA-MM-JJ` dans l'échantillon. |
| `URL MP3` | URL d'origine conservée à titre informatif ; aucun téléchargement automatique. |
| `FICHIER TXT` | Nom exact du fichier TXT correspondant, extension comprise. |
| `CORRESPONDANCE ID3` | Résultat déclaré par le processus ayant généré le CSV : `CONFIRMEE`, `NON_VERIFIEE`, `CONFLIT` ou `ABSENTE`. |
| `Statut` | Statut général du traitement source (ex. `OK`) ; distinct de la concordance ID3. |
| `Erreur` | Message d'erreur éventuellement émis par le traitement source. |
| `DateExecution` | Horodatage d'exécution du traitement source ; dernière colonne. |

**Interprétation exacte de `CORRESPONDANCE ID3` :**
- `CONFIRMEE` : la valeur du commentaire ID3 correspond au nom historique attendu, **selon le journal généré**.
- `NON_VERIFIEE` : le MP3 n'a pas été analysé.
- `CONFLIT` : les valeurs analysées diffèrent ou sont contradictoires.
- `ABSENTE` : aucune métadonnée exploitable n'a été trouvée.

**Règles impératives :**
1. Dans le développement Codex, utiliser le CSV comme **jeu de vérité de référence déclaré** pour tester le rapprochement noms MP3/TXT et les cas de statut ; le statut `CONFIRMEE` provenant du journal ne prouve pas, à lui seul, qu'un MP3 a été relu par l'application. Distinguer `journal_status` et `local_verification_status`.
2. Croiser `FICHIER MP3 D'ORIGINE`, `TITRE SYSTEME` et `FICHIER TXT` avec les fichiers effectivement disponibles. Ne jamais inventer un chemin absolu à partir du CSV et ne pas présumer que les fichiers sont dans le même répertoire.
3. **Au moment de la construction du produit**, fusionner le CSV complet et toutes les fiches TXT en une base SQLite documentaire versionnée et préindexée FTS5. **En fonctionnement final**, embarquer cette base : l’utilisateur ne doit fournir ni CSV ni TXT pour consulter et rechercher les épisodes. Conserver une voie d’import facultative de nouvelles fiches TXT ou d’un CSV actualisé pour les ajouts futurs.
4. Le CSV peut faciliter la construction et les tests du catalogue sans transférer les plus de 30 Go d'audio vers Codex Cloud. Prévoir seulement quelques MP3 de test contrôlés, ainsi que les TXT nécessaires. Ne pas ajouter toute la bibliothèque audio au dépôt Git.
5. Vérifier les doublons d'identifiants historiques, les noms TXT ou MP3 absents, les statuts contradictoires et les lignes incomplètes ; générer un rapport exploitable. Ne jamais transformer automatiquement un `CONFLIT` ou `NON_VERIFIEE` en association confirmée sur la seule foi d'un nom de fichier.
6. Les descriptions complètes, références littéraires et musiques restent extraites des TXT. `TITRE WEB` et le CSV ne doivent pas écraser silencieusement les contenus éditoriaux lus dans les TXT ; signaler les divergences.

**Critères de test associés :** parser un CSV à séparateur point-virgule et BOM ; retrouver les cinq correspondances de l'échantillon fourni ; valider les quatre états ID3 avec des données de tests dédiées ; vérifier que l'import direct MP3/TXT fonctionne toujours en l'absence de CSV ; ne jamais assimiler un `Statut = OK` à une confirmation ID3.

### 4.3 Catalogue documentaire intégré aux exécutables — exigence structurante

**Décision validée :** l’application finale contient une base SQLite documentaire **préremplie**, construite en amont par Codex avec le `journal.csv` complet et **tous les TXT**. Les MP3 (bibliothèque dépassant 30 Go) **ne sont pas embarqués**. Le CSV n'est pas le format consulté en priorité à l’exécution ; SQLite est le catalogue local distribué.

**Pipeline de génération du catalogue (build / préparation des releases) :**
1. Lire `journal.csv` (UTF-8 avec/sans BOM, séparateur `;`), valider les en-têtes et les 10 colonnes, contrôler les identifiants, les anomalies et les doublons.
2. Pour chaque ligne, retrouver `FICHIER TXT` parmi les TXT fournis au projet ; analyser titre, dates, description intégrale, sources et musiques, en préservant la donnée originale ; consigner les TXT absents ou ambigus.
3. Fusionner les champs de correspondance CSV et les données documentaires TXT sur l’identifiant historique `FICHIER MP3 D'ORIGINE`, puis signaler les conflits (titre/date/identifiant) plutôt que choisir silencieusement.
4. Générer un fichier SQLite **versionné**, contenant tous les épisodes, les variantes de noms (`TITRE SYSTEME`, nom historique, nom TXT), les sources, les musiques et un index FTS5 fonctionnel ; vérifier les contraintes de données et fournir un rapport (totaux, manquants, doublons, incohérences).
5. Inclure le SQLite de référence dans les assets Flutter des **deux** applications ; tester sa présence dans les packages effectivement livrés. Stocker une copie de travail modifiable dans l’espace privé applicatif pour y conserver les liens MP3, les imports facultatifs et autres données utilisateur. Ne jamais écrire directement dans un asset empaqueté.
6. Lors d’une mise à jour applicative, prévoir une migration/diff du catalogue de référence, préserver les associations locales et les ajouts utilisateur, et ne pas supprimer les données sans confirmation.

**Premier démarrage :** le catalogue doit être visible et interrogeable immédiatement, sans configuration, sans Internet et sans présence de MP3/TXT locaux. L’utilisateur peut choisir un dossier/ensemble de MP3 ; l’application scanne les fichiers audio, lit leurs métadonnées ID3 `COMM`, puis applique l’algorithme de §4.1 en bénéficiant aussi des noms actuels connus du CSV. Les fichiers reconnus deviennent lisibles. Les autres épisodes restent consultables et affichent « Audio non disponible ». Conserver les associations audio dans SQLite local et rafraîchir uniquement sur demande ou selon une stratégie incrémentale documentée.

**Priorité de rapprochement à l'exécution :** (1) identifiant historique dans les commentaires ID3, (2) nom courant égal au nom historique, (3) nom courant égal à `TITRE SYSTEME` du catalogue ; enfin (4) rapprochement normalisé/provisoire du titre si aucune discordance forte n’a été détectée. Les conflits sont traités explicitement, avec possibilité d’association manuelle. Un `CORRESPONDANCE ID3 = CONFIRMEE` dans le CSV signale une vérification historique **et ne remplace jamais une vérification du MP3 local**.

**Critères propres au catalogue livré :** les installations propres Windows et Android affichent le catalogue et retournent des résultats de recherche en mode avion sans qu’aucun TXT, CSV ou MP3 ne soit présent ; après sélection d’un dossier contenant le MP3 de référence, il devient lisible par identification ID3. Un MP3 au nom historique et un MP3 renommé d’après `TITRE SYSTEME` doivent également pouvoir être identifiés sans TXT. Les éventuels manquants du corpus sont reportés et ne sont pas considérés comme des épisodes entièrement documentés.

## 5. Fonctionnalités V1

### 5.1 Importation et maintenance

- À l'installation, charger le catalogue inclus automatiquement ; pour activer l'écoute, laisser l'utilisateur sélectionner un dossier de **MP3** depuis l'interface, avec prise en charge optionnelle des sous-dossiers.
- En phase de génération du catalogue, analyser les TXT ; sur l’appareil utilisateur, scanner principalement les MP3 et les associer au catalogue préchargé, extraire la durée audio et les métadonnées utiles (titre ID3, artiste, album, éventuelle couverture) sans charger toutes les données audio en mémoire.
- Indexer les épisodes même si le MP3 correspondant est absent : les fiches doivent rester consultables, avec lecture désactivée.
- Afficher le bilan : épisodes du catalogue, MP3 détectés, associations confirmées/provisoires, MP3 inconnus, audio absent, doublons et erreurs ; le rapport de génération du catalogue suit séparément les TXT manquants ou incorrects.
- Réimporter de manière **idempotente** et incrémentale : ne pas créer de doublons ; mettre à jour les fiches modifiées, détecter les déplacements et les fichiers manquants, conserver les choix manuels.
- Utiliser des transactions SQLite et gérer proprement les interruptions/annulations ; ne pas effacer massivement les anciens enregistrements en cas de dossier temporairement inaccessible.
- Fournir une interface de résolution des correspondances problématiques.

### 5.2 Recherche

- Champ de recherche libre en français ; recherche sur titre, description et sources, avec classement par pertinence et poids plus fort sur les titres.
- SQLite **FTS5** si disponible dans les distributions effectivement retenues ; valider sa présence sur Windows et Android avec des tests exécutés sur les deux plateformes.
- Utiliser `unicode61` / normalisation adaptée aux accents et à la casse ; requêtes paramétrées et échappement sûr de la syntaxe FTS5.
- Afficher les extraits textuels expliquant la pertinence du résultat ; filtres optionnels par date, sources et disponibilité audio.
- Gérer l'absence de résultats, les mots courants, les apostrophes, les accents, les phrases composées et les requêtes vides.
- Ne pas promettre de recherche par sens en V1 : **préparer une interface de moteur de recherche interchangeable** pour une V2 sémantique intégralement locale.

### 5.3 Consultation des épisodes

- Liste avec titre, date, durée, disponibilité MP3 et éventuellement extrait du résumé.
- Fiche détaillée : titre TXT, date, description complète, livres et sources, musiques, métadonnées du fichier local ; URLs d'origine affichables comme texte, sans requête automatique.
- Lecteur MP3 local : lecture, pause, reprise, recherche dans la piste, barre de progression, durée et position ; gestion explicite des fichiers introuvables ou illisibles.
- Navigation Windows : fenêtre redimensionnable, liste et panneau de détail ; Android : navigation tactile vers un écran de détail.
- La fiche reste fonctionnelle même si l'audio n'est pas importé.

### 5.4 Stockage Android

- **Objectif retenu :** catalogue documentaire SQLite préinstallé sur le téléphone ; possibilité de conserver également l’ensemble des MP3 sur le téléphone pour une écoute hors ligne, sans exiger les TXT après compilation.
- Éviter toute supposition sur l'accès direct aux chemins Windows. Étudier et valider le **Storage Access Framework** d'Android (sélection de dossier/fichiers, URI, permissions persistantes lorsque possibles).
- Pour une fiabilité hors ligne, prévoir un mécanisme explicite de **copie/import dans le stockage privé de l'application** ou une alternative basée sur des URI persistantes éprouvées. Documenter le coût en espace disque, les permissions et le comportement après déplacement/suppression des sources.
- La base SQLite locale est propre à chaque appareil : **aucune synchronisation automatique entre Windows et Android en V1**. Un **transfert manuel de suivi JSON**, décrit au §5.7, permet néanmoins de fusionner les écoutes et favoris ; les MP3 restent propres à chaque appareil.
- Le logiciel ne télécharge aucun podcast depuis Internet.

### 5.5 Renommage global facultatif des fichiers MP3

**Objectif :** permettre à l’utilisateur de convertir en une seule opération les noms historiques peu explicites (`mr_x_2013_04_27.mp3`) vers les noms descriptifs déjà connus dans le catalogue de référence (`2013-04-27 - 'Le Masque de fer' israélien.mp3`, valeur `TITRE SYSTEME` issue du CSV). Cette fonction n’est **jamais** déclenchée automatiquement : l’utilisateur l’active via un **bouton dédié « Renommer les MP3 »** après sélection et analyse de sa bibliothèque. Aucun choix épisode par épisode n’est nécessaire.

**Règles fonctionnelles :**
1. Parcourir tous les MP3 accessibles dans le dossier/ensemble sélectionné (sous-dossiers selon l'option de scan) et déterminer les épisodes reconnus par le moteur de matching. Seuls les fichiers associés **sans ambiguïté** à une entrée du catalogue peuvent être renommés automatiquement ; ignorer et signaler les fichiers inconnus, non vérifiés ou conflictuels.
2. Prendre comme cible préférentielle le nom `TITRE SYSTEME` du catalogue (extension `.mp3`) ; ne pas recalculer librement le nom à partir de `TITRE WEB` lorsque la valeur de référence existe. Vérifier les caractères interdits, noms réservés Windows, chemins trop longs, collisions après normalisation Unicode/casse et particularités du système de fichiers.
3. Présenter **avant toute écriture** une prévisualisation globale : nombre de fichiers analysés, renommages prévus, fichiers déjà conformes, ignorés et conflits ; proposer un bouton de confirmation unique et une possibilité d’annuler sans effet. L’utilisateur ne sélectionne pas les épisodes individuellement.
4. Ne jamais écraser un fichier existant. Détecter les collisions entre cibles et avec des fichiers non sélectionnés, y compris les noms ne différant que par casse ; en cas de risque, **ne pas renommer** les fichiers concernés et les inclure dans le rapport. Le lot peut traiter les autres fichiers sûrs.
5. Conserver les fichiers dans leur dossier d’origine : **renommage uniquement**, sans copie, déplacement vers un autre dossier, transcodage, réécriture ID3 ni téléchargement. Un nom déjà explicite doit rester inchangé ; relancer l’opération doit être idempotent.
6. Mettre à jour les associations locales (chemin/URI et nom courant) après **chaque** renommage réussi et conserver le lien à l’épisode, ses favoris et sa progression. Enregistrer un journal persistant de l’opération (avant/après, horodatage, résultat, erreur) pour diagnostic et reprise après interruption.
7. Réaliser l’opération par fichier avec gestion explicite des échecs ; un crash ou une coupure ne doit pas laisser la base pointant définitivement vers des noms inexistants. Au redémarrage, réconcilier le journal et les fichiers réellement présents. Fournir un bilan final des succès/échecs. Ne pas prétendre à une transaction atomique globale sur le système de fichiers.
8. Refuser de renommer un fichier actuellement en lecture tant que le lecteur ne l’a pas libéré ; informer l’utilisateur. Respecter les droits d’écriture et autorisations de stockage (Windows et Android) ; si le fournisseur de documents Android ne permet pas un renommage fiable, **désactiver cette action pour ces fichiers** avec une explication, plutôt que de contourner les permissions ou dupliquer 30 Go de données.
9. L’absence de `journal.csv` séparé chez l’utilisateur n’empêche pas le renommage : utiliser les noms explicites **intégrés à SQLite**. Si le catalogue ne contient pas de cible sûre, ignorer le fichier.

**Recette :** sur des copies de test, renommer en un clic plusieurs MP3 historiques ; vérifier le nom cible de référence, l’absence d’écrasement, l’immutabilité du contenu audio et des tags ID3, l’actualisation des liens et la conservation de la progression/favoris. Tester les collisions, fichiers inconnus, lecture en cours, refus de permission, interruption et exécution répétée. Tester séparément les capacités Windows et Android.

### 5.6 Suivi d’écoute, reprise et favoris

**Statuts par épisode, visibles partout :** `NON_ECOUTE`, `EN_COURS`, `ECOUTE`. Afficher un indicateur graphique **et textuel/accessibile** dans le catalogue, les résultats de recherche et la fiche détaillée (par exemple : cercle vide « Non écouté », progression « En cours », coche « Écouté »). Ne pas confondre disponibilité du MP3 et état d’écoute. Permettre de filtrer par statut, de trier et de marquer manuellement comme écouté/non écouté ; le retour à « non écouté » réinitialise explicitement la progression après confirmation adaptée.

**Reprise robuste :**
1. À chaque lecture, associer la position au **`episode_id` stable**, jamais uniquement au chemin ou au nom de fichier. Enregistrer `position_ms`, `duration_ms`, `last_played_at`, `playback_status` localement dans SQLite.
2. Sauvegarder périodiquement pendant la lecture (cible initiale : toutes les **5 secondes**) et immédiatement lors d’une pause, d’un changement d’épisode, d’une fermeture normale et d’un changement d’état applicatif quand possible ; ne jamais compter seulement sur l’événement de fermeture, qui peut ne pas survenir lors d’un crash/coupure. Éviter les écritures excessives, utiliser des transactions et vérifier la durabilité SQLite.
3. Après relancement, proposer ou appliquer la reprise à la dernière position valide (comportement réglable en préférences). Si le MP3 est absent, conserver la progression jusqu’à ce qu’il soit de nouveau accessible. Borner les positions aberrantes par la durée réelle et tolérer les changements de durée entre fichiers.
4. Lors de la première lecture, faire passer `NON_ECOUTE` à `EN_COURS` après une progression effective ; lorsqu’un épisode atteint la fin, passer à `ECOUTE` et conserver `completed_at`. Définir et documenter un seuil automatique proche de la fin (proposition : au moins 95 % **ou** moins de 60 secondes restantes, selon la durée) tout en permettant la modification manuelle. Un simple déplacement ponctuel du curseur vers la fin ne doit pas, à lui seul, valider une écoute complète.
5. **Favoris :** bouton bascule favori/non-favori sur les fiches et les listes ; section ou filtre « Favoris » ; conservation durable après fermeture, renommage des MP3, rescans et mises à jour du catalogue. Les favoris sont indépendants du statut d’écoute.
6. Toute donnée de suivi reste stockée localement, fonctionne hors ligne et survit aux mises à jour. Le **transfert manuel par fichier JSON** prévu en V1 au §5.7 permet de fusionner le suivi entre Windows et Android, sans synchronisation automatique.
7. En cas d’interruption brutale, accepter une perte de progression limitée à l’intervalle entre deux sauvegardes, jamais promettre la restauration de la milliseconde exacte. Tester notamment la fermeture forcée et la coupure simulée entre sauvegardes.

**Recette :** lancer un épisode, avancer dans la lecture, forcer l’arrêt du processus puis relancer et reprendre près de la dernière position enregistrée ; vérifier les statuts avant/après une écoute, le seuil de fin, l’action manuelle, les filtres et la persistance des favoris à travers un renommage global et une mise à jour de catalogue.

### 5.7 Synchronisation manuelle Windows ↔ Android du suivi d’écoute

**Objectif :** permettre à un utilisateur de transférer ses états d’écoute, positions de reprise et favoris entre plusieurs installations d’**IndeX**, sans compte, cloud, serveur, réseau obligatoire ou transfert de MP3. Chaque installation conserve sa propre base SQLite et fonctionne indépendamment entre deux transferts.

**Interface :** deux commandes explicites dans Paramètres → Suivi et synchronisation : **« Exporter mon suivi »** et **« Importer un suivi »**. L’export génère un fichier portable suggéré `index-suivi-AAAA-MM-JJ.json`, enregistrable dans un emplacement choisi par l’utilisateur (Windows) ou via un sélecteur de documents/partage compatible Android. L’import permet de choisir le fichier, d’en afficher le résumé (provenance, date, nombre d’épisodes, modifications, conflits), de confirmer ou annuler la fusion ; pas d’écriture avant confirmation. L’utilisateur transfère lui-même le fichier par le moyen de son choix (USB, partage de fichier, Bluetooth, etc.).

**Contrat JSON versionné :** spécifier un schéma documenté comportant `format: "index-listening-sync"`, `schema_version`, `export_id` unique, `exported_at` au format ISO 8601 UTC, `source_device_id` pseudonyme local stable et une collection `episodes`. Pour chaque épisode : `episode_id` stable fondé sur l’identifiant historique, `position_ms`, `duration_ms` si connue, `listening_status` (`NON_ECOUTE`, `EN_COURS`, `ECOUTE`), `is_favorite`, `last_played_at`/`completed_at` si applicable. Inclure également **des marqueurs de modification par champ** (statut, position et favori), par exemple identifiants de changement et versions par appareil, permettant d’identifier des modifications contradictoires ; un unique `updated_at` par épisode est insuffisant. Conserver les suppressions et retraits de favoris comme changements explicites afin qu’un ancien état ne les rétablisse pas. Les dates seules, soumises au décalage des horloges, ne doivent pas décider silencieusement de tous les conflits.

**Données exclues :** aucun MP3, aucune URL ou chemin/URI local, aucune copie du catalogue SQLite de référence, aucun détail documentaire inutile à la fusion, aucun secret ou donnée d’authentification. Limiter la taille des fichiers et le nombre d’entrées acceptés, valider les types et les identifiants ; rejeter sans effet un fichier malformé, incompatible ou excessif. Ne jamais exécuter de contenu importé. L’export ne doit pas altérer les états locaux.

**Règles de fusion :**
1. Faire correspondre les entrées par `episode_id`, **indépendamment du nom actuel et du chemin du MP3**. Conserver les données d’épisodes inconnus sous une forme contrôlée ou les signaler sans les affecter à un épisode arbitraire ; prévoir la compatibilité entre versions du catalogue.
2. Fusionner séparément l’état d’écoute, la position et le favori : un changement récent de favori ne doit pas écraser une progression de lecture indépendante. Préserver les changements explicites de remise à zéro (`NON_ECOUTE`) et de retrait des favoris.
3. Définir une stratégie reproductible d’ordre des modifications (identifiants/version de changement par appareil, ou journal d’événements pour résolution plus robuste). Lorsque deux changements concurrentiels ne peuvent être ordonnés sûrement, **présenter le conflit à l’utilisateur** et proposer « Conserver cet appareil » / « Utiliser le fichier ». Ne pas supposer que le maximum de `position_ms` représente toujours la bonne position.
4. Afficher avant confirmation le nombre d’épisodes nouveaux dans le suivi, de modifications non conflictuelles et de conflits à résoudre. L’import est idempotent : importer deux fois le même export ne recrée aucun doublon et ne régénère pas artificiellement des horodatages.
5. Appliquer les changements dans **une transaction SQLite** après validation et prise d’un point de sauvegarde/restauration ; en cas d’échec, revenir à l’état local précédent. Ne jamais remplacer globalement le fichier SQLite utilisé par IndeX.
6. Documenter clairement la bidirectionnalité **manuelle** : exporter de Windows puis importer sur Android ne met à jour qu’Android ; pour renvoyer les modifications Android vers Windows, effectuer l’export inverse. Aucune opération silencieuse en arrière-plan.
7. Préserver les préférences propres à l’appareil, les permissions Android, les chemins des MP3 et les historiques techniques locaux ; le système de renommage global reste indépendant de cette fonctionnalité.

**Recette :** exporter/importer Windows → Android puis Android → Windows ; vérifier statuts, reprise et favoris, y compris après renommage local ; simuler modification simultanée d’un même épisode sur deux appareils, retrait d’un favori, remise à `NON_ECOUTE`, horloges désynchronisées, import répété, catalogue de versions différentes, fichier tronqué et refus de permission Android. Aucun accès Internet n’est requis pour ces opérations.

## 6. Modèle de données proposé (à raffiner par Codex)

**`catalog_versions`** : `version`, `generated_at`, `schema_version`, `source_digest` ; suivi du catalogue de référence fourni dans la release.

**`episodes`** : `id` (clé interne), `original_mp3_name` (clé métier normalisée + valeur brute), `title`, `broadcast_date`, `description`, `source_text`, `txt_path_or_uri`, `mp3_path_or_uri` (nullable), `current_mp3_name` (nullable), `audio_duration_ms` (nullable), `original_page_url` (nullable), `original_mp3_url` (nullable), `matching_method`, `matching_status`, `match_notes`, `source_fingerprint`, `imported_at`, `updated_at`.

**`literary_sources`** : `id`, `episode_id`, `raw_text`, ordre, et champs structurés facultatifs uniquement lorsque fiables.

**`music_tracks`** : `id`, `episode_id`, `sequence`, `artist`, `track_title`, `album`, `label`.

**`local_playback_state`** : `episode_id` (référence unique stable), `position_ms`, `duration_ms`, `playback_status`, `last_played_at`, `completed_at`, `updated_at` ; suivi propre à chaque appareil, persistant et migrable.

**`user_favorites`** : `episode_id` (unique), `is_favorite`, `updated_at` ; facultativement préférences de lecture dans `user_preferences` (reprise automatique, etc.).

**`sync_changes` / `sync_imports`** : versions ou identifiants uniques des modifications de statut, position et favoris par appareil ; journal minimal des imports (`export_id`, source, date, résultat), conflits résolus et marqueurs de retrait, pour fusion fiable et idempotente. **`sync_device`** : identifiant pseudonyme persistant de l’installation.

**`rename_runs` / `rename_items`** : historique de renommages globaux, noms/chemins avant/après, états `planned/succeeded/skipped/failed`, erreurs et marqueurs de réconciliation après interruption.

**`import_runs` / `import_issues`** : historique d'import, chemin/URI, catégorie d'anomalie, gravité, message, statut de résolution.

**`episodes_fts`** : table virtuelle FTS5 sur `title`, `description` et les sources agrégées, synchronisée lors des insertions/modifications/suppressions. Définir clairement la stratégie de maintenance de l'index (triggers ou synchronisation transactionnelle), ainsi qu'une commande de reconstruction.

**Contraintes :** distinguer les données de référence incluses à la distribution des données locales mutables (`local_audio_links`, imports et préférences), afin de préserver les liens lors des mises à jour ; clés étrangères actives, migrations versionnées, gestion des doublons d'identifiants historiques (ne pas créer aveuglément une contrainte UNIQUE si des données contradictoires doivent être enregistrées pour examen), chemins/URI séparés des identités métiers.

## 7. Architecture logicielle proposée

**Socle suggéré :** Flutter et Dart ; SQLite + FTS5 pour recherche locale ; bibliothèques de lecture audio et de métadonnées validées sur Windows/Android. Pas de dépendance réseau pendant l'utilisation.

Modules distincts :

1. `domain` — entités Episode, Source, MusicTrack, MatchingCandidate, ImportIssue ; règles métiers.
2. `data/parsers` — parseur TXT avec tests de fixtures, lecture de tags ID3.
3. `data/storage` — SQLite, migrations, index FTS5, repositories, chargement du catalogue intégré et conservation des associations utilisateur.
4. `services/import` — scan des fichiers, association, détection des conflits, transactions, réindexation.
5. `services/search` — interface du moteur de recherche et implémentation FTS5.
6. `services/audio` — lecture locale et gestion d'indisponibilité.
7. `platform` — abstraction Windows/Android pour dossier, fichier, URI et copies d'import.
8. `ui` — écrans bibliothèque préremplie, recherche, détails, sélection des MP3, erreurs, paramètres.
9. `services/rename` — planification et exécution contrôlée du renommage global, rapport de collisions, vérification des autorisations, journal et réconciliation après crash.
10. `services/sync` — export JSON versionné, import et validation, fusion par champ, aperçu de conflits, transaction SQLite et historique d’import.
11. `tools/catalog_builder` — outil de développement/CI de construction déterministe de SQLite depuis `journal.csv` + tous les TXT ; validation et rapport de couverture, sans dépendance aux MP3 complets.

Sélectionner des packages maintenus et vérifier **avant codage** leur licence, leur disponibilité, leur compatibilité Windows/Android, la lecture des trames `COMM` multiples et le fonctionnement de la lecture locale. `audio_metadata_reader` peut servir de candidat, sans être imposé sans test sur les fixtures. Documenter les dépendances et verrouiller leurs versions dans le projet.

## 8. Parcours utilisateurs

**Premier lancement :** catalogue documentaire immédiatement disponible → effectuer une recherche et consulter une fiche → sélectionner facultativement le dossier MP3 → scanner et associer les audios → écouter les épisodes disponibles.

**Réimport :** l'utilisateur ajoute/renomme des MP3/TXT → relance l'import → actualisations sans doublons → anomalies visibles et corrigeables.

**Android :** l'utilisateur transfère ses fichiers sur le téléphone → autorise la sélection des documents → choisit les données à importer → copie locale si retenue → consulte et écoute sans réseau.

## 9. Fiabilité, sécurité et performances

- Import résistant aux fichiers malformés ou incomplets ; une erreur sur un épisode ne bloque pas tous les autres.
- Validation des tailles et chemins, lecture progressive si possible, protection contre les parcours de chemin arbitraires et injection dans les requêtes SQLite/FTS.
- Priorité à l'absence de perte ou de modification des sources ; accès lecture seule sur les MP3/TXT.
- Affichage d'un indicateur de progression pour l'import ; possibilité d'annuler proprement.
- Catalogue de plusieurs centaines d'épisodes sans blocage notable de l'interface ; indexation et I/O en dehors des tâches UI lourdes.
- Sauvegarde/portabilité : documenter le processus de régénération du catalogue depuis CSV + TXT, sa version et son rapport de couverture ; toute sauvegarde de la base devra tenir compte de la portabilité des chemins.
- Ne jamais afficher comme « association confirmée » une simple similarité de titres.
- Un fichier JSON importé est une entrée non fiable : limiter sa taille, contrôler son schéma/version et ses valeurs, assurer une fusion transactionnelle sans modifier le catalogue embarqué ni les liens locaux aux MP3.

## 10. Tests et critères d'acceptation

### Jeux de tests

0. **Installation vierge sur Windows et Android** : catalogue prérempli consultable et interrogeable sans fichiers externes, sans accès Internet ; intégrité du SQLite embarqué et conservation des liens lors d’une mise à jour.

1. **Fixture réelle** : `2013-04-27 - 'Le Masque de fer' israélien.txt` et MP3 associé ; valider l'association par commentaires anglais/français, non par titre.
2. MP3 renommé, nom original présent dans `COMM` ; association confirmée.
3. MP3 conservant son nom historique mais sans `COMM` ; repli `original_filename`.
4. Plusieurs `COMM`, dont un commentaire non pertinent ; sélectionner uniquement les candidats `.mp3` concordants.
5. `COMM` contradictoires, plusieurs MP3 correspondant au même TXT, et un MP3 correspondant à plusieurs TXT : conflits sans auto-association.
6. Variantes de titre avec `?`, `/`, guillemets, accents et espaces ; repli contrôlé, sans faux positifs.
7. TXT UTF-8 BOM, multi-paragraphes, sources absentes, musiques multiples, date invalide, rubrique manquante.
8. Réimport inchangé puis modifié : pas de doublon, mises à jour correctes, index FTS cohérent.
9. Recherche en français : accents, casse, apostrophes, phrase de plusieurs termes, tri pertinent, entrée FTS malformée.
10. Tests d'écoute locale, fichier supprimé après import, dossier révoqué sur Android, fonctionnement en mode avion.

### Critères de recette V1

- Le SQLite livré contient l’ensemble des entrées valides du `journal.csv` complet et les fiches enrichies à partir des TXT, avec rapport d’écarts connu. Les packages finaux incluent ce catalogue et FTS5.
- Une installation vierge permet la recherche dans les descriptions et la consultation des sources/musiques, sans sélection préalable d’un dossier ; aucun TXT/CSV/MP3 n’est demandé pour cette fonctionnalité.
- L’utilisateur sélectionne simplement son dossier MP3 ; reconnaissance automatique par ID3 `COMM` ou noms d’origine/renommés du catalogue ; association persistante sans modification des fichiers.

- La fixture MP3/TXT réelle est associée automatiquement grâce à `mr_x_2013_04_27.mp3` présent dans les commentaires ID3 et le TXT.
- Aucun changement d’octets ni de tags MP3/TXT durant les scans/imports (contrôle par empreinte sur fixture de test). En mode renommage explicitement confirmé, seul le **nom/chemin du MP3** peut changer.
- Tous les champs textuels de la fixture sont récupérés ; les deux morceaux sont distincts ; « Aucune donnée » ne crée pas de fausse source.
- Une réimportation identique n'ajoute pas de doublon.
- Un MP3 absent n'empêche pas de lire sa fiche ; la lecture audio est clairement désactivée.
- Les recherches indexées fonctionnent sur les distributions finales **Windows et Android**.
- L'application permet l'import et la lecture des MP3 sur un véritable appareil Android et sur Windows, sans connexion Internet.
- Les conflits sont consultables et ne sont pas résolus arbitrairement.
- Une opération globale peut renommer en un clic tous les MP3 reconnus sans écrasement ni perte des liens audio, en laissant intacts les fichiers ambigus, et génère un rapport persistant.
- Progression de lecture récupérable après arrêt forcé à l’intervalle de sauvegarde près, statuts visuels `NON_ECOUTE` / `EN_COURS` / `ECOUTE`, favoris fonctionnels et persistants.
- Export/import manuel JSON du suivi fonctionnel dans les deux sens Windows/Android, sans Internet ni MP3 ; fusion sûre, conflits explicites, répétition sans doublon et conservation des chemins audio locaux.

## 11. Développement incrémental avec Codex

**Lot 0 — Audit et plan technique.** Vérifier les packages, contraintes de stockage Android, capacité FTS5 et stratégie d'import ; produire architecture, liste des risques, plan et `AGENTS.md`. **Livrable :** document de conception et tests de faisabilité. **Ne pas développer toute l'application immédiatement.**

**Lot 1 — Parseur TXT et lecteur ID3.** Implémenter services purs, fixtures et tests de valeurs extraites, dont `COMM` multiples. **Livrable :** tests unitaires verts.

**Lot 2 — Matching et persistance.** Implémenter algorithme de correspondance, lecture facultative de `journal.csv`, modèle de données, SQLite, migrations et rapport d'import. **Livrable :** import idempotent de l'exemple et des cas d'erreur.

**Lot 3 — Recherche FTS5.** Indexation, classement et tests de recherche française. **Livrable :** requêtes pertinentes avec extraits et sans crash.

**Lot 4 — GUI Windows.** Catalogue disponible dès l’ouverture, sélection de MP3, liste de résultats, fiche détaillée, résolution d'anomalies. **Livrable :** version Windows utilisable.

**Lot 5 — Lecteur audio et Android.** Intégrer le lecteur, les abstractions de stockage Android, l'import local et une interface responsive. **Livrable :** version Android testée sur appareil réel.

**Lot 5 bis — Renommage global contrôlé.** Implémenter le bouton de conversion globale, prévisualisation, contrôle des collisions, permissions Windows/Android, journal/reprise et actualisation des liens sans perte des écoutes/favoris. **Livrable :** fonction de renommage testée sur copies de fichiers.

**Lot 5 ter — Export/import manuel du suivi.** Définir le format JSON versionné, implémenter les deux boutons, la fusion par champ, l’aperçu des conflits, la validation, les transactions et les essais Windows ↔ Android. **Livrable :** suivi portable, reprise et favoris conservés après transferts dans les deux sens.

**Lot 6 — Recette et distribution.** Tests d’installation vierge avec SQLite embarqué, mise à jour conservant les liens, mode avion, corrections, packaging/signatures, procédure d'installation et guide utilisateur. **Livrable :** distributions Windows et Android.

**Lot ultérieur facultatif :** recherche sémantique **locale**, uniquement après mesure de la pertinence de FTS5 ; prévoir taille du modèle, performances et compatibilité Android. Aucune dépendance cloud.

## 12. Consignes de collaboration avec Codex

- Travailler **exclusivement à partir de ce document**, en posant des questions seulement si une décision bloquante ne peut pas être déduite ; sinon retenir un choix prudent et le documenter.
- Avant chaque lot : proposer fichiers modifiés, choix, tests et risques. À la fin : lister modifications, commandes exécutées, résultats réels et limites.
- Ne pas déclarer qu'un test Windows/Android est validé sans l'avoir effectivement exécuté sur la plateforme concernée.
- Ne jamais réécrire les octets ou tags des MP3/TXT ; seul le renommage explicite de §5.5 peut changer le nom des MP3. Toute opération doit être explicitement déclenchée, tracée et testée.
- Maintenir `README.md`, `AGENTS.md`, un journal de décisions et une suite de tests reproductible.
- Utiliser Git et des commits cohérents, garder les gros MP3 de test hors dépôt sauf fixture anonymisée et autorisée.
- Proposer une validation humaine aux limites de chaque lot avant d'élargir le périmètre.

## 13. Points à confirmer par essais (pas des faits déjà établis)

- Répartition réelle des variantes TXT et des versions ID3 dans l'ensemble des centaines d'épisodes.
- Support effectif de toutes les variantes `COMM` par le package Dart sélectionné ; nécessité éventuelle d'un adaptateur bas niveau.
- Méthode finale d'import Android (copie privée ou URI persistante) et comportement des autorisations après redémarrage.
- Capacité FTS5 du moteur SQLite embarqué dans chaque cible.
- Politique future de transfert manuel/backup d'une bibliothèque entre appareils.
- Besoins éventuels de recherche dans les paroles (transcription audio) : exclus de la V1 tant qu'ils ne sont pas explicitement demandés.

---

## Avenant du 30 octobre 2026 — téléchargement manuel facultatif des MP3

Demande explicite utilisateur : lorsqu’un épisode n’a pas de MP3 local disponible,
remplacer Écouter par Télécharger si le champ URL MP3 du journal intégré est valide.
Cette décision complète le Lot 5 Windows et remplace l’exclusion initiale de tout
téléchargement ; elle ne lance ni le renommage (5 bis) ni le transfert JSON (5 ter).
Le majeur reste 5, conformément à la règle de versionnement utilisateur.

Le réseau n’est utilisé qu’après clic, pour le serveur indiqué dans l’URL MP3 du
journal et ses redirections HTTP/HTTPS contrôlées. Aucun compte, serveur intermédiaire,
télémétrie, recherche automatique de MP3 ou téléchargement au démarrage. Le catalogue,
la recherche, le scan, le suivi et l’écoute de fichiers locaux restent hors ligne.

Utiliser le dossier MP3 configuré ou demander un dossier existant. Recevoir sous
un nom temporaire, afficher progression (ou octets reçus si taille inconnue), proposer
Annuler et interrompre proprement à la fermeture. Publier seulement après réception
complète et contrôle de format MP3, sans jamais écraser un fichier existant. Utiliser
le nom historique exact du journal. Le fichier est ensuite associé à la fiche,
le bouton redevient Écouter, sans lecture automatique ni perte de favoris/suivi.
Une association manuelle indisponible ne change qu’après confirmation explicite.
Une erreur ou annulation ne doit pas créer d’association vers un fichier partiel.

Aucun MP3 n’est livré avec l’application. Le partage du cœur est conservé, mais
la destination SAF et la recette physique Android restent en attente du portage.


## Avenant du 31 octobre 2026 — lancement du Lot 5 bis et version 0.6.0

L’utilisateur valide le fonctionnement du dernier build Windows puis lance
explicitement le Lot 5 bis. La nouvelle série est **0.6.0**, puis incrément du
mineur à chaque build distribuable, sans remise à zéro des compteurs historiques.
Le majeur 6 et la présentation du mineur à partir de 0 sont autorisés par cette
demande ; tout autre changement de majeur ou passage en finale reste explicite.

Implémenter le §5.5 pour Windows : conversion historique → TITRE SYSTEME seulement,
aperçu et confirmation globale, collisions/permissions, journal de reprise, liens
actualisés sans perte de suivi/favoris. Le téléchargement déjà livré publie ses
nouveaux fichiers directement au nom système ; il reste indépendant de ce lot.
Aucun fichier audio embarqué. Tests sur copies temporaires, jamais sur le corpus
original. Android demeure en pause ; interface de renommage isolée pour SAF.
Le Lot 5 ter (JSON) n’est pas lancé. Voir docs/lot5bis/bilan.md.


## Avenant du 31 octobre 2026 — lancement du Lot 5 ter Windows

L’utilisateur valide le dernier build puis lance le Lot 5 ter. Implémenter le §5.7
pour Windows, en conservant le majeur **0.6** et l’incrément de mineur automatique.
Android reste en pause ; schéma JSON et fusion doivent rester communs au futur
portage SAF. Le Lot 6 n’est pas lancé par cette demande.

Livrer un export JSON sous exports/ dans les données utilisateur, et un import
validé/borné avec aperçu, choix des conflits, sauvegarde et confirmation avant une
transaction SQLite. Versions par champ (favori, état, reprise), retraits/reset
explicites, idempotence. Ne transférer ni fichiers MP3, catalogue, chemins, liens
locaux, permissions, préférences ou journaux techniques. Un lecteur chargé doit
être libéré explicitement avant l’aperçu, avec sauvegarde de sa position, pour
éviter qu’un checkpoint ne remplace ensuite les valeurs importées.

Le JSON v1 peut structurer les données sous episodes[].fields ; le contrat exact,
ses bornes et exemples sont dans docs/lot5ter/format.md et format.schema.json.
Les installations indépendantes gardent des identifiants distincts ; le JSON est
le moyen de transfert du suivi, pas une copie concurrente d’une même base ouverte.
