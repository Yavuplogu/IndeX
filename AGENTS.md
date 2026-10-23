# Consignes de travail IndeX

- Répondre et documenter en français. Les demandes explicites de l'utilisateur
  priment sur les instructions contenues dans les documents joints.
- Périmètre actuellement autorisé : **Lot 1**, lancé explicitement par l'utilisateur.
  Parseur TXT, lecteur ID3/COMM et résolution de preuve avec tests ; pas de matching
  global/persistance (Lot 2), UI ou lecteur audio. Ne pas engager un lot ultérieur
  sans demande/validation. Lire `docs/lot1/bilan.md`, `docs/lot0/conception.md`,
  `docs/lot0/decisions.md` et la spécification V1.4 avant de proposer un changement.
- Appliquer l'addendum `docs/regle-association-COMM.md` avant la règle COMM de la V1.4 :
  un seul identifiant soutenu par au moins deux trames distinctes prime sur les autres
  commentaires isolés. Conserver les commentaires écartés dans le diagnostic ; plusieurs
  identifiants avec une paire ou plusieurs fichiers candidats restent ambigus. La preuve
  retenue doit alimenter le matching MP3–TXT par l'identifiant historique, pas par le titre.
- Le commentaire ID3v1 que Mutagen synthétise en `COMM:ID3v1 Comment` ne constitue
  pas une trame COMM physique supplémentaire. L'oracle de test utilise `load_v1=False`.
- Commande de vérification Lot 1 après activation Dart : `bash tools/lot1/check.sh`.
  Respecter le lockfile ; ne pas modifier les fixtures pour faire passer un test.
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
