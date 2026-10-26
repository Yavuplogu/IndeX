# Lot 4 — GUI Windows portable

Date : **26 octobre 2026**. Code implémenté et contrôlé sur Linux. Les derniers
logs Windows (`logs_109499819369.zip`) valident les tests du cœur, mais deux tests
Flutter attendent des chemins à séparateurs mélangés. Les chemins affichés sont
bien décodés avec espaces et séparateurs natifs. Les attentes sont corrigées ;
une nouvelle exécution Windows est nécessaire avant qualification du paquet.
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
Les fichiers audio sont associés par noms du journal courant, sans lire COMM,
selon la [règle du 26 octobre](../regle-association-noms-journal.md). Le menu Fichiers présente le résultat, les conflits et
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
les tables personnelles existantes. Le seed versionné est désormais en **v4**, actualisé le 26 octobre depuis les
sources `f126478`, avec 716 identités conservées et les noms corrigés. Les seeds v2/v3/v4
sont reconnus en lecture seule, et un seed v4 avec réglages personnels est refusé.
Les index FTS restent synchronisés par les triggers et les choix par champ sont
ajoutés à `SearchOptions.fields`, avec noms de colonnes fixes et paramètres MATCH.
La pertinence BM25 et les extraits restent ceux du Lot 3. Le tri des titres et la
recherche de fiche pour association manuelle utilisent une clé de présentation
insensible aux accents/casse, sans modifier les identités métier.

Le bootstrap `application/index-portable.json` contient seulement version
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

Résultats : **184 tests Dart + 13 tests Flutter réussis**, formatage conforme et
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

Le [workflow Windows](../../.github/workflows/windows.yml) est préparé pour les étapes
ci-dessous. Sa première exécution, rapportée par les logs utilisateur, a échoué
dans les tests du cœur ; voir le diagnostic à la fin de ce bilan :

1. Tests du cœur et widgets sur Windows-2022 avec SDK épinglé.
2. Test d'intégration natif : chargement du seed, FTS5, six MP3 du dépôt, suivi et
   réouverture, interception réelle WM_CLOSE par le plugin.
3. Build Release, archive x64 portable avec runtime app-local et notices.
4. Extraction dans un dossier temporaire, lancement du premier démarrage et fermeture
   via demande Windows, vérification de l'absence de profil créé sans choix utilisateur.
5. Conservation de l'archive et de son SHA-256 comme artefact CI après succès.

Les logs successifs ci-dessous documentent la progression réelle du workflow.
Les derniers logs valident les 183 tests du cœur exécutables sous Windows (1 ignoré),
puis échouent sur deux comparaisons de chemins dans les tests Flutter.
**Aucun paquet Windows qualifié ni validation Android ne sont encore revendiqués.**
Les chemins de test sont désormais construits avec les séparateurs de la plateforme ;
les tests Flutter, la recette native et l'empaquetage restent à rejouer sous Windows.
Le workflow conserve les diagnostics disponibles en cas d'échec.

À compléter sur le paquet Windows précis : sélecteurs natifs avec annulation/permissions,
stockage amovible, arrêt forcé Windows pendant import, fermeture avec disque plein,
contrastes/zoom/DPI, fonctionnement hors ligne sur machine sans toolchain et
reprise d'une copie de données en erreur. Cette recette conditionne la qualification
du livrable Windows ; elle n'est pas remplacée par les 197 tests Linux.

## Première exécution Windows — diagnostic des logs

L'archive `logs_108969435751.zip`, fournie par l'utilisateur le 25 octobre 2026,
porte sur le commit `7fcd5b5`. Le SDK est installé et l'analyse Dart réussit, puis
les tests du cœur s'arrêtent avec **163 réussites, 1 test ignoré (SIGKILL POSIX)
et 10 échecs**. Les widgets, la recette native et la construction n'ont pas encore
été exécutés par ce workflow ; aucune archive portable n'a été produite.

Les échecs se répartissent ainsi :

- Six contrôles de descriptions TXT et l'extraction exacte du Masque de fer : le
  checkout Windows transforme les fins de ligne LF en CRLF. Les longueurs et les
  octets divergent des fixtures de référence. Ajout de `.gitattributes` avec
  `-text` sur le corpus et les fixtures : les octets doivent être conservés sur
  toutes les plateformes. Aucun hash, TXT, CSV, MP3 ou résultat attendu n'est modifié.
- Deux assertions de chemins : Windows renvoie la forme canonique longue
  `runneradmin` au lieu de l'alias court `RUNNER~1`, avec des séparateurs différents.
  Les tests vérifient désormais l'identité réelle du dossier, pas l'égalité de sa
  représentation textuelle. Le même correctif est appliqué au test du modèle GUI.
- Le test du second processus reçoit un échec non diagnostiqué. Sous Windows,
  l'ouverture du fichier déjà verrouillé peut échouer avant l'appel à `lock`.
  Le processus de contrôle capture les deux étapes, fournit un diagnostic JSON,
  et le test exige le code de refus attendu et ce diagnostic ; un échec arbitraire
  de lancement reste un échec du test, avec stdout/stderr dans le rapport.

Le comportement de checkout a été reproduit avec `core.autocrlf=true` : les six
TXT sont désormais restitués octet pour octet ; un chemin témoin non protégé subit
bien la conversion. Les contrôles Linux du cœur et de l’application ont été rejoués : **174 tests Dart
et 6 tests Flutter réussis**, analyses statiques sans problème.
Une nouvelle exécution Windows reste nécessaire après publication du correctif.

## Deuxième exécution Windows — sonde et hooks natifs

Les logs `logs_108972184764.zip` du commit `6ea5403` montrent **172 réussites,
1 test ignoré et 1 échec**. Les neuf échecs liés aux fins de ligne et aux chemins
ont disparu. Widgets, recette native et construction restent non atteints.

Le diagnostic enrichi du test de verrou montre cette erreur dans le sous-processus :

```text
Running build hooks... PathAccessException: Cannot delete file,
path = '...\.dart_tool\lib\sqlite3.dll' (OS Error: Access is denied, errno = 5)
```

Le script de la sonde n'est pas encore exécuté : `dart run` déclenche les hooks du
projet parent et tente de remplacer la DLL SQLite déjà chargée par les tests.
La capture d'une erreur lors de l'ouverture du verrou, ajoutée précédemment,
ne pouvait donc pas résoudre cette cause, désormais confirmée par les logs.

Correction : copier la sonde, qui dépend uniquement de dart:io/dart:convert, dans
un dossier temporaire sans pubspec et l'y lancer avec un répertoire de travail
isolé. Les dépendances natives du projet ne sont ainsi pas reconstruites par le
sous-processus. Le test continue d'exiger le refus du verrou ; il exige aussi que
la même sonde réussisse après libération, pour distinguer un vrai verrou d'un
échec général d'accès ou de lancement. Aucun test n'est ignoré pour contourner l'erreur.

Le test ciblé, incluant refus puis acquisition, réussit sur Linux. La suite complète
réussit également : **174 tests Dart et 6 tests Flutter**, analyses sans problème.
Une nouvelle exécution Windows reste nécessaire avant qualification.

## Troisième exécution Windows — synchronisation du test de fermeture

Les logs `logs_108975556785.zip` du commit `5a429c4` confirment la réussite de
**tous les tests du cœur : 173 exécutés, 1 ignoré (SIGKILL POSIX)**. La sonde de
verrou isolée réussit. L'analyse Flutter réussit également ; cinq tests Flutter
passent, et seul le scénario de sauvegarde/fermeture échoue.

Le message est `pumpAndSettle timed out`, après le délai fixe de 150 ms au second
essai de fermeture. Le test reprenait son horloge simulée avant la fin des E/S
réelles ; l'indicateur de sauvegarde restait donc actif. Attendre la fin des
animations ne constitue pas une attente fiable de la sauvegarde disque.

Le test attend maintenant les états observables avec une limite de 20 secondes,
en laissant progresser les E/S et les frames de l'interface. Il vérifie toujours :

- dossier de sauvegarde bloqué : erreur affichée, aucune demande de fermeture ;
- après réparation : sauvegarde créée et session fermée avant la demande de destruction ;
- réponse du système de fenêtre retenue par une barrière de test : la fenêtre
  n'est considérée détruite qu'après libération de cette barrière ;
- fermeture finale unique et nettoyage réussi.

Les délais fixes de 50/150 ms ont été supprimés. La logique de sauvegarde de
l'application n'est pas modifiée. Le test ciblé et la suite complète réussissent sur Linux : **174 tests Dart et
6 tests Flutter**, sans problème d’analyse statique. Une nouvelle exécution Windows
doit encore atteindre la recette native et la construction de l’archive.

## Quatrième exécution Windows — création de l'archive portable

Les logs `logs_108978692044.zip` du commit `25a714a` attestent les réussites suivantes :

- tests du cœur (173 exécutés, 1 ignoré), 6 tests Flutter et analyses statiques ;
- recette native Windows : seed, FTS5, persistance/reprise, scan et interception de fermeture ;
- compilation Debug pour la recette, puis **compilation Release de `IndeX.exe`**.

Le script d'archive échoue après la compilation en cherchant :

```text
VC/Redist/MSVC/v143/x64
```

Le tri alphabétique des dossiers avait retenu `v143`, qui ne contient pas ce
runtime x64. Le nouveau résolveur privilégie les dossiers de versions numériques
et ignore tout candidat sans CRT x64 complet. Il exige `vcruntime140.dll`,
`vcruntime140_1.dll` et `msvcp140.dll`, puis copie l'ensemble des DLL du CRT retenu.
Le chemin sélectionné est affiché dans les logs ; l'absence de runtime valide
produit une erreur explicite avec les dossiers contrôlés.

`tools/lot4/test_runtime_windows.ps1` vérifie ce résolveur sur des répertoires
temporaires, sans Pester ni Visual Studio : dossier v143 sans x64, tri 14.10 après
14.9, x86 ignoré, DLL manquantes, sélection du plus récent complet, repli sur un
ancien complet et erreurs de dossiers absents. Ces contrôles ont été exécutés
avec **PowerShell 7.5.4 sur Linux**, ainsi qu'une analyse syntaxique de tous les
scripts PowerShell du Lot 4. Le workflow les lance désormais avant l'installation
du SDK et les étapes de compilation.

Cela ne remplace pas une exécution de l'empaquetage sous Windows. La prochaine
exécution doit encore produire le ZIP, lancer son contenu extrait et publier
l'artefact. Aucune fonction applicative ni fixture du corpus n'est modifiée.

L'analyse syntaxique a aussi révélé deux apostrophes typographiques dans des
chaînes PowerShell entre apostrophes simples de `smoke_archive.ps1`. Ces chaînes
sont corrigées avant que cette étape ne soit atteinte. Le contrôle rapide du
workflow analyse désormais tous les scripts PowerShell, en plus des cas du
résolveur, pour détecter ces erreurs avant la compilation.

## Cinquième exécution Windows — crash à la fermeture du ZIP extrait

Les logs `logs_108982078950.zip` du commit `a41351f` confirment :

- tous les tests exécutés réussissent (173 du cœur, 1 ignoré, 6 Flutter et 1 recette native) ;
- compilation Release et sélection du runtime x64 `14.44.35112` réussies ;
- création de `IndeX_0.4.0_windows_x64_portable.zip` ;
- fenêtre du paquet extrait détectée, demande de fermeture acceptée, puis arrêt
  avec le code **-1073740771**, soit **`0xC000041D`**.

Ce code signale une exception fatale dans un callback Windows. Les logs ne
contiennent ni pile native ni module fautif : l'attribution précise du crash
reste à confirmer. Le test continue de refuser toute sortie non nulle.

Le parcours existant appelait `windowManager.destroy()`, qui envoie directement
`PostQuitMessage(0)` sous Windows. Cela court-circuite la destruction normale de
la fenêtre ; le runner pouvait ensuite libérer COM avant le moteur Flutter et
ses plugins. Le correctif remplace cette sortie forcée par la désactivation de
l'interception de fermeture, puis une demande normale `WM_CLOSE`, uniquement
après validation de la sauvegarde. Le runner appelle également `window.Destroy()`
avant `CoUninitialize()` si la boucle de messages se termine autrement. L'accès
au moteur lors de `WM_FONTCHANGE` est protégé pendant sa destruction.

La fenêtre n'est plus montrée automatiquement par le premier rendu C++ : Dart
l'affiche une fois les options appliquées et le listener de fermeture enregistré.
La recette native affiche explicitement sa fenêtre pour conserver son parcours.
Un test Flutter vérifie l'ordre des appels de fermeture ; les tests existants
continuent de vérifier qu'un échec de sauvegarde empêche de fermer.

Le test du ZIP conserve désormais les sorties du processus, le code de sortie
numérique et hexadécimal, l'étape atteinte et, en cas d'échec, les événements
Windows Application 1000/1001 concernant IndeX lorsqu'ils sont disponibles.
L'artefact `IndeX-windows-diagnostics` est téléversé même en cas d'échec ; cela
ne rend pas le ZIP défaillant admissible comme livrable.

Vérifications exécutées sur Linux : `bash tools/lot4/check.sh` réussit avec
**174 tests Dart et 7 tests Flutter**, formatage et analyses sans problème.
PowerShell 7.5.4 valide la syntaxe de tous les scripts du Lot 4 et les cas du
résolveur CRT. La disparition du crash natif doit encore être vérifiée par une
nouvelle exécution Windows ; aucun résultat local ne la démontre.


## Ajustements de l’interface après essais utilisateur

L’interface Flutter applique les [spécifications complémentaires](specifications.md#ajustements-après-essais-de-linterface-windows) :
fiche en haut, navigation réelle par flèches avec défilement de la sélection,
lettrine sur deux lignes, couleurs et typographie harmonisées, curseurs main
explicites pour Windows, suppression du chemin MP3 redondant, diagnostic
sélectionnable/défilant et export TXT dans le dossier utilisateur.

La recherche de l’application utilise désormais des préfixes FTS5 dès trois
caractères, après 250 ms sans saisie. Aucun changement de schéma ou reconstruction
du seed n’est nécessaire. L’option de préfixe est explicite dans `SearchOptions` ;
le contrat de recherche exacte existant reste disponible pour les autres usages.
Chaque terme reste extrait et cité par le code, les requêtes sont paramétrées et
bornées. Les rubriques et extraits surlignés proviennent de `highlight`/`snippet`
de SQLite, avec marqueurs internes interprétés comme styles de texte, jamais HTML.
Le texte brut des extraits reste disponible séparément.

Le lecteur du Lot 4 reste sans audio. Son libellé ne dépend plus de la fiche
consultée ; la lecture réelle et son contrôleur indépendant restent au Lot 5.

Vérifications locales : **175 tests Dart + 8 tests Flutter**, formatage et analyses
statiques. Le nouveau test du cœur couvre préfixes, accents, rubriques exactes et
syntaxe utilisateur neutralisée. Le test d’interface couvre haut/bas, stabilité
du titre sans sources, seuil de recherche, effacement, indication des rubriques,
curseur main, défilement de 100 diagnostics, export et affichage sombre à 1024 × 740.
La recette visuelle et les interactions natives doivent encore être vérifiées sur
le prochain paquet Windows ; ces tests Linux ne qualifient pas le binaire Windows.


## Nouvelle archive, lettrine corrigée et parcours des correspondances

Le ZIP contient désormais un répertoire `IndeX/`. Seul le lanceur `IndeX.exe`
figure comme fichier à sa racine ; `application/` conserve le bundle Flutter et
ses DLL sans modifier leur disposition interne, `documentation/` contient notices,
licences et manifeste. Le lanceur C++17 utilise le CRT statique MSVC, localise le
programme à partir de son propre chemin (indépendamment du répertoire courant),
attend sa fin et transmet son code de sortie, y compris un crash. Le programme
continue de retrouver ses ressources et son pointeur utilisateur à côté de son
exécutable réel, donc dans `application/`. Les versions antérieures sont décrites
avec une migration manuelle du pointeur dans le mode d'emploi.

CMake minimum 3.15 active la sélection du CRT statique pour le seul lanceur ; le
programme Flutter conserve sa distribution de runtime app-local. Les deux exécutables
partagent l'icône X multirésolution (16 à 256 px). Le workflow contrôle la nouvelle
structure puis démarre le lanceur, identifie son processus enfant pour fermer sa
fenêtre et contrôle les codes de sortie du programme et du lanceur.

Le vide dans le résumé provenait d'une mesure détachée du style hérité : la coupure
pouvait laisser trois lignes étroites, puis un retour incorrect à pleine largeur.
`document_text.dart` mesure et affiche les mêmes `TextSpan`, styles hérités, zoom
et strut. La coupure est prise sur la deuxième ligne mesurée, et une fin de ligne
explicite n'est pas rendue une seconde fois comme ligne vide. La lettrine regroupe
les signes d'ouverture jusqu'au premier caractère alphanumérique. Les cadres des
matchs sont peints d'après les rectangles réels du paragraphe ; ils n'ajoutent
aucun widget en ligne susceptible de modifier le retour des mots.

`EpisodeSearch` indexe les occurrences des champs effectivement affichés, à partir
des mots marqués par FTS5 pour les champs cochés. Le titre, le résumé, les références,
auteurs/éditeurs et les champs musicaux sont concernés. Les noms techniques masqués
ne deviennent pas des occurrences visibles. L'extrait brut reste dans le contrat
de recherche, mais le panneau de la fiche affiche désormais une explication. Les
commandes précédent/suivant restent dans une barre persistante, changent d'onglet
et révèlent le rectangle de l'occurrence active. Les couleurs rouge clair/rouge,
la barre supérieure grisée et les marges hautes sont déclinées dans les deux thèmes.

Vérifications locales : **175 tests Dart et 11 tests Flutter**, analyses et formatage
sans problème. Les tests couvrent les guillemets/apostrophes, chiffres et caractères
composés, deux lignes exactes sous plusieurs largeurs/zoom avec texte conservé,
alignement des trois zones, parcours entre onglets et visibilité du match actif.
Sous PowerShell 7.5.4 sur Linux, la syntaxe des scripts, le résolveur CRT et les
fixtures de disposition/ZIP sont validés ; la copie refuse MP3 et profils utilisateur.
La compilation du lanceur, ses ressources et le lancement natif de l'archive doivent
encore être vérifiés sur Windows. Aucun binaire Windows n'est qualifié par ces tests Linux.


## Exécution `logs_109036839586.zip` — code de sortie non disponible

Les logs du commit `9a22149` confirment sous Windows :

- **174 tests du cœur réussis, 1 test POSIX ignoré, 11 tests Flutter réussis** ;
- recette d'intégration native réussie ;
- compilations Debug/Release, dont le nouveau lanceur, réussies ;
- runtime Microsoft x64 sélectionné et nouvelle archive `IndeX/` créée ;
- fenêtre du programme enfant détectée et demande de fermeture aboutie.

L'étape suivante échoue sur `smoke_archive.ps1:46` avec **« Fermeture avec erreur : »**,
sans code numérique. Le test compare `$null` à zéro, ce qui échoue. Ces logs
n'établissent donc pas un nouveau crash `0xC000041D`, ni une fermeture propre :
le code de sortie du programme n'est simplement pas disponible dans cet objet
`Process`. L'artefact de diagnostics est bien conservé par le workflow.

Le script récupérait le processus enfant avec `Get-Process` après lancement par
le lanceur. Sous Windows, il faut ouvrir et conserver son `Handle` pendant que
le processus est vivant pour pouvoir interroger sa sortie après sa disparition.
`Get-TrackedProcess` réalise cette acquisition ; le handle est libéré après la
rédaction du rapport. Le lanceur conserve également un handle explicite.
`Get-RequiredExitCode` refuse tout code absent et tout processus encore actif :
aucune conversion de `$null` en zéro, aucun recours au code du lanceur pour ignorer
celui de l'application. Les codes nuls/non nuls et leur égalité restent contrôlés.
Le rapport ne présente plus `0x00000000` si le code numérique manque.

Le nouveau test PowerShell lance deux vrais processus témoins, les récupère avec
un objet `Process` indépendant, libère l'objet d'origine puis déclenche leur sortie
par un fichier témoin. Après `WaitForExit` et `Refresh`, les codes **0 et 7** doivent
rester lisibles. Un processus actif et un code absent sont refusés. Sous Windows,
un troisième témoin vérifie aussi le code négatif `-1073740771` (`0xC000041D`).
Le workflow exécute ce test avant l'installation du SDK.

Vérifications exécutées sous **PowerShell 7.5.4 sur Linux** : tests des processus
(0/7, refus actif/absent), tests de disposition/ZIP et résolveur CRT, analyse syntaxique
de tous les scripts du Lot 4. Aucun code applicatif, fichier source documentaire ou
seed n'a changé. Le cas natif négatif et la fermeture du paquet complet restent
à vérifier lors de la prochaine exécution Windows.


## 26 octobre — catalogue actualisé et suppression de COMM dans l'association

Avant la modification du moteur, les sources de `main` au commit `af6c1a8` ont été
vérifiées et le seed régénéré sous `corpus-2026-10-26-noms-journal` (schéma v4).
Les huit corrections demandées sont présentes, dont les doubles points avant
extension. Intégrité SQLite et FTS contrôlées ; les 716 identités n'ont pas changé.
Le rapport compte 30 avertissements et une fiche à vérifier, sans erreur ni
quarantaine : une divergence supplémentaire du nom TXT des Hmongs du Laos est
conservée sans modifier les sources. Voir la [règle actuelle](../regle-association-noms-journal.md).

Un essai réel d'import de l'ancien seed v3 vers la base de travail v4, puis du
nouveau seed, a donné **0 insertion, 9 mises à jour et 707 fiches inchangées**,
avec identité des 716 épisodes, choix manuel, favori, statut et position conservés.
L'index FTS est resté cohérent. Le bundle Flutter a été préparé depuis le nouveau
seed et son empreinte actualisée.

Le scan ne lit plus les tags ; seuls les noms complets du journal courant sont
utilisés, d'abord FICHIER MP3 D'ORIGINE puis TITRE SYSTEME. NFC/casse seulement,
aucune recherche approximative par titre. Les conflits au premier niveau ne sont
pas contournés ; les doublons locaux sont refusés. Les anciens alias système sont
conservés pour audit mais ne participent plus aux concordances. Les parseurs ID3
et l'oracle Mutagen restent des outils d'audit indépendants.

Les choix manuels sont retirés de la recherche automatique et préservés, avec
rapports reflétant les décisions réellement stockées. Au scan complet, les anciens
liens automatiques sans concordance sont désactivés ; une réattribution certaine
est auditée sans déplacer ni effacer de suivi. Le scan incomplet préserve les liens
et ne valide aucune nouvelle association automatique. Tous les liens par nom sont
marqués NON_VERIFIEE pour le contenu audio, indépendamment du statut ID3 historique.

Vérification locale : **184 tests Dart et 11 tests Flutter réussis**, formatage et
analyses sans problème. Couverture : vrais fichiers temporaires avec langue COMM
invalide, paire contradictoire ou ID3 tronqué ; nom inconnu malgré une paire COMM
valide ; égalité NFC/casse, ponctuation/espaces stricts ; doublons et ambiguïtés ;
liens manuels, anciens liens COMM réévalués, réaffectation sans transfert du suivi,
scan incomplet ; huit noms dans le seed et six MP3 réels associés par nom système.
La compilation/recette du nouveau paquet Windows reste à exécuter sous Windows.


## 26 octobre — correction du TXT des Hmongs du Laos intégrée

Le commit utilisateur `e730f77` renomme le TXT en
`2003-10-25 Les Hmongs du Laos et la C.I.A..txt`. Le titre, la date, l'identifiant
historique et les noms attendus dans le journal concordent. Les octets du fichier
corrigé sont intégrés sans retouche dans le seed **`corpus-2026-10-26-noms-journal-r2`**,
avec manifeste, rapport et copie Flutter actualisés.

L'avertissement `journal_txt_name_mismatch` et le marquage de fiche à vérifier
ont disparu : **716 épisodes, 29 avertissements historiques, aucune erreur,
quarantaine ou fiche à vérifier**. Les identités restent inchangées. Le test des
noms corrigés couvre désormais les neuf fichiers, dont les Hmongs ; les constats
précédents de 30 avertissements décrivent la révision avant cette correction.


## 26 octobre — seed r3, compteurs et défilement de fiche indépendant

Les sources `f126478` actualisent Le colonel B. (11/11/2000) et L'affaire L.
(21/04/2001), avec les noms TXT et MP3 système à double point. Le seed
**`corpus-2026-10-26-noms-journal-r3`** et le bundle Flutter sont régénérés.
Comparaison avec le seed r2 : seules ces deux fiches changent, les 716 identités
restent identiques. 716 épisodes, 29 avertissements historiques, aucune erreur,
quarantaine ou fiche à vérifier. Le test des noms corrigés couvre les onze fichiers.

Le compteur utilise le nombre visible à gauche et les MP3 associés disponibles
dans tout le catalogue à droite, plus les absents après vérification complète.
Le diagnostic décode les URI de fichiers pour affichage et export TXT uniquement,
sans modifier les clés de liens. Les cartes sélectionnables ont le fond des
Paramètres et placent les fichiers avec « Associer… » en premier.

La hauteur fixe de `SliverPersistentHeader` réservait plus d'espace que ses boutons,
d'où le vide sous les onglets. Elle est supprimée. Une zone d'en-tête à hauteur
naturelle et une zone de données défilante ont désormais des contrôleurs distincts.
Les mêmes rectangles de correspondances révèlent la cible dans le viewport des
données ; titre et onglets restent fixes. Un plafond de 70 % pour l'en-tête permet
son défilement manuel à fort zoom/petite fenêtre et garde de la place aux données.

La palette des correspondances et des commandes reprend le fond des Paramètres
et l'encre primaire du thème utilisée par le X. Chaque bouton a son propre fond,
sans fond rectangulaire derrière leur rangée. Libellés et explication sont actualisés.
Les épisodes connexes utilisent un survol rectangulaire ; leurs dates reprennent
explicitement `bodyMedium` et la couleur d'état de la liste, à taille inchangée.

Vérifications : **184 tests Dart et 13 tests Flutter**, analyses et formatage.
Les régressions vérifient l'absence d'espace réservé sous les onglets, la stabilité
du titre et des onglets pendant la navigation, les couleurs, les compteurs globaux
malgré les filtres, les chemins avec espaces (sans altérer les URI), le listing
sélectionnable/trié et l'accès au bouton d'association dans les deux apparences.
La recette native du nouveau paquet Windows reste à exécuter sous Windows.


## Exécution `logs_109499819369.zip` — séparateurs dans les chemins attendus

Les logs du commit `ea1cb26` confirment **183 tests Dart réussis et 1 test POSIX
ignoré** sous Windows. Deux tests Flutter échouent, les 11 autres réussissent :

- `Compteurs MP3 globaux indépendants des filtres et chemins lisibles` ;
- `Rapport : fichiers à associer en premier, texte copiable et chemins lisibles`.

Les tests construisaient un objet `File` à partir de `${root.path}/dossier avec
espaces/...` : sous Windows, la racine temporaire contient des antislashs et le
suffixe ajouté des slashs. `File.absolute.path` garde cette forme mélangée.
L'affichage reconstruit depuis l'URI fournit au contraire les séparateurs Windows
natifs, tout en décodant correctement les espaces. La comparaison textuelle et la
recherche de widget échouaient donc sur les séparateurs, pas sur le décodage.
Le test du nom contenant littéralement `%20` avait la même construction à corriger.

Les trois chemins attendus sont désormais assemblés avec `Platform.pathSeparator`.
Les assertions restent strictes : chemin complet, espaces présents, pourcentage
littéral conservé, export lisible et URI technique inchangée. Aucun fichier source,
seed, module applicatif ou comportement d'association n'est modifié.

Vérifications locales : analyse Flutter sans problème, formatage conforme et
**13 tests Flutter réussis** sous Linux. Cette correction des attentes doit encore
être exécutée sous Windows ; le workflow précédent s'est arrêté avant la recette
native et la construction de l'archive du commit concerné.
