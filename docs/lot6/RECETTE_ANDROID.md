# IndeX — diagnostic Android Lot 6B

APK ARM64 pour Android 7.0 ou plus récent. Il s’agit du socle de diagnostic,
pas du portage complet : téléchargement local, import/export JSON et renommage
dans le dossier géré IndeX sont maintenant disponibles. La lecture se met encore
en pause en quittant l’application (Lot 6C).
Aucun MP3 n’est embarqué. Préparer un dossier de **copies** de MP3 avec les noms
historiques ou système du catalogue. Les tags COMM ne participent pas au scan.

## Récupérer et utiliser l’APK

Après commit/push des changements, GitHub → Actions → Verification Android Lot 6B
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
   progression sans nouveau sélecteur. La pause en arrière-plan est attendue ici.
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
3. **Renommage** : Fichiers → Utiliser le dossier MP3 IndeX. Confirmer la limite
   de stockage privé (MP3 supprimés à la désinstallation). Avec le gestionnaire
   Android, copier quelques MP3 au nom historique dans un sous-dossier de test
   de IndeX · MP3, puis choisir ce sous-dossier dans IndeX. Paramètres → aperçu
   du renommage : vérifier avant/après, confirmer, vérifier lecture et suivi.
   Ajouter une copie au nom système identique pour vérifier le refus de collision.
   Dans un autre fournisseur, l’aperçu doit expliquer le refus sans changer les noms.
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

Préparer un **sous-dossier de copies** dans IndeX · MP3, contenant au moins un
fichier au nom historique exact du catalogue. Le test renomme réellement ces
copies et conserve leurs octets ; il crée un profil de recette temporaire isolé.
Le fichier JSON externe choisi reste sur le téléphone ; le profil temporaire est
supprimé à la fin. Le sélecteur demande d’abord le sous-dossier MP3, puis un
emplacement externe pour le JSON.

```sh
python3 tools/lot4/prepare_assets.py
cd apps/index_windows
flutter pub get --enforce-lockfile
flutter test integration_test/android_storage_test.dart -d <identifiant-appareil> --dart-define=INDEX_CONFIRM_RENAME_COPIES=true
```

Relancer sur un jeu de copies originales restauré : le test exige un renommage
à effectuer et ne remet pas les noms en sens inverse. Ce test ne remplace pas les
essais d’arrêt brutal, de fournisseur externe et l’échange physique avec Windows.


### Régression export JSON EACCES (3 novembre 2026)

Installer le nouvel APK en mise à jour, sans effacer les données. Exporter le suivi :
le sélecteur de destination externe doit s’ouvrir sans erreur `link failed`.
Enregistrer une copie et vérifier l’import sur Windows. Annuler un deuxième export :
la copie interne et le suivi restent conservés. Le test physique automatisé vérifie
également qu’une cible privée existante n’est pas écrasée. Retester téléchargement
et renommage sur copies dans IndeX · MP3 : ils utilisaient la même primitive refusée.
