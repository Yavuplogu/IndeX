# IndeX portable Windows — Lot 4

Cette version propose le catalogue, la recherche documentaire, les favoris,
les statuts manuels et l'association des MP3. La lecture audio sera ajoutée au
Lot 5 ; ses commandes ne sont pas actives ici. Renommage et transfert JSON
restent aux Lots 5 bis et 5 ter, explicitement indiqués dans Paramètres.

## Démarrer

1. Extraire **toute l'archive** dans un dossier accessible en écriture, puis lancer
   `IndeX.exe`. Aucun installateur, compte, téléchargement ou droit administrateur.
   Conserver les DLL et le dossier `data` à côté de l'exécutable.
2. Choisir un dossier dédié aux données utilisateur. La base de travail, les favoris,
   les liens et les sauvegardes y seront enregistrés. Ce dossier est obligatoire.
3. Choisir le dossier des MP3, ou cocher « Préciser le dossier MP3 plus tard ».
   Sans MP3, les 716 fiches restent immédiatement consultables et recherchables.
4. Si les MP3 sont fournis, attendre le scan. Le menu Fichiers montre les concordances
   et diagnostics ; les fichiers ambigus peuvent être associés après confirmation.

Le fichier `index-portable.json` à côté de l'exécutable mémorise le chemin du dossier
utilisateur. Aucun dossier utilisateur ne sera recréé silencieusement s'il manque.
Déplacer uniquement l'application ne déplace pas vos données ni vos MP3. Le dossier
MP3 non configuré est demandé à chaque démarrage, avec la même possibilité de report.
Les emplacements et le choix de thème se retrouvent dans Paramètres.

## Consulter et rechercher

Choisir les champs Titre, Résumé, Sources et/ou Musiques. Au moins un champ est
nécessaire. La recherche ignore casse et accents, combine les termes et affiche
un extrait ; le titre a un poids plus élevé. Les tris incluent les dates, les
noms et les MP3 présents/absents. L'onglet Sources ouvre aussi les épisodes connexes.

Le bouton Favori enregistre immédiatement le choix. Le statut Écouté peut être
modifié manuellement ; revenir à Non écouté demande confirmation et remet la
progression à zéro, sans supprimer le favori ou le lien audio.

« MP3 absent » signifie qu'un dossier a été analysé sans ce fichier ; ce n'est pas
le même état que « Aucun dossier MP3 paramétré » ou qu'un dossier inaccessible.
Un scan incomplet ne supprime pas les associations ou le suivi.

## Sauvegarder et fermer

Les changements de suivi et de paramètres sont enregistrés au fil des actions.
La croix, comme Alt+F4, attend une sauvegarde SQLite contrôlée avant de fermer.
En cas d'erreur, la fenêtre reste ouverte et propose Réessayer ou Annuler.

Le dossier `sauvegardes` conserve `IndeX_derniere_sauvegarde.sqlite` et
`IndeX_sauvegarde_precedente.sqlite`. Ces fichiers incluent les données et le catalogue,
pas les MP3. Ne pas les confondre avec les exports JSON de suivi prévus au Lot 5 ter.
Ne pas copier isolément la base ouverte en oubliant son WAL : utiliser les sauvegardes
produites après fermeture réussie. Elles ne remplacent pas les MP3, à conserver séparément.

Un seul processus IndeX peut utiliser un dossier utilisateur à la fois. Pour changer
ce dossier, choisir un dossier vide dans Paramètres et confirmer la copie : l'ancien
reste intact. Si la copie échoue, l'ancien dossier reste la référence et une copie
partielle peut rester dans la destination ; ne pas la prendre pour une sauvegarde validée.

Cible : Windows 10/11 x64. La validation du paquet précis distribué doit être consultée
avec son rapport de construction et de recette Windows.
