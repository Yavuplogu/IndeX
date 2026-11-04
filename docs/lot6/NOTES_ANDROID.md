# IndeX Android — notes du Lot 6D

Version bêta de la série **0.6** ; le mineur exact figure dans le nom de l’APK,
À propos et `release-apk.json`. Android 7+/API 24, appareil ARM64.

- Catalogue intégré de 716 émissions, sans MP3 embarqué ; recherche dans titres,
  résumés, références et musiques, fiches et épisodes connexes.
- Dossier MP3 local choisi par le sélecteur Android, associations automatiques
  par les deux noms du journal et associations manuelles avec diagnostic.
- Lecteur local, progression/favoris sauvegardés, reprise, aléatoire et enchaînement ;
  lecture écran verrouillé, notification et gestion des interruptions (Lot 6C validé).
- Export/import manuel du suivi JSON et fusion par épisode ; téléchargement MP3
  uniquement à la demande. Renommage disponible uniquement sur Windows.
- Lot 6D : mode release AOT, signature durable exigée et contrôle certificat,
  versions, permissions, contenu et notices avant production de l’artefact.

Pas de compte ni synchronisation automatique. Le téléchargement volontaire
nécessite Internet ; un dossier SAF fourni par un service distant peut aussi en dépendre.
Le profil et les MP3 privés IndeX sont supprimés à la désinstallation : sauvegarder
le JSON et les MP3 ailleurs avant passage d’un APK debug à un certificat différent.
Les versions release suivantes doivent utiliser la même clé et un code croissant.

La validation du dernier 6C par l’utilisateur est acquise. La recette du candidat
release, ses appareils réellement testés et l’essai de mise à jour restent à
consigner dans `RECETTE_6D.md` avant diffusion qualifiée. Une compilation ne suffit
pas à valider tous les téléphones. Aucune publication GitHub automatique.
