# Lot 5 — lecteur audio et Android

Lancement autorisé le **27 octobre 2026**. Le dernier build Windows du Lot 4 est
signalé fonctionnel par l’utilisateur, sans problème apparent ni crash. Cette
recette utilisateur permet d’engager le lot, sans constituer une qualification
native du nouveau code audio.

## Priorité révisée le 27 octobre 2026

Windows est désormais prioritaire : terminer sa recette audio et stabiliser le
suivi avant de reprendre Android. Le code Android décrit ci-dessous est conservé,
mais son développement et sa recette physique sont en pause. Toutes les fonctions
essentielles restent à porter ; les règles métier et données restent communes,
les API système isolées. Voir l’avenant au cahier des charges. Les Lots 5 bis et
5 ter ne sont pas lancés par ce changement de priorité.

Le workflow Android est désormais manuel (`workflow_dispatch`) ; aucun APK n’est
construit automatiquement à chaque push/PR. Les tests de régression communs et
les tests Android simulés existants sont conservés. Les résultats ci-dessous
restent ceux observés avant cette mise en pause, sans nouvelle qualification.

## Décisions

Le code Flutter existant `apps/index_windows` devient la source commune Windows
et Android ; son nom de package est conservé pour ne pas déplacer l’application.
Le coeur Dart reste indépendant de Flutter. Pas de renommage ni de transfert JSON
réel dans ce lot (Lots 5 bis / 5 ter).

Décision initiale du 27 octobre (moteur Windows remplacé le 28 octobre, voir
la révision WinRT en fin de document) : les candidats media_kit/libmpv/FFmpeg du
Lot 0 étaient remplacés par des adaptateurs système derrière AudioPort :

- Windows : MCI `mpegvideo`, temps en millisecondes, commandes structurées
  `mciSendCommandW`, chemins Unicode séparés des commandes ; bibliothèque système
  `winmm`, aucun codec ou exécutable tiers redistribué.
- Android : `MediaPlayer`, préparation asynchrone, flux ouverts par ContentResolver
  sur URI locales SAF, priorité audio et mise en pause sur perte de focus.
- Aucun accès HTTP audio. Aucun MP3 dans les assets ni APK/ZIP.

Ce choix évite les dépendances binaires audio supplémentaires et leurs licences.
Il doit être confronté aux MP3 réels (notamment VBR, seek, durées et chemins longs)
sur Windows et sur téléphone. Références API :
[Windows MCI](https://learn.microsoft.com/windows/win32/multimedia/mci),
[MediaPlayer](https://developer.android.com/reference/android/media/MediaPlayer),
[SAF](https://developer.android.com/training/data-storage/shared/documents-files).

## Lecture et suivi

La fiche propose Écouter. Le lecteur compact affiche titre + date de l’épisode
réellement chargé, lecture/pause, arrêt, précédent/suivant, choix aléatoire parmi
les MP3 associés disponibles, position/durée, déplacement et volume. La navigation
entre fiches ne change pas la lecture. Depuis la révision du 28 octobre, l’arrêt utilisateur remet le suivi à zéro ; pause et fermeture conservent la position.
La reprise utilise l’identité métier et peut être désactivée dans Paramètres.
Un épisode arrivé au terme repart du début pour une nouvelle lecture.

Checkpoints transactionnels toutes les cinq secondes de progression et à pause,
arrêt, déplacement, changement de piste et fermeture. Première progression et
validation de fin sont aussi enregistrées immédiatement. Une erreur de stockage
met en pause et affiche l’erreur ; la fermeture ne revendique pas une sauvegarde
réussie. La borne visée de perte est cinq secondes si les commits réussissent.

Passage à En cours après progression réellement jouée. Fin : zone à >=95 % ou
<=60 secondes restantes, puis dix secondes continues réellement jouées dans cette
zone. Un seek/discontinuité réinitialise cette garde ; une durée inconnue ne valide
pas automatiquement une fin. Écouté reste acquis pendant une réécoute ; seule une
action manuelle explicite le remet à zéro. Favori indépendant.

Le schéma utilisateur passe de v4 à v5, ajoutant `last_played_at`, `completed_at`
et `playback_status`. Le seed documentaire livré reste v4, lu sans modification.
Les imports de seeds v2/v3/v4/v5 sont reconnus. Migration transactionnelle, SQLite
WAL et synchronous FULL conservés, attente de verrou SQLite bornée à cinq secondes
pour sérialiser checkpoints et scans ; favori/suivi existants préservés. Le retrait
explicite d’association conserve sa dernière règle : effacement du suivi et du
favori de cet épisode, après libération de son lecteur pour éviter de les recréer.

## Android

Android >=23, SDK/cible 36, NDK 28.2.13676358 ; Java 21 et Gradle 9.3.1.
Catalogue intégré et données SQLite dans le stockage privé. Sélection des MP3 par
ACTION_OPEN_DOCUMENT_TREE, autorisation de lecture persistante ; aucune conversion
URI vers chemin Windows, aucune copie implicite de bibliothèque ni lecture de tags.
Parcours borné des sous-dossiers et diagnostic en cas d’accès partiel/refusé ; aucun
nouveau lien validé sur scan incomplet. Une perte d’accès ne supprime pas le suivi.

La reprise des permissions après redémarrage et l’accès réellement hors ligne
restent à qualifier sur appareil, notamment pour les fournisseurs cloud. Choisir
un dossier local contenant les MP3 physiquement présents. La copie privée optionnelle
n’est pas implémentée : l’alternative retenue est l’URI persistante, à éprouver.

Cette V1 de lecteur met en pause et sauvegarde en arrière-plan ; pas de service
média prolongé, notification de lecture ni reprise automatique après appel.
Le bouton Retour Android attend la sauvegarde avant de quitter. L’export du
diagnostic TXT utilise ACTION_CREATE_DOCUMENT pour choisir une destination hors
du stockage privé. Aucune permission Internet dans le manifeste principal. Sauvegarde Android système
désactivée pour garder les données locales. Les APK de CI sont signés avec une clé
de développement, réservés aux essais, pas publiés dans un magasin.

## Reproduction et recette

Linux : activer Flutter puis `bash tools/lot4/check.sh`.
Android : SDK/JDK configurés, `bash tools/lot5/build_android.sh`. Le workflow
`android.yml` produit `IndeX-Android-arm64-test`. Un APK compilé ne remplace pas
une recette sur téléphone.

Windows : `tools/lot4/check.ps1`, puis paquet et smoke existants. Sur une machine
avec sortie audio, exécuter aussi `tools/lot5/check_windows_audio.ps1` : le test natif
ouvre un MP3 réel du corpus, vérifie durée/position et checkpoint après pause,
puis réouvre la session et retrouve cette position. Cette cible matérielle n’est
pas activée par défaut sur les runners CI sans sortie audio ; leurs tests de
stockage et fermeture restent obligatoires. Aucun succès audio natif n’est déduit
de ces seuls tests généraux.

Sur les deux cibles : lecture et seek réels, pause/arrêt/volume/aléatoire,
consultation d’une autre fiche sans changer le lecteur, progression et favoris,
kill du processus après cinq secondes puis reprise, faux seek de fin sans Écouté,
dix secondes réellement jouées près du terme, MP3 disparu, disque plein, mise à
jour du catalogue. Android : redémarrage, révocation de permission, sous-dossiers,
mode avion, écran éteint, appel et casque retiré. Aucun appareil Android physique
n’est attaché à l’environnement cloud ; cette porte de validation reste ouverte.

## Environnement de compilation

L’environnement cloud disposait seulement d’un JRE ; JDK Temurin 21.0.9+10 et
Android command-line tools 19.0 ont été installés hors du checkout, avec empreintes
officielles vérifiées (voir dependances.json). SDK 36, build-tools 36.0.0 et NDK
28.2.13676358 installés. Gradle utilise le proxy réseau de la plateforme et le
magasin de confiance système, sans désactiver TLS. Les chemins et caches locaux
ne sont pas versionnés. La CI emploie setup-java et setup-android.

## Contrôles exécutés

- Coeur Dart : 188 tests réussis, dont migration réelle d’une base utilisateur v4
  contenant favori et progression, checkpoints et réouverture, import du seed v4,
  scans SAF complets/incomplets sans perte de données sur permission refusée.
- Flutter : 24 tests réussis, dont garde de fin virtuelle, seek, erreurs d’écriture,
  indépendance fiche/lecteur, affichage téléphone, dossiers privés Android et
  sauvegarde à Retour. Le test de sortie Android est isolé dans son propre fichier
  pour ne pas réutiliser le moteur de test après la simulation de sortie système.
- Analyses Dart/Flutter sans diagnostic, formatage et syntaxe PowerShell vérifiés.
- APK debug ARM64 compilé avec succès sur Linux ; contenu vérifié par ZIP : seed
  strictement identique au manifeste et aucun MP3, SQLite natif ARM64 présent.
- Pas d’essai Windows audio natif ni d’essai sur appareil Android physique ici.
  Le Lot 5 est implémenté pour recette ; il n’est pas déclaré qualifié sur appareil.

L’APK et les caches SDK/Gradle sont des sorties ignorées par Git. Les workflows
Windows (automatique) et Android (manuel) constituent les chemins de construction reproductibles, sans publication en magasin ni commit automatique.

## Installer l’APK de test

Lors de la reprise Android, ouvrir GitHub Actions, choisir **Verification Android Lot 5**,
cliquer sur **Run workflow**, puis télécharger l’artefact **IndeX-Android-arm64-test** du run réussi. Extraire
`app-debug.apk`, le transférer sur un téléphone ARM64 Android >=6 et autoriser son
installation depuis la source choisie si Android le demande. Ouvrir IndeX,
choisir un dossier local de MP3 ou reporter ce choix. Les données sont privées à
l’application ; Windows et Android gardent chacun leur propre suivi pour le moment.
L’export/import de suivi des paramètres reste prévu au Lot 5 ter.


## Incident Windows du 27 octobre 2026 — MCI 277 et crash mciqtz32

Recette utilisateur : fermeture au clic Écouter ; Moniteur de fiabilité :
`mciqtz32.dll` 10.0.26100.1150, exception `0xc0000005`, offset `0x4e67`.
Un autre essai affiche `audio_native`, MCI 277 (`MCIERR_NULL_PARAMETER_BLOCK`).

Défaut identifié dans notre adaptateur : `MCI_PLAY` recevait un bloc de paramètres
nul, comme `MCI_PAUSE` et `MCI_CLOSE`. Le pilote `mpegvideo` recevait également
les petites structures génériques pour OPEN/SET. Correction : blocs initialisés
pour PLAY/PAUSE/CLOSE et structures `MCI_DGV_OPEN_PARMSW` / `MCI_DGV_SET_PARMS`
complètes pour OPEN/SET. Une fermeture en erreur conserve l’identifiant du lecteur
pour ne pas perdre sa référence. Les erreurs retournées incluent maintenant le
nom de la commande et le texte système de `mciGetErrorStringW`.

MCI 277 est cohérent avec le pointeur nul ; le lien exact entre ce défaut et
l’accès mémoire invalide reste à confirmer par une nouvelle recette Windows.
Aucun remplacement de DLL système ni changement des MP3 n’est requis.
La recette native optionnelle couvre aussi pause répétée, seek, volume et reprise :
`tools/lot5/check_windows_audio.ps1` sur Windows avec une sortie audio disponible.
La compilation et cette recette ne peuvent pas être exécutées sur l’hôte Linux ;
les tests avec faux lecteur ne qualifient pas ce correctif natif.

Il n’existe toujours pas de journal de crash persistant dans l’application.
En cas de récidive, conserver le rapport Windows, la commande MCI éventuellement
affichée et préciser si tous les MP3 ou seulement certains sont concernés.

Contrôles du correctif sur Linux : analyse de `windows_smoke_test.dart` sans
anomalie, trois tests `audio_player_test.dart` réussis, formatage et
`git diff --check` sans erreur. Aucun essai audio natif Windows exécuté ici.


## Échec de compilation Windows — logs 110020027551

Le build du correctif MCI s’arrête dans `audio_channel.cpp`, ligne 45, avec
C2440 : conversion interdite de `const wchar_t*` vers `LPWSTR`. La structure
`MCI_DGV_OPEN_PARMSW` attend des pointeurs modifiables pour le type de pilote et
le chemin. Le correctif utilisait encore un littéral constant et `path.c_str()`.
Ils sont remplacés par un tableau local `wchar_t[]` et `path.data()` (C++17),
valides pendant tout l’appel synchrone `MCI_OPEN`. Aucun retrait de constance
par cast ; les blocs de paramètres MCI corrigés restent en place.

Les logs valident avant cet échec 187 tests Dart avec un test ignoré sur Windows,
24 tests Flutter et les analyses. La recette native n’a pas pu démarrer et aucun
nouveau paquet Windows n’a été produit. Contrôle local du nouveau changement :
`git diff --check` sans erreur ; compilation et écoute Windows restent à refaire
par la CI puis sur la machine de l’utilisateur. Aucun changement Dart ou Android.


## Révision Windows du 28 octobre 2026 — version 0.5.01 et lecteur

Les décisions du 28 octobre priment sur le comportement initial du lot : Arrêt
utilisateur efface la progression et remet le statut à Non écouté (favori conservé).
La pause et la fermeture gardent leurs checkpoints. Le passage manuel en Écouté
est confirmé, arrête la piste concernée et remet sa position à zéro. Un nouveau
ListeningGuard empêche l’ancien suivi en mémoire de rétablir l’état précédent.

Fiche : pourcentage de progression en cours sans flèche tournante. Liste : fond
proportionnel à la position/durée pour une écoute commencée, couleur des épisodes
écoutés, actualisé depuis le lecteur et repris depuis SQLite après redémarrage.
Sans durée connue, pas de pourcentage estimé ni de remplissage. Le titre du lecteur
ouvre sa fiche ; date de même police/couleur que la liste, survol du curseur avec
horodatage, cible conservée pendant le seek natif et raccourcis ±10 secondes.
Les filtres de fichiers reprennent le fond des boutons latéraux.

Les modes auto-suivant (défaut actif) et aléatoire (défaut inactif) sont persistés.
L’aléatoire lance immédiatement une autre piste et enchaîne au hasard à chaque fin ;
il prime sur auto-suivant. Hors aléatoire, auto-suivant respecte la liste affichée,
les tris/filtres et les MP3 disponibles, sans boucler au dernier. Une fin est traitée
une seule fois. Ni une pause ni un arrêt manuel ne provoquent d’enchaînement.
Le cœur de suivi et ces modes restent communs pour le futur portage Android.

Version publique et archives : voir `tools/versioning/README.md`. Le compteur de
build est distinct des migrations SQLite et des versions de catalogue. Android
reste en pause, aucun nouveau build Android n’est demandé par cette révision.

Contrôles de cette révision : `bash tools/lot4/check.sh` — 188 tests Dart et
26 tests Flutter réussis, analyses sans anomalie. Après les derniers ajustements,
12 tests PortableSession, les deux nouveaux tests des modes/seek et le test UI
lecteur ciblé réussissent ; analyse Flutter sans anomalie, formatage conforme.
Deux tests Python du compteur passent (compteur local et dépôt Git temporaire,
réservation CI persistante sans modification de main). Scripts PowerShell validés
par leur analyseur syntaxique et script Bash par `bash -n`. Le lockfile Flutter
n’a changé que pour la version du package local index_core, sans dépendance ajoutée.
Aucun build/essai natif Windows exécuté ici, ni nouvelle qualification Android.


## Échec du compteur Windows — logs 110050750608 (28 octobre 2026)

L’étape de réservation initiale a attribué `0.5.01`, mais les tests Python du
compteur échouent avant les tests Dart/Flutter et la compilation. Sous Windows,
`subprocess.run(..., text=True, input=...)` traduit LF en CRLF sur stdin. Le CR
reste dans le nom d’entrée donné à `git mktree` : `counters.json\r`. La relecture
par le nom attendu échoue. Ce défaut touche aussi la branche technique réelle,
confirmée en lecture seule par `git ls-tree -z` ; elle contient la valeur 1.

Correctif : échanges Git en octets UTF-8 et arbre terminé par NUL (`mktree -z`).
Récupération explicite de l’ancien blob au nom erroné, sans remettre le compteur
à zéro ; le prochain build réserve `0.5.02` et réécrit le nom canonique dans un
nouveau commit de la branche technique. Aucun changement distant effectué ici.
Un compteur manquant/ambigu/invalide est refusé.

Contrôles locaux : quatre tests Python réussis, dont reproduction exacte de
l’ancien nom avec CR, récupération sans réutilisation de 01, relecture du nom
canonique et réservation suivante 03, plus refus d’un compteur manquant.
Le compteur réel est relu à 1 sans modification. `git diff --check` sans erreur.
Aucun changement applicatif/Dart/Android ; la compilation et la recette audio
Windows restent à refaire après push du correctif.


## Révision du 28 octobre 2026 — remplacement de MCI par just_audio / WinRT

L’utilisateur autorise `just_audio` **0.10.6** et `just_audio_windows` **0.2.3**.
Windows utilise désormais `JustAudioPort`, créé paresseusement au premier fichier,
avec WinRT MediaPlayer. Le canal MCI, ses fichiers C++, sa propriété de fenêtre et
le lien winmm sont retirés ; Flutter enregistre le plugin Windows généré. Le
package vérifie `just_audio_windows_plugin.dll` dans le bundle ; le lanceur racine
et la distribution sans installateur restent identiques. Aucun MP3 embarqué.

L’interface AudioPort et la base utilisateur sont conservées. `play()` lance sans
attendre la fin de piste (le Future just_audio peut rester pendant toute l’écoute),
les erreurs de lecture asynchrones sont conservées et remontées au prochain poll.
`ProcessingState.completed` produit une fin explicite, avec `playing=false`, pour
les modes auto-suivant/aléatoire. Le seek conserve la lecture active sans second
redémarrage natif. Dispose libère le moteur et une prochaine ouverture le recrée.
Après erreur décodeur, le contrôleur sauvegarde son dernier état connu et permet
une nouvelle piste ou une fermeture ; une erreur SQLite reste bloquante.

Seules les URI locales file sont acceptées sur cet adaptateur : pas d’URL distante,
proxy/cache réseau, conversion ou modification des fichiers. Les titres, dates,
liens et suivis existants sont inchangés, sans migration SQL supplémentaire.

Android reste en pause et garde son adaptateur MediaPlayer/SAF actuel. Les
packages apportent des implémentations transitives d’autres plateformes ; leur
présence n’engage pas un portage. `path_provider_android` **2.2.23** est contraint
explicitement dans la plage autorisée de path_provider : la résolution initiale
2.3.1 ajoutait JNI et son plugin CMake Windows, inutiles pour IndeX Windows.
Le pin évite cette nouvelle chaîne Java ; il devra être réévalué lors de la reprise
Android. Les dépendances et leurs licences sont relevées dans
`just-audio-dependances.json`, archives verrouillées par SHA256. MIT/BSD-3-Clause/
Apache-2.0 pour les nouveaux packages ; notices copiées par le packaging existant.
Ni libmpv ni FFmpeg ne sont ajoutés.

Recette native restante : ouvrir des MP3 locaux avec espaces/accents et pistes
longues/VBR, pause/reprise, ±10 secondes, seek lointain, volume, fin/auto-suivant,
arrêt, fermeture et redémarrage. La cible `tools/lot5/check_windows_audio.ps1`
utilise le nouvel adaptateur et affiche le temps d’acquittement du seek ; cette
mesure ne représente pas à elle seule le délai jusqu’au retour audible du son.
Comparer ce dernier au MCI observé et viser <200 ms sans le déclarer acquis.
La compilation et l’écoute Windows ne sont pas exécutables sur cet hôte Linux.

Contrôles du remplacement : `bash tools/lot4/check.sh` réussit — 188 tests Dart,
29 tests Flutter (dont trois nouveaux avec le vrai contrôleur just_audio et un
backend de plateforme simulé), quatre tests Python du compteur ; analyses sans
anomalie. Les tests de l’adaptateur vérifient play non bloquant, URI avec accents/
espaces, seek sans redémarrage, fin explicite, erreurs tardives et réouverture.
Après ajout du cas fermeture sur erreur : les trois tests ciblés passent encore,
analyse Flutter conforme. Syntaxe du packaging PowerShell vérifiée ;
`git diff --check` sans erreur. Aucun benchmark audible ni build Windows natif
exécuté ici. Le mineur sera réservé automatiquement par le prochain build CI,
sans changer le majeur 5. Aucun commit/push automatique.


## Régression MP3_Bugs — signalement utilisateur du 28 octobre 2026

`main` récupéré et intégré en avance rapide jusqu’à **f13f098** : huit MP3 sous
`MP3_Files/MP3_Bugs`. Le signalement indique cinq lectures OK et trois timeouts
(Haïti, trésor du PC soviétique, Zimbabwe). Audit en lecture seule : les huit
se décodent intégralement avec FFmpeg, sans erreur de décodage. Les fréquences,
canaux et tags ne permettent pas d’isoler une caractéristique exclusive aux trois
échecs ; Moudjahiddin, qui fonctionne, partage le profil MPEG/16 kHz/stéréo/40 kbit/s
de deux échecs. Cela ne prouve pas que WinRT accepte les huit sources.
Rapport reproductible, empreintes et signalement : `mp3-bugs-audit.json` ; commande
`python3 tools/lot5/audit_mp3_bugs.py --decode --output docs/lot5/mp3-bugs-audit.json`.
Les octets/tags/noms des MP3 sont inchangés, pas de mise à jour du seed nécessaire.

Défauts identifiés dans le chemin d’intégration (pas de reproduction WinRT sur Linux) :

- Le plugin 0.2.3 émettait MediaFailed/ItemFailed comme erreurs EventChannel,
  ignorées par l’abonnement natif de just_audio 0.10.6 : un chargement pouvait
  rester loading jusqu’à notre timeout, sans erreur réelle affichée.
- Événements envoyés depuis les callbacks WinRT vers Flutter sans transfert
  explicite au thread UI ; notifications avant abonnement perdues, seules les
  transitions PlaybackStateChanged écoutées, pas MediaOpened/durée.
- Durée encore inconnue : position=durée=0 interprétée à tort comme completed.
- Le timeout de Playback n’annulait pas à lui seul le Future/moteur sous-jacent.

Correctif local MIT `third_party/just_audio_windows` **0.2.3+index.1**, à partir
de l’archive officielle avec provenance/empreintes conservées. Notifications
réacheminées au thread UI via une file faible/protégée et le délégué de fenêtre,
notifications d’ouverture et de durée ajoutées, dernier événement rejoué,
erreurs converties dans le protocole d’état reconnu par just_audio. Une erreur
est émise sans interroger une session WinRT déjà défaillante. Fin seulement pour
une durée strictement positive. Lecteurs libérés à la destruction du plugin avant
COM. Détail dans `third_party/just_audio_windows/INDEX_PATCHES.md`.

JustAudioPort attend un état prêt et arbitre chargement/erreur ; timeout interne
20 s puis destruction effective, nettoyage borné à 3 s, avant la limite externe
30 s. Les événements tardifs d’un lecteur détaché ne modifient pas le suivant.
Nouvelle piste possible après un échec sans perte du favori/suivi. Journal local
`<données>/logs/lecteur-audio.log` : noms de fichiers, états, position/durée connue,
erreur et résultat de l’ouverture, rotation 512 Kio avec un précédent, sans réseau.
Un échec d’écriture du journal ne bloque pas le suivi ou la lecture.

Recette Windows étendue dans la cible audio existante : les six fixtures racine
restent scannées sans récursivité dans le scénario historique, puis les huit
MP3_Bugs doivent chacun s’ouvrir, progresser et accepter un seek. Les tests des
compteurs récursifs tiennent désormais compte de **14** fichiers (716 épisodes,
702 manquants), et 13 associations après retrait d’une, sans modifier les fixtures.
Les autres scénarios non récursifs restent à six fichiers. Aucun MP3 embarqué.
Android reste en pause, aucune dépendance audio Android remplacée.

Limite : ces correctifs résolvent des défauts identifiés de notification et de
nettoyage, mais la cause précise du refus éventuel de chacun des trois MP3 reste
à confirmer sur Windows. Ne pas déclarer les huit lectures WinRT validées sur la
base du décodage FFmpeg. Si un fichier est réellement refusé par le décodeur
Windows, son erreur native doit désormais apparaître et figurer dans le journal.

Contrôles exécutés : audit FFmpeg intégral des huit fichiers, codes de sortie 0
et empreintes avant/après identiques ; 188 tests Dart et quatre tests du compteur
réussis. Suite Flutter corrigée pour les nouvelles fixtures : 31 tests réussis,
analyse sans anomalie, dont ouverture bloquée annulée/réouverture et erreur native
pendant loading sans attendre le timeout. Test C++ portable compilé par
`g++ -std=c++17 -pthread -Wall -Wextra -Werror tools/lot5/test_audio_state.cpp`
(exécutable dans /tmp) : états/durée nulle, durée 64 bits, notifications concurrentes,
erreurs conservées, arrêt et événement tardif ignoré réussis. Formatage et contrôle
diff conformes. Le code Win32/WinRT complet n’a pas été compilé/exécuté ici ;
recette des huit MP3 sous Windows restant obligatoire avant qualification.


## Refus des trois MP3 après index.1 — accès aux fichiers locaux

Retour utilisateur : plus de blocage prolongé, mais les mêmes fichiers refusés
avec `(1001) sourceNotSupportedError: The system cannot find the file specified`.
Ce message situe le problème rapporté dans l’accès au fichier ; il ne démontre
pas une incompatibilité de décodage. Les noms fournis sont NFC dans le dépôt ;
les trois échecs ont accents et parenthèses, mais cette corrélation ne prouve pas
à elle seule une cause. Aucune modification des noms, tags ou octets audio.

Correctif `just_audio_windows` **0.2.3+index.2** : les sources file sont ouvertes
via un chemin Windows Unicode exact et `CreateRandomAccessStreamOnFile`, puis
`MediaSource::CreateFromStream` en audio/mpeg. Ce chemin évite l’interprétation
file:// par CreateFromUri. Le helper décode le pourcentage une seule fois et
conserve ponctuation, accents, NFC/NFD et UNC ; il refuse NUL, échappements
invalides, URI relatives ou avec query/fragment. Un `%20` littéral dans un nom
reste `%20` après décodage de `%2520`. Le mode d’accès est l’enum WinRT
FileAccessMode.Read (pas les flags STGM), signature vérifiée dans la documentation
SDK. API Shcore du système : aucun installateur ni nouveau moteur/codec.
Flux lisible/seekable, sans copie complète en RAM ou sur disque et sans remuxage.

JustAudioPort vérifie d’abord via Dart que le chemin associé existe et s’ouvre
en lecture seule. Un échec indique de relancer l’analyse au lieu de le présenter
comme une erreur de décodeur. Le probe partage le budget de 20 s avec le moteur
(pas deux timeouts cumulés). Journal enrichi avec chemin décodé à l’ouverture,
`file_access_ok` ou `file_access_failed`, puis l’éventuelle erreur du moteur.
Cela permet de distinguer un lien absent/périmé d’un échec après accès réussi.

Tests portables C++ : chemins des trois noms concernés, accents/parenthèses,
NFD, UNC, `%`, `#`, `+`, échappements malformés et NUL, plus la file de notifications
et les états de fin. Deux tests Flutter ajoutés : fichier absent refusé avant
création du moteur, fichier Unicode avec caractères spéciaux transmis tel quel
sans modifier ses octets (backend simulé). Les tests antérieurs de moteur utilisent
explicitement un probe simulé pour leurs URI synthétiques. Le parcours Windows
natif des huit vrais MP3 est conservé et reste à exécuter ; pas de qualification
WinRT sur la foi des tests Linux.

Contrôles de index.2 : analyse Flutter sans anomalie et **33 tests Flutter réussis**.
Classification/file de notifications et nouveaux cas de chemins compilés/exécutés
avec g++ C++17 sans avertissement ; formatage/diff conformes. Les huit empreintes
MP3 de référence restent identiques. La compilation de Shcore/WinRT et la lecture
des huit vrais fichiers sur Windows ne sont pas exécutées ici. Le numéro mineur
applicatif sera réservé automatiquement au prochain build, majeur 5 conservé.


## Recette utilisateur et interactions du lecteur — 28 octobre 2026

Retour utilisateur après le build avec ouverture par flux local : plus de bug
Audio apparent et sauts quasi instantanés. Ce retour valide les essais effectués
sur sa machine Windows ; il est distinct des contrôles Linux et n’engage pas Android.

Nouvelle révision UI : titre du lecteur avec curseur main, ouverture de fiche
indépendante des résultats et du défilement de la liste. La sélection hors résultats
est conservée lors des rechargements/checkpoints et réinitialisée par nouvelle
recherche ou sélection explicite. En vue Fichiers/compacte, un dialogue de fiche
préserve la vue sous-jacente ; onglets adaptés pour éviter un débordement horizontal.
Précédent/suivant respectent désormais le mode aléatoire (tirage testable et sans
répétition immédiate). L’horodatage suit le glissement et reste visible jusqu’au
relâchement, même lors d’une sortie de la zone. Filtres de fichiers avec curseur main.

Les erreurs lecteur, Paramètres, recherche, validation de dossiers et contenus des
dialogues utilisent SelectableText ; la bannière et les diagnostics étaient déjà
sélectionnables. Pas de modification du moteur WinRT, des MP3, du suivi persistant
ou des règles de versionnement. Le prochain build réserve son mineur automatiquement.

Validation : analyse Flutter sans anomalie, 33 tests Flutter réussis. Scénarios
étendus : conservation recherche/tri/identités/scroll après clic titre, fiche compacte,
fiche hors résultats après checkpoint, précédent/suivant aléatoires déterministes,
temps visible pendant glissement et hors zone, erreurs de lecteur/bannière et
alerte de sauvegarde sélectionnables. Vérification visuelle Windows de cette
révision UI à réaliser dans le prochain build ; pas de nouvel essai natif ici.


## Correction de la réécoute et du statut conservé — 28 octobre 2026

Le signalement utilisateur concernait une relance depuis la fiche encore ouverte,
après fin et démarrage automatique du suivant. Le test de régression a reproduit
le statut Écouté conservé, avec et sans changement de fiche, avec et sans
succession automatique. La position repartait à zéro mais le checkpoint conservait
volontairement tout statut Écouté : une relance nécessite donc un reset explicite,
sans modifier cette protection générale des checkpoints.

AppModel consulte désormais le suivi SQLite courant plutôt que la position d’un
objet de fiche ancien. Pour un épisode Écouté, Playback exécute la réinitialisation
après sauvegarde de la piste quittée et ouverture/positionnement réussis, avant le
premier checkpoint de la nouvelle lecture. Cela évite que l’ancien checkpoint
réintroduise Écouté, notamment pour une relance sur la même piste. Le favori est
préservé ; un échec d’ouverture conserve le statut et la date de fin enregistrés.
La reprise d’un épisode inachevé reste active. Lecture après fin sans enchaînement
emprunte le même parcours. Aucun changement de moteur, de MP3 ni de schéma SQLite.

Les quatre variantes du test échouaient avant correction sur le statut encore
Écouté ; elles vérifient ensuite position zéro, statut, favori, progression après
relance et reprise depuis le dernier checkpoint même avec une ancienne fiche.
Un autre test couvre l’échec d’ouverture sans effacement du suivi.

Validation : `bash tools/lot4/check.sh` réussi, soit 188 tests du cœur, 38 tests
Flutter et 4 tests du compteur de versions ; analyses sans anomalie et formatage
conforme. Les variantes sans enchaînement vérifient aussi une deuxième fin puis
la relance via Lecture du lecteur. Ces tests utilisent un moteur simulé ; la
reproduction visuelle sur Windows reste à confirmer au prochain build. Le numéro
mineur sera réservé par le mécanisme habituel, sans changement de majeur.
