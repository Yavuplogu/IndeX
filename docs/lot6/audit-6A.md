> Actualisation du 5 novembre 2026 : décision utilisateur de remplacer
> `fr.index.index_windows` par `fr.index.app` avant distribution durable.
> Les identifiants et résultats de compilation ci-dessous sont historiques.

# Lot 6A — Audit et décisions Android

Lancé explicitement le 1er novembre 2026. Le périmètre de cette étape est la
compilation, les décisions et la préparation de la preuve sur appareil réel.
La validation utilisateur des étapes successives reste prévue par le plan Lot 6.
Windows validé par l’utilisateur est conservé ; aucune Release n’est publiée.

## Décisions de plateforme

- Réutiliser l’application Flutter et le cœur Dart ; le répertoire historique
  `apps/index_windows` ne signifie pas qu’une deuxième application doit être créée.
- Android **7.0/API 24 minimum**, cible et compilation API 36, ARM64 pour le premier
  APK. C’est la valeur réelle de Flutter 3.47.7/FlutterExtension.kt ; la mention
  historique minSdk 23 du Lot 5 était devenue inexacte. Android 6 n’est pas promis.
  Élargir aux autres architectures seulement avec construction/recette distinctes.
- Conserver l’identifiant `fr.index.index_windows` pour assurer la continuité du
  socle déjà distribué en APK de test ; son nom technique n’est pas visible dans
  l’interface. Une modification créerait une autre application et un autre profil.
- Conserver les données utilisateur SQLite dans le stockage privé Android, jamais
  dans un dossier documentaire SAF. La désinstallation peut supprimer ce profil :
  expliquer et prévoir l’export manuel du suivi. Aucun backup cloud automatique.
- Dossier MP3 via ACTION_OPEN_DOCUMENT_TREE, références `content://` persistantes.
  Demander seulement les droits nécessaires : lecture pour le catalogue/lecteur,
  écriture explicitement pour les fonctions 6B. Pas de permission d’accès à tous
  les fichiers, pas de conversion arbitraire URI → chemin de disque.
- Conserver provisoirement MediaPlayer derrière AudioPort pour la preuve 6A ;
  aucun changement de moteur Windows. Mesurer les huit MP3_Bugs sur appareil.
  Les durées VBR/seek et leurs délais conditionnent la confirmation de ce choix.
- Cible fonctionnelle 6C : lecture continue écran éteint/arrière-plan, avec service
  média, notification et commandes système. Le code actuel dans MainActivity et
  la suspension Dart au passage en arrière-plan ne le permettent pas. Le moteur
  devra être possédé par le service, avec gestion du focus, arrêt et reprise.
  Ne pas simplement supprimer onStop : cela ne résoudrait pas le cycle de vie.
  Un éventuel package de service/Media3 sera revu (API/licence/version) avant ajout ;
  aucun package nouveau décidé ou ajouté au Lot 6A.
- APK debug diagnostique uniquement pour cette étape. Signature de distribution
  durable à établir en 6D, hors Git. Une mise à jour exige même identifiant et même
  certificat ; un passage debug → clé de production ne constitue pas une mise à
  jour directe. Exporter le suivi avant une éventuelle réinstallation.
- Majeur 0.6 et bêta conservés. Le workflow Android manuel réserve un mineur dans
  le même compteur que Windows, avec le même verrou de workflow. Le nom APK,
  l’artefact, le versionCode/versionName et À propos reçoivent cette réservation.
  Une compilation locale intermédiaire sans distribution ne réserve pas de version.

## Matrice des écarts

| Fonction | État constaté | Suite / risque à qualifier |
|---|---|---|
| Catalogue 716, fiches et FTS5 | Cœur et assets partagés ; test widget Android sous Linux | Prouver le SQLite natif/FTS5 sur appareil en 6A |
| MP3 facultatifs, premier lancement | Profil privé et sélecteur existants | Première ouverture/réouverture réelle, annulation et message de dossier absent |
| Scan SAF et noms du journal | Requête documentaire récursive, identités partagées | Droits persistants, fournisseur absent, redémarrage, scan incomplet |
| Favoris, états, checkpoints | Stockage et règles communs | Kill du processus, reprise et fin réelle sur MediaPlayer |
| Lecture locale / seek | MediaPlayer natif via content:// ; focus/casque présents | Mesures réelles MP3/VBR, erreurs d’ouverture et interruption |
| Arrière-plan / écran éteint | Pause native onStop + suspension Dart ; aucun service | Service média et notification en 6C ; comportement actuel à annoncer |
| Recherche, filtres, UI | Base responsive existante | Lisibilité 390 px, rotation, clavier, grands caractères, Retour en 6C |
| Renommage | Bloqué explicitement côté Android | Adaptateur SAF, URI retournée, collisions et garanties fournisseur en 6B |
| JSON v2, lecture v1 | Moteur partagé ; import/export Android bloqués | Sélecteurs documentaires, publication, aperçu et échanges réels en 6B |
| Téléchargement | Désactivé dans UI et modèle Android | Destination SAF, permission Internet ciblée et publication sûre en 6B |
| Diagnostic TXT / ouverture dossier | Canaux exportText/showTree existants | Sélecteur, gestionnaire disponible et messages copiables en 6B/6C |
| Données et sauvegardes | Profil privé ; backup SQLite commun | Dossier privé non choisi comme sous Windows ; transfert JSON pour échanges |
| Fermeture/Retour | Retour racine sauvegarde puis SystemNavigator.pop | Navigation entre panneaux et arrière-plan à adapter en 6C |
| Packaging | Ancien workflow APK debug manuel, pas de release signée | Workflow diagnostique versionné ; recette et signature en 6D |

## Dépendances et API observées

Lockfiles conservés : Flutter 3.47.7/Dart 3.13.5 (BSD-3-Clause), sqlite3 3.7.1
(MIT, bibliothèque native SQLite), just_audio 0.10.6 (MIT) et audio_session
transitifs, path_provider_android 2.2.23 (BSD-3-Clause). La présence de just_audio
dans l’APK ne signifie pas que l’application l’utilise comme moteur Android :
AppModel choisit NativeAudioPort. Les plugins transitoires doivent néanmoins
compiler et leurs notices restent à vérifier au paquet final.

Gradle 9.3.1 (SHA-256 épinglé), AGP 9.1.0/Kotlin 2.4.0 (Apache-2.0), JDK 21
et NDK 28.2.13676358 conservés. Les deux options de compatibilité AGP 9 déjà
présentes dans gradle.properties restent nécessaires pour les plugins actuels.
Le manifeste principal ne demande pas Internet ; le manifeste debug le demande
pour l’outillage Flutter. Ajouter le téléchargement en 6B demandera une revue
réseau explicite, notamment les URL HTTP du journal et la politique cleartext.
Ne pas ouvrir globalement toutes les connexions HTTP sans justification.

## Livrables et portes

- Workflow Android manuel : contrôles communs, réservation partagée, APK ARM64
  debug et SHA-256, contrôle du seed et absence de MP3 par inspect_apk.py.
- Test d’intégration supervisé android_feasibility_test.dart : vrai SQLite/FTS5,
  scan d’un dossier choisi, lecture et seek d’un MP3, checkpoint et réouverture du
  profil de test, réutilisation du dossier sans nouveau sélecteur. Profil isolé,
  aucun renommage, téléchargement ou changement des MP3.
- [Recette et commandes](RECETTE_ANDROID.md) : tests manuels sur téléphone avant
  de qualifier la faisabilité et d’engager 6B.

L’absence d’appareil réel laisse la porte 6A ouverte, même si l’APK compile.
Le test de réouverture du profil ne remplace pas le redémarrage physique, la
révocation des permissions ou les mesures audio perçues. Les tests Windows et
Linux existants ne constituent pas une qualification Android.


## Vérifications exécutées le 1er novembre 2026

- `bash tools/lot5/build_android.sh` : réussite, APK debug ARM64 compilé avec
  le lockfile. Compilation intermédiaire locale, version technique de base
  0.6.0+1 ; aucun numéro CI réservé, aucune distribution publiée.
- `python3 tools/lot6/inspect_apk.py <apk>` : seed/manifeste strictement identiques
  aux références, bibliothèques ARM64 vérifiées, aucun MP3/profil utilisateur.
  Un APK temporaire contenant un MP3 ajouté est refusé ; original inchangé.
- `aapt dump badging` : identifiant fr.index.index_windows, minSdk 24, targetSdk 36.
  Permissions fusionnées du debug : INTERNET, ACCESS_NETWORK_STATE et permission
  interne du receiver non exporté. Leur présence n’est pas une preuve de trafic ;
  observation réseau de la distribution finale requise en 6D.
- `apksigner verify --print-certs` : signature de développement Android Debug
  valide ; aucune clé de distribution créée ou publiée.
- `bash tools/lot4/check.sh` : **243 tests Dart, 61 tests Flutter et 7 tests Python
  réussis**, formatage conforme et analyses sans diagnostic. Le nouveau test
  physique est analysé statiquement, pas exécuté sur un téléphone.
- Syntaxes shell/Python/YAML et groupe de concurrence commun des workflows
  vérifiés. Le workflow GitHub modifié n’a pas été déclenché depuis le cloud.

Incidents d’environnement résolus : caches Gradle/Android déplacés dans des
répertoires écrivable hors dépôt ; confiance Java sur le magasin système, TLS
conservé. Une seule variable ANDROID_USER_HOME doit définir les préférences
AGP : la combiner avec d’anciens ANDROID_SDK_HOME/ANDROID_PREFS_ROOT peut provoquer
une erreur de chemins contradictoires. Le SDK 35 requis par une dépendance a été
installé par Gradle, en plus du SDK 36 de l’application, sans modification du dépôt.
ADB n’a pas pu démarrer dans ce sandbox (répertoire ~/.android non écrivable).
Aucun téléphone ni essai USB n’a été qualifié ici. La porte physique 6A reste
ouverte : suivre RECETTE_ANDROID.md avant de valider le passage à 6B.


## Premier échec CI Android — paquet SDK historique

Logs `logs_111982889002.zip`, 1er novembre 2026 : version réservée **0.6.09**
(code 10). L’exécution échoue dans android-actions/setup-android@v3 avant Flutter,
les tests et la construction : `sdkmanager tools` puis
`Warning: Failed to find package 'tools'`. L’action utilise par défaut
`packages: tools platform-tools`, dont le premier paquet est obsolète.

Correction minimale du workflow : préciser `packages: platform-tools`.
Les command-line tools sont installés séparément par l’action ; plateformes 36,
build-tools 36.0.0 et NDK 28.2.13676358 restent explicitement installés à l’étape
suivante. Aucun changement de code applicatif, lockfile, SDK cible ni compteur.
Le mineur 09 reste consommé ; la prochaine réservation suit le compteur courant.
Une relance CI sur la branche contenant le correctif reste nécessaire.


## Deuxième échec CI Android — cache Pub incomplet

Logs `logs_111986788898.zip`, version réservée **0.6.10** (code 11).
L’installation SDK réussit. Les 7 tests Python passent, puis les contrôles
s’arrêtent au premier `dart pub get --offline --enforce-lockfile` :
`test 1.31.1 ... doesn't match any versions`. Ce message concerne les versions
présentes dans le cache local, pas la disponibilité du paquet sur pub.dev.
Le runner neuf n’a pas été préparé avant les scripts historiques hors ligne.

Correction : ajouter avant les contrôles une récupération en ligne des dépendances
du cœur (`dart pub get --enforce-lockfile`) puis de l’application Flutter
(`flutter pub get --enforce-lockfile`). Les contrôles restent hors ligne après
cette préparation, les deux lockfiles et toutes les versions sont conservés.
Le cache de flutter-action est une optimisation, pas un prérequis de réussite.
Le mineur 10 reste consommé ; relancer sur la branche contenant ce correctif.

Validation locale du correctif : récupération des deux projets avec un PUB_CACHE
temporaire initialement vide, puis récupération des deux projets avec
`--offline --enforce-lockfile` dans ce même cache : quatre commandes réussies,
aucune modification des lockfiles. Configuration YAML et ordre des étapes vérifiés.
Le cache de développement habituel a ensuite été réactivé. Le workflow GitHub
complet reste à relancer ; aucun changement applicatif ne nécessite de refaire
la recette audio pour cette seule correction de préparation.


## Ajustements d’interface du 2 novembre 2026

Demande utilisateur distincte de la porte 6A : corrections visuelles Android
autorisées sans lancer les adaptateurs SAF 6B ni le service audio 6C.
- Signature À propos commune Windows/Android : « Monsieur K. ».
- Sur Android, la fiche est un panneau de mêmes dimensions maximales que
  Paramètres (650 × 780, contraint à l’écran), fermeture en bas et titre 24 px
  comme Bibliothèque. Les ouvertures depuis la liste et le lecteur sont cohérentes.
- Navigation Android : cinq icônes sur une ligne, avec infobulles/libellés
  accessibles et état sélectionné ; pas de modification de la navigation Windows.
- Fichiers et associations Android : bouton « Voir les fichiers et associations »
  vers un panneau défilant dédié, contenant les filtres et les associations.
  Les actions/données restent communes et le panneau se met à jour immédiatement.
- Le clavier recouvre le lecteur et le menu Android, au lieu de les faire remonter.
  Les boîtes de dialogue gardent leur adaptation au clavier pour la saisie.
Les fonctionnalités en attente du portage demeurent indisponibles ; aucune
validation native Android implicite ni changement de majeur.

Validation de ces ajustements : analyse Flutter sans diagnostic, 61 tests Flutter
réussis (dont les contrôles Windows existants et le test Android enrichi),
compilation APK debug ARM64 réussie et contrôle de contenu : seed identique,
aucun MP3 embarqué. Le test Android vérifie dimensions Paramètres/fiche, bouton
Fermer en bas, titre 24, cinq icônes alignées, stabilité du menu sous clavier,
panneau fichiers et ses filtres réactifs, signature et sauvegarde à Retour.
Ces contrôles sont exécutés sous Linux ; l’affichage du clavier et les gestes
sur téléphone restent à confirmer dans le prochain APK de diagnostic.
Aucun changement de lockfile, de version majeure ni de données utilisateur.


### Compléments Android — recherche et associations, 2 novembre 2026

À l’ouverture d’un épisode depuis une recherche, faire défiler l’en-tête de fiche
Android jusqu’en bas après sa mise en page pour rendre visibles Résultat précédent
et Résultat suivant, même avec un titre très long. Le faire une seule fois par
épisode/recherche ; un checkpoint ou un clic de navigation ne doit pas annuler
le défilement manuel de l’utilisateur. Aucun défilement automatique ajouté à Windows.

La fiche Android reprend la palette de la fiche Windows, clair et sombre : fond
papier panel, textes ink, boutons et correspondances issus de la palette partagée.
Son Dialog ne doit plus hériter du fond controls des avertissements ni d’un voile
de teinte Material. Les autres panneaux et les couleurs Windows sont conservés.

Dans Liste des fichiers Android, les actions Associer… et Enlever l’association
sont sous le message et le chemin, alignées à droite ; la largeur du cadre est
ainsi disponible pour le texte. Sur Windows, les actions restent à droite du texte.

Validation : analyse et formatage Flutter conformes, 61 tests Flutter réussis.
Le test Android utilise un titre volontairement très long, vérifie les commandes
accessibles et l’en-tête au bas de son défilement, puis vérifie qu’un défilement
manuel est conservé. Il contrôle également fond/texte/correspondances en clair
et sombre, ainsi que la position des deux actions sous les chemins des fichiers.
APK debug ARM64 recompilé avec succès, seed identique et aucun MP3 embarqué.
Recette visuelle sur téléphone à confirmer ; aucun changement de données,
lockfile ou version majeure, aucun commit/push automatique.
