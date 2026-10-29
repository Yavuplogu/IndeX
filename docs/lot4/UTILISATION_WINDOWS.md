# IndeX portable Windows — Lot 4

Cette version propose le catalogue, la recherche documentaire, les favoris,
les statuts manuels et l'association des MP3. Le Lot 5 raccorde désormais le
lecteur audio et le suivi automatique ; sa recette native est décrite dans le
[bilan Lot 5](../lot5/bilan.md). Renommage et transfert JSON
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
« Scanner le dossier MP3 à chaque ouverture » est cochée par défaut.
Décochez-la pour conserver les derniers résultats sans scan automatique.
La recocher réactive le scan à chaque ouverture.

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

## Lecteur audio — Lot 5

Écouter charge l’épisode de la fiche. Le lecteur du bas conserve son propre épisode
lorsque vous consultez une autre fiche. Il affiche son titre et sa date, la position
et la durée, les commandes lecture/pause/arrêt, précédent/suivant, aléatoire et volume.
Relâcher le curseur applique le déplacement. Arrêt remet la position à zéro et le statut à Non écouté ; le favori est conservé. Pause et fermeture conservent la reprise.
Sans MP3 disponible, les commandes de lancement restent désactivées.

La position est sauvegardée toutes les cinq secondes et aux transitions. Le passage
En cours exige une progression réelle ; un simple seek vers la fin ne marque pas
l’épisode Écouté. La reprise à la dernière position peut être désactivée dans Paramètres.
Une erreur d’audio ou de stockage est affichée ; une sauvegarde défaillante bloque
la fermeture avec les mêmes possibilités Réessayer/Annuler. La lecture Windows
peut continuer quand la fenêtre est réduite ; Android met en pause en arrière-plan.


## Version bêta 0.5.01 et commandes du lecteur

Le nom du ZIP et de l’artefact indique la version, par exemple
`IndeX_0.5.01_windows_x64_portable.zip`. Le dernier nombre augmente à chaque
construction distribuable ; télécharger l’artefact du run réussi le plus récent.

- Survoler la barre de progression affiche le temps ciblé. Relâcher le clic
  applique le déplacement, sans retour visuel intermédiaire à l’ancienne position.
- Flèches gauche/droite : reculer/avancer de 10 secondes (hors saisie de texte).
- Cliquer le titre dans le lecteur ouvre la fiche de l’épisode réellement lu.
- Le bouton En cours affiche le pourcentage ; le fond de la ligne se remplit
  progressivement avec la couleur des épisodes écoutés. La durée doit être connue.
- Le changement manuel en Écouté exige une confirmation, arrête cet épisode et
  remet sa position à zéro. Le statut Écouté masque le pourcentage.
- Lecture automatique suivante est activée par défaut. Elle suit la liste affichée,
  saute les MP3 indisponibles et s’arrête au dernier épisode disponible.
- Lecture aléatoire est désactivée par défaut. L’activer lance immédiatement un
  autre épisode disponible de la liste, puis en choisit un autre à chaque fin,
  même si la lecture suivante dans l’ordre est désactivée. La désactiver ne coupe
  pas la piste en cours. Avec un seul MP3 disponible, il n’est pas relancé en boucle.
  Ces deux modes sont conservés localement entre les ouvertures.


Le lecteur Windows utilise désormais WinRT MediaPlayer via just_audio. Les
bibliothèques nécessaires accompagnent l’exécutable dans `application/` ; aucune
installation de lecteur externe n’est demandée. La réactivité des déplacements
dépend aussi du MP3 et de son emplacement ; elle reste à vérifier sur vos fichiers.


En cas de blocage audio, le journal **`logs/lecteur-audio.log`** dans votre dossier
de données contient le nom du fichier, les états du moteur et les erreurs
Windows. Il est local, sans envoi automatique ; un journal précédent est conservé
lorsque sa taille dépasse 512 Kio. Une ouverture non confirmée est annulée :
l’application doit permettre de choisir un autre épisode. Ce diagnostic n’altère
ni vos MP3 ni leurs tags et ne remplace pas les sauvegardes du suivi.


Le bouton **À propos**, dans la navigation, ouvre une présentation de l’application,
de son principe et de ses fonctions. Le premier cadre reprend le logo IndeX, le bouton Voir sur GitHub (actuellement
factice, aucun site ouvert), la version du build et le mot de l’auteur. Le contact
ouvre votre logiciel de messagerie, sans envoyer de message automatiquement. Le panneau
est défilant, avec un bouton Fermer en haut et en bas, en clair comme en sombre.
