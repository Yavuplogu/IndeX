# IndeX — diagnostic Android Lot 6C

APK ARM64 pour Android 7.0 ou plus récent. Il s’agit du socle de diagnostic,
pas du portage complet : téléchargement local et import/export JSON sont disponibles.
Le renommage est réservé à Windows. Le Lot 6C ajoute le service média pour la lecture
écran éteint et en arrière-plan, à qualifier sur téléphone avec la recette ci-dessous.
Aucun MP3 n’est embarqué. Préparer un dossier de **copies** de MP3 avec les noms
historiques ou système du catalogue. Les tags COMM ne participent pas au scan.

## Récupérer et utiliser l’APK

Après commit/push des changements, GitHub → Actions → Verification Android Lot 6C
→ Run workflow sur la branche contenant le lot. Rien n’est lancé automatiquement.
Le résultat contient IndeX-<version>-Android-arm64-test : APK, empreinte SHA-256,
rapport de contenu et ce guide. L’APK est signé pour le développement ; conserver
le profil existant et sa sauvegarde avant toute réinstallation. L’identité et la
clé doivent correspondre pour une mise à jour sans désinstallation.

Sur le téléphone, autoriser l’installation depuis la source utilisée, ouvrir
l’APK puis IndeX. Aucun ordinateur/Flutter nécessaire pour les vérifications
manuelles suivantes. Ne pas choisir un fournisseur cloud pour un essai hors ligne.

1. Sans MP3 et en mode avion : consulter les 716 épisodes et leurs fiches, chercher
   « Yougo » puis un terme présent dans les sources ; vérifier les résultats.
2. Choisir le dossier de copies via le sélecteur Android (éviter les racines
   interdites par Android). Vérifier scan récursif, correspondances et diagnostic.
3. Lire un fichier, pause, volume, seek et reprise. Répéter avec les huit fichiers
   de MP3_Files/MP3_Bugs copiés sur le téléphone ; noter toute erreur, le modèle
   du téléphone, sa version Android et la latence perçue.
4. Quitter/revenir, puis redémarrer le téléphone : retrouver le dossier et la
   progression sans nouveau sélecteur. La lecture doit continuer en arrière-plan (voir recette 6C).
5. Révoquer l’accès au dossier, rouvrir : un diagnostic doit signaler le problème
   sans supprimer favoris/suivi. Choisir à nouveau le dossier et vérifier la reprise.

Transmettre les résultats de chaque point, modèle/version Android et erreurs
exactes. Une réussite sur un téléphone ne qualifie pas toutes les versions.
Matrice souhaitée : une cible API 24–28, une API 30–33, une API 34–36 ; au minimum
un appareil physique récent avant 6B, puis couverture complète avant distribution.

## Test automatisé supervisé sur téléphone USB

Pour un poste de développement avec Flutter épinglé, SDK Android et USB debugging :

```sh
python3 tools/lot4/prepare_assets.py
cd apps/index_windows
flutter pub get --enforce-lockfile
flutter devices
flutter test integration_test/android_feasibility_test.dart -d <identifiant-appareil>
```

Le test ouvre un sélecteur : choisir un dossier de copies contenant au moins un
épisode du catalogue de plus de trente secondes. Le profil de recette est créé
dans un sous-dossier privé temporaire et supprimé à la fin ; les MP3 sont lus
uniquement. L’autorisation SAF accordée au dossier reste accordée à l’application.
Pour choisir précisément un MP3 (nom historique ou système, extension comprise) :

```sh
flutter test integration_test/android_feasibility_test.dart -d <identifiant-appareil> --dart-define="INDEX_TEST_MP3_NAME=2007-10-20 Le Zimbabwe _ la Rhodésie du Sud (1 sur 2).mp3"
```

Ce test vérifie la progression et le seek, mesure le délai de la commande, puis
réouvre le profil et rescane sans sélecteur. Il ne valide pas la latence audible,
la résistance à un redémarrage physique ni la lecture écran éteint. Ne pas
l’exécuter sur Linux en le présentant comme une recette Android.

## Construction intermédiaire locale

Configurer JAVA_HOME, ANDROID_HOME et les caches écrivable hors dépôt, puis
activer Flutter et exécuter `bash tools/lot5/build_android.sh`. Le script contrôle
le contenu de l’APK. Sans variables INDEX_VERSION/INDEX_BUILD_NAME/INDEX_BUILD_NUMBER,
c’est une compilation de développement, pas une nouvelle distribution numérotée.
Dans le cloud, GRADLE_USER_HOME et ANDROID_USER_HOME doivent être dans un dossier
écrivable. Utiliser une seule méthode de configuration des préférences Android.
Si nécessaire, fournir à Java le magasin de confiance système via
-Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts ; ne jamais désactiver TLS.


Depuis la décision du 1er novembre 2026, Windows se lance également uniquement
à la demande. Un push ne lance aucun des deux workflows. Si Windows est déjà
en cours, Android attend encore sa fin : le verrou de version reste commun.
Pour libérer la file immédiatement, le propriétaire peut annuler l’exécution
Windows en cours depuis Actions → exécution → Cancel workflow. Son numéro déjà
réservé reste consommé. Changer les déclencheurs n’annule aucune exécution existante.


## Recette Lot 6B — copies uniquement

La validation utilisateur du 2 novembre a confirmé 6A. Pour 6B, noter le modèle,
la version Android, la version APK et les résultats séparément :

1. **Dossier externe** : resélectionner le dossier MP3 afin d’accorder l’écriture.
   Choisir un épisode absent, Télécharger, attendre la fin : nom système exact,
   bouton Écouter, suivi/favori conservés. Annuler un transfert avant la finalisation
   puis vérifier l’absence d’association. Une cible existante doit être conservée.
   Tester aussi un refus d’écriture et l’espace insuffisant sur des copies.
2. **Arrêt brutal** : interrompre le processus pendant un téléchargement puis
   une copie finale. Relancer avec/sans scan automatique : aucune copie non validée
   ne doit être proposée comme disponible ; diagnostics lisibles et suivi conservé.
   Vérifier le document concerné dans Fichiers Android, sans supprimer un original
   sous prétexte d’un diagnostic ambigu. Une copie réellement incomplète peut être
   retirée manuellement puis le dossier rescanné.
3. **Renommage indisponible sur Android** : ouvrir Paramètres → Fichiers audio.
   Vérifier la mention « Le renommage des MP3 est disponible uniquement sur Windows. »
   et le bouton de prévisualisation désactivé, même avec un dossier MP3 configuré.
   Aucune sélection de dossier géré n’est nécessaire pour cette vérification.
4. **Windows → Android** : exporter un suivi Windows, transférer le JSON via USB
   ou copie manuelle. Android → Paramètres → Importer et fusionner : choisir le
   fichier, vérifier la provenance Windows et l’aperçu, annuler une première fois,
   puis confirmer. Écoute liée et favori indépendant ; vérifier backup et chemins
   MP3 locaux conservés. Réimporter : aucun effet supplémentaire.
5. **Android → Windows** : exporter depuis Android, choisir un emplacement externe
   (Documents/Téléchargements ou support local, pas le fournisseur MP3 qui ne crée
   que des MP3/dossiers). Le fichier proposé est IndeX_suivi_AAAAMMJJ_HHMMSS.json.
   Le retrouver dans le gestionnaire, le copier sur Windows, importer et vérifier
   la provenance Android, les états et les conflits. Modifier le suivi des deux
   côtés pour éprouver les choix et le retour après résolution. Tester aussi un
   JSON tronqué : refus sans perte des favoris/progressions.

Les données et les MP3 du dossier **IndeX · MP3 sont privés**, malgré leur visibilité
dans le gestionnaire via le fournisseur SAF. Les fichiers d’un dossier externe
choisi par l’utilisateur ne sont pas supprimés par la désinstallation d’IndeX.
Toujours exporter le suivi et copier les MP3 gérés ailleurs avant désinstallation.
Les APK restent de diagnostic : une ancienne signature différente peut exiger une
réinstallation ; ne pas accepter cette opération sans préserver les données.
La CI conserve désormais sa clé debug en cache pour les prochaines mises à jour
de diagnostic ; cela ne restitue pas une ancienne clé perdue et n’est pas une
signature de distribution finale.

### Test physique automatisé de 6B (poste de développement)

Préparer un dossier de copies contenant au moins un MP3 reconnu du catalogue.
Le test scanne ce dossier, vérifie le refus du renommage sans changement de fichier,
puis l’export/import JSON et la conservation du suivi dans un profil temporaire isolé.
Le JSON externe choisi reste sur le téléphone ; le profil temporaire est supprimé
à la fin. Le sélecteur demande d’abord le dossier MP3, puis la destination du JSON.

```sh
python3 tools/lot4/prepare_assets.py
cd apps/index_windows
flutter pub get --enforce-lockfile
flutter test integration_test/android_storage_test.dart -d <identifiant-appareil>
```

Le test est relançable sans restaurer les noms des copies : aucun renommage n’est
exécuté. Il ne remplace pas les essais d’arrêt brutal, de fournisseur externe et
l’échange physique avec Windows.


### Régression export JSON EACCES (3 novembre 2026)

Installer le nouvel APK en mise à jour, sans effacer les données. Exporter le suivi :
le sélecteur de destination externe doit s’ouvrir sans erreur `link failed`.
Enregistrer une copie et vérifier l’import sur Windows. Annuler un deuxième export :
la copie interne et le suivi restent conservés. Le test physique automatisé vérifie
également qu’une cible privée existante n’est pas écrasée. Retester le téléchargement sur copies dans IndeX · MP3 : il utilisait la même
primitive refusée. Le renommage Android a depuis été désactivé.


### Fluidité et suivi pendant lecture/pause (3 novembre 2026)

Sur téléphone, faire défiler une liste longue puis un résumé long, successivement
sans lecture, en lecture, en pause et après Arrêt. Refaire avec une recherche active.
La progression du lecteur, le remplissage de la ligne et le pourcentage de la fiche
doivent rester actualisés pendant l’écoute sans saccades liées aux ticks globaux.
En pause, l’horodatage reste stable. Consulter une autre fiche puis revenir, changer
de piste sans changer de fiche : les pourcentages sauvegardés restent cohérents.
Après plus de cinq secondes de lecture, terminer brutalement le processus puis
relancer : reprise au dernier checkpoint. Après Pause, la reprise conserve la
position de pause. Vérifier les filtres En cours/Écouté lors du début et de la fin,
le seek au terme, l’arrêt/reset et l’enchaînement. Recette Windows également requise
pour ces parcours partagés ; ne pas déduire une validation physique des tests Linux.


### Paysage Android et caractères agrandis (3 novembre 2026)

Retour utilisateur : les points de vérification précédents sont validés sur son
appareil, sauf l’adaptation à l’écran. Les bandes jaunes/noires signalées en
paysage sont un débordement Flutter ; elles ne doivent pas être simplement masquées.

En paysage, la recherche et ses champs occupent une colonne gauche (3/8 de la
largeur), les épisodes une colonne droite plus large (5/8). Les filtres de tri et
d’état sont sur la ligne Bibliothèque/Favoris ; le compteur reste juste dessous.
Les libellés longs des filtres sont tronqués dans le bouton si nécessaire, avec
leur texte complet dans le menu. La recherche est indépendante du défilement des
épisodes ; sa colonne reste défilable séparément si le texte agrandi dépasse sa
hauteur. Les lignes Android grandissent avec la taille de police système.

À confirmer sur téléphone avec et sans lecture, thèmes clair/sombre :
- Tourner en paysage : les épisodes sont visibles, aucun débordement rayé.
- Faire défiler les épisodes : le cadre de recherche reste à sa place.
- Chercher un terme, changer les champs et les filtres, ouvrir une fiche.
- Tourner en portrait puis revenir : saisie, critères et suivi restent conservés.
- Refaire avec caractères système agrandis et avec le clavier affiché.
La présentation Windows et l’organisation portrait restent conservées. Cette
correction ne comprend pas la lecture en arrière-plan ni les notifications 6C.


## Recette Lot 6C — service média, écran verrouillé et interruptions

6B et le paysage sont validés par l’utilisateur le 3 novembre. Cette recette porte
sur les changements 6C, après construction du nouvel APK et mise à jour conservant
l’identifiant/signature/profil. Noter version APK, téléphone, version Android et
réglage de batterie. Les tests Linux et la compilation ne valident pas ces points.

1. Lire plusieurs minutes, revenir à l’accueil Android et ouvrir une autre application :
   le son continue, une notification média IndeX affiche titre/date et les commandes.
   Appuyer sur Retour depuis la bibliothèque avec une piste chargée : la tâche passe
   en arrière-plan ; pas d’arrêt/reset ni fermeture du profil.
2. Verrouiller le téléphone au moins dix minutes. Contrôler pause/reprise, précédent,
   suivant et déplacement dans la piste depuis les commandes disponibles sur cet
   Android. Certains skins choisissent quels boutons montrer. Pause répétée ne
   relance pas la lecture ; arrêt remet progression et statut à zéro. Le titre/date
   et la progression système correspondent au lecteur, pas à la fiche consultée.
3. Toucher la notification : retrouver la même écoute, le suivi et les filtres sans
   nouvelle configuration, erreur de verrou ni deuxième lecteur. Tourner l’écran,
   ouvrir d’autres fiches et vérifier thèmes et paysage. Répéter après une mise en
   arrière-plan prolongée ; si Android a détruit le service inactif, Lecture réouvre
   le fichier depuis le checkpoint. Aucun autoplay imposé au redémarrage du processus.
4. Pendant une écoute, recevoir un appel, démarrer un autre lecteur puis débrancher
   un casque filaire/déconnecter le Bluetooth : pause immédiate, position sauvegardée.
   Reprise explicite seulement ; aucune reprise automatique après l’appel/reconnexion.
   Vérifier aussi les boutons du casque, la priorité audio refusée et une source
   inaccessible : erreur sélectionnable et absence de lecture concurrente.
5. Écran verrouillé, atteindre la fin naturellement puis après seek vers la dernière
   seconde : Écouté, suivi durable et suivant disponible/non écouté. Tester aléatoire,
   précédent/suivant manuels et auto-suivant désactivé. Revenir dans IndeX et vérifier
   le pourcentage, la fiche et les statuts ; réécouter un épisode terminé.
6. Après plus de cinq secondes en arrière-plan, forcer l’arrêt du processus puis
   rouvrir : reprise au dernier checkpoint confirmé, favoris conservés. Force-stop
   arrête le son et la notification ; pas de relance automatique du service.
   Enlever l’application des tâches récentes sans force-stop : la lecture continue
   si Android ne termine pas lui-même le processus. Ne pas promettre la survie à
   une action système explicite d’arrêt ou à toutes les politiques constructeur.
7. Faire une pause prolongée : pas de verrou CPU conservé après sauvegarde. Tester
   d’abord le réglage de batterie standard, puis documenter toute restriction du
   constructeur. Ne pas demander automatiquement d’exemption batterie globale.
   L’app utilise une notification MediaStyle/MediaSession, exemptée de la demande
   POST_NOTIFICATIONS des notifications ordinaires sur Android 13+ ; vérifier les
   réglages média du téléphone si les commandes sont masquées par l’utilisateur.
8. Régression Windows : lecture, pause, arrêt, seek/fin, aléatoire/suivant, fermeture,
   reprise et JSON restent identiques. API Android 24–28, 30–33 et 34–36 à couvrir
   avant diffusion 6D ; consigner chaque appareil réellement testé.

### Test supervisé de progression en arrière-plan (poste de développement)

Choisir un dossier de copies contenant au moins deux MP3 reconnus, de plus de vingt
secondes. Aucun MP3 n’est modifié ; le test utilise un profil temporaire, sauvegarde
la progression en arrière-plan, saute au terme pour vérifier le suivant, puis pause.
Il ne remplace pas les commandes réelles du verrouillage, les appels ou Bluetooth.

```sh
python3 tools/lot4/prepare_assets.py
cd apps/index_windows
flutter test integration_test/android_background_audio_test.dart -d <identifiant-appareil>
```

Pour diagnostiquer sur un poste ADB : `adb shell dumpsys media_session`,
`adb shell dumpsys activity services fr.index.index_windows`, et
`adb logcat -v time` pendant la reproduction. Retirer les informations personnelles
avant partage. Une erreur FGS, une notification incorrecte ou un checkpoint absent
reste un échec de recette même si l’APK compile.
