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


## Réglages de liste persistants et fin après seek — 28 octobre 2026

La vue de liste conserve recherche, champs, tri, statut et Favoris dans un réglage
JSON local versionné `library_view`, au sein de `local_settings` existante. Il est
restauré avant le premier chargement des résultats. L’écriture n’a lieu que si le
réglage change, pour éviter une écriture supplémentaire à chaque checkpoint audio.
Les valeurs inconnues reviennent aux choix par défaut ; un JSON illisible ne
bloque pas l’ouverture. Le champ de recherche reprend la valeur du modèle à sa
création. La temporisation d’affichage de 250 ms reste en place, mais la saisie est
durable immédiatement. Aucun changement de schéma, de seed ou de dépendance.

La case Reprendre à la dernière position sauvegardée utilise l’affinité à gauche.
La garde de fin accepte désormais une vraie fin du moteur après progression
continue depuis le dernier seek, même lorsque moins de dix secondes restaient.
Un simple seek à 100 %, une discontinuité sans progression ou une durée inconnue
ne valent toujours pas validation. Un événement de fin à position identique au
dernier échantillon est accepté si une progression dans la zone de fin a déjà été
observée depuis le seek. La validation anticipée sur dix secondes est conservée.
Cette règle remplace l’obligation antérieure des dix secondes lors d’une fin réelle.

Tests ajoutés : fermeture/réouverture avec filtres combinés et retrait de ceux-ci,
saisie avant temporisation, réglage illisible, texte de recherche visible, case à
gauche, gardes de fin (fin réelle, position finale répétée, seek seul, durée inconnue)
et suivi SQLite après seek à trois secondes de la fin, avec/sans auto-suivant.

Validation : `bash tools/lot4/check.sh` réussi : 188 tests du cœur, 44 tests Flutter,
4 tests de versionnement ; analyses sans anomalie, formatage et diff conformes.
Les tests audio utilisent un moteur simulé : recette Windows réelle à confirmer
au prochain build. Aucun build distribuable lancé ici ; le prochain mineur reste
attribué par le compteur habituel, majeur 5 conservé.


## Fin atteinte par avance clavier — 28 octobre 2026

Le retour Windows confirme la fin naturelle après seek court, mais révèle un cas
supplémentaire : la flèche droite place directement à la durée, puis le snapshot
final ne contient plus de progression après le seek. La garde anti-seek refuse
alors de valider, laissant En cours à 100 %.

Playback distingue désormais `skip(delta)` relatif du `seek(position)` absolu.
Les flèches gauche/droite appellent skip. Pour une avance pendant la lecture,
d’une position avant la fin jusqu’à une durée connue, la garde mémorise une demande
de fin. Seul le signal ended du moteur valide alors Écouté, sauvegardé avant
l’enchaînement. La commande n’anticipe pas ce signal. Pause, recul et seek absolu
restent exclus ; toute nouvelle discontinuité annule la demande. Les autres règles
de fin et de progression continue sont conservées. Aucun changement de moteur,
de schéma SQLite, de dépendance ou de MP3.

Tests : variantes avec/sans clavier et avec/sans auto-suivant, statut durable et
absence de validation avant la fin moteur ; exclusions en pause, après nouveau
seek et après recul. Les tests UI existants exercent aussi les raccourcis ±10 s.

Validation : `bash tools/lot4/check.sh` réussi : 188 tests du cœur, 47 tests Flutter
et 4 tests de versionnement ; analyses sans anomalie, formatage et diff conformes.
Les tests audio utilisent un moteur simulé. Le cas clavier doit encore être
confirmé sur Windows au prochain build, dont le mineur sera réservé automatiquement.


## Panneau À propos et case de scan — 29 octobre 2026

Clarification utilisateur : cochée = scanner ; valeur par défaut cochée. Seule
l’interface inverse le booléen skip_startup_scan existant : les préférences de scan
conservent leur effet après mise à jour, sans migration.

À propos est disponible en navigation latérale/compacte, dans les deux thèmes.
Il réutilise les cadres des Paramètres, avec identité/version/GitHub dans le premier
cadre puis description structurée et défilante. Le lien factice affiche un message,
sans ouverture de site. Les fonctions futures et la pause Android sont explicites.
Le script de packaging Windows transmet la version publique réservée en dart-define
INDEX_VERSION, sans nouvelle réservation ni modification de politique de version.
Le lancement de développement affiche Développement. Aucune dépendance ajoutée.

Tests UI : libellé/état par défaut et désactivation du scan, ouverture/fermeture de
À propos sans perte de la recherche/liste, thèmes clair/sombre, fenêtre compacte,
version, retour du lien factice et défilement jusqu’aux fonctions prévues.

Validation : `bash tools/lot4/check.sh` réussi : 188 tests du cœur, 48 tests Flutter
et 4 tests de versionnement ; analyses sans anomalie, formatage/diff conformes.
Test À propos également réussi avec une version injectée via dart-define (valeur
de test uniquement, sans réservation). Syntaxe PowerShell du packaging vérifiée
avec le parseur PowerShell 7.5.4. Aucun build Windows lancé sous Linux : présentation
et numéro du prochain exécutable à confirmer lors de la recette Windows.


## Textes et identité de À propos — 29 octobre 2026

Correction Rendez-vous avec X dans le Brand et les textes UI. À propos utilise
Brand comme en-tête du premier cadre ; GitHub renommé Voir sur GitHub et placé
avant la version sur une même ligne. Récit, signature et cinq descriptions repris
du texte utilisateur, avec emphases demandées. Le cadre Fonctions prévues disparaît ;
la mention d’export/import est accompagnée d’une précision de non-disponibilité
actuelle, sans engager le Lot 5 ter.

Le contact ouvre uniquement l’URI fixe mailto:index.en9nr@passinbox.com via
ShellExecuteW sur demande utilisateur (canal Windows existant), sans lancement de
commande ni destinataire arbitraire, sans envoi automatique. Une erreur/plateforme
non implémentée ouvre une alerte avec adresse sélectionnable. GitHub reste factice.
Aucune dépendance ajoutée. Les échanges éventuels du logiciel de messagerie sont
extérieurs à IndeX ; aucune transmission automatique n’est introduite.

Le test À propos couvre maintenant la réutilisation de Brand, ordre et alignement
GitHub/version, retrait du cadre, clic contact via canal simulé, défilement jusqu’au
dernier cadre et conservation de la liste, en clair/sombre et en format compact.

Validation : cœur 188 tests et compteur 4 tests réussis lors de la vérification
commune ; après correction d’un alignement GitHub/version en fenêtre compacte,
analyse Flutter sans anomalie et totalité des 48 tests Flutter réussie. Formatage
et diff conformes. Le lien mailto est simulé dans le test : compilation du runner
et ouverture réelle du logiciel de messagerie à confirmer au prochain build
Windows. Aucun build distribuable lancé ici.


## Portabilité des chemins internes et presse-papiers — 30 octobre 2026

Pointeur portable v2 relatif pour les données internes, absolu pour les externes ;
v1 lu et converti à l’ouverture existante. Racine déterminée depuis application/
ou le dossier portable en développement. La racine précédente est mémorisée dans
local_settings.portable_root_v1. En cas de déplacement, réévaluation transactionnelle
des références sous cette seule racine : liens, preuves/diagnostics de scans,
mp3_directory et exclusions persistantes. Les références extérieures et tout le
suivi restent intacts. Une contrainte d’unicité annule la transaction, sans effacer
ni réattribuer les liens. Un dossier absent affiche son chemin et n’est jamais
remplacé par un nouveau profil. Pas de migration de schéma ni changement du seed.

Un ancien pointeur v1 déjà cassé sans racine mémorisée demande une relocalisation
explicite ; impossible d’identifier sûrement un profil à partir du seul nom de
son dossier. Ouvrir la mise à jour une fois avant un futur déplacement initialise
les métadonnées nécessaires. Aucune modification des fichiers MP3, TXT ou CSV.

Contact : suppression du canal natif mailto, Clipboard.setData et notification
immédiate (même après le message GitHub). Phrase révisée, adresse centrée et espace.
GitHub utilise une icône Octicons MIT locale et OutlinedButton ; source SVG, PNG
transparent et licence/provenance conservés. Licence copiée dans documentation/
licences lors du packaging. Conversion SVG→PNG avec CairoSVG comme outil local
uniquement, aucune dépendance runtime supplémentaire, aucun téléchargement à l’usage.

Tests : déplacement réel de la racine avec caractères accentués/#, réouverture sans
scan, suivi/favori, association manuelle, exclusion conservée après rescan, chemins
externes, conversion v1→v2, refus de chemin sortant, dossier manquant sans création,
annulation d’un conflit unique. Test À propos adapté au presse-papiers et au bouton
avec bordure, thèmes clair/sombre et format compact.

Validation finale : `bash tools/lot4/check.sh` réussi : 193 tests du cœur, 48 tests
Flutter et 4 tests de versionnement ; analyses sans anomalie, formatage/diff
conformes. Parseur PowerShell 7.5.4 : packaging valide. Les déplacements réels de
répertoires ont été testés sous Linux ; la recette Windows (autre emplacement ou
disque, chemins et Explorateur) reste à confirmer au prochain build. Aucun build
distribuable lancé ici. Le prochain mineur sera réservé automatiquement.


## Correction CI Windows : alias de chemins courts/longs — 30 octobre 2026

Les logs fournis logs_111457984147.zip (run du 30 octobre, commit f86ade4) montrent
quatre échecs dans les tests de déplacement avant toute construction du paquet.
La racine canonique contient Users/runneradmin tandis que les références de test
utilisent Users/RUNNER~1. Le changement de racine ne reconnaissait pas cet alias
8.3 ; le test de collision ne produisait donc pas la collision attendue. Deux autres
assertions comparaient des chaînes de chemins équivalents mais écrits différemment.

Les formes canonique et effectivement utilisée de la racine sont désormais
mémorisées dans portable_root_aliases_v1 (local_settings), après vérification de
leur identité physique. Elles sont mises à jour dans la même transaction que les
liens et la racine. Le réécrivain pur portable_paths.dart reconnaît ces racines
connues, les URI, la casse et les séparateurs Windows, avec frontière de dossier ;
il ne devine aucun alias après disparition de la source et préserve les suffixes
encodés, les noms et les références extérieures. La racine canonique reste la
destination. Aucun changement de seed, de schéma SQLite ou de dépendance.

Les tests de déplacement prennent la destination canonique, vérifient l’identité
physique des dossiers et préparent la collision sous la forme canonique réellement
produite. La protection contre collision n’est pas retirée. Un test portable
supplémentaire reproduit RUNNER~1/runneradmin et un changement de disque, accents,
espaces/#/%, casse, séparateurs et frontières de répertoire, même sous Linux.

Validation : `bash tools/lot4/check.sh` réussi sous Linux : 194 tests du cœur,
48 tests Flutter, 4 tests de versionnement ; analyses sans anomalie, formatage et
diff conformes. Les scénarios Windows synthétiques s’exécutent sans dépendance
au système hôte, mais ne remplacent pas la prochaine exécution de la CI Windows.
Pas de build distribuable ni de nouvelle réservation de version ici.


## Téléchargement explicite depuis le journal — 30 octobre 2026

Demande utilisateur et avenant au cahier des charges : MP3 absent → Télécharger.
Les 716 URL MP3 sont déjà présentes dans journal_json du seed, toutes en HTTP
sur rendezvousavecmrx.free.fr ; elles correspondent actuellement à mp3_url des TXT.
Le nouveau champ DesktopEpisode.downloadUrl provient exclusivement du journal.
Pas de migration, régénération de seed ni nouvelle dépendance. Majeur 5 inchangé.

Service partagé Mp3Download (dart:io) : URL HTTP/HTTPS sans identifiants, nom de
fichier système validé (pas de traversée/ADS/nom Windows réservé), réception
streamée dans un sous-dossier .index-download-* du dossier cible. Taille limitée
à 512 Mio, délais connexion/en-tête/inactivité de 20 s, annulation explicite.
Redirections bornées à cinq, pas de schéma non HTTP(S) ni rétrogradation HTTPS→HTTP.
Pas de compte, cookie ajouté, secret, authentification ou envoi du suivi/favoris.
Content-Disposition n’impose jamais le nom. Refus HTTP non 200, page texte/HTML/JSON,
dépassement de taille et longueur annoncée incohérente. Vérification de deux trames
MPEG Layer III consécutives après éventuel en-tête ID3 ; aucune utilisation de COMM.
C’est un contrôle de format, pas un décodage intégral ni une preuve d’identité du
contenu. Les quatorze fixtures existantes passent ce contrôle en lecture seule.

Publication Windows injectée par callback : MoveFileExW avec WRITE_THROUGH, sans
REPLACE_EXISTING. Le parent cible doit être physiquement le parent du dossier
temporaire (.index-download-*/payload.part), y compris si des alias 8.3 existent.
Aucune copie de gros tampon via MethodChannel. Une cible apparue pendant la réception
est refusée, pas écrasée. Nettoyage du répertoire temporaire à erreur/annulation ;
un résidu après arrêt brutal/échec de nettoyage n’a pas l’extension MP3 et n’est
jamais associé. La recette Windows inclut publication puis conflit sans écrasement.

AppModel : transfert séparé de busy pour préserver lecteur/navigation, unique par
session, progression/annulation affichées dans LibraryPage. Réglages de stockage
et scans bloqués pendant transfert, statuts/favoris restent utilisables. Fermeture :
annulation puis attente avant sauvegarde, pas de nouveau job pendant la fermeture ;
échec de sauvegarde rétablit la possibilité d’utiliser l’application. Pas d’auto-play.
Le scan associe normalement le nom système (révision du 31 octobre) ; l’action explicite peut lever une
exclusion, avec confirmation UI si un ancien choix manuel indisponible est remplacé.
Le suivi est conservé. Si l’association échoue après publication, garder le MP3 et
l’indiquer. Android reste désactivé pour cette action en attendant la publication SAF ;
réseau/validation sont partagés et la publication est une interface injectée.

À propos : Brand.showSubtitle=false seulement dans ce panneau. Texte sur le mode
hors ligne adapté à l’accès réseau facultatif, sans changement des autres fonctions.

Tests locaux : serveur HTTP loopback, succès, redirection, HTTP 404, HTML, fichier
tronqué de format, limite de taille, boucle de redirection, cible préexistante ou
concurrente, annulation d’un flux suspendu et nettoyage ; aucune récupération du
corpus public. Tests modèle/UI : source journal distincte du TXT, suivi conservé,
progression, annulation/retry, choix du dossier absent, bascule Écouter sans auto-play,
erreur URL et fermeture immédiate. Le smoke test Windows vérifie l’API native.

Sonde réelle limitée à HEAD sur une URL du journal : réponse 403 via envoy dans
l’environnement cloud. Cela ne qualifie ni la disponibilité du serveur depuis
Windows ni le succès d’un téléchargement réel. Aucun contournement, proxy intégré
ou téléchargement distant de MP3 réalisé. Recette Windows nécessaire après build.

Validation : `bash tools/lot4/check.sh` réussi (204 tests du cœur, 51 tests Flutter,
4 tests de versionnement). Après ajout du verrou de fermeture, analyse Flutter
à nouveau sans anomalie et les 51 tests Flutter réussis. Formatage/diff conformes.
Le test UI couvre aussi le choix du dossier quand aucun MP3 n’est configuré.
Publication native, HTTP réel et lecteur sur MP3 reçu restent à qualifier sur
Windows : pas de compilation Windows ni de récupération depuis le serveur public
sur cette machine Linux. Aucun build distribuable ni réservation de version ici.

### Révision du 31 octobre — nom système et panneaux

DesktopEpisode expose system_name du catalogue. Le téléchargement publie le fichier
validé directement sous ce nom, avec la même publication atomique sans écrasement ;
le nom d’origine reste une référence documentaire. Un nom système absent/invalide
est refusé. Aucun fichier existant renommé et aucun lancement du Lot 5 bis.
Le test modèle vérifie le nom système, le suivi conservé et le refus d’une cible
existante sans nouvelle requête réseau. À propos : logo/version/GitHub sur une ligne,
version avant GitHub, groupe ancré à droite ; site source en texte simple. Paramètres :
taille du corps harmonisée et description de reprise alignée sous son libellé.

Vérification Linux : 204 tests Dart, 51 tests Flutter et 4 tests Python réussis ;
analyses statiques et formatage conformes. Les tests À propos couvrent les deux
thèmes et la fenêtre étroite ; l’alignement de la description de reprise est
vérifié. Publication native et téléchargement réel restent à confirmer dans le
prochain build Windows.


## Révision lecteur — 31 octobre 2026

Un glissement utilisateur pendant lecture vers le terme ou la dernière seconde
arme une validation à réception de la fin moteur, comme l’avance clavier au terme.
Playback.seekFromPlayer est distinct de seek (programmatique), et ne valide ni
le placement seul ni un déplacement en pause. Un nouveau seek réinitialise
la demande de fin. L’enchaînement automatique exclut les épisodes ECOUTE dans
l’ordre visible, y compris en aléatoire ; les commandes manuelles restent libres.
Reset global : pause/libération, backup, transaction complète des positions et
états, marqueurs causaux de reset et favoris préservés. Un abandon avant confirmation
ne modifie rien ; une erreur SQLite annule les états et versions ensemble.
