> Recette 0.7.01 et mise à jour signée validées par l’utilisateur sur Pixel 9/10,
> OnePlus 15 (Android 17) et Galaxy S21 (Android 14). Aucune publication automatique.
> Le bouton GitHub ouvre le navigateur uniquement sur clic ; le programme ne
> contacte pas GitHub au démarrage ou pour vérifier des mises à jour.

> Décision du 5 novembre 2026 — série **0.7.01** : l’emplacement privé
> « IndeX · MP3 » est supprimé, ainsi que son bouton et le fournisseur Android.
> Aucun accès de récupération n’est conservé. Choisir un dossier MP3 visible
> dans le sélecteur Android. Aucun fichier existant n’est supprimé par ce retrait.
> Le stockage privé du profil (favoris, progression, réglages) reste nécessaire
> et distinct. Les exports JSON utilisent toujours une destination choisie.
> Identifiant `fr.index.app` et clé durable conservés.

# Distribution Android — Lot 6D

Le dernier 6C est validé par l’utilisateur le 4 novembre 2026. Le 6D prépare un
APK **release bêta 0.7**, sans publication automatique. Une compilation réussie
ne remplace pas la recette de cet APK sur téléphone : voir [la fiche 6D](RECETTE_6D.md).

## Deux modes dans GitHub Actions

Dans **Actions → Construction IndeX — version commune → Run workflow**, choisir
**Windows et Android** pour les deux livrables, ou **Android** pour l’APK seul.
Pour **android_mode**, choisir :

- **release** (par défaut) : APK AOT ARM64, signé avec votre clé durable. Ce mode refuse une
  configuration absente, une signature incorrecte et une permission imprévue.
- **diagnostic** : APK debug et clé de test mise en cache, comme au 6C.

Le lancement réserve un seul mineur pour toutes les plateformes sélectionnées,
même en cas d’échec ultérieur. **Re-run failed jobs** conserve la réservation
réussie ; un nouveau lancement ou **Re-run all jobs** en crée une nouvelle.
Les deux plateformes utilisent le même commit source. Série bêta actuelle 0.9,
sans passage en finale. Voir [le guide commun](../../tools/versioning/README.md).
L’APK exige Android 7/API 24 minimum, cible API 36 et un appareil ARM64.
Identifiant définitif depuis le 5 novembre 2026 : `fr.index.app`. Aucun Google Play/AAB requis.

En release, télécharger l’artefact `IndeX-<version>-Android-arm64-release` : APK,
SHA-256, rapport de contrôle, provenance du build, notices de licences, notes,
ce guide et fiche de recette. L’artefact n’est pas
une GitHub Release publique. Le workflow ne publie rien et n’inclut jamais le keystore.
Les APK diagnostic restent identifiés `IndeX-<version>-Android-arm64-test`.

## Créer et conserver la clé durable

Pour une première configuration depuis un PC Windows, suivre le
[guide pas à pas illustré par les commandes PowerShell](SIGNATURE_ANDROID_DEPUIS_WINDOWS.md) :
explication des clés/certificats, installation du JDK, création, sauvegardes,
secrets et variable GitHub, premier build et passage du diagnostic à la release.


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

## Identifiant Android définitif — 5 novembre 2026

`fr.index.app` remplace `fr.index.index_windows`. Le namespace, le service média
et les contrôles APK sont alignés. L’ancien fournisseur `fr.index.app.documents`
est retiré en 0.7.01, sans accès réservé. Android considère cette version comme une nouvelle application, même
avec la même signature : elle peut coexister avec l’ancienne, mais ne récupère pas
son profil privé ni ses autorisations SAF. Exporter le JSON et copier les MP3
privés hors de l’ancienne application avant toute désinstallation. Installer la
nouvelle, rechoisir le dossier et importer le JSON. Les futures mises à jour
conserveront `fr.index.app` et votre clé durable.

Si le keystore a déjà été créé, **le conserver** : le certificat n’est pas lié à
l’identifiant de package. Aucun changement des secrets, alias ou empreinte GitHub
n’est nécessaire du seul fait de ce changement d’identifiant. Ne pas recréer la clé.

## Passer des tests à la signature durable

Android refuse une mise à jour du même identifiant avec un certificat différent.
Un diagnostic récent sous `fr.index.app` ne peut donc normalement pas être mis
à jour directement par une release utilisant une autre clé. Les anciens APK sous
`fr.index.index_windows` restent, eux, une application distincte : la nouvelle
peut s’installer à côté, sans désinstallation préalable.
**Avant toute désinstallation**, exporter le suivi JSON vers un dossier extérieur
à l’application et le vérifier. Les MP3 du dossier externe choisi par SAF restent à leur emplacement.
La version 0.7.01 ne propose aucun accès de récupération à l’ancien dossier MP3 privé.

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
contenus documentaires ou MP3 externes. Le code original est désormais sous GNU GPL v3 uniquement (GPL-3.0-only) :
voir LICENSE et LICENSE_SCOPE.md à la racine. MP3, documentation et contenus
documentaires sont hors de cette licence du code ; notices tierces inchangées.

Permissions fusionnées autorisées :

| Permission | Usage |
| --- | --- |
| INTERNET | Téléchargement MP3 explicite |
| ACCESS_NETWORK_STATE | Dépendance Android du moteur audio Flutter existant |
| FOREGROUND_SERVICE / FOREGROUND_SERVICE_MEDIA_PLAYBACK | Lecture en arrière-plan |
| WAKE_LOCK | Lecture/checkpoint lorsque l’écran s’éteint |
| `fr.index.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | Récepteurs internes AndroidX, permission propre à l’application |

Pas de lecture des appels, permission globale de stockage ou accès contacts.
Le fournisseur documentaire IndeX est retiré du manifeste. Le service média
n’est pas exporté. Le profil privé n’est pas exposé dans Fichiers Android.
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


## Compteur sur main et tag de publication

Le compteur est maintenant préparé dans `tools/versioning/counters.json` sur
main. Le premier build utilisant la migration fusionne les dernières valeurs
historiques puis supprime la branche dédiée dans une transaction atomique.
Les deux plateformes restent manuelles et partagent le verrou. Les nouvelles
réservations créent des commits sur main. Le commit réservé est désormais celui
compilé sur les deux plateformes et utilisé pour le tag : le résumé GitHub affiche
**Commit de la version (code compilé et tag Release)**. `INDEX_SOURCE_COMMIT` et
`INDEX_COUNTER_COMMIT` dans `build-info.json` contiennent le même SHA (second nom
conservé comme alias de compatibilité). Si main a changé hors compteur avant
réservation, lancer une nouvelle exécution depuis main à jour. Voir
[le guide du versionnement](../../tools/versioning/README.md).
