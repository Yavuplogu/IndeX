# IndeX — diagnostic Android Lot 6A

APK ARM64 pour Android 7.0 ou plus récent. Il s’agit du socle de diagnostic,
pas du portage complet : renommage, import/export JSON et téléchargement Android
sont encore indisponibles ; la lecture se met en pause en quittant l’application.
Aucun MP3 n’est embarqué. Préparer un dossier de **copies** de MP3 avec les noms
historiques ou système du catalogue. Les tags COMM ne participent pas au scan.

## Récupérer et utiliser l’APK

Après commit/push des changements, GitHub → Actions → Verification Android Lot 6A
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
