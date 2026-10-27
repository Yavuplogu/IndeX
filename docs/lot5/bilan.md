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

Les candidats media_kit/libmpv/FFmpeg du Lot 0 sont remplacés par des adaptateurs
système, derrière AudioPort :

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
entre fiches ne change pas la lecture. L’arrêt sauvegarde et conserve la position.
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
