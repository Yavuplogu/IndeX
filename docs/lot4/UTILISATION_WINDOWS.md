# IndeX portable Windows — Lot 4

Cette version propose le catalogue, la recherche documentaire, les favoris,
les statuts manuels et l'association des MP3. La lecture audio sera ajoutée au
Lot 5 ; ses commandes ne sont pas actives ici. Renommage et transfert JSON
restent aux Lots 5 bis et 5 ter, explicitement indiqués dans Paramètres.

## Démarrer

1. Extraire **toute l'archive**, ouvrir le dossier **IndeX** puis lancer son unique
   fichier `IndeX.exe`. Aucun installateur, compte, téléchargement ou droit administrateur.
   Conserver les sous-dossiers `application/` et `documentation/` avec ce lanceur.
   Le dossier extrait doit être accessible en écriture.
2. Conserver le dossier `IndeX/user` présélectionné, ou choisir un autre dossier dédié aux données utilisateur. La base de travail, les favoris,
   les liens et les sauvegardes y seront enregistrés. Ce dossier est obligatoire.
3. Choisir le dossier des MP3, ou cocher « Préciser le dossier MP3 plus tard ».
   Sans MP3, les 716 fiches restent immédiatement consultables et recherchables.
4. Si les MP3 sont fournis, attendre le scan. Le menu Fichiers montre les concordances
   et diagnostics ; les fichiers ambigus peuvent être associés après confirmation.

Le fichier `application/index-portable.json` mémorise le chemin du dossier
utilisateur. La racine reste limitée au lanceur et aux sous-dossiers. Aucun dossier utilisateur ne sera recréé silencieusement s'il manque.
Déplacer uniquement l'application ne déplace pas vos données ni vos MP3. Le dossier
MP3 non configuré ne bloque pas les ouvertures suivantes : chargement animé puis bibliothèque.
Les données et le thème se retrouvent dans Paramètres ; les MP3 et l’analyse des
sous-dossiers dans Fichiers et associations. Dans Paramètres, la case
« Ne plus scanner le dossier MP3 à chaque ouverture » est décochée par défaut.
La cocher conserve les derniers résultats ; relancer un scan manuel pour les actualiser.

## Consulter et rechercher

Choisir les champs Titre, Résumé, Sources et/ou Musiques. Au moins un champ est
nécessaire. La recherche se déclenche dès trois caractères et accepte les débuts
de mots (« Yougo » trouve « Yougoslavie »). Elle ignore casse et accents et exige
l'ensemble des termes ; le titre a un poids plus élevé. Les correspondances sont
encadrées sur fond beige, dans la couleur du X et en gras dans les onglets. Le cadre
« Résultat de la recherche » explique ces repères ; les boutons Résultat précédent /
Résultat suivant changent d'onglet et font défiler uniquement les données jusqu'au texte trouvé ; le titre, les commandes
et les onglets restent en place.
Ces boutons restent accessibles pendant le défilement. Les tris incluent les dates, les
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


## Organisation et mise à jour du dossier portable

```text
IndeX/
├── IndeX.exe                 ← double-cliquer ici
├── application/              ← programme Flutter, DLL et ressources
│   ├── IndeX.exe
│   ├── data/
│   └── index-portable.json   ← créé après choix du dossier utilisateur
├── user/                     ← créé au premier lancement, emplacement modifiable
└── documentation/
    ├── LISEZ-MOI.md
    ├── manifest-fichiers.json
    └── licences/
```

Le lanceur et le programme portent la même icône X. Ne pas extraire seulement le
lanceur, ni déplacer les DLL séparément. Les MP3 et données utilisateur restent
aux emplacements choisis ; ils ne sont pas dans l'archive.

Pour passer de l'ancienne archive plate à cette présentation, fermer IndeX,
extraire le nouveau ZIP dans un nouveau dossier et copier l'ancien
`index-portable.json` vers `application/index-portable.json` pour retrouver le même
dossier utilisateur. Conserver l'ancien dossier jusqu'à vérification du suivi.
Sans ce pointeur, indiquer le dossier de données existant au premier lancement ;
ne pas choisir un dossier vide pour retrouver un suivi existant.


## Association des MP3 par leur nom

Le journal déjà intégré à l'application fait autorité : d'abord le nom MP3 d'origine,
puis le nom système. Une correspondance exacte et unique est nécessaire. Casse et
représentation Unicode équivalente sont ignorées ; accents, espaces et ponctuation
restent significatifs. Aucun CSV supplémentaire à fournir, aucun tag COMM à corriger.
Un fichier nommé `C.I.A..mp3` ne correspond pas au nom `C.I.A.mp3`.

Un nom inconnu ou plusieurs candidats apparaissent dans le diagnostic de scan,
exportable en TXT. Choisir une association manuelle après vérification si nécessaire.
Les choix manuels sont conservés. Un scan incomplet ne valide aucun nouveau lien
automatique. Une association par nom ne garantit pas que l'enregistrement soit le bon.

Après mise à jour du programme, le catalogue est actualisé à l'ouverture et le dossier
MP3 configuré est rescanné, sauf désactivation du scan au lancement dans Paramètres. Les anciens liens automatiques fondés sur COMM sont alors
réévalués ; le suivi et les favoris restent attachés aux mêmes épisodes. Sans dossier
accessible, les données existantes sont conservées jusqu'à un scan complet.


## Compteurs et diagnostic

Sous les filtres, le nombre de gauche compte les épisodes affichés et celui de
droite le total du catalogue. Aucun rappel à côté. Les menus de tri et d’état
peuvent être ouverts alternativement en un clic.

Fichiers et associations regroupe le total du catalogue, les fichiers MP3 détectés,
les épisodes associés disponibles et les manquants après un scan complet. Sans
vérification complète, les manquants sont indiqués « Non vérifié ». Les fichiers
inconnus/doublons peuvent expliquer un écart entre MP3 détectés et épisodes associés.
« Ouvrir le dossier MP3 » affiche le dossier configuré dans l’Explorateur Windows.
L’analyse des sous-dossiers est cochée par défaut ; votre choix est conservé.

Dans Fichiers et associations, les fichiers proposant « Associer… » apparaissent
en premier. Le texte des cartes et du diagnostic est sélectionnable. Les chemins
s'affichent avec leurs espaces, également dans l'export TXT, sans altérer les
références internes des associations.

## Diagnostic et retrait d’une association

Dans Fichiers et associations, le bouton **Diagnostic du scan**, placé avant
l’export TXT, ouvre un panneau flottant. Les messages sont sélectionnables et
copiables ; la liste peut défiler. Fermer revient à la liste des fichiers.

Les fichiers non associés ont un fond gris et leur message apparaît dans le
rouge du logo. Le bouton Associer… conserve son beige. Les fichiers associés
proposent **Enlever l’association** : après confirmation, seul le lien local est
retiré et les données personnelles de cet épisode sont supprimées (favori, statut,
progression et durée). Le fichier MP3 est conservé. Ce choix résiste aux scans et
aux réouvertures. Utiliser Associer… pour rétablir un lien manuellement, sans
restaurer les données supprimées.

Dans Paramètres, deux boutons **Mode clair** et **Mode sombre** remplacent le menu
Apparence ; le mode actif est mis en évidence et le choix est mémorisé.

Juste avant la liste de Fichiers et associations, les filtres **Fichiers associés**,
**Fichiers non associés** et **Tous les fichiers** permettent de choisir les lignes
affichées. Tous les fichiers est actif initialement, avec les fichiers non associés
en premier. Les statistiques globales et le diagnostic restent indépendants de ce
filtre. Si aucun fichier ne correspond, un message le signale.
