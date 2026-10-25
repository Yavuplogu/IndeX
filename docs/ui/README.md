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

- Catalogue de 716 épisodes : recherche de titre, tri alphabétique/date dans les
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

Les disponibilités MP3, écoutes et favoris sont **fictifs**. Les modifications
restent en mémoire pendant la session ; recharger la page rétablit les états de
présentation. Aucune donnée personnelle de l'application n'est lue ou modifiée.

Le lecteur **ne lit aucun audio** : sa durée de 38 min 20 s et son volume sont
illustratifs. Le compteur et la progression simulent une écoute, et le statut
évolue automatiquement à son début et à sa fin. L'arrêt remet le curseur à zéro
sans retirer le statut écouté. Consulter une fiche ne remplace pas l'épisode du lecteur.
Précédent/suivant suivent le tri courant du catalogue parmi les MP3 marqués présents ;
l'aléatoire évite l'épisode courant quand plusieurs candidats sont disponibles.
La répétition règle l'enchaînement en fin de simulation.

La recherche HTML filtre les **titres** ; elle ne remplace pas le moteur FTS5 Dart.
Le menu Fichiers est un emplacement visuel : sélection réelle de MP3, associations,
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
