# Distribution Android — Lot 6D

Le dernier 6C est validé par l’utilisateur le 4 novembre 2026. Le 6D prépare un
APK **release bêta 0.6**, sans publication automatique. Une compilation réussie
ne remplace pas la recette de cet APK sur téléphone : voir [la fiche 6D](RECETTE_6D.md).

## Deux modes dans GitHub Actions

Dans **Actions → Verification Android Lot 6D → Run workflow**, choisir :

- **diagnostic** (par défaut) : APK debug et clé de test mise en cache, comme au 6C ;
- **release** : APK AOT ARM64, signé avec votre clé durable. Ce mode refuse une
  configuration absente, une signature incorrecte et une permission imprévue.

Les deux modes restent manuels, partagent le compteur/verrou Windows et consomment
un nouveau mineur, même en échec. Aucun changement de majeur ou passage en finale.
L’APK exige Android 7/API 24 minimum, cible API 36 et un appareil ARM64.
Identifiant conservé : `fr.index.index_windows`. Aucun Google Play/AAB requis.

En release, télécharger l’artefact `IndeX-<version>-Android-arm64-release` : APK,
SHA-256, rapport de contrôle, provenance du build, notices de licences, notes,
ce guide et fiche de recette. L’artefact n’est pas
une GitHub Release publique. Le workflow ne publie rien et n’inclut jamais le keystore.
Les APK diagnostic restent identifiés `IndeX-<version>-Android-arm64-test`.

## Créer et conserver la clé durable

À faire sur une machine de confiance avec le JDK (`keytool`), **hors du dépôt**.
Cette clé Android peut être autosignée : aucun achat de certificat n’est requis.
Elle ne signe pas l’exécutable Windows.

```text
keytool -genkeypair -v -keystore index-android-release.jks -alias index-release -keyalg RSA -keysize 3072 -validity 10000
keytool -list -v -keystore index-android-release.jks -alias index-release
```

Les mots de passe sont demandés par `keytool`, sans les inscrire dans la commande.
Avec le format PKCS12 par défaut, utiliser le même mot de passe de clé et de magasin.
Choisir un nom distinct de `Android Debug`. Conserver le fichier, l’alias et les
mots de passe dans **deux sauvegardes sécurisées indépendantes**. La perte de la clé
empêche les mises à jour compatibles ; GitHub Secrets n’est pas une sauvegarde.
Ne pas joindre la clé à cette conversation, ne pas la committer ni la publier.

Dans **Settings → Secrets and variables → Actions**, ajouter ces repository secrets :

| Secret | Valeur |
| --- | --- |
| `INDEX_ANDROID_KEYSTORE_BASE64` | Fichier keystore encodé en Base64, contenu complet |
| `INDEX_ANDROID_STORE_PASSWORD` | Mot de passe du magasin |
| `INDEX_ANDROID_KEY_ALIAS` | `index-release` si vous avez suivi l’exemple |
| `INDEX_ANDROID_KEY_PASSWORD` | Mot de passe de cette clé |

Ajouter la **variable Actions** `INDEX_ANDROID_CERT_SHA256` : empreinte SHA256 du
certificat affichée par `keytool -list`, avec ou sans deux-points. Cette empreinte
est publique et permet de refuser un autre signataire. La modifier exige une
revue explicite de la continuité des mises à jour, pas une rotation improvisée.

Exemple Windows PowerShell pour placer le Base64 dans le presse-papiers, depuis le
dossier sécurisé de la clé (le coller uniquement dans le secret Actions) :

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path .\index-android-release.jks))) | Set-Clipboard
```

Le runner décode dans `RUNNER_TEMP` avec droits 0600, puis retire le fichier même
en échec. Aucun cache de clé release, affichage de mot de passe ou repli debug.
L’accès en écriture aux workflows et aux secrets doit rester limité aux personnes
de confiance. Exécuter la release sur une révision relue et contrôlée du dépôt.

## Passer des tests à la signature durable

Android refuse une mise à jour du même identifiant avec un certificat différent.
La première release ne peut donc généralement pas remplacer l’APK debug actuel.
**Avant toute désinstallation**, exporter le suivi JSON vers un dossier extérieur
à l’application et le vérifier. Copier également ailleurs tous les MP3 du dossier
privé « IndeX · MP3 » : ils sont supprimés à la désinstallation, comme le profil.
Les MP3 d’un dossier externe choisi par SAF restent à leur emplacement.

Après sauvegarde, réinstaller avec la clé durable si nécessaire, rechoisir le
dossier MP3 puis importer/fusionner le JSON. Les droits SAF devront être redonnés.
Ne pas désinstaller pour les mises à jour release suivantes : même identifiant,
même certificat et versionCode supérieur doivent conserver profil et droits.
Cela doit être vérifié sur téléphone avant diffusion élargie.

## Contrôles et installation

Vérifier le SHA-256 de l’APK avec `Get-FileHash -Algorithm SHA256` (Windows) ou
`sha256sum` (Linux), et le comparer au fichier `.sha256`. Ce hash contrôle les
altérations de fichier ; le certificat de confiance contrôle son signataire.

Le rapport `release-apk.json` contient SHA-256 APK/catalogue/certificat, versionName,
versionCode et permissions autorisées. Le contrôle utilise `apksigner verify`,
vérifie l’identité, API 24/36, absence de debuggable/testOnly, sauvegarde automatique
désactivée, code AOT ARM64, notices et catalogue exact, aucun MP3/profil/keystore.
Il ne prétend pas valider les comportements sur appareil ni l’absence de tous
les défauts possibles.

Transférer l’APK au téléphone, autoriser l’installation depuis cette source si
Android le demande puis l’ouvrir. Les avertissements Android d’installation hors
store peuvent subsister ; la signature ne les supprime pas automatiquement.
Une mise à jour via ADB se fait avec `adb install -r <apk>` ; ne jamais utiliser
une désinstallation automatique pour contourner une erreur de signature.

## Permissions, réseau et licences

Aucun package runtime ajouté au 6D. Les composants déjà retenus et leurs licences
figurent dans `docs/lot5/dependances.json`, les lockfiles et les notices Flutter
`NOTICES.Z` de l’APK. L’icône GitHub Octicons conserve sa notice MIT. Les API Android
MediaPlayer/MediaSession/SAF sont fournies par le système, pas redistribuées.
Le contrôle vérifie la présence des notices, pas une certification juridique des
contenus documentaires ou MP3 externes. Le dépôt n’a pas de licence globale à sa
racine ; aucune licence de réutilisation du code n’est inventée par ce lot.

Permissions fusionnées autorisées :

| Permission | Usage |
| --- | --- |
| INTERNET | Téléchargement MP3 explicite |
| ACCESS_NETWORK_STATE | Dépendance Android du moteur audio Flutter existant |
| FOREGROUND_SERVICE / FOREGROUND_SERVICE_MEDIA_PLAYBACK | Lecture en arrière-plan |
| WAKE_LOCK | Lecture/checkpoint lorsque l’écran s’éteint |
| `fr.index.index_windows.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | Récepteurs internes AndroidX, permission propre à l’application |

Pas de lecture des appels, permission globale de stockage ou accès contacts.
Le fournisseur documentaire exposé est protégé par MANAGE_DOCUMENTS ; le service
média n’est pas exporté. Le profil privé n’est pas exposé par ce fournisseur.
`allowBackup=false` désactive la sauvegarde Android automatique du profil.

La revue des points d’entrée du code ne relève pas de télémétrie ni de serveur
IndeX. Le catalogue, recherche, écoute et fusion fonctionnent hors ligne. Un
fournisseur SAF distant peut cependant faire ses propres accès réseau. Le bouton
Télécharger utilise les URL du catalogue, avec redirections contrôlées. Le HTTP
clair est autorisé seulement pour `rendezvousavecmrx.free.fr` par la configuration
Android ; cela n’apporte pas les garanties TLS d’une connexion HTTPS. Aucun audit
par capture réseau sur téléphone n’a été réalisé dans le cloud. Le système Android,
son installateur et ses protections peuvent eux-mêmes communiquer indépendamment.

## Publication ultérieure

Après recette, une publication GitHub explicite pourra joindre cet APK, son hash,
les notes et le rapport de signature. Pas de clé privée. Les notes doivent préciser
bêta, Android 7+/ARM64, téléchargement facultatif, renommage Windows uniquement,
sauvegarde avant changement de certificat et limites des appareils réellement testés.
La publication et un changement de version majeure/finale exigent une instruction distincte.
