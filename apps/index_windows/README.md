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
./tools/lot4/smoke_archive.ps1 -Archive ./dist/IndeX_0.4.0_windows_x64_portable.zip
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
