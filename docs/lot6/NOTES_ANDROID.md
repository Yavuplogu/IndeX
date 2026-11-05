> Décision du 5 novembre 2026 — série **0.7.01** : l’emplacement privé
> « IndeX · MP3 » est supprimé, ainsi que son bouton et le fournisseur Android.
> Aucun accès de récupération n’est conservé. Choisir un dossier MP3 visible
> dans le sélecteur Android. Aucun fichier existant n’est supprimé par ce retrait.
> Le stockage privé du profil (favoris, progression, réglages) reste nécessaire
> et distinct. Les exports JSON utilisent toujours une destination choisie.
> Identifiant `fr.index.app` et clé durable conservés.

# IndeX Android — notes du Lot 6D

Depuis le 5 novembre 2026, l’identifiant Android définitif est **`fr.index.app`**.
Il remplace `fr.index.index_windows` : nouvelle installation indépendante,
export/import JSON et nouveau choix du dossier MP3. Sauvegarder les MP3 privés
avant toute suppression de l’ancienne application. La clé de signature déjà
créée reste utilisable ; ne pas la recréer pour ce changement.
Le X de l’icône est réduit de 12 %, centré sur le même fond beige adaptatif.

Version bêta de la série **0.7** ; le mineur exact figure dans le nom de l’APK,
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
