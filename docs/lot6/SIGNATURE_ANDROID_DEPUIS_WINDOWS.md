> Décision du 5 novembre 2026 — série **0.7.01** : l’emplacement privé
> « IndeX · MP3 » est supprimé, ainsi que son bouton et le fournisseur Android.
> Aucun accès de récupération n’est conservé. Choisir un dossier MP3 visible
> dans le sélecteur Android. Aucun fichier existant n’est supprimé par ce retrait.
> Le stockage privé du profil (favoris, progression, réglages) reste nécessaire
> et distinct. Les exports JSON utilisent toujours une destination choisie.
> Identifiant `fr.index.app` et clé durable conservés.

# Signer IndeX Android depuis un PC Windows, puis avec GitHub

Ce guide concerne **la signature de l’application Android**, même si vous créez
la clé sur votre PC Windows. Il ne signe pas `IndeX.exe` : la signature Windows
Authenticode et SmartScreen suivent un autre processus.

Vous allez créer votre identité de signature **une seule fois** sur votre PC,
en conserver des sauvegardes, puis permettre au workflow GitHub existant de
l’utiliser à chaque nouvelle construction Android. Aucun achat de certificat,
Android Studio, Flutter ou téléphone branché n’est nécessaire pour créer cette clé.

## 1. Comprendre ce qui est créé

Une signature est une preuve cryptographique attachée à une version de
l’application. L’outil de signature utilise une **clé privée** pour signer l’APK.
Android utilise la clé publique contenue dans le certificat embarqué pour vérifier
la signature. Une modification ultérieure de l’APK invalide cette vérification.

Pour une mise à jour normale d’IndeX, Android vérifie notamment le même identifiant
d’application (`fr.index.app`), la continuité du signataire et un code
de version compatible. Le workflow IndeX impose un code croissant. Il n’y a pas
de rotation de clé mise en place dans ce projet : conserver la même clé durable.

La signature ne garantit pas qu’un programme est sans bug ou sans code malveillant.
Sur Android, un certificat autosigné ne fait pas vérifier votre identité civile
par une autorité indépendante. Il permet de reconnaître la continuité du signataire.

| Élément | Rôle | Confidentialité |
| --- | --- | --- |
| Clé privée | Permet de signer vos versions officielles | Secrète, à sauvegarder |
| Certificat | Contient la clé publique, le nom choisi, les dates de validité | Public, inclus dans l’APK |
| Keystore | Fichier protégé par mot de passe contenant la clé privée et son certificat | Secret, à sauvegarder |
| Alias | Nom de la clé à l’intérieur du keystore ; ici `index-release` | Pas intrinsèquement secret ; configuré comme secret dans ce workflow |
| Empreinte SHA-256 du certificat | Identifiant public permettant de contrôler le signataire attendu | Publique, stable tant que le certificat reste le même |
| Signature de l’APK | Résultat du calcul sur cette version du programme | Publique, change avec le contenu signé |
| SHA-256 du fichier APK | Empreinte du fichier complet pour vérifier le téléchargement | Publique, change d’une version à l’autre |

Le keystore n’est donc pas « la signature » à joindre aux téléchargements.
Chaque APK aura sa propre signature, produite avec la même clé privée.
Le certificat public est embarqué automatiquement ; il n’est pas à installer
séparément sur le téléphone.

## 2. Comprendre le rôle de GitHub

Le dépôt public contient le code et le workflow, **pas votre clé privée**.
GitHub Actions est le service qui compile et signe automatiquement lorsque vous
lancez manuellement le workflow en mode `release`.

Le trajet est le suivant :

1. **Votre PC Windows** : vous créez le keystore et gardez vos sauvegardes.
2. **GitHub Secrets** : vous enregistrez une copie encodée du keystore et ses mots de passe.
3. **GitHub Actions** : une machine temporaire récupère le code, reconstitue le
   keystore, compile, signe et vérifie l’APK, puis retire le keystore temporaire.
4. **Artefact Actions** : vous téléchargez l’APK signé et ses rapports, sans clé privée.
5. **Téléphone Android** : Android vérifie la signature pendant l’installation
   et les mises à jour. Il n’a pas besoin de contacter GitHub pour la vérifier.

GitHub n’est pas l’autorité qui vous délivre un certificat : c’est vous qui créez
le certificat Android autosigné, gratuitement. Un dépôt public ne rend pas les
repository secrets lisibles par ses visiteurs. En revanche, une personne capable
de modifier un workflow exécuté avec vos secrets pourrait chercher à les extraire :
réserver ces accès aux personnes de confiance et lancer la release sur du code relu.
Le masquage dans les logs ne protège pas contre un workflow malveillant.

## Identifiant définitif et clé déjà créée

Depuis le 5 novembre 2026, l’identifiant définitif est `fr.index.app`, en remplacement
de `fr.index.index_windows`. Le changement crée une nouvelle application Android,
même avec la même clé : export/import du suivi et nouveau choix du dossier MP3
sont nécessaires, sans récupération automatique du profil. Sauvegarder les MP3
privés avant de désinstaller l’ancienne application. Les deux peuvent coexister et portent le même nom visible « IndeX ».

**Si vous avez déjà créé le keystore, ne le recréez pas.** La clé et son certificat
ne sont pas liés au nom du package ; ils restent utilisables. Les secrets GitHub,
l’alias et l’empreinte du certificat restent identiques. Seule l’identité de
l’application compilée change. Les prochaines mises à jour doivent conserver
`fr.index.app` et cette même clé.

## 3. Installer l’outil sur Windows

L’outil s’appelle **keytool** et fait partie du **JDK Java**.
Temurin n’est pas obligatoire : un JDK existant compatible, notamment celui
fourni avec Android Studio, convient aussi. PowerShell lance `keytool`, comme il
peut lancer `ssh-keygen` pour SSH ; la clé SSH ne remplace pas un keystore Android.
Pour une nouvelle installation alignée avec la construction IndeX, utiliser le JDK 21.

1. Télécharger **Eclipse Temurin 21 JDK** depuis le site officiel :
   <https://adoptium.net/temurin/releases/?version=21>.
2. Choisir Windows, votre architecture (généralement x64) et l’installateur MSI
   **JDK**, pas seulement JRE. Pour un Windows ARM64, prendre le JDK adapté.
3. Installer en activant l’ajout au **PATH** si l’option est proposée.
4. Fermer puis rouvrir PowerShell après installation.
5. Taper cette commande :

```powershell
keytool -help
```

Une liste des commandes doit apparaître. Si PowerShell indique que `keytool`
n’est pas reconnu, vérifier l’installation du JDK et l’option PATH, puis rouvrir
le terminal. Cette étape ne nécessite pas d’installer le SDK Android ou Flutter.

## 4. Créer le dossier privé de signature

Ouvrir **PowerShell** et coller ce bloc :

```powershell
$dossierSignature = Join-Path $env:USERPROFILE 'IndeX-signature-Android'
New-Item -ItemType Directory -Path $dossierSignature -Force | Out-Null
Set-Location $dossierSignature
```

Le dossier sera par exemple `C:\Users\VotreNom\IndeX-signature-Android`.
Il doit rester **hors du dépôt Git**, hors de l’archive de l’application et hors
d’un dossier partagé publiquement. Ce dossier n’est pas le dossier de données
utilisateur d’IndeX et ne sera jamais demandé par l’application.

## 5. Créer la clé durable — une seule fois

Dans la même fenêtre PowerShell, coller ce bloc :

```powershell
$cleAndroid = Join-Path $dossierSignature 'index-android-release.jks'
if (Test-Path -LiteralPath $cleAndroid) {
    throw 'Ce keystore existe déjà. Ne pas créer une nouvelle clé : passer à sa vérification.'
} else {
    keytool -genkeypair -v -storetype PKCS12 -keystore $cleAndroid -alias index-release -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=IndeX Android Release'
}
```

`keytool` vous demande un **mot de passe**, puis sa confirmation. Choisir un mot
de passe long et unique, enregistré dans votre gestionnaire de mots de passe.
L’absence de caractères à l’écran pendant la saisie est normale. Ne pas mettre
le mot de passe directement dans la commande ni le transmettre dans cette conversation.

La commande choisit :

- `index-android-release.jks` : le fichier contenant la clé et le certificat ;
- `PKCS12` : le format interne, explicitement fixé. L’extension `.jks` du nom ne
  change pas ce format ; Java et la chaîne Android savent le lire ;
- `index-release` : l’alias à réutiliser dans GitHub ;
- RSA 3072 : l’algorithme et la taille de clé ;
- `10000` : la validité en jours, environ 27 ans ; ne pas régénérer à chaque build ;
- `IndeX Android Release` : un nom public dans le certificat, sans adresse personnelle.

Avec ce format PKCS12, **le mot de passe de la clé et celui du magasin seront
identiques**. C’est normal : vous mettrez la même valeur dans deux secrets GitHub.
Le nom public du certificat ne change pas le nom affiché de l’application.

Si vous relancez PowerShell plus tard, les variables ne seront plus définies.
Pour les commandes suivantes, les chemins complets sont reconstruits sans
nécessiter de garder cette fenêtre ouverte.

## 6. Vérifier la clé et relever son empreinte publique

```powershell
$cleAndroid = Join-Path $env:USERPROFILE 'IndeX-signature-Android\index-android-release.jks'
keytool -list -v -storetype PKCS12 -keystore $cleAndroid -alias index-release
```

Saisir le mot de passe. Vérifier :

- alias `index-release` ;
- type d’entrée **PrivateKeyEntry** : le magasin contient bien une clé privée ;
- nom du certificat `CN=IndeX Android Release` ;
- dates de validité ;
- ligne **SHA256** dans les empreintes du certificat.

Copier la **valeur entière de SHA256**, sans le libellé `SHA256:`.
C’est une suite de 64 caractères hexadécimaux, éventuellement séparés par des
deux-points. Les deux présentations sont acceptées par IndeX.

Ne pas confondre avec **SHA1**, ni avec le résultat de `Get-FileHash` sur le
keystore ou l’APK : ce ne sont pas les empreintes attendues pour ce réglage.
Cette empreinte publique servira à `INDEX_ANDROID_CERT_SHA256`.

## 7. Sauvegarder avant de continuer

Conserver au minimum :

- le fichier `index-android-release.jks` ;
- son mot de passe ;
- l’alias `index-release` ;
- l’empreinte SHA-256 du certificat.

Prévoir deux sauvegardes sécurisées indépendantes, dont une hors du disque du PC.
Par exemple : copie du fichier dans une sauvegarde chiffrée externe et seconde
copie chiffrée sur un autre support, mots de passe dans un gestionnaire sauvegardé.
Vérifier au moins une copie avec `keytool -list` en lui donnant son chemin.

**GitHub Secrets n’est pas votre sauvegarde** : son interface ne permet pas de
retélécharger la valeur d’un secret enregistré. Si vous perdez définitivement la
clé ou son mot de passe, la chaîne actuelle ne permet plus de fournir une mise à
jour compatible aux installations signées par cette clé. Ne pas remplacer le
keystore par une nouvelle clé pour contourner un problème de configuration.

## 8. Ajouter les quatre secrets au dépôt GitHub

Dans le navigateur, ouvrir votre dépôt :
<https://github.com/Yavuplogu/IndeX>.

1. Ouvrir **Settings** du dépôt, pas les réglages de votre compte.
2. Dans le menu de gauche : **Secrets and variables → Actions**.
3. Sélectionner l’onglet **Secrets**.
4. Cliquer **New repository secret** pour chaque ligne du tableau ci-dessous.

| Champ Name — copier exactement | Champ Secret — valeur à saisir |
| --- | --- |
| `INDEX_ANDROID_KEYSTORE_BASE64` | Contenu Base64 du fichier, préparé juste après |
| `INDEX_ANDROID_STORE_PASSWORD` | Mot de passe choisi à la création |
| `INDEX_ANDROID_KEY_ALIAS` | `index-release` |
| `INDEX_ANDROID_KEY_PASSWORD` | Le même mot de passe pour cette clé PKCS12 |

Pour obtenir la valeur du **premier secret**, exécuter sur votre PC :

```powershell
$cleAndroid = Join-Path $env:USERPROFILE 'IndeX-signature-Android\index-android-release.jks'
[Convert]::ToBase64String([IO.File]::ReadAllBytes($cleAndroid)) | Set-Clipboard
```

La commande copie le contenu dans le presse-papiers, sans l’afficher.
Sur GitHub, créer `INDEX_ANDROID_KEYSTORE_BASE64`, puis faire **Ctrl+V** dans
le champ **Secret** et cliquer **Add secret**.

Ce que vous collez est le **contenu du fichier**, pas son chemin Windows ni
le nom du fichier. Base64 est un encodage, **pas un chiffrement** : ce contenu
reste confidentiel, comme le keystore. Ne pas le coller dans une issue, un fichier
du dépôt, les logs ou cette conversation.

Après ajout, remplacer le contenu courant du presse-papiers :

```powershell
Set-Clipboard -Value ' '
```

Si l’historique Windows du presse-papiers ou sa synchronisation est activé, retirer
également l’entrée Base64 de l’historique (**Windows+V**). Le remplacement du
contenu courant n’efface pas les anciennes entrées.

Créer ensuite les trois autres secrets du tableau, puis vérifier que les
**quatre noms exacts** figurent dans la liste. GitHub n’affiche pas leurs valeurs
après enregistrement ; c’est normal. Vous pourrez les remplacer depuis vos copies.

## 9. Ajouter la variable publique de contrôle

Toujours dans **Settings → Secrets and variables → Actions** :

1. Sélectionner l’onglet **Variables**.
2. Cliquer **New repository variable**.
3. Dans **Name**, saisir `INDEX_ANDROID_CERT_SHA256`.
4. Dans **Value**, coller l’empreinte SHA256 du certificat relevée à l’étape 6,
   sans le libellé `SHA256:`. Conserver ou retirer les deux-points, au choix.
5. Cliquer **Add variable**.

Il s’agit bien d’une **variable**, pas d’un cinquième secret : le workflow utilise
`vars.INDEX_ANDROID_CERT_SHA256`. La mettre uniquement dans Secrets ferait échouer
la configuration actuelle. L’empreinte publique n’est pas le keystore encodé.

Cette référence permet au contrôle de refuser un APK signé avec une autre clé.
Elle protège notamment contre une erreur de configuration ; elle ne peut pas
protéger contre quelqu’un ayant les droits de modifier à la fois le workflow et
cette référence. Les droits d’administration du dépôt restent importants.

## 10. Lancer la première construction signée

1. Ouvrir **Actions** dans le dépôt.
2. Choisir **Verification Android Lot 6D**.
3. Cliquer **Run workflow**.
4. Sélectionner la branche **main** contenant les modifications validées.
5. Pour **mode**, choisir **release**, pas diagnostic.
6. Cliquer sur le bouton de lancement.

La construction peut attendre le verrou partagé si un autre build IndeX est déjà
en cours. Le numéro mineur est réservé automatiquement ; ne pas le choisir à la
main. Un échec consomme son numéro. **Release est ici le mode de compilation et
de signature : la version publique reste bêta 0.7.** Ce lancement ne crée pas de
GitHub Release publique et ne met pas les sources en ligne à votre place.

Le workflow :

- effectue les contrôles du projet ;
- reconstitue temporairement votre keystore depuis le secret ;
- compile l’APK release et le signe avec cette clé ;
- vérifie la signature, l’empreinte attendue, les versions, les permissions et
  le contenu ;
- prépare l’artefact puis retire le keystore temporaire, même en cas d’échec.

Aucun nouveau secret à créer pour chaque version : les prochains builds release
réutiliseront la même configuration. Le cache de clé **debug** sert seulement
au mode diagnostic ; ce n’est pas la sauvegarde de votre clé durable.

## 11. Récupérer et contrôler l’APK

Après succès, ouvrir le résumé du run et descendre jusqu’à **Artifacts**.
Télécharger `IndeX-<version>-Android-arm64-release` et décompresser l’archive.
Elle contient notamment :

- `IndeX_<version>_android_arm64_release.apk` ;
- le fichier `.apk.sha256` ;
- `release-apk.json`, avec l’empreinte du certificat et le code de version ;
- `build-info.json`, avec le commit et les références du run ;
- les guides, la recette et les notices de licences.

Dans `release-apk.json`, `certificate_sha256` doit correspondre à votre empreinte
de certificat. L’affichage en minuscules et sans deux-points est normal.

Pour vérifier le fichier téléchargé depuis PowerShell, vous pouvez ouvrir le
dossier décompressé dans l’Explorateur, cliquer dans la barre d’adresse, taper
`powershell` puis Entrée, et lancer :

```powershell
Get-ChildItem -File -Filter '*_android_arm64_release.apk' | Get-FileHash -Algorithm SHA256
Get-Content -Path '.\*.apk.sha256'
```

Comparer les deux valeurs SHA-256, sans tenir compte de la casse. Ce sont les
empreintes **de l’APK**, qui changent à chaque version, pas celle du certificat.
La vérification cryptographique de signature a déjà été effectuée par le workflow.

## 12. Installer et préparer les mises à jour

Les anciens APK de diagnostic utilisaient `fr.index.index_windows`. Avec le
nouvel identifiant `fr.index.app`, la nouvelle application s’installe à côté,
sans transfert automatique du profil. Si vous avez aussi installé un diagnostic
récent sous `fr.index.app`, sa signature debug différente empêchera normalement
de le mettre à jour directement avec la release.
Ce refus ne signifie pas que votre nouvelle signature est mauvaise.

Avant toute désinstallation :

1. Exporter le suivi JSON depuis IndeX et le placer **hors du stockage privé de l’application**.
2. Vérifier que vous pouvez retrouver et ouvrir ce fichier avec un gestionnaire de fichiers.
3. Sauvegarder également les MP3 du dossier privé **IndeX · MP3**, s’il est utilisé.
4. Conserver les MP3 externes dans leur dossier habituel ; ne pas les supprimer.

Seulement après ces sauvegardes, si le certificat différent empêche la mise à
jour, désinstaller manuellement l’ancien diagnostic, installer l’APK release,
rechoisir le dossier MP3 puis importer/fusionner le JSON. La désinstallation
supprime le profil privé et les MP3 privés, ainsi que les autorisations SAF.

Pour les versions release suivantes : même clé, même identifiant et numéro de
build supérieur. Installer la mise à jour **sans désinstaller** ; profil et droits
doivent être conservés. Vérifier ce scénario sur téléphone avec la fiche 6D.
La signature n’élimine pas automatiquement les avertissements Android liés à une
installation hors store et ne vaut pas validation de tous les appareils.

## 13. Résoudre les erreurs fréquentes

| Message ou situation | Vérification |
| --- | --- |
| `keytool` introuvable | JDK installé, ajout au PATH, PowerShell rouvert |
| Le keystore existe déjà / alias déjà présent | Ne pas régénérer ; utiliser et vérifier la clé existante |
| `Secrets de signature Android incomplets` | Quatre secrets exacts et une variable `INDEX_ANDROID_CERT_SHA256` dans le même dépôt |
| `Base64 invalide` / format de keystore incorrect | Refaire l’encodage du fichier original complet, pas de son chemin |
| Mot de passe ou clé incorrecte | Vérifier les deux mots de passe et l’alias avec `keytool -list` sur le PC |
| Certificat différent de l’empreinte attendue | Comparer SHA256 du certificat de la clé originale à la variable ; ne pas changer arbitrairement de clé |
| Mise à jour Android refusée | Comparer signatures diagnostic/release, identifiant et versionCode ; sauvegarder avant toute réinstallation |
| Aucun artefact après échec | Ouvrir le run Actions et l’étape rouge ; ne pas transmettre de secret avec les logs |
| Le mode diagnostic fonctionne mais release échoue | Le diagnostic ne teste pas vos secrets de signature release |

Pour demander de l’aide, fournir le nom de l’étape et le message d’erreur,
**jamais le keystore, son Base64 ou les mots de passe**. Une empreinte publique
de certificat peut être communiquée.

## 14. Ce qui est différent pour Windows

Créer cette clé **sur Windows** ne signe pas le programme **pour Windows**.
L’exécutable `IndeX.exe` utilise une signature **Authenticode**, avec certificat
de signature de code reconnu par Windows et un processus de signature distinct.
Un certificat autosigné peut produire une signature technique Windows, mais il
n’est généralement pas reconnu sur les PC des utilisateurs et ne supprime pas
SmartScreen. Même une signature reconnue ne garantit pas la disparition immédiate
de tous les avertissements, la réputation du logiciel intervenant aussi.

Le caractère open source peut permettre une candidature à des programmes de
signature gratuite sous conditions ; ce n’est pas automatique. La configuration
Android ci-dessus ne met rien en place pour Windows. Les licences open source
et droits de redistribution du catalogue sont également des décisions distinctes
de la création d’une signature.

Pour les détails techniques du workflow : [DISTRIBUTION_ANDROID.md](DISTRIBUTION_ANDROID.md).
Pour les résultats de recette à consigner : [RECETTE_6D.md](RECETTE_6D.md).
