# Interface Éditorial validée pour le Lot 4

**Dernière révision validée par l’utilisateur le 25 octobre 2026**, après les
ajustements des commandes de fenêtre, des cadres documentaires, de la lettrine
et des Paramètres. Cette version remplace la maquette précédemment validée et constitue la
référence visuelle et interactive pour le Lot 4 (GUI Windows), avec une déclinaison
mobile et deux apparences, claire et sombre. Cette validation porte sur la maquette ;
elle ne constitue pas une validation d'une distribution Windows ou Android.

## Ouvrir le HTML

Ouvrir [maquettes.html](maquettes.html) dans un navigateur récent (Edge, Chrome ou
Firefox). Aucun serveur, installation, compte ou accès Internet n'est nécessaire.
Depuis GitHub, télécharger le fichier avec **Download raw file**, puis ouvrir le
fichier `.html` localement : la page de code de GitHub ne rend pas cette interface.

Le HTML est autonome : styles, interactions JavaScript et catalogue sont intégrés.
Il ne charge ni police distante, bibliothèque JavaScript, image ou fichier audio.
L'apparence se choisit dans **Paramètres → Apparence**. Pour démarrer directement
en sombre dans une copie du HTML, ajouter `data-theme="dark"` à la balise `body`.

## Comportements utilisables

- Catalogue de 716 épisodes : recherche dans les champs sélectionnés (titre, résumé,
  sources, musiques), tri alphabétique/date dans les
  deux sens et filtres par statut d'écoute ; navigation Bibliothèque/Favoris.
- Fiche avec onglets Résumé, Sources et Musiques ; références et morceaux dans
  des cadres séparés, avec libellés distincts des valeurs. Les sources conservent
  leurs 1 896 références et les musiques leurs 614 morceaux. Le nom de la référence
  ou du morceau est l’en-tête du cadre ; les lignes Référence et Morceau ne sont
  pas répétées. Un nom de morceau vide affiche « Aucune donnée ».
- Épisodes connexes cliquables avec titre et date côte à côte, sans bouton de retour à une fiche précédente. `data-original-name` et `data-episode-id` conservent les identités
  techniques sans afficher le nom historique `.mp3`.
- Boutons Écouté/Non écouté et Favori, indépendants de la disponibilité audio.
  Retour à Non écouté après confirmation, avec remise à zéro de la progression.
- Épisodes écoutés distingués ; épisodes sans MP3 sur fond gris et texte atténué,
  avec « MP3 absent » en rouge adapté à chaque thème.
- Logo au-dessus de Bibliothèque, aucun bandeau de présentation ; réglage de thème
  dans Paramètres. « Épisodes connexes » utilise la couleur des autres libellés.
- Lecteur compact : titre puis date, temps écoulé/durée, position réglable,
  lecture/pause, arrêt, précédent/suivant, sauts de 15 secondes, volume/muet,
  aléatoire et répétition (non/épisode/tout).

## Simulation et limites

Les disponibilités MP3, écoutes et favoris sont **fictifs**. Les chemins et modifications
restent en mémoire pendant la session ; recharger la page rétablit les états de
présentation. Aucune donnée personnelle de l'application n'est lue ou modifiée.

Le lecteur **ne lit aucun audio** : sa durée de 38 min 20 s et son volume sont
illustratifs. Le compteur et la progression simulent une écoute, et le statut
évolue automatiquement à son début et à sa fin. L'arrêt remet le curseur à zéro
sans retirer le statut écouté. Consulter une fiche ne remplace pas l'épisode du lecteur.
Précédent/suivant suivent le tri courant du catalogue parmi les MP3 marqués présents ;
l'aléatoire évite l'épisode courant quand plusieurs candidats sont disponibles.
La répétition règle l'enchaînement en fin de simulation.

La recherche HTML combine les termes dans les champs cochés ; elle ne remplace
pas le moteur FTS5 Dart ni son classement. Au moins un champ est requis.
Les chemins du démarrage et des Paramètres sont saisis comme exemples, sans
vérification d’accès ni écriture. Le scan est simulé. Le menu Fichiers est un
emplacement visuel : sélection réelle de MP3, associations,
résolution d'anomalies et suivi persistant restent à raccorder dans l'application.
Paramètres contient les entrées Renommage des MP3, Exporter le suivi JSON et
Importer et fusionner un suivi JSON. Ces boutons ouvrent des aperçus de parcours
pour les Lots 5 bis/5 ter, sans renommage, export ou import réel.

## Actualiser le catalogue intégré

Depuis la racine, avec Python 3.10+ (bibliothèque standard seulement) :

```sh
python3 tools/ui/build_mockup.py
```

Le script lit `assets/catalogue.sqlite` en lecture seule et remplace uniquement
le bloc JSON `catalogue-data` du HTML. Il conserve les identifiants des épisodes
connexes, refuse les références absentes, ne modifie pas les TXT/CSV/MP3 et n'ajoute
aucune donnée personnelle. Une deuxième exécution donne le même fichier.
Le JSON est séparé du code d'interaction, tout en restant dans le même HTML.

## Vérifications

Contrôles exécutés dans **Chromium sous Linux**, le 25 octobre 2026 :

- catalogue, tris/filtres et recherche ; cadres sources/musiques, navigation liée,
  titres et dates visibles, noms MP3 masqués ;
- écoute/favori, confirmation/annulation, évolution automatique du statut simulé ;
- lecture/pause/arrêt, compteur, sauts/position, précédent/suivant, aléatoire,
  répétition/enchaînement et volume/muet ;
- apparence dans Paramètres sans perte de la fiche ni de la lecture ; contrastes
  des textes de liste vérifiés en sombre (au moins 4,5:1) ;
- au moins dix épisodes et lecteur visibles à 1440 × 900, lecteur compact,
  pas de débordement horizontal à 390 × 844 ;
- fonctionnement du fichier autonome sans requête réseau, aucune erreur JavaScript.

Ces contrôles ne remplacent pas la recette Windows/Android des futurs packages.

## Ajustements validés — 25 octobre 2026

- Commandes de fenêtre en haut à droite sur ordinateur : réduire/restaurer,
  agrandir/restaurer et fermer/rouvrir l'aperçu. Elles agissent seulement sur le
  cadre HTML ; elles ne ferment pas l'onglet du navigateur. Masquées sur mobile.
- Logo suivi de « Recherche et écoute de Rendez-Vous avec X ».
- Bouton Fiche précédente supprimé. Les épisodes connexes restent cliquables.
- Titres des références et morceaux en tête de cadre, avec la typographie et la
  couleur des anciens en-têtes Source/Musique. Les lignes Référence et Morceau
  sont supprimées ; les autres champs sont conservés. Si le nom du morceau est
  vide, l’en-tête affiche « Aucune donnée ».
- Fond d'Épisodes connexes identique à celui des libellés Auteur/Éditeur.
- Lettrine de résumé : police du titre de la fiche et couleur de l'onglet Résumé.
  Le titre du lecteur reprend également cette police.
- Aperçus des parcours de renommage et de transfert manuel du suivi dans Paramètres.

Ces ajustements ont été contrôlés dans Chromium en clair et sombre : noms des
cadres et valeur de repli, lettrine et couleurs, commandes de fenêtre, paramètres,
liens connexes, lecteur, dix lignes visibles sur ordinateur et largeur mobile,
sans requête réseau ni erreur JavaScript. La régénération du catalogue conserve
les modifications de présentation.

## Portée de la validation pour le développement

La présente validation couvre la structure, les deux thèmes, les règles de
présentation et les interactions démontrées dans ce HTML. Elle complète le cahier
des charges V1.4 et les décisions techniques ; les règles métier de durabilité,
d'association et de sécurité continuent de s'appliquer.

Pour le Lot 4, utiliser cette révision comme référence de la GUI Windows, en
raccordant le catalogue SQLite/FTS5 et les parcours prévus par ce lot. Le lecteur
réel et Android restent au Lot 5 ; le renommage réel au Lot 5 bis ; le transfert
JSON avec fusion réelle au Lot 5 ter. Les entrées correspondantes dans Paramètres
fixent leur emplacement et leur parcours, sans annoncer ces fonctions comme livrées.
La validation de la maquette ne lance pas, à elle seule, le développement du Lot 4.

## Compléments Windows du 25 octobre 2026

Les [spécifications complémentaires du Lot 4](../lot4/specifications.md) consignent
les nouvelles exigences : archive portable sans installateur, dossier dédié aux
données utilisateur, premier démarrage, report explicite du dossier MP3 et demande
renouvelée aux ouvertures suivantes, visibilité de l'absence de dossier, sauvegarde
avant fermeture et protection contre les arrêts brutaux.

Le HTML ouvre une fenêtre de démarrage : dossier utilisateur exigé, et dossier MP3
ou case « Préciser le dossier MP3 plus tard ». Les chemins sont fictifs dans
la maquette. La croix capture un instantané en mémoire avant de fermer l'aperçu ;
Rouvrir IndeX redemande les MP3 s'ils sont toujours non configurés. Un rafraîchissement
du navigateur revient au premier démarrage : aucun suivi n'est écrit sur disque.
Le dossier non configuré est distingué d'un fichier absent après scan.

Les Paramètres reprennent les deux chemins. Le renommage explique la conversion
exclusive nom historique → nom système du catalogue. Le transfert décrit les
données incluses/exclues ; son aperçu d'export affiche un chemin dans `exports/`
sous le dossier utilisateur et un nom daté sans espaces. Aucun JSON réel n'est créé.

Les choix des champs de recherche sont manipulables, avec titres, résumés, auteurs,
éditeurs et musiques. Le moteur natif devra recevoir cette sélection lors du
raccordement de l'interface : l'API Dart actuelle ne la propose pas encore.

Contrôles Chromium effectués : formulaire obligatoire/report, réouverture simulée,
conservation du dossier utilisateur en session, configuration des dossiers dans
Paramètres, recherche multi-champ, absence de faux « MP3 absent » sans dossier,
chemin d'export sans espaces dans son nom, thèmes, dix lignes visibles et largeur
mobile, sans requête réseau ni erreur JavaScript.

### Raccourci réservé aux tests HTML

Dans la fenêtre de démarrage, cocher **« Test HTML uniquement : ignorer la saisie
des dossiers et ouvrir la maquette »** ferme immédiatement la fenêtre, sans
exiger de chemin. Ce raccourci dispense du rappel au redémarrage simulé pour la
session courante. Recharger la page rétablit le formulaire normal. Les chemins
restent vides s'ils n'ont pas été saisis : aucun faux dossier n'est créé. Le mode
de test affiche des disponibilités fictives, comme après un scan, pour retrouver
les exemples de couleurs (présents, absents, écoutés) et manipuler le lecteur.
L'indication « disponibilités MP3 — données simulées » distingue cet aperçu du
parcours normal sans dossier MP3, qui conserve son avertissement et la lecture désactivée.

La case est repérée par `data-html-test-only` et **doit être exclue du livrable
Windows/Android**. Elle ne modifie pas l'exigence de dossier utilisateur obligatoire
pour l'application réelle. Le parcours normal reste disponible en ne la cochant pas.

### Disposition des réglages et recherche

Dans Paramètres, l'ordre est **Apparence → Dossiers → Transfert du suivi → Fichiers audio**.
La sélection des champs de recherche est placée immédiatement sous le champ de
saisie ; le tri et le filtre d'écoute restent sous Bibliothèque. Cette disposition
et les couleurs de démonstration sont communes aux thèmes clair et sombre.
Enregistrer des dossiers explicitement quitte le mode de disponibilités fictives
activé par le raccourci HTML et rétablit le parcours normal de configuration.

Les quatre groupes de Paramètres (Apparence, Dossiers, Transfert du suivi, Fichiers
audio) sont chacun encadrés. Deux boutons Fermer identiques, en haut à droite et
en bas, ferment la même fenêtre. Le champ de recherche et la sélection des champs
sont réunis dans un cadre, avec un espace sous les filtres avant Bibliothèque.
Ces dispositions sont communes aux deux thèmes et vérifiées dans Chromium, avec
dix épisodes visibles à 1440 × 900 et sans débordement à 390 × 844.

La case **« Préciser le dossier MP3 plus tard »** est réservée au démarrage initial
et aux démarrages suivants sans dossier MP3 configuré. Elle n'apparaît pas dans
Paramètres : le champ de chemin reste modifiable, et le laisser vide retire la
configuration sans supprimer le suivi.

Le tri propose aussi **MP3 disponibles d'abord** et **MP3 absents d'abord**.
Ces options conservent tous les épisodes, les regroupent par disponibilité et
classent chaque groupe par date décroissante, puis identité stable. Sans dossier
configuré ni mode de test, la disponibilité reste inconnue et le tri revient à
la date décroissante, sans annoncer de fausses absences.
