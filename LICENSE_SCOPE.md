# Périmètre de la licence d’IndeX

Le code source original d’IndeX est distribué sous la **GNU General Public License,
version 3 uniquement** — identifiant SPDX `GPL-3.0-only`. Le texte intégral et
non modifié de cette licence est dans [LICENSE](LICENSE).

Ce choix couvre le programme, le cœur partagé, les adaptateurs Windows/Android,
les tests et les scripts/configurations nécessaires à la construction, notamment
le code original dans `lib/`, `bin/`, `apps/`, `test/`, `tools/` et `.github/`.
Il ne remplace pas les licences des composants tiers.

Sont hors du champ de cette licence du code, **sans qu’une autre licence leur soit
attribuée par le présent fichier** :

- les MP3, notamment `MP3_Files/` ;
- la documentation du projet, notamment `docs/`, les guides et README ;
- les contenus documentaires et jeux de données, notamment `TXT_Files/`,
  `Journal_Files/`, les fixtures documentaires/audio et le catalogue SQLite
  prérempli avec ses données dans `assets/` et ses copies embarquées ;
- les autres ressources non logicielles auxquelles aucun droit n’est accordé ici.

Les bibliothèques, SDK, icônes et autres éléments tiers conservent leurs propres
licences et notices, dont celles de `third_party/just_audio_windows/` et
`apps/index_windows/assets/icons/LICENSE-octicons.txt`. Leurs conditions et
attributions doivent être conservées lors de la redistribution. Cette délimitation
n’ajoute aucune restriction aux droits accordés par ces licences tierces.

Une distribution du programme sous GPL v3 doit fournir l’accès au code source
correspondant et aux éléments de construction requis, selon la licence. Le tag
et le commit doivent correspondre au binaire distribué, y compris les modifications
locales des composants tiers. La clé privée de signature et ses mots de passe
ne font pas partie des fichiers publiés dans la distribution actuelle.
