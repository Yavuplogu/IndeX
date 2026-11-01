# Lot 4 — Spécifications complémentaires Windows

Décisions utilisateur du **25 octobre 2026**. Ce document complète le cahier des
charges V1.4 et la [référence Éditorial](../ui/README.md). Les règles ci-dessous
sont à appliquer au développement ; elles ne signifient pas que l'application
Windows ni les fonctions des Lots 5/5 bis/5 ter sont déjà livrées.

## Distribution portable et données

Windows est distribué en archive portable, **sans installateur**. L'utilisateur
extrait le dossier et lance IndeX.exe. Les DLL, ressources Flutter et le catalogue
SQLite de référence accompagnent l'exécutable ; « portable » ne promet pas un
exécutable unique. Aucun MP3 n'est embarqué, aucun service n'est installé.

Au premier démarrage, un dossier vide **`IndeX/user`** est créé et présélectionné pour les données utilisateur. L’utilisateur peut choisir un autre dossier ; la validation reste obligatoire.
Il héberge la base de travail (suivi, favoris, liens, réglages), ses sauvegardes
cohérentes et les exports JSON. Sous-dossiers proposés : `sauvegardes/` et `exports/`.
Le catalogue de référence livré reste distinct de la base de travail.

Choix technique proposé pour retrouver ce dossier aux ouvertures suivantes : un
petit `application/index-portable.json` conserve uniquement son chemin
et la version de configuration. L'archive extraite doit donc pouvoir écrire ce
fichier ; sinon afficher l'erreur et demander un emplacement accessible. Ne pas
basculer silencieusement vers AppData ou un dossier temporaire. Les dossiers choisis
peuvent être extérieurs au dossier de l'exécutable ; déplacer seulement celui-ci
ne déplace pas les MP3 ni les données. Cette proposition n'ajoute pas de données
personnelles hors du dossier dédié, hormis le pointeur nécessaire pour le retrouver.

Valider existence/accès/écriture et détecter un éventuel verrou d'une autre instance.
Si le dossier utilisateur connu est absent, inaccessible ou la base en erreur,
proposer de le retrouver/réessayer, sans créer silencieusement un suivi vide ni
écraser une base existante. Un changement de dossier dans Paramètres demande un
aperçu et un transfert cohérent vérifié avant de changer le pointeur.

## Premier démarrage et ouvertures suivantes

Le premier écran demande :

1. Le dossier contenant les MP3.
2. La case **« Préciser le dossier MP3 plus tard »**, décochée initialement.
   Cocher cette case rend le dossier MP3 facultatif ; sinon il est requis.
3. Le dossier des données utilisateur, prérempli avec `IndeX/user`, modifiable et obligatoire.

L'utilisateur peut quitter avant de terminer. Le catalogue reste entièrement
consultable sans MP3 une fois le dossier utilisateur validé.

Si un dossier MP3 est fourni, lancer le scan et les concordances avec les règles
de la [règle du 26 octobre 2026](../regle-association-noms-journal.md) : noms du
journal uniquement, sans lire COMM, conflits signalés, aucune
modification de nom ou de tag. Montrer progression/résultat, erreurs et accès refusés.
Une indisponibilité ou un scan incomplet ne supprime pas les liens ni le suivi.

Aux ouvertures ultérieures, afficher un chargement dynamique puis la vue principale,
même sans dossier MP3 : ne plus présenter le formulaire initial. Si le dossier est
configuré mais inaccessible, signaler l’indisponibilité sans supprimer les données.
Le scan au lancement reste actif par défaut. Dans Paramètres, la case décochée
« Ne plus scanner le dossier MP3 à chaque ouverture » permet de le désactiver.
Conserver alors le dernier rapport et ses liens ; les disponibilités peuvent dater.
Un scan manuel reste possible, y compris dans les sous-dossiers selon l’option persistée.

Afficher durablement **« Aucun dossier MP3 paramétré »** dans la bibliothèque,
les fiches, le lecteur et les autres fenêtres concernées. Distinguer :

- Dossier non configuré : disponibilité audio inconnue, lecture impossible.
- Dossier configuré, MP3 non trouvé : « MP3 absent », rouge et ligne grisée.
- Dossier configuré mais inaccessible : avertissement d'accès, pas de faux scan vide.

Le dossier des données est accessible dans **Paramètres**, dans son cadre dédié.
Le dossier MP3, son retrait, son changement et l’option sous-dossiers sont accessibles
uniquement dans **Fichiers et associations**. Un dossier MP3 peut être retiré sans effacer le suivi.

## Fermeture et sauvegarde durable

La croix en haut à droite ferme réellement l'application Windows **après** validation
de la sauvegarde du suivi, des favoris, des liens et des réglages en cours :

1. Intercepter la demande de fermeture ; suspendre les commandes concurrentes.
2. Capturer le dernier état utile et attendre la fin des écritures transactionnelles.
3. Produire/valider la sauvegarde cohérente dans le dossier utilisateur, fermer les
   ressources, puis autoriser la fermeture de la fenêtre/processus.
4. En cas d'échec (disque plein, dossier retiré…), laisser la fenêtre ouverte avec
   erreur explicite et choix Réessayer/Annuler. Ne pas afficher de fausse réussite.

Cela **complète** les écritures au fil des modifications et les checkpoints périodiques
prévus (cible de lecture : 5 s, Lot 5). Un arrêt brutal ne passe pas nécessairement
par la croix. Utiliser les mécanismes SQLite de sauvegarde cohérente, jamais une
copie isolée du `.sqlite` pendant que le WAL contient encore des transactions.

## Recherche et sélection des champs

Rechercher par défaut dans **titre, résumé, sources et musiques**, avec une
sélection indépendante des champs : titre seul, résumé seul, titre + résumé,
sources seules ou autres combinaisons. Au moins un champ est requis. Les termes
peuvent être répartis entre les champs sélectionnés, combinés avec AND.

Dans l'application, utiliser FTS5 : casse/accents neutralisés, requêtes littérales
bornées et paramétrées, extraits et classement donnant priorité au titre.
Les sources comprennent référence, auteur et éditeur ; les musiques leurs champs
documentaires. Le filtrage par champs doit être ajouté à l'API SearchOptions : le
moteur du Lot 3 recherche déjà dans ces contenus mais ne propose pas encore ce choix.
La recherche demeure utilisable sans sélection de dossier audio.

Le HTML illustre ces combinaisons par un filtre textuel en mémoire, sans prétendre
exécuter le moteur FTS5 ni ses scores.

## Renommage — règle exclusive du Lot 5 bis

Une seule conversion est proposée : **nom historique → TITRE SYSTEME du catalogue**.
Exemple fourni par l'utilisateur :

```text
mr_x_2005_10_15.mp3
→ 2005-10-15 L'Irak (1 sur 3) _ Halabja.mp3
```

Aucun modèle libre, renommage inverse ou autre convention ne doit être proposé.
Un fichier déjà au nom système n'est pas renommé à nouveau. Un nom différent du
nom historique, un conflit, une association incertaine ou un TITRE SYSTEME absent
est exclu et expliqué. Ne pas reconstruire un nom à partir du titre web.

Les paramètres expliquent ce périmètre avant le bouton de prévisualisation.
Conserver aperçu avant/après, contrôle des collisions/permissions/noms Windows,
confirmation explicite, opération dans le même dossier et journal/reprise. Les tags
et octets MP3 restent inchangés. Il s'agit d'un changement de nom de fichier local,
pas d'un changement de titre documentaire.

## Transfert manuel du suivi — Lot 5 ter

Dans Paramètres, expliquer brièvement :

- **Transféré** : identités stables d'épisode, favoris, statuts d'écoute, positions,
  durées connues et métadonnées de version/causalité nécessaires à une fusion sûre.
- **Non transféré** : MP3, TXT, catalogue complet, dossiers et chemins locaux,
  permissions d'accès, liens audio propres à l'appareil, préférences d'apparence.
- L'export crée un fichier ; il ne déplace pas les données et ne les efface pas.
  L'import compare et fusionne avec aperçu/confirmation ; aucune synchronisation
  automatique et aucune résolution silencieuse par l'horloge ou la position maximale.

Créer le JSON **dans le dossier dédié aux données utilisateur**, sous `exports/`,
avec un nom explicite **sans espace**, par exemple :

```text
IndeX_suivi_20261031_215134.json
```

Le nom utilise la date et l’heure locales à la seconde, sans suffixe aléatoire.
Créer sans écraser un export existant ; si un export existe à cette seconde,
inviter à réessayer une seconde plus tard. Écrire temporairement puis publier
après validation. Les dates ne décident pas de la fusion. Afficher le chemin final et permettre d'ouvrir son
dossier. Ne pas demander une destination extérieure comme choix par défaut.
L'utilisateur copie ensuite ce fichier vers l'autre appareil et l'importe.
Si le dossier n'est pas inscriptible, afficher un échec sans annonce d'export réussi.

## Critères de recette à exécuter

| Cas | Résultat attendu |
|---|---|
| Archive sur Windows propre | Lancement sans installateur ; catalogue accessible hors ligne. |
| Premier démarrage, champs vides | Dossier utilisateur exigé ; dossier MP3 ou case de report exigé. |
| MP3 reportés | Catalogue/recherche accessibles et indication persistante de dossier absent. |
| Redémarrage sans dossier MP3 | Sélection de dossier proposée à nouveau, dossier utilisateur conservé. |
| Dossier MP3 choisi/changé | Scan et concordances, conflits visibles, aucun renommage implicite. |
| Dossier connu indisponible | Erreur distincte, suivi préservé, aucun effacement massif. |
| Fermeture par croix | Écritures/sauvegarde confirmées avant fermeture ; reprise identique. |
| Erreur de sauvegarde | Fenêtre maintenue ouverte, erreur et nouvelle tentative possibles. |
| Arrêt forcé | Données validées intactes ; perte bornée au dernier checkpoint confirmé. |
| Recherche par champs | Résultat présent/exclu selon les champs, y compris sans MP3. |
| Renommage (Lot 5 bis) | Uniquement historique → système ; aperçu/confirmation, collisions bloquées. |
| Export (Lot 5 ter) | JSON sans espaces dans exports/, aucune collision/aucun MP3, erreur d'écriture gérée. |
| Import (Lot 5 ter) | Aperçu de fusion et choix explicites, suivi/liaisons locales préservés. |

Ces critères sont des exigences à vérifier sur les livrables réels. Les contrôles
de la maquette HTML ne constituent ni une recette Windows ni une preuve de
sauvegarde sur disque, de scan MP3 réel ou de fusion JSON implémentée.

### Exception de présentation pour le HTML uniquement

La maquette dispose d'une case de test pour ignorer les chemins et fermer le
formulaire de démarrage. Ce contournement est limité à la session HTML et ne doit
pas être porté dans l'application livrée : le dossier utilisateur demeure obligatoire
et le report explicite des MP3 conserve les règles décrites ci-dessus.

Pour rendre les essais visuels explicites, ce raccourci HTML affiche également
les disponibilités fictives des exemples et active le lecteur simulé. Il ne
configure aucun dossier réel et ne doit pas être confondu avec le parcours de
report des MP3 de l'application, qui affiche « Aucun dossier MP3 paramétré ».

### Précisions sur le report et le tri audio

La case s'intitule **« Préciser le dossier MP3 plus tard »**. Elle est visible
uniquement dans la sélection au démarrage (première ouverture, puis tant qu'aucun
dossier n'a été défini), jamais dans Paramètres. Dans Paramètres, le chemin audio
reste facultatif ; le laisser vide retire la configuration et réactive la demande
au prochain démarrage, sans effacer le suivi.

Ajouter au tri du catalogue les options **MP3 disponibles d'abord** et **MP3 absents
d'abord**, sans exclure les autres épisodes. Départager chaque groupe par date
décroissante puis identité stable. Un dossier jamais configuré ne permet pas de
conclure à une absence de fichiers ; conserver l'avertissement prévu.


## Ajustements après essais de l’interface Windows

Demandes utilisateur complémentaires :

- Fiche ancrée en haut, y compris sans résumé, source ou musique. La lettrine
  occupe deux lignes, avec retour du texte à pleine largeur après ces deux lignes.
- Dans la liste, les flèches haut/bas sélectionnent l’épisode précédent/suivant
  selon les filtres et le tri actifs, ouvrent sa fiche et maintiennent la sélection
  visible. Consulter une fiche ne doit jamais changer un épisode en lecture.
  Au Lot 4, le lecteur est un aperçu sans audio ; il ne reprend plus le titre
  de chaque fiche consultée.
- Curseur main pour les commandes actives, menus et éléments cliquables ; champs
  de texte et commandes désactivées gardent leurs curseurs appropriés.
- Fond beige clair harmonisé pour les dialogues, Paramètres et boutons de navigation,
  avec variante chaude sombre. Typographie agrandie légèrement, sans réduire un
  agrandissement d’accessibilité existant. Favoris de la liste et de la fiche
  dans la même couleur d’accent ; logo « Inde » gris, « X » conservé.
- Aucun bandeau de chemin MP3 lorsque le dossier est prêt. Les avertissements
  d’absence, d’inaccessibilité ou de scan incomplet restent visibles. Aucun rappel
  du dossier sous le titre Paramètres ; le champ reste dans la section Dossiers.
- Recherche dynamique après 250 ms sans saisie, à partir de trois caractères.
  Avant ce seuil, la liste conserve les autres filtres, sans requête documentaire.
  Chaque terme est recherché comme début de mot (par exemple « Yougo » trouve
  « Yougoslavie »), avec tous les termes requis et respect des champs cochés.
  Un bouton efface immédiatement le champ et annule toute recherche différée.
- Rubriques trouvées (Titre, Résumé, Sources, Musiques) sous chaque résultat.
  Dans la fiche, cadre distinct « Résultat de la recherche » avec les mots trouvés
  en gras et en couleur, accents conservés. Ces repères proviennent de FTS5,
  sans interprétation HTML du corpus.
- Diagnostic de scan défilant dans une zone bornée avec barre visible et texte
  sélectionnable. Export TXT UTF-8 dans `exports/` du dossier utilisateur,
  sous `IndeX_diagnostic_scan_<horodatage_UTC>.txt`, sans espace. Le fichier
  comprend messages, sources et rapport complet, sans modifier les MP3.


## Nouvelle présentation portable et corrections de la fiche

Les demandes suivantes complètent les ajustements précédents :

- Le ZIP contient un dossier `IndeX/`, avec **un seul fichier à sa racine :
  `IndeX.exe`**, le lanceur. Les composants Flutter restent ensemble dans
  `application/`, les notices et le manifeste dans `documentation/`. Le pointeur
  vers le dossier utilisateur est créé dans `application/`. Le lanceur est sans
  installateur ni dépendance DLL à sa racine ; il attend le programme et transmet
  son code de sortie. Le test du ZIP doit lancer ce fichier visible.
- Même icône X typographique pour le lanceur et le programme. Barre de fenêtre
  légèrement grisée, distincte du panneau principal en clair comme en sombre.
- Haut du logo, cadre de recherche et titre de fiche alignés sur la même marge.
- Lettrine sur deux lignes exactes, sans troisième ligne étroite ni ligne vide
  ajoutée sous la lettrine. Mesure et rendu utilisent les mêmes styles de police,
  surlignages et facteur d'agrandissement. La ponctuation initiale est groupée avec
  la première lettre ou le premier chiffre, y compris après guillemets/apostrophes.
  Les retours et paragraphes du texte documentaire sont conservés visuellement.
- Épisodes connexes : même police Georgia, graisse et couleurs d'état que la liste,
  dates à côté et fine séparation grise entre les lignes. Les boutons restent
  cliquables même lorsque leur texte contient une correspondance.
- Le cadre « Résultat de la recherche » explique les repères et ne répète plus
  l'extrait. Dans les onglets et le titre, les correspondances des champs cochés
  sont encadrées sur fond rouge clair, en rouge et en gras. Match précédent / Match
  suivant parcourent les occurrences affichées, changent d'onglet et positionnent
  la vue sur l'occurrence active. Le parcours boucle après la dernière ou avant
  la première occurrence. Les boutons restent accessibles pendant le défilement ;
  un contour plus marqué distingue l'occurrence active.


## Association par noms du journal — 26 octobre 2026

La [règle dédiée](../regle-association-noms-journal.md) remplace toute priorité COMM
ou repli par titre décrit dans les documents antérieurs. Le catalogue doit intégrer
les dernières sources avant empaquetage. Les huit corrections de noms sont intégrées
au seed v4 sans modifier les identités, favoris ou suivi. Le diagnostic doit expliquer
les noms inconnus et ambiguïtés, distinguer les choix manuels et ne jamais présenter
une association par nom comme une validation ID3 ou du contenu audio.


## Compteurs, diagnostic et fiche fixe — révision du 26 octobre 2026

Cette révision remplace les couleurs rouge clair et la barre défilante décrites
plus haut. Les sources `f126478` (TXT Le colonel B. et L'affaire L. avec doubles
points, journal correspondant) sont intégrées au seed r3 avant empaquetage.

- Compteur : gauche inchangée (épisodes visibles avec filtres), droite égale au
  nombre global d'épisodes avec MP3 associé disponible ; rappel « Y MP3 absents »
  avec la même typo et couleur après scan complet. Si non vérifié, ne pas qualifier
  les fichiers d'absents.
- Chemins de diagnostic affichés avec espaces, sans encodage URI visible, y compris
  dans le TXT exporté. Les URI techniques dans SQLite restent inchangées.
- Cartes du listing d'associations : textes sélectionnables, fond des Paramètres,
  fichiers dotés d'un bouton « Associer… » en tête, ordre stable dans chaque groupe.
- Cadre Résultat de la recherche, correspondances et boutons : fond des Paramètres,
  encre identique au X du logo ; cadres des occurrences et texte gras conservés.
  Texte exact : « Correspondances encadrées en rouge, utilisez les boutons pour
  parcourir. » Le compteur reste dessous. Boutons « Résultat précédent » et
  « Résultat suivant », chacun portant son propre fond limité à sa forme, sans
  rectangle coloré autour ni entre les boutons.
- En-tête fixe (titre, date, états, cadre explicatif, commandes et onglets), données
  défilantes indépendantes : la navigation révèle le résultat dans cette zone sans
  déplacer le haut de la fiche. Aucune hauteur de barre fixe ne doit créer un vide
  sous les onglets, avec ou sans recherche. En petite fenêtre ou à fort zoom,
  l'en-tête peut défiler manuellement dans une zone bornée pour conserver une zone
  de lecture utilisable ; son défilement est indépendant de celui des données.
- Épisodes connexes : survol rectangulaire à la taille de la cellule. Date de même
  police, graisse et couleur d'état que la liste générale ; taille actuelle conservée.
- Appliquer les mêmes règles dans le thème sombre.

## Démarrage et paramètres — complément du 26 octobre 2026

Le dossier `user` est créé vide au premier lancement seulement en l’absence de
pointeur portable. La base y est créée après validation ; un autre chemin reste
possible. Un pointeur existant invalide ou un dossier connu manquant ne déclenche
jamais la création automatique d’un profil vide. Le pointeur reste dans `application/`.

Les cadres Paramètres gardent leur beige actuel ; le fond du panneau reprend celui
de la barre latérale (`panel`), dans les deux thèmes. Le menu Apparence utilise des
bordures arrondies, des fonds et des textes de la palette Éditorial. Le cadre données
est séparé, sans cadre de choix MP3. Le texte Transfert précise la création future
d’un fichier `.json` dans `exports` du dossier utilisateur (Lot 5 ter inchangé).
Le chevron de « Résultat suivant » est placé après le libellé.

## Chargement, compteurs et menus — révision du 27 octobre 2026

Cette révision remplace la présentation des compteurs décrite plus haut.
- Pendant toute l’ouverture d’un profil existant, y compris après ouverture de la
  base et pendant le scan, afficher une animation de chargement. Le formulaire de
  premier démarrage ne doit pas réapparaître ; les erreurs de données restent signalées.
- Sous les filtres, restaurer « épisodes affichés / total du catalogue épisodes »,
  sans rappel des MP3 absents ni message de disponibilité à côté.
- Dans Fichiers et associations : total des épisodes du catalogue, fichiers MP3
  détectés au dernier scan, épisodes associés disponibles et épisodes manquants.
  Le nombre de fichiers peut dépasser celui des épisodes associés (inconnus,
  doublons, conflits). Sans scan complet, les manquants restent « Non vérifié ».
- Ajouter « Ouvrir le dossier MP3 » : ouvrir le dossier configuré dans l’Explorateur
  Windows, sans shell ni nouvelle dépendance. Bouton désactivé sans dossier ; erreur
  explicite si le dossier est devenu inaccessible.
- « Analyser aussi les sous-dossiers » est coché par défaut en l’absence de réglage ;
  une préférence explicite déjà enregistrée est conservée.
- Les menus de tri et de statut permettent de passer de l’un à l’autre en un seul
  clic, même si le premier est ouvert. Menus accessibles par clavier conservés.

## Dossiers, menus et associations — complément du 27 octobre 2026

- L’ouverture du dossier MP3 passe par un canal Flutter du runner Windows vers
  `ShellExecuteW`, avec le dossier en argument `lpFile`, sans construction de ligne
  de commande Explorer. Chemin Windows normalisé, espaces et Unicode conservés ;
  un dossier inaccessible produit une erreur, sans repli volontaire vers Documents.
- Tous les menus déroulants ont le même fond que les boutons latéraux, sans teinte
  de surface ajoutée. Apparence reprend le menu ancré sous son bouton, indépendamment
  du mode sélectionné, au lieu de centrer la liste sur la valeur active.
- Le chargement affiche « N’allons pas trop vite... » sous l’animation.
- L’accueil explique la consultation/recherche du catalogue, les MP3 personnels
  facultatifs et le dossier dédié aux favoris, au suivi et aux sauvegardes.
- Dans Fichiers, les cartes sans association sont grises ; leur message est dans
  le rouge du X, sans colorer le nom ou le chemin. Associer… conserve son beige.
- Une association existante propose Enlever l’association, avec confirmation.
  Le fichier et le suivi restent intacts. Une exclusion locale persistante par
  référence empêche sa recréation au prochain scan. Une association manuelle
  explicite lève cette exclusion. Aucun effet sur les autres fichiers ou épisodes.
- Le bouton Diagnostic du scan précède Exporter le diagnostic TXT sur la même
  ligne. Il ouvre un panneau flottant refermable avec résultats défilants,
  sélectionnables et copiables ; aucun diagnostic reste déplié dans la page.

## Apparence, retrait et filtres — dernière révision du 27 octobre 2026

Cette décision remplace le menu Apparence et la conservation du suivi lors du
retrait décrits dans la révision précédente.

- Apparence : deux boutons Mode clair / Mode sombre, choix actif distinct et
  préférence persistée ; aucun menu déroulant dans ce cadre.
- Retrait confirmé : supprimer dans une seule transaction le lien et la ligne
  `user_episode_state` de l’épisode lié (favori, statut, progression, durée), tout
  en conservant le MP3 et les données des autres épisodes. Le dialogue annonce
  explicitement cette suppression. L’exclusion locale persiste ; réassocier ne
  restaure pas les données effacées. Une erreur annule l’ensemble de la transaction.
- Juste avant la liste des fichiers : Fichiers associés, Fichiers non associés,
  Tous les fichiers. Ce dernier est actif initialement, non associés en premier.
  Un retrait ou une association actualise immédiatement le résultat du filtre.
  Le filtre concerne la liste du dernier scan ; compteurs et diagnostics globaux
  ne sont pas filtrés. Prévoir un message si aucun résultat.


## Ajustements du lecteur et copie des erreurs — 28 octobre 2026

- Titre du lecteur : pointeur main, ouverture de la fiche sans réinitialiser la
  recherche, les champs, les filtres, le tri ou la position de défilement de la liste.
  La fiche peut rester celle d’un épisode hors résultats ; un checkpoint ne doit
  pas la remplacer par le premier résultat. Une nouvelle sélection dans la liste
  ou une nouvelle recherche reprend le parcours habituel. Si la fiche n’est pas
  affichée (vue Fichiers ou compacte), ouvrir un dialogue sans quitter cette vue.
- En mode aléatoire, les commandes manuelles Épisode précédent/Épisode suivant
  tirent elles aussi un autre épisode au hasard parmi les disponibles de la liste,
  sans répétition immédiate. Hors aléatoire, ordre séquentiel conservé.
- Pendant un clic-glissé du curseur, l’horodatage reste visible et suit la cible,
  même si le pointeur quitte verticalement la barre avant relâchement. La cible
  reste affichée pendant l’acquittement du seek, sans retour à l’ancienne position.
- Boutons de filtres Fichiers et associations : pointeur main, thèmes clair/sombre.
- Erreurs copiables : lecteur, bannière principale, Paramètres, erreurs de recherche
  et de validation de dossiers, contenu des fenêtres d’alerte dont Sauvegarde
  impossible. Sélection et copie standard Flutter, diagnostics déjà sélectionnables
  conservés. Les onglets de fiche s’adaptent à une largeur compacte sans débordement.


## Réécoute d’un épisode terminé — 28 octobre 2026

Un clic sur Écouter pour un épisode déjà Écouté démarre une nouvelle écoute à
zéro : statut Non écouté initialement, puis En cours dès la progression réelle,
remplissage progressif de la ligne et nouvelle validation de fin habituelle.
Le favori est conservé. Cette règle vaut aussi lorsque la fiche reste ouverte
après le démarrage automatique du suivant, ainsi qu’après navigation entre fiches.
Le bouton Lecture du lecteur applique la même règle après la fin sans enchaînement.

Le suivi persistant fait autorité, même si l’objet de fiche est ancien. La remise
à zéro intervient après le dernier checkpoint de la piste quittée et après
ouverture/positionnement réussis de la nouvelle lecture, avant son premier
checkpoint. Une ouverture échouée ne doit pas effacer le statut Écouté existant.
Une écoute inachevée conserve sa reprise, selon le réglage utilisateur ; pause,
Arrêt et changement manuel de statut conservent leurs comportements respectifs.


## Conservation des filtres et fin après déplacement — 28 octobre 2026

- À la réouverture, restaurer les réglages de la liste : recherche saisie, champs
  Titre/Résumé/Sources/Musiques cochés, ordre de tri, filtre de statut et vue Favoris.
  Ils sont conservés dans les réglages du profil utilisateur ; effacer un filtre
  conserve aussi son retrait. Le champ de recherche affiche le texte restauré.
  La saisie est enregistrée immédiatement, même si la fermeture précède le délai
  de rafraîchissement des résultats. Aucun démarrage automatique de l’audio.
- Dans Paramètres → Lecture et reprise, placer la case de reprise à gauche du texte.
- Après un déplacement à quelques secondes du terme, la fin signalée par le moteur
  valide Écouté si une progression réelle a eu lieu depuis le déplacement. Le statut
  est sauvegardé avant l’éventuel enchaînement ; la ligne est entièrement colorée
  comme Écouté, sans rester En cours à 100 %. Le simple placement du curseur à la
  fin sans lecture ne suffit pas. Sans signal de fin, conserver la validation
  anticipée après dix secondes continues dans la zone de fin. Une durée inconnue
  ne déclenche pas de validation automatique.


## Avance clavier atteignant le terme — 28 octobre 2026

La flèche droite (+10 s) pendant la lecture peut atteindre ou dépasser le terme.
Dans ce cas, la position est bornée à la durée et le statut passe à Écouté lorsque
le moteur confirme la fin, avant l’éventuel passage au suivant. Aucun besoin de
laisser s’écouler les dernières secondes après cette avance. Cette exception
complète la règle précédente : elle concerne l’avance relative en lecture, avec
une durée connue. Un simple positionnement absolu à 100 %, une avance en pause
ou un recul ne valide pas une écoute. Un autre seek annule la demande en attente.


## Analyse au démarrage et À propos — 29 octobre 2026

La case Analyse au démarrage porte le libellé « Scanner le dossier MP3 à chaque
ouverture ». Cochée = scanner, décochée = ne pas scanner, suivant la clarification
explicite de l’utilisateur. Elle est cochée par défaut ; les préférences existantes
sont conservées en inversant uniquement la présentation de skip_startup_scan.

Ajouter À propos dans la navigation latérale et dans la navigation compacte.
Le panneau reprend dimensions, couleurs et cadres des Paramètres, avec contenu
sélectionnable/défilant et boutons Fermer en haut et en bas. Premier cadre : IndeX,
version publique réelle du build et bouton GitHub factice avec retour explicite,
sans navigateur ni accès réseau. Présentation : catalogue intégré, recherche et
filtres, fiches documentaires, associations MP3, lecteur, suivi/favoris, stockage
local et portabilité Windows. Distinguer les fonctions prévues (renommage et JSON)
et la pause Android des fonctions actuellement disponibles.

La construction portable transmet la version publique réservée via INDEX_VERSION
à Flutter. Le panneau reprend ainsi le même numéro, avec mineur sur au moins deux
chiffres, que l’archive. Hors construction de distribution, afficher Développement
plutôt qu’un numéro de build fictif. Aucun nouveau package requis.


## Révision éditoriale de À propos — 29 octobre 2026

Employer « Rendez-vous avec X » dans le sous-titre de marque et les textes de
l’application. Le premier cadre de À propos réutilise le même widget Brand que
la barre latérale, avec mêmes couleurs, police et sous-titre. Sur la ligne suivante,
placer Voir sur GitHub en premier puis la version du build. Le lien GitHub reste
factice, sans navigateur/réseau ; son libellé ne contient plus « lien factice ».

Ajouter dans ce cadre le récit personnel fourni par l’utilisateur (création de
l’utilitaire hors ligne, Patrick Pesnot, essais avec l’IA), le contact et la signature
« Bonne écoute, K. ». Le contact index.en9nr@passinbox.com ouvre le gestionnaire
Windows mailto sur clic explicite, sans envoi automatique. En cas d’absence de
messagerie, une alerte sélectionnable permet de copier l’adresse.

Reprendre les nouveaux textes des cinq cadres : catalogue de 716 émissions/420 h,
recherche/fiches, associations/lecteur, suivi, stockage local. Les chiffres et le
récit sont ceux fournis par l’utilisateur. Mettre en gras Fichiers, les deux noms
MP3 d’exemple et les états Non écouté/En cours/Écouté. Supprimer le cadre Fonctions
prévues. Le paragraphe utilisateur sur le transfert est suivi d’une précision
courte : l’export/import JSON du Lot 5 ter reste non livré. Aucun changement de
règle d’association, d’audio ou de disponibilité des futurs lots.


## Dossiers internes déplaçables et contact — 30 octobre 2026

La racine portable Windows est le parent du dossier application ; hors ce layout,
c’est le dossier portable lui-même. Le pointeur index-portable.json v2 enregistre
les données internes relativement à cette racine ; les données externes restent
absolues. Les pointeurs v1 sont reconnus et convertis après ouverture réussie du
profil existant. Pas de profil vide de remplacement si le dossier attendu manque.
Les chemins relatifs sortants et les liens de données qui sortent de la racine
sont refusés. L’erreur de dossier absent affiche désormais le chemin concerné.

Une racine mémorisée dans local_settings permet, avant scan/lecture, de réévaluer
les références internes après déplacement : dossier MP3, liens automatiques et
manuels, exclusions, références et diagnostics des scans. La mise à jour se fait
dans une transaction ; collision = annulation, aucun écrasement de lien ou suivi.
Les identités, favoris, progressions et fichiers MP3 ne sont pas modifiés. Les
références extérieures restent inchangées. Les chemins de travail restent absolus
pour le moteur ; leur racine est recalculée au démarrage. Aucune migration du
schéma SQLite ni changement de seed. Application fermée pendant le déplacement.

Pour un ancien profil sans racine mémorisée, ouvrir une fois la mise à jour avant
le déplacement. Si son pointeur absolu est déjà périmé, relocaliser explicitement
les données existantes ; ne pas choisir un autre profil par supposition.

À propos : phrase d’introduction révisée, mail centré sur sa propre ligne et espace
après. Clic = copie dans le presse-papiers avec confirmation, sans lien externe ni
messagerie. GitHub reste factice, avec logo Primer Octicons MIT embarqué et bouton
à bordure. Licence et provenance conservées, licence incluse dans la distribution.


Complément Windows du 30 octobre : une racine peut avoir plusieurs écritures
physiquement identiques (nom court 8.3 et nom long). Les mémoriser avant déplacement
et les reconnaître lors de la réévaluation des liens. Garder les frontières de
répertoire, les caractères encodés des URI et les chemins extérieurs ; annuler
toujours une collision. Ne pas assimiler deux chemins par approximation de texte.


## Télécharger un MP3 manquant — 30 octobre 2026

Dans la fiche, MP3 disponible = Écouter ; absent = Télécharger, désactivé si aucune
URL MP3 valide n’existe dans journal_json. Aucun repli vers une URL du TXT ou une
recherche web. Infobulle avec hôte et connexion Internet requise. Sans dossier MP3,
ouvrir le sélecteur ; annuler ce choix n’émet aucune requête. Une association manuelle
indisponible demande confirmation avant d’être remplacée par le fichier téléchargé.

Afficher un bandeau de progression non modal dans la vue principale (taille reçue,
total si connu, sinon progression indéterminée), avec Annuler. Navigation
et lecture d’un autre épisode restent possibles ; dossiers/associations ne changent
pas pendant le transfert. Une seule réception à la fois. La fermeture annule/attend
le nettoyage avant sauvegarde ; après publication commencée, elle attend la fin de
l’association. Aucun nouveau téléchargement pendant cette fermeture.

Après succès : disponibilité et fiche actualisées, bouton Écouter, suivi/favoris
conservés, aucun démarrage audio imposé. Une erreur s’affiche dans la bannière
sélectionnable. Un MP3 publié mais non associé à cause d’une erreur reste conservé
et le message invite à relancer une analyse. Aucune cible préexistante n’est écrasée.
Dans À propos, supprimer le sous-titre seulement de la marque du panneau ; conserver
celui de la barre latérale et de l’accueil. Adapter le texte hors ligne à l’exception
explicite du téléchargement facultatif.


### Ajustements du 31 octobre — présentation et nom des téléchargements

Dans À propos, logo à gauche et groupe version puis bouton GitHub ancré à droite
sur la même ligne. Le site rendezvousavecmrx.free.fr est mentionné dans Écouter vos
MP3, en texte simple sans lien externe. Retirer la phrase relative au contact du
serveur dans Vos données restent chez vous.

Un téléchargement réussi est publié directement sous le nom complet TITRE SYSTEME
du catalogue (extension .mp3 incluse), jamais sous le nom historique de l’URL.
Nom système absent/invalide ou cible existante : refus sans écrasement. Cette règle
concerne uniquement le nouveau fichier reçu ; aucun renommage des MP3 existants.
Conserver les contrôles, l’association et le suivi/favoris.

Les textes des cadres Paramètres partagent la taille du corps de texte d’À propos.
La description Lecture et reprise est placée sous son libellé, alignée après la
case comme dans Analyse au démarrage. Dispositions communes aux deux thèmes.


### Lot 5 bis lancé — 31 octobre 2026

Le bouton Prévisualiser le renommage des MP3 de Paramètres → Fichiers audio ouvre
un panneau de renommage Windows fonctionnel, en clair et sombre. Analyse du
dossier MP3 et sous-dossiers selon le réglage ; tableau global avant/après,
comptes des prévus/déjà conformes/ignorés/conflits. Fermer l’aperçu ne modifie rien.
Seul Confirmer les N renommages exécute les conversions ; bilan sélectionnable
et journal SQLite persistant. Les MP3 utilisés par le lecteur sont ignorés.
Le panneau permet d’actualiser l’aperçu et de consulter le journal précédent.
Blocage du scan si une interruption laisse une réconciliation ambiguë.
Description technique et recette : ../lot5bis/bilan.md. Version initiale 0.6.0.


### Lot 5 ter — transfert JSON Windows, 31 octobre 2026

Dans Paramètres → Transfert du suivi, les deux boutons sont fonctionnels. Export
vers exports/ sous le dossier utilisateur, nom explicite sans espaces, publication
complète sans écrasement et notification avec chemin sélectionnable/ouverture du
dossier. Import : sélecteur JSON, panneau d’aperçu (source, date, comptes, changements
et inconnus), choix par conflit Conserver cet appareil / Utiliser le fichier, puis
confirmation globale. Selon la révision utilisateur suivante, les conflits
présélectionnent le fichier importé ; Fermer annule sans effet sur le suivi importé. Les erreurs sont
sélectionnables. Couleurs/cadres communs aux thèmes clair et sombre.

Lecteur chargé : proposer Mettre en pause et libérer la piste, sauvegarder la
position, puis préparer l’aperçu. Sauvegarde SQLite avant fusion, suivi local changé
depuis aperçu = nouvel aperçu requis. JSON déjà importé = annonce sans application.
Android demeure désactivé pour ce parcours, format partagé préparé. Voir le bilan
et le contrat du Lot 5 ter. Aucune modification de la maquette HTML historique.


### Révision lecteur et panneaux — 31 octobre 2026

- Titre du lecteur : liseré au survol, main et accès à la fiche sans modifier le listing.
- Renommer les MP3 : filtres Tous/À renommer/Déjà conformes/Ignorés/Conflits dans
  l’aperçu ; Tous/Renommés/Échecs/Non effectués/À réconcilier dans le journal.
  Le filtre n’altère pas le lot global soumis à confirmation.
- Import : filtres par type, conflits en premier, dont tous les choix sont initialisés
  à Utiliser le fichier importé. Choix au cas par cas et deux commandes pour tous les
  conflits (y compris masqués). La confirmation globale reste obligatoire et le
  moteur de fusion exige une réponse pour chaque conflit. Aucune comparaison de
  dates ou de position maximale pour décider. Les dates s’affichent en heure locale
  AAAA-MM-JJ HH:mm:ss, la reprise indique son pourcentage (— si durée inconnue).
- Après fusion réussie, le panneau contient seulement le message Import terminé et
  un bouton Fermer. Aucun bouton Confirmer grisé ni ancien aperçu conservé à l’écran.
- Export : IndeX_suivi_AAAAMMJJ_HHMMSS.json, heure locale, sans UUID dans le nom.
  Un export existant n’est pas remplacé ; même seconde = message demandant de réessayer.
  Le contenu JSON conserve son export_id unique et ses dates UTC.
- Enchaînement automatique, séquentiel ou aléatoire : exclure ECOUTE. S’arrêter
  sans redémarrer un épisode terminé si aucun candidat admissible ne reste. Les
  commandes manuelles conservent la possibilité de réécouter un épisode.
- Paramètres, cadre Lecture et reprise : remise à zéro de tout le catalogue, après
  confirmation explicite et sauvegarde. Position=0, NON_ECOUTE, dates d’écoute/fin
  effacées, favoris/durées connues/MP3/associations conservés. Une transaction et
  marqueurs causaux par épisode rendent le reset transférable et atomique.
- Glissement du lecteur pendant lecture vers le terme ou la dernière seconde :
  attendre le vrai signal ended pour valider Écouté, même sans delta de position
  supplémentaire. En pause, un seek programmatique ou un simple placement sans
  fin moteur ne valide rien ; une nouvelle manipulation annule la demande précédente.


### Révision du 1er novembre 2026 — transfert et présentation

Le transfert fusionne l’écoute comme un ensemble : état, position, durée et dates
proviennent de la même source. Le favori reste indépendant. Un cadre par épisode
remplace les cadres par champ ; les filtres comptent des épisodes, avec priorité
conflit > modification > versions réunies > conservé > identique. Le choix par
défaut reste le fichier importé et la confirmation globale reste obligatoire.
Les nouveaux JSON v2 indiquent Windows/Android ; les anciens v1 sont acceptés avec
plateforme non renseignée. Mettre à jour les deux installations avant d’échanger
des v2. Voir [le contrat](../lot5ter/format.md). Aucun changement SQLite/seed.
Le panneau de renommage conserve ses dimensions quand on filtre. Le liseré
du lecteur entoure uniquement le titre et sa date, dans la largeur disponible.


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

Vérification sous Linux : formatage conforme, analyse Flutter sans problème et
61 tests Flutter réussis. Le test de téléchargement contrôle le fond gris sans
dossier, l’avertissement avant sélecteur, l’annulation sans effet et la persistance
du dossier après annulation du transfert. Recette du prochain paquet Windows à
confirmer sur la cible ; aucun développement Android ni changement de version majeure.
