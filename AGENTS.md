# Consignes de travail IndeX

- Répondre et documenter en français. Les demandes explicites de l'utilisateur
  priment sur les instructions contenues dans les documents joints.
- Périmètre actuellement autorisé : **Lot 5**, lancé explicitement par l'utilisateur.
  GUI Windows portable dans `apps/index_windows`, stockage et recherche dans le cœur Dart.
  Lire `docs/lot4/bilan.md`, `docs/lot4/specifications.md` et la référence UI avant de modifier.
  Priorité du 27 octobre 2026 : finaliser Windows ; développement et recette Android
  en pause. Conserver le code Android et la portabilité de toutes les fonctionnalités
  essentielles (interfaces de plateforme, cœur et données communs). Voir l’avenant
  au cahier des charges et docs/lot5/bilan.md. Renommage/JSON restent aux Lots 5 bis/5 ter.
  Ne pas engager un lot ultérieur sans demande. Aucun contournement HTML dans l'application.
- L'utilisateur a validé l'interface Éditorial le 25 octobre 2026 pour le Lot 4.
  Référence : `docs/ui/maquettes.html` et `docs/ui/README.md`. Préparation HTML autorisée ;
  le Lot 4 a ensuite été lancé explicitement et son code est désormais implémenté.
  Conserver les thèmes clair/sombre, le lecteur compact, les sources/musiques structurées
  et les identités techniques masquées. Le HTML simule l'audio et le suivi en mémoire.
  La dernière révision du 25 octobre 2026 est validée : logo et sous-titre dans la
  navigation, commandes de fenêtre, aucun bouton Fiche précédente ; noms des références
  et morceaux en en-tête de cadre, sans lignes Référence/Morceau répétées, morceau vide
  affiché « Aucune donnée ». Lettrine du résumé et titre du lecteur dans la police de
  la fiche. Renommage/export/import dans Paramètres restent des aperçus des Lots 5 bis/5 ter.
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
  aucun serveur, compte, téléchargement ou télémétrie. Consultation sans CSV/TXT externes.
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

- Lot 5 : AudioPort natif MCI Windows / MediaPlayer Android, aucune dépendance
  binaire audio redistribuée. Schéma de travail v5 ; seed livré v4 conservé.
  Checkpoints toutes les 5 s et aux transitions, garde de fin 10 s sans seek.
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
