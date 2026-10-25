# Lot 4 — GUI Windows portable

Date : **25 octobre 2026**. Code implémenté et contrôlé sur Linux ; **construction
et recette Windows non exécutées sur cet hôte**. Le Lot 4 ne doit pas être déclaré
qualifié sur Windows tant que le workflow natif et la recette du paquet n'ont pas réussi.
Le lecteur audio réel et Android restent au Lot 5 ; renommage et JSON aux Lots 5 bis/5 ter.

## Livrable et comportement

L'application Flutter est dans [apps/index_windows](../../apps/index_windows/README.md),
le cœur Dart demeure séparé. L'interface reprend la maquette Éditorial validée :
logo/sous-titre, thèmes clair et sombre, liste compacte, recherche encadrée avec
sélection des champs, tris date/titre/disponibilité, favoris et statuts, fiche à
onglets et références/musiques dans des cadres. Les titres sont les en-têtes des
cadres ; les épisodes connexes sont cliquables avec leur date, sans nom historique
exposé. Résumé avec initiale agrandie et police de titre reprise par la zone lecteur.

Le premier démarrage exige le dossier des données et demande les MP3 ou la case
« Préciser le dossier MP3 plus tard ». Cette case est absente de Paramètres et
aucun contournement HTML n'existe dans l'application. Sans dossier MP3 configuré,
le choix revient au lancement et l'avertissement reste visible. Un dossier connu
est rescanné à l'ouverture ; dossier inaccessible et scan incomplet sont distingués.

Le catalogue intégré est chargé depuis le SQLite seul, avec empreinte vérifiée,
import dans la base de travail et recherche FTS5. Aucun TXT/CSV/MP3 externe requis.
Les fichiers audio sont scannés en lecture seule ; matching et diagnostics des
Lots 1–2 sont utilisés. Le menu Fichiers présente le résultat, les conflits et
permet une association manuelle après choix et confirmation, sans fabriquer une
preuve ID3. Les choix manuels restent protégés au réimport.

Les favoris, statuts et réglages sont persistés immédiatement. Le retour à Non
écouté exige confirmation. La croix et Alt+F4 sont interceptés : attendre les tâches
en cours, produire une sauvegarde cohérente, puis fermer. Une erreur conserve la
fenêtre avec Réessayer/Annuler. Les contrôles de lecture sont identifiés comme
prévus au Lot 5, sans fausse simulation d'audio dans l'application.

## Architecture et stockage

- `PortableSession` (`index_desktop.dart`) : pointeur portable, verrou exclusif,
  base utilisateur, recherche et suivi, scans, sauvegarde et copie vers un dossier vide.
- `DesktopEpisode` : modèle de consultation, séparant contenu, suivi et disponibilité.
- `AppModel` : état et opérations asynchrones de la GUI ; chargement, scan et copie
  signalés par progression, interface protégée pendant les mutations longues.
- Widgets Flutter : démarrage, bibliothèque/fiche, Paramètres et rapport de scan.
- `file_selector` : sélecteurs natifs ; `window_manager` : taille, réduction,
  agrandissement et interception des demandes de fermeture.

Schéma de travail **v4** : ajout transactionnel de `local_settings`, sans modifier
les tables personnelles existantes. Le seed versionné reste en **v3**, avec le
même contenu de 716 épisodes ; il est importable dans la cible v4. Les seeds v2/v3/v4
sont reconnus en lecture seule, et un seed v4 avec réglages personnels est refusé.
Les index FTS restent synchronisés par les triggers et les choix par champ sont
ajoutés à `SearchOptions.fields`, avec noms de colonnes fixes et paramètres MATCH.
La pertinence BM25 et les extraits restent ceux du Lot 3. Le tri des titres et la
recherche de fiche pour association manuelle utilisent une clé de présentation
insensible aux accents/casse, sans modifier les identités métier.

Le bootstrap `index-portable.json`, à côté de l'exécutable, contient seulement version
et chemin des données. Base `index-utilisateur.sqlite`, verrous, sauvegardes et
futurs exports restent dans le dossier choisi. Dossier attendu manquant ou
configuration invalide : pas de nouveau profil vide créé silencieusement.
Aucun repli vers AppData/temporaire pour les données personnelles.

Verrou OS exclusif, plus protection des doubles ouvertures dans le même processus.
Scans et import initial tournent dans des isolates sans envoyer de connexion SQLite
ou de handle de fichier entre isolates. La recherche et les petites écritures
transactionnelles restent sur la connexion principale.

La sauvegarde utilise **sqlite3_backup**, en une étape native pour le catalogue
actuel, puis contrôles SQLite/FK/FTS avant publication. Deux générations conservées,
la précédente restant disponible pendant la création de la suivante. Aucun simple
copier/coller du `.sqlite` ouvert en ignorant son WAL. Les mutations favorites/statuts
committent au fil des actions ; la robustesse ne dépend pas seulement de la croix.

Le déplacement des données copie la base par backup et les sauvegardes/exports,
refuse une destination occupée ou située dans le dossier source, conserve l'ancien
dossier et ne change le pointeur qu'après contrôle de la destination. Pas de suppression
automatique d'une destination partielle en cas d'erreur. Le lecteur/checkpoint de
progression toutes les cinq secondes reste à intégrer au Lot 5.

## Dépendances et distribution

Flutter **3.47.7** et Dart **3.13.5**, package cœur 0.4.0, application 0.4.0+1.
Dépendances directes ajoutées : `file_selector` **1.1.0** (BSD-3-Clause),
`window_manager` **0.5.2** (MIT), Flutter/localisations SDK. Tests Flutter et
integration_test du même SDK. Archives directes vérifiées par SHA-256 et licences
conservées dans [dependances.json](dependances.json). Toutes les résolutions natives
et transitives sont épinglées dans le lockfile de l'application.

L'asset Flutter est préparé par `tools/lot4/prepare_assets.py` depuis le seed unique
à la racine, après contrôle de son empreinte. Copie générée ignorée par Git : pas de
second catalogue source à maintenir. Les assets embarqués utilisent des chemins
internes simples `assets/catalogue.sqlite`, sans sortir du répertoire du bundle.

`package_windows.ps1` construit une archive **portable sans installateur**, avec
DLL et runtime Microsoft C++ app-local, notices, mode d'emploi et manifeste SHA-256.
Il refuse les MP3 et données personnelles et n'écrase pas une archive existante.
Le dossier de l'exécutable doit être inscriptible pour le pointeur portable.
Le script exige PowerShell 7, Python et Visual Studio C++ pour **construire** ;
les utilisateurs du paquet extrait n'ont pas besoin de Flutter, Python ou Visual Studio.

## Vérifications exécutées

Sur cet hôte Linux x64 :

```sh
. /workspace/toolchains/activate-flutter.sh
bash tools/lot4/check.sh
```

Résultats : **174 tests Dart + 6 tests Flutter réussis**, formatage conforme et
analyses statiques sans problème. Les tests Flutter exécutent bien SQLite natif
et chargent le seed via le bundle, au-delà d'un rendu de données fictives.

Couverture ajoutée :

- choix des champs FTS, exclusion des champs non sélectionnés, termes répartis,
  source/auteur et musique, champ vide refusé ;
- catalogue complet sans sources externes, favoris/statuts/réglages après fermeture
  et réouverture, confirmation de reset ;
- backup WAL avec contrôle et deux générations, échec de backup bloquant la fermeture,
  maintien des données modifiables et nouvelle tentative ;
- absence de base attendue, empreinte/configuration invalides, verrous de même processus
  et d'un second processus ;
- scan natif des six MP3 réels, changement de dossier et indisponibilité sans perte
  des liens/favoris ;
- copie de base, sauvegardes et exports, destination occupée refusée et ancien dossier conservé ;
- widgets de démarrage sans case HTML, bibliothèque, sources, favoris, recherche,
  Paramètres, et fermeture GUI empêchée en cas d'erreur puis réussie après réparation ;
- modèle de démarrage : demande MP3 répétée, configuration invalide sans profil vide,
  scan réel au lancement et état d'indisponibilité.

Les tests précédents d'import interrompu/SIGKILL, migrations et génération
reproductible continuent de réussir. Le SIGKILL POSIX reste ignoré sous Windows.

## Porte de validation Windows restante

Le [workflow Windows](../../.github/workflows/windows.yml) est préparé, non exécuté ici :

1. Tests du cœur et widgets sur Windows-2022 avec SDK épinglé.
2. Test d'intégration natif : chargement du seed, FTS5, six MP3 du dépôt, suivi et
   réouverture, interception réelle WM_CLOSE par le plugin.
3. Build Release, archive x64 portable avec runtime app-local et notices.
4. Extraction dans un dossier temporaire, lancement du premier démarrage et fermeture
   via demande Windows, vérification de l'absence de profil créé sans choix utilisateur.
5. Conservation de l'archive et de son SHA-256 comme artefact CI après succès.

Le workflow pourra s'exécuter après commit/push. **Aucune archive Windows construite,
aucun test Windows/Android exécuté ni recette utilisateur sur machine Windows propre
ne sont revendiqués.** Les scripts PowerShell n'ont pas été exécutés sur cet hôte Linux.

À compléter sur le paquet Windows précis : sélecteurs natifs avec annulation/permissions,
stockage amovible, arrêt forcé Windows pendant import, fermeture avec disque plein,
contrastes/zoom/DPI, fonctionnement hors ligne sur machine sans toolchain et
reprise d'une copie de données en erreur. Cette recette conditionne la qualification
du livrable Windows ; elle n'est pas remplacée par les 180 tests Linux.
