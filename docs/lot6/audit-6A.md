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
