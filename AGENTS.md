# Consignes de travail IndeX

- Répondre et documenter en français. Les demandes explicites de l'utilisateur
  priment sur les instructions contenues dans les documents joints.
- Périmètre actuel : **Lot 6C lancé le 3 novembre 2026**, après validation utilisateur
  de tous les points 6B et de l’adaptation paysage sur son téléphone. Lire
  docs/lot6/plan.md, bilan-6C.md et RECETTE_ANDROID.md. Autorisés : service média,
  lecture écran éteint/arrière-plan, notification/commandes système, interruptions,
  interface et suivi mobile. Windows et le cœur restent partagés et protégés.
  SQLite utilisateur v7/seed v4/JSON v2 avec lecture v1 ; minSdk 24/target 36 ARM64.
  Renommage réservé à Windows ; ne pas réactiver le renommage Android.
  Aucun nouveau package runtime : MediaPlayer/MediaSession/Service/Notification
  système, moteur Flutter unique conservé. Revoir API/licences avant tout ajout.
  Workflow manuel 6C, compteur/verrou partagé Windows, majeur 0.6/bêta inchangés.
  Pas de publication ni signature finale (6D non lancé), iOS exclu. Clé debug en
  cache Actions, jamais dans Git/artefacts. Tests simulés/compilation distincts
  de la recette 6C physique à réaliser après ce lot.
- L'utilisateur a validé l'interface Éditorial le 25 octobre 2026 pour le Lot 4.
  Référence : `docs/ui/maquettes.html` et `docs/ui/README.md`. Préparation HTML autorisée ;
  le Lot 4 a ensuite été lancé explicitement et son code est désormais implémenté.
  Conserver les thèmes clair/sombre, le lecteur compact, les sources/musiques structurées
  et les identités techniques masquées. Le HTML simule l'audio et le suivi en mémoire.
  La dernière révision du 25 octobre 2026 est validée : logo et sous-titre dans la
  navigation, commandes de fenêtre, aucun bouton Fiche précédente ; noms des références
  et morceaux en en-tête de cadre, sans lignes Référence/Morceau répétées, morceau vide
  affiché « Aucune donnée ». Lettrine du résumé et titre du lecteur dans la police de
  la fiche. Dans le HTML historique, renommage/export/import restent des aperçus ;
  les fonctions natives des Lots 5 bis/5 ter lancés explicitement priment.
- Les compléments utilisateur du 25 octobre 2026 sont dans `docs/lot4/specifications.md` :
  Windows portable sans installateur, dossier `IndeX/user` présélectionné et modifiable,
  MP3 facultatifs par case au premier démarrage seulement. Aux ouvertures suivantes,
  chargement puis bibliothèque même sans MP3 ; scan au lancement désactivable
  par une case décochée par défaut. Choix MP3/récursivité dans Fichiers, données dans Paramètres. Sauvegarder avant de fermer
  sans dépendre uniquement de la fermeture. Recherche multichamp configurable. Renommage
  exclusivement historique → TITRE SYSTEME. Export JSON dans le dossier utilisateur,
  sous `exports/`, avec nom explicite sans espaces. Ces parcours sont simulés dans le HTML.
- Décision utilisateur du 26 octobre 2026 : appliquer `docs/regle-association-noms-journal.md`.
  Association uniquement par nom complet FICHIER MP3 D'ORIGINE, puis TITRE SYSTEME
  du journal courant intégré. NFC et casse seulement ; pas de suppression d'accents,
  de ponctuation ou d'espaces. Conflits/doublons terminaux, aucun repli par titre.
  Ne plus lire ni utiliser COMM/ID3 pendant le scan. L'ancienne règle COMM et ses
  tests restent historiques/audit indépendant ; un nom ne certifie pas l'audio.
  Préserver les choix manuels. Réévaluer les anciens liens automatiques au scan
  complet avec diagnostic, sans effacer/transférer le suivi ; aucun nouveau lien
  automatique sur scan incomplet. Les anciens alias système ne sont pas une autorité.
- Commande de vérification des Lots 1–4 après activation du SDK : `bash tools/lot4/check.sh`.
  Respecter le lockfile ; ne pas modifier les fixtures pour faire passer un test.
- Corpus `f126478` : 716 TXT/CSV, 716 épisodes, aucune erreur, quarantaine ou fiche
  à vérifier ; les 29 avertissements historiques sont conservés. Le nom TXT des Hmongs
  du Laos est corrigé avec deux points. Voir `docs/lot3/catalogue-report.json`.
  Ne pas modifier les sources silencieusement. Seed v4
  `corpus-2026-10-26-noms-journal-r3`, sans audio, suivi ou réglages ; 716 identités
  conservées. Régénérer et versionner son manifeste.
- SQLite v4 : FTS5 externe maintenu par triggers dans la transaction ; ne pas
  modifier les tables FTS à la main. Utiliser `SqliteSearchEngine.rebuildIndex/checkIndex`.
  Seeds v2/v3/v4 acceptés en lecture seule ; le seed ne devient jamais base utilisateur.
  Requêtes littérales bornées, jamais une expression FTS fournie par l'utilisateur.
- Flutter 3.47.7 / Dart 3.13.5 épinglés. Préparer l'asset par
  `python3 tools/lot4/prepare_assets.py` ; ne pas versionner la copie dans l'app.
  Windows doit être construit/testé sur Windows via `tools/lot4/check.ps1` et la CI.
  Ne pas déclarer Windows qualifié sur la seule base des contrôles Linux.
- Les imports de référence doivent préserver les choix manuels, liens, suivi et ajouts
  utilisateur. Un dossier temporairement inaccessible ne justifie aucune suppression.
- Utiliser le checkout existant ; ne pas créer de worktree sans demande explicite.
- Avant un lot, annoncer fichiers concernés, décisions, tests et risques ; après,
  rapporter les commandes et résultats réels. Ne pas prétendre avoir validé une
  plateforme sur la foi d'un test Linux ou d'une déclaration de package.
- Ne jamais modifier les octets, tags ou noms des MP3/TXT lors d'un scan ou audit.
  Le futur renommage exige un aperçu puis une confirmation explicite dans l'UI,
  et ne doit changer que le nom dans le même dossier, jamais écraser une cible.
  Tester uniquement sur des copies temporaires ; préserver les fixtures existantes.
- V1 : SQLite documentaire prérempli dans les deux packages, aucun MP3 embarqué,
  aucun serveur propre à IndeX, compte ni télémétrie ; téléchargement manuel
  facultatif autorisé explicitement le 30 octobre (avenant ci-dessous). Consultation sans CSV/TXT externes.
- Séparer identité métier, données documentaires, liens audio locaux et suivi.
  Ne jamais identifier un épisode par son chemin, titre ou sa date seule.
- Ne pas écraser le suivi lors d'une mise à jour du catalogue. Sauvegarde périodique
  en lecture, transactions SQLite et migrations testées sont obligatoires.
- Fusion JSON manuelle par champ et causalité, avec aperçu et confirmation ; aucun
  choix silencieux fondé sur l'horloge ou le maximum de position. Retraits/reset explicites.
- Ne pas confondre statut ID3 du journal et vérification réelle du fichier local.
  Conflits et rubriques inconnues doivent être signalés sans perte du texte brut.
- Maintenir README, décisions et tests reproductibles. Ne pas introduire de dépendance
  avant vérification licence, API, versions, plateformes et absence d'accès réseau à l'usage.
- Ne pas committer automatiquement ni ajouter des archives SDK, venv, bases temporaires
  ou MP3 supplémentaires. Ne jamais supprimer des fichiers existants pour satisfaire un test.

- Nouvelle disposition portable autorisée : `IndeX/IndeX.exe` est le seul fichier
  racine (lanceur C++ CRT statique). Bundle réel dans `application/`, notices dans
  `documentation/`, pointeur dans `application/index-portable.json`. Tester le ZIP
  via le lanceur et contrôler aussi le processus enfant ; ne pas masquer son code
  de sortie. Test d'assemblage : `tools/lot4/test_portable_windows.ps1`.
- Les derniers ajustements de fiche priment sur les simulations HTML antérieures :
  mesure/rendu identiques de la lettrine, deux lignes exactes, ponctuation initiale
  avec première lettre/chiffre ; correspondances encadrées dans les onglets et
  navigation persistante. Voir la fin de `docs/lot4/specifications.md`.

- Révision UI du 26 octobre : en-tête de fiche séparé des données défilantes,
  sans hauteur fixe réservée sous les onglets. Navigation Résultat précédent/suivant
  dans les seules données ; fond beige des Paramètres et encre identique au X.
  Révision du 27 octobre : compteur sous les filtres = épisodes visibles / total
  du catalogue, sans rappel. Statistiques MP3 dans Fichiers et associations
  (détectés, associés, manquants), ouverture du dossier par Explorateur Windows.
  Récursivité activée par défaut sauf choix explicite conservé. Décoder les URI uniquement pour affichage/export
  du diagnostic, jamais pour modifier les références stockées. Cartes de scan
  sélectionnables, fichiers avec bouton Associer en tête ; cartes non associées
  grises, message rouge du X et bouton beige. Diagnostic dans un panneau flottant.
  Retrait confirmé : exclusion locale persistante par référence, levée par
  association manuelle. Dernière décision du 27 octobre : retrait confirmé =
  suppression transactionnelle du favori et du suivi de cet épisode, fichier MP3
  conservé. Apparence : deux boutons clair/sombre. Fichiers : filtres associés,
  non associés et tous (non associés en tête). Ouverture du
  dossier par canal natif ShellExecuteW, sans ligne de commande Explorer.

- Lot 5 : JustAudioPort Windows (`just_audio` 0.10.6 + `just_audio_windows` 0.2.3+index.2,
  WinRT MediaPlayer), NativeAudioPort/MediaPlayer Android conservé en pause.
  MCI retiré. Plugin Windows dans le bundle, licences natives/packages inventoriées. Schéma de travail v5 ; seed livré v4 conservé.
  Checkpoints toutes les 5 s et aux transitions ; validation anticipée après 10 s
  en zone de fin, ou fin moteur après progression réelle depuis le dernier seek.
  Mise en pause/sauvegarde en arrière-plan Android, SAF et droits persistants.
  Ne pas annoncer une recette physique Android sans appareil réel.

- Décision du 28 octobre 2026 : version publique `0.5.01` au premier nouveau build.
  Premier nombre : 0 bêta / 1 finale, second : majeur (5), dernier : mineur sur
  au moins deux chiffres, incrémenté à chaque build distribuable. Ne jamais changer
  le majeur ni passer en finale sans ordre explicite. Voir tools/versioning/README.md.
  Arrêt utilisateur remet position/statut à zéro ; pause/fermeture conservent la reprise.
  Changement manuel en Écouté confirmé, position remise à zéro. Pourcentage en cours
  et remplissage dynamique de la ligne ; flèches gauche/droite ±10 s, titre lecteur
  cliquable. Auto-suivant actif par défaut ; aléatoire inactif par défaut, enchaînant
  au hasard lorsqu’activé. Ordre et candidats de la liste affichée, MP3 disponibles.

- Décision du 28 octobre : adopter just_audio + just_audio_windows pour Windows.
  Ne pas attendre la fin du Future AudioPlayer.play() pour libérer les commandes ;
  capturer erreurs tardives et fin explicitement. AudioPort.dispose() doit permettre
  une réouverture (unload puis lecture). Préserver l’interface et le suivi communs.
  path_provider_android 2.2.23 épinglé pour éviter la chaîne JNI sur Windows.
  Ne pas prétendre une latence <200 ms sans mesure sur appareil et MP3 réels.

- Régression MP3_Bugs du 28 octobre : plugin Windows corrigé localement dans
  third_party/just_audio_windows (MIT/provenance conservées), pas dans le cache pub.
  Voir INDEX_PATCHES.md. Les huit fichiers sont des fixtures en lecture seule,
  jamais embarquées. Six fixtures racine + huit imbriquées = 14 fichiers au scan
  récursif de test ; les scénarios historiques non récursifs gardent six fichiers.
  Journal audio local logs/lecteur-audio.log dans les données utilisateur,
  rotation 512 Kio ; aucun envoi réseau. Timeout interne d’ouverture 20 s avec
  destruction du lecteur (nettoyage borné), erreurs natives remontées immédiatement.
  Ne pas annoncer les huit lectures WinRT validées sur la seule base de FFmpeg/Linux.

- Suivi du refus "system cannot find the file specified" : index.2 ouvre les MP3
  via un chemin Unicode exact et un flux système aléatoire en lecture seule, pas
  via le gestionnaire WinRT file://. Probe Dart présence/lecture avant démarrage,
  même budget d’ouverture ; journal file_access_ok/failed et chemin décodé.
  Décodage URI une seule fois : ne pas normaliser les noms ni transformer '+'
  en espace. Aucune conversion/copie/cache des MP3. Recette WinRT toujours requise.

- UX lecteur du 28 octobre : titre main/cliquable vers fiche sans changer listing,
  filtres/tri/recherche/scroll. select(..., keepOutsideList:true) conserve la fiche
  hors résultats aux checkpoints ; select classique et nouvelle recherche libèrent
  cette sélection. Mode aléatoire appliqué aussi à précédent/suivant manuels.
  Horodatage maintenu pendant le glissement ; filtres fichiers avec curseur main.
  Messages d’erreur/alertes/validation sélectionnables (SelectableText). Voir la
  dernière section de docs/lot4/specifications.md. Retour utilisateur : audio
  Windows et seeks quasi instantanés fonctionnels sur le build précédent.

- Révision du 28 octobre : persister recherche/champs/tri/statut/Favoris dans
  local_settings.library_view, restaurer avant reload et dans le champ de saisie.
  Pas d’écriture si les critères sont inchangés ; une saisie est durable avant
  expiration des 250 ms de temporisation. Case Lecture et reprise à gauche.
  Une fin moteur après progression post-seek valide Écouté même à moins de 10 s
  du terme ; seek seul à 100 % et durée inconnue exclus. Voir les dernières
  sections des spécifications Lot 4 et du bilan Lot 5.

- Complément fin clavier : flèches via Playback.skip(delta). Une avance pendant
  la lecture atteignant une durée connue demande une validation à réception du
  vrai signal ended, même sans progression après le saut ; pas avant. Seek absolu,
  pause et recul exclus ; nouveau seek annule la demande. Voir bilan Lot 5.

- Révision du 29 octobre : case « Scanner le dossier MP3 à chaque ouverture »,
  cochée = scanner, défaut cochée, clarification explicite utilisateur. Conserver
  skip_startup_scan existant en inversant seulement sa présentation. À propos
  disponible en latéral/compact, cadres communs aux Paramètres, version publique
  INDEX_VERSION fournie par le packaging, Développement hors distribution.
  GitHub factice : aucun navigateur/réseau ; fonctions futures identifiées.

- Révision éditoriale À propos du 29 octobre : « Rendez-vous avec X » dans l’UI,
  widget Brand commun au premier cadre et à la barre latérale. Voir sur GitHub
  avant version, lien toujours factice ; récit utilisateur, contact et emphases.
  Mailto fixe index.en9nr@passinbox.com sur clic explicite via canal Windows,
  jamais d’envoi automatique. Retrait Fonctions prévues ; précision de non-livraison
  du JSON conservée dans Vos données restent chez vous. Aucun lancement de Lot 5 ter.

- Révision du 30 octobre : pointeur portable v2 relatif à la racine IndeX pour les
  données internes (parent de application/), externe absolu, v1 accepté/migré.
  local_settings.portable_root_v1 permet la réévaluation transactionnelle des
  références internes MP3/liens/exclusions/diagnostics avant scan ou lecture.
  Collision = annulation ; suivi et fichiers intacts. Ancien pointeur déjà cassé
  sans racine connue : relocalisation explicite, jamais de profil supposé/vide.
  Contact À propos = copie presse-papiers/notifiée, mailto natif retiré. Logo GitHub
  Octicons MIT embarqué dans bouton bordé, licence à distribuer.

- Correction CI du 30 octobre : mémoriser portable_root_aliases_v1, racines
  canonique et utilisée (dont Windows 8.3 RUNNER~1/runneradmin), vérifiées comme
  même dossier. Réécriture des seules racines connues, destination canonique.
  Dans les tests, comparer identité physique/canonique et préparer les collisions
  avec la destination réellement produite. Ne pas supprimer la garde d’unicité.

- Décision explicite du 30 octobre : télécharger un MP3 absent depuis URL MP3
  du journal SQLite intégré, uniquement sur clic. Consultation/scan/lecture locale
  restent sans réseau. Cœur Mp3Download (dart:io, sans nouvelle dépendance), fichier
  temporaire borné/annulable, contrôle de format puis publication Windows atomique
  MoveFileExW sans remplacement. Aucun MP3 embarqué, aucun téléchargement de test
  depuis le serveur public. Préserver suivi/favoris ; remplacement d’un lien manuel
  indisponible confirmé dans l’UI. Android en pause : publication SAF à porter.
  Ne pas changer le majeur 5. About Brand.showSubtitle=false uniquement dans À propos.

- Décision du 31 octobre : Lot 5 bis lancé, nouveau majeur explicitement autorisé
  **0.6.0**, puis mineur +1 à chaque build ; minor_width=1, first_minor=0.
  Ne pas réinitialiser le compteur historique 0.5. Voir docs/lot5bis/bilan.md.
  Schéma utilisateur v6 (rename_runs/items), seed v4 conservé. Renommage seulement
  historique → nom système du journal, aperçu/confirmation globale ; MoveFileExW
  sans remplacement, même dossier. Journal avant tentative et réconciliation avant
  scan au démarrage ; SHA-256 en lecture seule, pas de réécriture ID3/audio.
  Tests uniquement sur copies temporaires. Android reste en pause, adaptateur
  RenameFile commun ; export/import JSON non lancé.

- Correction du premier build 0.6 : dans le renommage, comparer liens/exclusions et
  cibles avec une clé de parent canonique (aliases Windows 8.3 inclus), même après
  disparition de la feuille source. Ne pas modifier les références pour une simple
  comparaison. Préserver le refus d’une cible liée à un autre épisode ; diagnostics
  actualisés après succès. Tests : identité physique plutôt qu’URI courte/longue.

- Disponibilité après renommage : LocalAudioPaths partagé pour les comparaisons de
  parents et de périmètre. PortableSession.episodes doit reconnaître un dossier MP3
  configuré via alias court/long et conserver la frontière du dossier (MP3-autre
  reste extérieur à MP3/). Ne pas remplacer ce contrôle par available=1 seul.

- Lot 5 ter lancé explicitement : schéma utilisateur v7 (sync_device/fields/imports),
  seed documentaire v4 conservé. JSON index-listening-sync v1, états/favoris/reprise
  seulement, aucune URL/chemin/permission/réglage/MP3. Voir docs/lot5ter/format.md
  et bilan.md. Triggers transactionnels par champ et tombstones lors d’un retrait ;
  horloges vectorielles, aucune résolution par date ou position maximale.
  Aperçu périmé rejeté ; lecteur libéré explicitement avant import ; sauvegarde
  SQLite puis transaction unique. Export dans user/exports, publication Windows
  publishExport sans remplacement. Android en pause, format/cœur partagés.
  Majeur reste 0.6, mineur réservé par le build. Lot 6 non lancé.

- Nouvelle précision de version du 31 octobre : minor_width=2 pour la série 0.6,
  affichage public 0.6.03…0.6.09, 0.6.10…0.6.99, 0.6.100. Continuer le compteur
  existant sans reset ; build_name SemVer non complété, INDEX_VERSION public
  complété pour À propos et les noms d’archive/artefact. Majeur 6 conservé.

- Révision utilisateur du 31 octobre : filtres renommage/import, conflits d’abord,
  présélection fichier importé (remplace l’ancienne absence de présélection),
  commandes pour tous les conflits y compris filtrés, confirmation globale maintenue.
  Export court IndeX_suivi_AAAAMMJJ_HHMMSS.json en heure locale ; refuser une collision
  à la seconde sans écraser. Dates JSON UTC/identifiant unique inchangés.
  Auto-suivant/aléatoire automatique exclut ECOUTE. Seek souris en lecture dans
  la dernière seconde exige le vrai ended pour valider, sans validation en pause
  ou sur seek programmatique seul. Reset global confirmé et sauvegardé, atomique,
  marqueurs de reset transférables, favoris/MP3/associations conservés. Majeur 0.6.


- Révision du 1er novembre 2026 : état et reprise forment une seule unité de fusion
  Écoute ; favori indépendant, un cadre par épisode, compteurs en épisodes.
  Comparer le produit des horloges par champ, sans maximum interchamps.
  Nouveaux exports JSON v2 avec source_platform ; lecture v1 et empreintes
  historiques conservées. Ancien lecteur v1 incompatible avec nouveaux exports.
  SQLite v7/seed v4/majeur 0.6 inchangés. Renommage : dimensions stables sous
  filtrage ; liseré lecteur limité au titre et à la date.


### Validation et ajustements du 1er novembre 2026

Le plan documentaire Lot 6 Android en quatre étapes est validé ; cette validation
ne lance pas encore le développement Android.
Sans dossier MP3 configuré, la liste affiche les épisodes en MP3 absent, fond et
texte gris comme après un scan sans fichier correspondant. Le bandeau « dossier
MP3 non paramétré » est conservé. Un suivi existant n’est ni effacé ni modifié.
Avant le sélecteur ouvert depuis Télécharger, un avertissement explique que le
dossier choisi deviendra le dossier MP3 global, pour cet épisode et les futurs
téléchargements. Annuler cet avertissement ou le sélecteur ne change aucun dossier
et ne lance aucun transfert. Un dossier choisi est analysé et mémorisé avant le
téléchargement ; annuler ensuite le transfert conserve ce choix. Un dossier déjà
configuré ne déclenche pas cet avertissement.


- Décision du 1er novembre 2026 : Windows et Android uniquement workflow_dispatch,
  aucun déclenchement sur push/pull_request. Conserver le même groupe de
  concurrence pour le compteur partagé, sans reset ni annulation automatique des
  builds déjà lancés. Chaque lancement manuel distribuant un artefact réserve
  son mineur. Ce changement ne dispense pas de vérifier avant de distribuer.


- Demande du 2 novembre : ajustements UI Android explicitement autorisés dans
  l’étape 6A, sans lancement des adaptateurs 6B/services audio 6C. Signature
  À propos commune « Monsieur K. ». Fiche Android même dimensions que Paramètres,
  Fermer en bas, titre 24 ; menu à cinq icônes accessibles sur une ligne ; liste
  et filtres fichiers dans un panneau Android dédié ; clavier au-dessus du menu
  et du lecteur. Préserver la présentation Windows.


- Compléments Android du 2 novembre : en-tête défilé en bas une fois à
  l’ouverture d’une recherche pour exposer précédent/suivant ; ne pas forcer le
  scroll aux checkpoints. Fiche Android fond panel, sans teinte Material, palette
  commune Windows clair/sombre. Actions des associations sous le chemin sur
  Android seulement. Présentation et défilement Windows conservés.


- Garanties 6B : content:// opaque pour les fournisseurs externes. Copie MP3
  complète en privé avant publication SAF et contrôle SHA-256 ; journal natif
  durable avant création, exclusion des publications non validées et contrôle
  des disponibilités au redémarrage même sans scan. Ne pas effacer un original
  à partir d’un diagnostic ambigu. Écriture MP3 limitée aux fournisseurs locaux
  Android et IndeX. HTTP limité au domaine du journal, politique à chaque redirect.
- Renommage Android historique (désactivé le 3 novembre) dans IndeX · MP3 : provider local exposant uniquement
  files/mp3, déplacement privé contrôlé + fsync même parent, journal SQLite avant
  mutation, reprise par empreinte et compatibilité des anciens liens durs. Autres fournisseurs refusés
  sans garantie. Dossier privé optionnel : avertir de l’effacement à la
  désinstallation. Aucun déplacement automatique ni réécriture des MP3/ID3.
- JSON Android : copie interne exports puis copie externe ACTION_CREATE_DOCUMENT ;
  import borné ACTION_OPEN_DOCUMENT. Pas d’atomicité SAF externe inventée ;
  parseur et fusion partagés, lecteur libéré, aperçu, backup et transaction.

- Correctif Android EACCES du 3 novembre : aucun nouvel Os.link. Les déplacements
  privés passent par PrivateFileMoves : confinement canonique, cible absente par
  lstat, rename et fsync sous le mutex partagé de tous les écrivains privés.
  Provider et worker restent dans le même processus ; ne pas étendre ce protocole
  aux fournisseurs SAF externes ni à un stockage partagé. Test JVM reproductible :
  bash tools/lot6/test_private_moves.sh ; recette physique encore nécessaire.

- Fluidité lecteur du 3 novembre : ne pas relayer les ticks Playback vers le
  ChangeNotifier global AppModel. Régions UI ciblées pour lecteur, ligne et boutons ;
  polling arrêté en pause/fin/erreur et relancé à la reprise. Conserver checkpoints
  cinq secondes/transitions, cache de suivi actualisé sans recharger les documents,
  recalcul des filtres sur changement de statut. Aucun lancement du Lot 6C.

- Décision du 3 novembre : renommage réservé à Windows. Sur Android, bouton
  d’aperçu désactivé dans Paramètres et mention explicite ; AppModel refuse aperçu,
  exécution et libération audio pour renommage. Conserver la réconciliation des
  anciens journaux et le stockage MP3 géré, sans nouveau renommage proposé.
  La demande finale ne comprend aucune réorganisation des listes/panneaux.

- Retour physique du 3 novembre : l’utilisateur valide les contrôles précédemment
  listés sauf adaptation à l’écran. Correction paysage Android autorisée : recherche
  à gauche (3/8), liste à droite (5/8), filtres à côté de Bibliothèque/Favoris,
  défilements indépendants. Préserver portrait/Windows, critères et suivi. Adapter
  la hauteur des lignes Android au texte agrandi. Ce correctif ne lance pas le
  service audio/notification du Lot 6C.

- Décision du 3 novembre : 6B/paysage validés par l’utilisateur, lancement 6C.
  Le service Android possède MediaPlayer et MediaSession ; moteur Flutter unique
  conservé pour les checkpoints/règles Dart, aucune seconde base/isolate de suivi.
  Les événements système passent par la même logique que les commandes UI.
  Ne pas réintroduire suspend() dans les transitions Android hidden/paused/detached.
  Retour racine avec piste chargée met la tâche en arrière-plan ; fermeture explicite
  après sauvegarde arrête le service et détruit le moteur conservé.
  Pause manuelle/casque/perte définitive de focus exigent une reprise explicite.
  Depuis le 4 novembre, une perte temporaire reprend au GAIN si la piste était en
  lecture, sans choix manuel intervenu. Verrou CPU libéré après checkpoint,
  aucun redémarrage automatique après force-stop/kill. Recette physique obligatoire
  pour verrouillage, notifications, interruptions, batterie et retour par notification.

- Correctif du 4 novembre : AudioInterruptionPolicy réserve une reprise par jeton
  et révision de source pour LOSS_TRANSIENT/CAN_DUCK ; conserver AudioFocusRequest
  et le foreground pendant cette pause, libérer le verrou CPU après checkpoint.
  GAIN reprend via Dart/AudioPort avec revalidation native du jeton ; pas de reset.
  Pause/arrêt/seek/source changée/casque/erreur/perte permanente annulent la réserve.
  Notifications imbriquées et GAIN précoce ne doivent ni relancer une autre piste
  ni annuler un choix récent. Test JVM tools/lot6/test_audio_interruptions.sh en CI.

- Révision Windows du 4 novembre : double clic sur une ligne disponible de la
  bibliothèque = sélection/ouverture de fiche puis playEpisode, mêmes règles
  qu’Écouter (reprise/réécoute, favori conservé). Simple clic = fiche seulement.
  Android ne reçoit aucun gestionnaire double clic. Une ligne MP3 absente ne
  déclenche ni lecture ni téléchargement ; les gardes d’occupation restent partagées.

- Incident CI Windows 0.6.24 du 4 novembre : libellés FilterMenu toujours Flexible,
  sur une ligne avec ellipsis, pas uniquement en paysage. Ne pas ignorer les
  débordements de quelques fractions de pixel ; texte complet dans le menu.
  Le test Android simulé est aussi exécuté sur Windows : vérifier les exceptions
  avant démontage pour conserver le diagnostic du widget d’origine.
