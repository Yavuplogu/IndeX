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

Au premier démarrage, choisir un **dossier dédié aux données utilisateur**, obligatoire.
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
3. Le dossier des données utilisateur, obligatoire.

L'utilisateur peut quitter avant de terminer. Le catalogue reste entièrement
consultable sans MP3 une fois le dossier utilisateur validé.

Si un dossier MP3 est fourni, lancer le scan et les concordances avec les règles
de la [règle du 26 octobre 2026](../regle-association-noms-journal.md) : noms du
journal uniquement, sans lire COMM, conflits signalés, aucune
modification de nom ou de tag. Montrer progression/résultat, erreurs et accès refusés.
Une indisponibilité ou un scan incomplet ne supprime pas les liens ni le suivi.

À **chaque ouverture ultérieure**, tant que le dossier MP3 n'est pas configuré,
représenter la sélection avec la même case de report. Conserver le dossier utilisateur
connu ; ne pas redemander de créer des données. La case ne dispense que pour
l'ouverture en cours. Si le dossier est configuré mais inaccessible, signaler
l'indisponibilité ; ne pas le traiter comme un dossier jamais configuré.

Afficher durablement **« Aucun dossier MP3 paramétré »** dans la bibliothèque,
les fiches, le lecteur et les autres fenêtres concernées. Distinguer :

- Dossier non configuré : disponibilité audio inconnue, lecture impossible.
- Dossier configuré, MP3 non trouvé : « MP3 absent », rouge et ligne grisée.
- Dossier configuré mais inaccessible : avertissement d'accès, pas de faux scan vide.

Ces chemins et la possibilité de scanner/changer le dossier sont accessibles
également dans **Paramètres**. Un dossier MP3 peut être retiré sans effacer le suivi.

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
IndeX_suivi_20261025T143000Z_a1b2c3d4.json
```

Le timestamp UTC sert à nommer le fichier, pas à résoudre les conflits. Ajouter un
suffixe unique et créer sans écraser un export existant ; écrire temporairement
puis publier après validation. Afficher le chemin final et permettre d'ouvrir son
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
