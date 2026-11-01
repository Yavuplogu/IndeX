# IndeX — application Flutter Windows

Interface Éditorial des Lots 1–4. Le cœur Dart reste dans le package racine ; cette
application référence celui-ci par chemin. Voir le [bilan](../../docs/lot4/bilan.md),
les [spécifications](../../docs/lot4/specifications.md) et le [mode d'emploi](../../docs/lot4/UTILISATION_WINDOWS.md).

Préparer depuis la racine du dépôt avec Flutter 3.47.7 / Dart 3.13.5 et Python 3.10+ :

```sh
python3 tools/lot4/prepare_assets.py
cd apps/index_windows
flutter pub get --enforce-lockfile
flutter run -d windows
```

La copie de travail du seed sous `assets/` est générée et ignorée par Git ; l'unique
source versionnée est `../../assets/catalogue.sqlite`, vérifiée par empreinte avant
copie. Le paquet contient le SQLite et son manifeste, aucun MP3/TXT/CSV externe requis.

La construction Windows exige Windows et Visual Studio C++/SDK. Pour les contrôles
et l'archive portable, utiliser PowerShell 7 depuis la racine :

```powershell
./tools/lot4/test_runtime_windows.ps1
./tools/lot4/check.ps1
./tools/lot4/package_windows.ps1
./tools/lot4/smoke_archive.ps1 -Archive ./dist/IndeX_0.6.0_windows_x64_portable.zip
```

L'archive comprend les DLL Flutter/plugins/SQLite et le runtime C++ app-local,
les notices de dépendances et un manifeste de fichiers. Ces outils refusent les MP3
et les bases/configurations personnelles dans la distribution. Ils ne créent
ni installateur ni publication GitHub Release.

Le test de l'archive écrit `dist/diagnostics-smoke/` : sorties standard/erreur,
étape atteinte et code de sortie dans `resultat.json`, événements d'erreur Windows
concernant IndeX si disponibles. Le workflow les conserve dans l'artefact
`IndeX-windows-diagnostics`, même en cas d'échec ; le paquet portable n'est publié
comme artefact qu'après réussite du test.


Le ZIP s'ouvre sur `IndeX/IndeX.exe`, unique fichier à sa racine. Ce lanceur C++
avec CRT statique démarre le bundle Flutter de `application/` et transmet son code
de sortie. Les notices sont dans `documentation/` ; les ressources, DLL et le
pointeur utilisateur restent dans `application/`. Tester la disposition sans
compilation : `./tools/lot4/test_portable_windows.ps1`. Le smoke test Windows ferme
la fenêtre du processus enfant et vérifie aussi la fin du lanceur.

La recette acquiert le handle du processus enfant avant fermeture afin de lire
son code même après sa disparition sous Windows. Le contrôle autonome
`./tools/lot4/test_process_windows.ps1` vérifie la conservation des codes de sortie
et refuse explicitement les codes absents ; il est exécuté avant la compilation CI.

## Lot 5 — source commune Android et Windows

Le lecteur et le suivi automatique sont décrits dans le [bilan Lot 5](../../docs/lot5/bilan.md).
Le nom du package reste `index_windows`, mais le dossier `android/` et la branche
Android de `main.dart` réutilisent le même catalogue et la même interface responsive.

Avec JDK 21, Android SDK 36 et NDK 28.2.13676358 configurés :

```sh
bash tools/lot5/build_android.sh
```

Cette commande s’exécute depuis la racine du dépôt. L’APK ARM64 de test est produit
sous `apps/index_windows/build/app/outputs/flutter-apk/app-debug.apk` et est ignoré
par Git. Le workflow Android conserve cet APK comme artefact ; la signature de
production et une publication en magasin ne font pas partie de cette construction.
Recette audio réelle sur Windows avec sortie audio : `tools/lot5/check_windows_audio.ps1`.

Le numéro de l’archive varie à chaque build. Remplacer `0.6.0` dans l’exemple
par la version produite. Voir [la politique de version](../../tools/versioning/README.md).


Lecteur Windows : `just_audio` 0.10.6 + `just_audio_windows` 0.2.3+index.2 (WinRT
MediaPlayer), sans ancien moteur MCI. Le plugin DLL est inclus dans `application/`.
Les licences sont copiées dans `documentation/licences/`, y compris les notices
complètes transitives. `docs/lot5/just-audio-dependances.json` conserve versions,
licences et empreintes des nouvelles dépendances. Pas de dépendance Java dans
le bundle Windows ; path_provider_android est contraint à 2.2.23 pour éviter JNI.
La recette audio réelle se lance sur Windows avec `tools/lot5/check_windows_audio.ps1`.


Le plugin Windows corrigé est versionné dans `third_party/just_audio_windows`
(source MIT/provenance conservées). Voir `INDEX_PATCHES.md`. Il ne doit pas être
remplacé par le package 0.2.3 non corrigé sans réexécuter la recette MP3_Bugs.
Le journal local est dans `<données utilisateur>/logs/lecteur-audio.log`, JSONL
avec rotation à 512 Kio (un précédent conservé), aucun envoi. En cas d’échec,
conserver ce journal et préciser quel MP3 est concerné. La commande audio native
existante teste maintenant aussi les huit MP3_Bugs, en lecture seule.


## Lot 5 bis — Windows 0.6.0

Le bouton Paramètres → Fichiers audio ouvre un aperçu réel du renommage global,
avec confirmation et journal de reprise. Cœur `Mp3Renamer` commun ; publication
Windows `renameMp3` via MoveFileExW sans remplacement. Le schéma utilisateur v6
ajoute le journal, le seed documentaire v4 reste inchangé. Voir le
[bilan Lot 5 bis](../../docs/lot5bis/bilan.md) et la recette Windows restante.
Android est en audit Lot 6A ; le renommage SAF sera porté en 6B. Le transfert JSON
Windows est décrit ci-dessous au Lot 5 ter.


## Lot 5 ter — transfert JSON du suivi

Paramètres → Transfert du suivi : export Windows dans exports/, import avec aperçu,
conflits explicites et sauvegarde avant transaction. Cœur ListeningSync et contrat
JSON v2 (lecture v1 conservée) communs au futur Android ; sélection/publication SAF restent différées.
Schéma utilisateur v7, seed documentaire v4 conservé. Le compteur de builds 0.6
continue sans réinitialisation. Voir [le bilan](../../docs/lot5ter/bilan.md) et
[le contrat](../../docs/lot5ter/format.md).


## Lot 6A — diagnostic Android

Lancement le 1er novembre 2026. APK ARM64 de diagnostic compilable, Android
7.0 minimum (API 24), cible API 36. Le workflow Android manuel réserve une version
dans le compteur commun Windows/Android. Renommage, JSON et téléchargement restent
à porter en 6B ; la lecture continue écran éteint sera réalisée en 6C.
Voir [audit et décisions](../../docs/lot6/audit-6A.md) et
[recette sur téléphone](../../docs/lot6/RECETTE_ANDROID.md).
