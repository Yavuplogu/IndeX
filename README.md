<div align="center">

<img src="apps/index_windows/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" alt="Logo IndeX" width="80" height="80">

<h1>IndeX</h1>

<p><strong>Rechercher, explorer et écouter les épisodes de Rendez-vous avec X.</strong></p>

<p>Windows portable · Android · Interface en français · Code sous GPL v3</p>

<p>
  <a href="https://github.com/Yavuplogu/IndeX/releases"><strong>Télécharger</strong></a> ·
  <a href="#prise-en-main">Prise en main</a> ·
  <a href="#fonctionnalités">Fonctionnalités</a> ·
  <a href="https://github.com/Yavuplogu/IndeX/issues">Signaler un problème</a>
</p>

</div>

---

IndeX rassemble le catalogue documentaire de **716 émissions**, représentant environ
**420 heures d’écoute**, dans une interface claire. Consultez les résumés, retrouvez
les références et écoutez vos MP3 depuis une même application.

Le catalogue est intégré : il reste entièrement consultable **sans MP3 et sans
fichiers TXT ou CSV externes**.

> **Version bêta** — Disponible pour Windows et Android. Aucun MP3 n’est embarqué
> dans les applications.

## Télécharger

Les versions publiées sont disponibles dans les **[Releases](https://github.com/Yavuplogu/IndeX/releases)**.
Choisissez le fichier correspondant à votre plateforme :

| Plateforme | Distribution | Configuration minimale |
| --- | --- | --- |
| **Windows** | Archive portable `.zip`, sans installateur | Windows 10 ou 11 · x64 |
| **Android** | Application `.apk` | Android 7 ou supérieur · ARM64 |

## Fonctionnalités

| | Ce que propose IndeX |
| --- | --- |
| **Explorer** | Recherche dans les titres, résumés, sources et musiques ; tris, filtres et favoris. |
| **Comprendre** | Fiches documentaires avec résumés, références, musiques et accès aux épisodes connexes. |
| **Associer** | Reconnaissance automatique des noms de MP3, associations manuelles et diagnostic du dossier. |
| **Écouter** | Lecture, pause, arrêt, volume, déplacement dans la piste et sauts de dix secondes ; modes aléatoire et enchaînement. |
| **Reprendre** | Progression sauvegardée localement, reprise d’écoute et états **Non écouté**, **En cours**, **Écouté**. |
| **Transférer** | Export/import JSON entre Windows et Android, avec aperçu et résolution des conflits avant fusion. |
| **Compléter** | Téléchargement à la demande d’un MP3 absent lorsqu’une URL est disponible dans le catalogue. |
| **Organiser** | Suppression confirmée des MP3 écoutés en conservant le suivi et les favoris ; renommage facultatif sur Windows. |
| **Personnaliser** | Thèmes clair et sombre ; interface Android adaptée au portrait et au paysage. |

Sur **Android**, la lecture continue en arrière-plan, avec commandes dans les
notifications et sur l’écran verrouillé.

## Prise en main

### Windows

1. Télécharger et décompresser l’archive portable.
2. Conserver l’ensemble des dossiers extraits.
3. Lancer **`IndeX.exe`**.
4. Choisir le dossier des données utilisateur et, éventuellement, celui des MP3.

Le dossier `IndeX/user` est proposé par défaut pour vos données ; cet emplacement
reste modifiable.

### Android

1. Télécharger puis installer l’APK.
2. Autoriser l’installation depuis cette source si Android le demande.
3. Choisir le dossier contenant les MP3, ou commencer sans fichiers audio.

Pour les mises à jour Android, installer le nouvel APK officiel **sans désinstaller
IndeX**, afin de conserver les données.

## Vos fichiers MP3

L’association automatique reconnaît les noms d’origine et les titres système du
catalogue, par exemple :

```text
mr_x_1997_01_04.mp3
1997-01-04 La 5ème Colonne.mp3
```

Les autres noms peuvent être associés manuellement. **Le scan ne modifie pas les
fichiers.**

Le renommage, disponible uniquement sur Windows, convertit les noms d’origine vers
les titres système du catalogue. Il est facultatif et nécessite un aperçu puis
une confirmation.

La suppression des MP3 écoutés est accessible sur Windows et Android depuis
**Paramètres → Fichiers audio**, avec aperçu et confirmation. Le suivi et les
favoris sont conservés. **La suppression peut être définitive, sans passage par
une corbeille.**

## Données et fonctionnement hors ligne

Le catalogue, la recherche et l’écoute de fichiers locaux fonctionnent **hors
ligne**. Aucun compte n’est requis et aucune synchronisation automatique n’est
effectuée.

| Données | Emplacement ou contenu |
| --- | --- |
| **Favoris, progressions et réglages** | Dossier utilisateur choisi sur Windows ; stockage interne de l’application sur Android. |
| **MP3** | Dossier choisi par l’utilisateur ; aucun fichier audio dans les applications distribuées. |
| **Export JSON** | Suivi d’écoute et favoris, pour sauvegarde ou fusion sur un autre appareil ; aucun MP3 inclus. |

Le téléchargement volontaire nécessite Internet. Un fournisseur de fichiers
distant choisi sous Android peut également nécessiter une connexion.

## Compatibilité vérifiée

La version **0.7.01**, y compris sa mise à jour signée, a été déclarée fonctionnelle
par l’utilisateur sur les appareils suivants :

| Appareil | Version Android déclarée |
| --- | --- |
| Google Pixel 9 et Pixel 10 | Android 17 |
| OnePlus 15 | Android 17 |
| Samsung Galaxy S21 | Android 14 |

Cette validation concerne ces appareils et cette version ; elle ne constitue pas
une recette de toutes les configurations compatibles.

## Documentation

| Besoin | Guide |
| --- | --- |
| Utiliser l’application sur Windows | [Mode d’emploi](docs/lot4/UTILISATION_WINDOWS.md) |
| Comprendre les associations MP3 | [Règle d’association par noms du catalogue](docs/regle-association-noms-journal.md) |
| Supprimer les MP3 écoutés | [Fonctionnement et contrôles](docs/suppression-mp3-ecoutes.md) |
| Construire l’application | [Application Flutter et commandes de construction](apps/index_windows/README.md) |
| Signer et distribuer Android | [Guide de distribution](docs/lot6/DISTRIBUTION_ANDROID.md) |
| Comprendre les versions | [Politique de versionnement](tools/versioning/README.md) |
| Consulter les notes de développement | [Ancien README et références techniques](docs/README-historique.md) |

## Retours et contributions

Pour signaler un problème ou proposer une amélioration, utilisez les
**[Issues](https://github.com/Yavuplogu/IndeX/issues)**. Précisez la version d’IndeX,
votre système et les étapes permettant de reproduire le problème.

IndeX est développé avec **Flutter et Dart**, avec un cœur partagé entre Windows
et Android. Les scripts de construction et de vérification se trouvent dans
[`tools/`](tools/). Les workflows GitHub Actions se lancent manuellement.

## Licence

Le code original d’IndeX est distribué sous **GNU GPL v3 uniquement**
(`GPL-3.0-only`).

Consultez [LICENSE](LICENSE) et [LICENSE_SCOPE.md](LICENSE_SCOPE.md) pour le texte et
son périmètre. Cette licence du code ne s’applique pas aux MP3, à la documentation
ni aux contenus documentaires. Les composants tiers conservent leurs propres
licences.
