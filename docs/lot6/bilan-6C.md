# Lot 6C — Lecture Android en arrière-plan et commandes système

Lancé explicitement le **3 novembre 2026**, après validation utilisateur de tous
les contrôles précédents, y compris le paysage corrigé. Cette validation est celle
de son téléphone ; elle ne remplace pas une matrice de versions Android. La recette
6C ci-dessous reste distincte, à exécuter avec le nouvel APK. 6D/signature finale et
Release GitHub ne sont pas lancés. Windows et le majeur bêta 0.6 sont conservés.

## Décisions et réalisation

Aucun nouveau package Flutter, Maven ou binaire tiers. Utiliser les API système
Android déjà disponibles dès API 24 : Service, MediaPlayer, MediaSession,
Notification.MediaStyle, AudioManager et PowerManager. Les branches API 26/29/33+
sont conditionnées à la version du système. API 36/ARM64, identité et signature de
diagnostic existantes restent conservées. Voir l’inventaire des dépendances.

### Un propriétaire du moteur audio et un propriétaire du suivi

- `IndexPlaybackService`, non exporté, possède MediaPlayer, MediaSession, la
  notification et le focus. Il fonctionne en foreground de type mediaPlayback
  pendant la lecture. Il lit les URI SAF opaques avec les grants existants ;
  aucun chemin déduit, MP3 copié ou modifié, réseau ou permission de stockage ajouté.
- `IndexEngine` conserve un seul FlutterEngine/isolate lors de la destruction de
  l’Activity. Sa réouverture rattache la vue au même moteur, donc au même AppModel
  et profil SQLite. Il n’y a pas de deuxième base ni de concurrence entre deux
  propriétaires des états/horloges JSON.
- `AndroidAudioBridge` appartient au moteur, pas à l’Activity. La partie stockage
  et sélecteurs reste raccordée à l’Activity courante. Aucun MediaPlayer n’est
  conservé ni libéré dans MainActivity.onStop/onDestroy.
- L’Activity n’est plus propriétaire de la durée de vie audio. La fermeture
  explicite sauvegarde, libère le lecteur, arrête le service et détruit le moteur.
  Retour racine avec piste chargée met la tâche en arrière-plan, même en pause ;
  sans piste, le parcours de fermeture sauvegardée reste conservé.

La suspension inconditionnelle Dart lors de hidden/paused/detached est remplacée
par un checkpoint sans pause, si le profil existe. Les cinq secondes et les
transitions de suivi restent en Dart. Les filtres, la fin/seek, la réécoute, le
favori, l’aléatoire et le suivant non écouté utilisent les mêmes fonctions que Windows.
Le service envoie aussi une impulsion de suivi à la seconde pendant la lecture ;
Playback protège les polls concurrents. Aucun timer de service ne reste actif en pause.

### CPU et durabilité

Le service garde un verrou CPU partiel pendant la lecture pour que le moteur et
les checkpoints Dart continuent écran éteint. Les pauses natives (focus, casque,
notification) arrêtent immédiatement le son puis demandent le checkpoint partagé.
Le verrou est libéré après confirmation de sauvegarde ; une sauvegarde qui échoue
ne produit pas de faux acquittement. Une pause UI sans confirmation a un garde-fou
à cinq secondes ; une commande système sans réponse est suspendue au plus tard
après son watchdog de 35 secondes. Ces bornes sont des garde-fous de ressource,
pas une promesse de sauvegarde si SQLite ou l’isolate sont bloqués.

En pause manuelle, le service quitte le foreground après sauvegarde et libère le focus/CPU ;
la notification média et la session restent disponibles tant que le service vit.
Android peut détruire ce service inactif : `backendLost` sauvegarde le dernier état
connu et libère la référence Dart pour réouvrir le fichier à la prochaine Lecture.
La libération de piste laisse le service réutilisable jusqu’à sa destruction par
Android/fermeture explicite, évitant une course stopSelf/nouvelle ouverture.

`START_NOT_STICKY` : aucun autoplay/restart à partir d’un état supposé après kill
ou force-stop. Après mort du processus, le prochain lancement reprend au dernier
checkpoint SQLite confirmé. Le service ne garantit pas la survie à un arrêt
explicite Android, à un manque de mémoire ou à toutes les politiques constructeur.
Aucune demande automatique d’exemption globale d’optimisation batterie.

### Commandes et présentation système

MediaSession + notification : titre/date, lecture/pause, arrêt, précédent/suivant,
seek et sauts de dix secondes si exposés par l’interface système/casque. Le choix
visuel des boutons sur le verrouillage dépend d’Android et du constructeur.
Toucher la notification ouvre IndeX via l’Activity existante ou une nouvelle vue
rattachée au moteur conservé, sans changer la fiche/listing ni la piste.

Les commandes sont sérialisées en Dart et attendent une ouverture engagée ainsi
qu’un poll déjà en vol. L’acquittement d’une fin ne doit pas précéder le checkpoint
et l’enchaînement déjà engagés par le timer Dart. Play et
Pause sont idempotents ; Arrêt remet à zéro via stopAudio ; précédent/suivant
respectent l’aléatoire et la fin utilise l’auto-suivant excluant les épisodes écoutés.
La préparation et les seeks restent asynchrones, leurs résultats remplacés sont
annulés ; les callbacks d’une ancienne instance MediaPlayer sont ignorés. Atteindre
le terme par seek ne doit pas relancer accidentellement le même MP3 à zéro.

Métadonnées republiées seulement au changement de source/durée, y compris réécoute
du même épisode. La session Android extrapole la position ; aucun rafraîchissement
global de l’UI ni publication de métadonnées à chaque tick à 250 ms. Les régions
PlaybackBuilder et les optimisations de fluidité sont conservées.

Depuis le correctif du 4 novembre, perte temporaire de focus (notification/appel) :
pause immédiate puis reprise à GAIN si la piste était en lecture et qu’aucun choix
manuel n’a annulé la réserve. Perte définitive ou ACTION_AUDIO_BECOMING_NOISY :
reprise explicite seulement, sans son inattendu au retour du casque.
La priorité audio doit être accordée avant start. Aucun accès aux contacts,
appels, périphériques Bluetooth ou SMS demandé pour cela.

Permissions nouvelles : FOREGROUND_SERVICE, FOREGROUND_SERVICE_MEDIA_PLAYBACK et
WAKE_LOCK. Pas de POST_NOTIFICATIONS : les notifications de session média suivent
l’exemption Android 13+, à vérifier sur les appareils retenus et leurs réglages.
Aucune permission Internet supplémentaire ; le téléchargement volontaire reste
la seule fonction propre à IndeX qui contacte le serveur source.

## Tests et preuves

Nouveaux tests Flutter : commandes venant du canal système, idempotence,
checkpoint/arrêt, seek au terme/suivant non écouté, navigation conservée, reprise
après perte du backend, sérialisation pendant ouverture, acquittement après
sauvegarde et absence d’acquittement sur erreur stockage. Le test widget vérifie
hidden/paused sans pause audio et Retour mettant en arrière-plan sans fermer SQLite.
Les anciens tests Windows, suivi, JSON, fichiers et paysage restent conservés.

Test natif supervisé : `integration_test/android_background_audio_test.dart`,
profil temporaire, dossier de copies, au moins deux MP3 reconnus de plus de vingt
secondes. Vérifie le service/wake lock, la progression SQLite après sept secondes
hors premier plan, la fin/suivant en arrière-plan et la pause durable. Il ne prouve
pas les commandes réelles du verrouillage ni les politiques de batterie.

La recette physique de RECETTE_ANDROID.md doit ensuite vérifier notification,
verrouillage prolongé, retour par notification, casque/Bluetooth/appels/autres
lecteurs, arrêt du processus, différentes versions Android et régression Windows.
Ne pas déduire cette qualification d’une compilation ou d’un test simulé.


## Vérifications exécutées le 3 novembre 2026

- Contrôles communs `tools/lot4/check.sh` : 7 tests Python et 257 tests Dart du
  cœur réussis ; formatage et analyses conformes. Après les derniers tests de
  concurrence/fermeture, la suite Flutter complète est relancée séparément :
  **86 tests réussis**, analyse `--fatal-infos` sans anomalie.
- `tools/lot5/build_android.sh` : APK debug ARM64 compilé avec les sources Kotlin
  réelles, seed/manifeste inchangés, aucun MP3 ou profil utilisateur embarqué.
  SHA-256 de l’APK intermédiaire local :
  `fe7348f16ea7ddf5bea4780403236d903ddb1ba7ac343ccafa14ea4416db0ba2`.
- Manifeste binaire de l’APK inspecté avec AAPT : service non exporté,
  stopWithTask=false, type mediaPlayback=0x2 ; permissions foreground/mediaPlayback
  et wake lock attendues, absence de POST_NOTIFICATIONS. XML conformes.
- Aucun lockfile ni catalogue modifié ; aucun nouveau package runtime. Le workflow
  Android reste uniquement manuel, renommé Verification Android Lot 6C ; même
  compteur/verrou et artefact versionné qu’auparavant. Aucun mineur de distribution
  réservé localement, aucun workflow GitHub ou publication déclenché ici.

Le test d’intégration natif est préparé et analysé, **pas exécuté sur un téléphone**
dans cet environnement. La validation physique 6C (verrouillage, contrôles système,
interruptions, consommation, recréation Activity) et la nouvelle recette Windows
native restent à réaliser. Les validations utilisateur 6A/6B/paysage sont conservées
mais ne constituent pas une qualification des nouveaux changements 6C.


## Correctif du 4 novembre — reprise après notification ou appel

Retour utilisateur : notifications et appels suspendent le lecteur sans reprise.
La première version 6C abandonnait le focus dans idle(), après toute perte de
priorité. Elle ne pouvait donc plus recevoir le GAIN attendu pour une interruption
passagère. Ce comportement historique exigeant une reprise manuelle est remplacé.

`AudioInterruptionPolicy` réserve la reprise d’une piste qui jouait avant un
LOSS_TRANSIENT ou LOSS_TRANSIENT_CAN_DUCK. Garder la demande de focus et le service
foreground pendant cette pause, sans conserver le verrou CPU après sauvegarde.
AudioAttributes SPEECH et setWillPauseWhenDucked(true) demandent une pause des
paroles plutôt qu’une baisse automatique du volume. Au retour GAIN, réacquérir
brièvement le CPU et reprendre par le canal partagé focusResume. Pas de permission
téléphone/Bluetooth ni de nouvelle dépendance ajoutée.

Le jeton et la révision de source sont revalidés juste avant la pause/reprise
native. Pause/arrêt manuel, seek, changement de source, déconnexion casque, erreur
et perte permanente annulent l’intention. Une piste déjà en pause ne repart pas.
Une nouvelle perte après GAIN invalide la reprise déjà mise en file. Les notifications
imbriquées conservent l’intention initiale ; GAIN avant l’acquittement de pause reste
ordonné par la file Dart. Une reprise refusée ne change pas l’état courant.

La reprise conserve épisode, position, favori et suivi : aucun open/reset à zéro,
polling relancé et checkpoint au retour. Les pertes définitives restent manuelles ;
la reprise d’un appel dépend de la restitution du focus par Android. Aucun polling
de l’état téléphonique ni READ_PHONE_STATE demandé. En cas d’erreur, les garde-fous
existants annulent la reprise et suspendent la lecture.


Vérifications du correctif : test JVM de la politique native réussi (gain, pause
préalable, notifications imbriquées, gain précoce, annulation et source différente),
16 tests ciblés puis **89 tests Flutter complets réussis**, formatage et analyse
`--fatal-infos` conformes. Le test JVM est ajouté à la CI Android après le JDK.
APK debug ARM64 compilé et inspecté, aucun MP3, seed inchangé ; SHA-256 local
`bdd7b756d2f24b01cd7163adef8575662c447959d78c22b0aab3d1736f70f3d7`.
Aucun mineur réservé localement, package ou permission ajouté, aucun workflow
GitHub déclenché. Les notifications/appels et la reprise écran éteint restent
à retester sur le téléphone : les callbacks Android réels ne sont pas qualifiés
par ces tests simulés/JVM. Le Lot 6D n’est pas lancé.


## Échec Windows du 4 novembre — libellé de filtre à la limite de largeur

Archive `logs_113401415949.zip`, version réservée 0.6.24 (code 25). Le cœur passe
(256 tests et un ignoré prévu sur Windows). La suite Flutter s’arrête avec un échec :
`episode_double_click_test.dart`, scénario Android simulé. Le scénario de double
clic Windows passe ; aucun nouveau binaire applicatif Windows n’est construit
après l’échec des contrôles.

Cause : Row du FilterMenu non contraint, avec libellé « MP3 · Disponibles d’abord »
plus flèche, à la limite de 350 px. Le runner Windows signale un dépassement de
0,000244 px. Les erreurs ultérieures « deactivated widget’s ancestor » surviennent
pendant la description du débordement après démontage du widget, et sont secondaires.

Le libellé est désormais Flexible sur une ligne avec ellipsis dans tous les modes,
et pas seulement dans la disposition paysage. La largeur reste compacte par défaut,
remplie en disposition contrainte. Le menu conserve les libellés complets et le choix
de tri. Aucune erreur de rendu n’est ignorée ni masquée. Le test d’ouverture Android
contrôle aussi l’absence d’exception avant de démonter la fiche.

Régression : avant correctif, le test de filtre à 200 px reproduit un débordement.
Après correction, largeurs 357,9997 / 358 / 200 px, ouverture et sélection du menu,
interaction Windows/Android, paysage et suite widget : **18 tests réussis** sous
Linux, analyse sans anomalie. Le dépassement fractionnaire spécifique Windows doit
être confirmé corrigé par la prochaine exécution de son workflow ; aucune nouvelle
qualification native Windows revendiquée ici. 0.6.24 reste consommé, sans reset du
compteur ni réservation locale supplémentaire.
