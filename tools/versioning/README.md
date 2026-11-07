# Versionnement IndeX — compteurs centralisés sur main

## Série actuelle

Série bêta **0.9**, premier numéro **0.9.00** (version Flutter **0.9.0**),
autorisée par l’utilisateur le 7 novembre 2026. Le mineur reste affiché sur au
moins deux chiffres : 0.9.00, 0.9.01…0.9.09, 0.9.10, puis 0.9.99, 0.9.100.
Ne pas changer le majeur ou passer en finale sans ordre utilisateur.
`version.json` fixe la politique. L’interface et le nom des artefacts reçoivent
la version publique ; Flutter reçoit la forme SemVer sans zéro initial.

`build_number_base: 9000` et `first_minor: 0` donnent les codes techniques 9001,
9002, etc., supérieurs aux APK de la série 0.7. Le `pubspec.yaml` commun Windows
et Android utilise `0.9.0+9001` comme version locale de départ. La CI fournit la
version effectivement réservée. Aucun compteur historique n’est réinitialisé et
aucun numéro 0.9 n’est préconsommé par cette modification.

## Construire Windows et Android avec la même version

Depuis le 7 novembre 2026, utiliser **Actions → Construction IndeX — version
commune → Run workflow**, sur le `main` actuel :

1. Choisir **Windows et Android** (par défaut) pour obtenir les deux livrables
   portant exactement la même version.
2. Choisir **diagnostic** ou **release** pour Android. Le mode release exige les
   secrets de signature existants ; Windows reste portable dans les deux cas.
3. Lancer une seule fois le workflow. Le job **Réserver la version commune**
   attribue le numéro, puis les constructions Windows et Android démarrent
   indépendamment, en parallèle si des runners sont disponibles.
4. Récupérer les deux artefacts dans cette même exécution GitHub Actions.

`build.yml` est le seul point d’entrée manuel et le seul appelant CI de
`reserve.py --ci`. `windows.yml` et `android.yml` sont des workflows réutilisables
(`workflow_call`) : ils n’ont plus de bouton de lancement indépendant et ne
réservent jamais de numéro. Ils reçoivent la même version publique, le même nom
SemVer, le même code technique et les mêmes SHA source/réservation. Leur checkout
est explicitement fixé au SHA source, même si `main` avance pendant l’exécution.
Le jeton est en lecture seule dans les constructions ; seul le job de réservation
peut écrire le compteur sur `main`. Les secrets de signature passent uniquement
au job Android. Le verrou commun est porté par le coordinateur, sans verrou
identique dans les workflows appelés, pour éviter un blocage entre parent/enfant.

Les versions déjà utilisées **0.9.00 et 0.9.01 sont conservées**. La première paire
utilisant ce nouveau parcours recevra **0.9.02** si aucune réservation n’intervient
d’ici là, avec le code technique **9003** sur les deux plateformes. Chaque nouveau
lancement manuel réserve le mineur suivant pour toute sa sélection de plateformes.

Il reste possible de sélectionner seulement **Windows** ou **Android**. Ce choix
réserve aussi une nouvelle version ; deux lancements manuels séparés ne forment
pas une paire et ne partageront pas le même numéro. Pour une version commune,
sélectionner les deux plateformes en un seul lancement.

### Échec et relance

- Un échec après réservation consomme le numéro, même si aucun artefact n’est créé.
- Si une seule plateforme échoue, l’artefact réussi de l’autre reste disponible.
  Utiliser **Re-run failed jobs** pour reprendre les jobs échoués avec les sorties
  du job de réservation réussi : aucun numéro supplémentaire, même code source.
- **Re-run all jobs** rejoue la réservation et les deux constructions sélectionnées :
  une nouvelle version est attribuée. **Run workflow** crée également une nouvelle
  réservation. Pour inclure une correction de code, pousser la correction puis
  lancer ce nouveau workflow ; une relance d’un ancien run garde son ancien code.
- Si la réservation elle-même échoue, aucun constructeur ne démarre. Une relance
  de ce job effectue une nouvelle tentative ; un éventuel numéro déjà poussé reste
  consommé. Aucun retour en arrière ni réemploi manuel des numéros.
- Les envois d’artefacts autorisent le remplacement du même nom dans une même
  exécution pour reprendre une étape d’envoi échouée. Cela ne remplace aucun
  artefact d’une autre exécution. Une relance complète créant une nouvelle version
  peut laisser les anciens artefacts versionnés visibles dans cette exécution ;
  vérifier le numéro affiché par le nouveau job de réservation.
- Ne pas relancer les anciens workflows indépendants antérieurs à cette adaptation :
  leurs définitions historiques continuent de réserver un numéro par plateforme.

## Stockage sur main

Décision utilisateur : centraliser le versionnement sur `main`. Le script,
la politique et **`tools/versioning/counters.json`** y sont désormais réunis.
Ce fichier contient le dernier mineur réservé par série, pas le prochain numéro.
Ne jamais le supprimer, le réduire ou supprimer ses anciennes séries.

La migration a conservé les anciennes séries 0.5, 0.6 et 0.7. Leurs dernières
réservations restent dans `counters.json`. La nouvelle série 0.9 démarre à zéro
lors de sa première réservation, sans modifier les mineurs des séries précédentes.

Le coordinateur reste exclusivement manuel (`workflow_dispatch`), avec
`contents: write` sur le seul job de réservation et le groupe
`index-windows-version-counter`. Les constructeurs sont appelés via `workflow_call`.
Le nom historique du verrou est conservé afin de sérialiser aussi une ancienne
construction encore en cours. Les commits de réservation ne lancent pas de build.

À chaque `reserve.py --ci` :

1. Lire le dernier `main` distant, pas seulement le compteur du checkout du run.
2. Pendant la migration, lire aussi le dernier ancien compteur distant et garder
   le maximum de chaque série. Un ancien nom `counters.json` suivi d’un CR est
   accepté uniquement sur cette branche historique.
3. Réserver le mineur suivant et créer un commit basé sur le dernier `main`,
   ne changeant que `tools/versioning/counters.json`.
4. Pousser ce commit sans forcer l’historique de `main`. Si l’ancien compteur
   existe, supprimer sa branche **dans la même transaction Git atomique**, avec
   vérification de son SHA attendu. Soit les deux opérations réussissent, soit
   aucune n’est appliquée.
5. Exporter le numéro et les identifiants de traçabilité dans `GITHUB_OUTPUT`
   pour les deux jobs appelés, et dans `GITHUB_ENV` pour les usages existants.

Après la première transaction réussie, `index-build-versions` n’est plus utilisée
et n’existe plus sur le serveur. Ne pas la supprimer manuellement avant cette
migration. Si l’ancienne branche avance entre sa lecture et la transaction,
le lease fait échouer toute la transaction ; relancer un nouveau run depuis main.
Un push concurrent de code sur main fait également refuser le push plutôt que
l’écraser. Aucun retry silencieux avec un numéro déjà utilisé. Si la réservation
elle-même est refusée, aucun numéro n’est attribué et aucun artefact n’est produit.

Le jeton Actions doit pouvoir créer un commit sur `main` et, pour la première
migration, supprimer la branche historique. Des règles de protection peuvent
refuser ces opérations : le build échoue alors explicitement. Le script ne
contourne pas les protections et ne réinitialise jamais un compteur absent,
ambigu ou invalide. Si le serveur ne prend pas en charge les pushs atomiques,
il refuse la réservation, sans repli partiel.

Après migration, **utiliser le coordinateur sur le main actuel**. Ne pas relancer
un ancien run précédant la migration du compteur : une révision historique ne
connaît pas le compteur centralisé et pourrait recréer l’ancienne branche. Les anciennes
révisions restent dans l’historique Git, elles ne sont pas modifiées rétroactivement.

## Code compilé et traçabilité

Le checkout source commun reste celui sélectionné au lancement du coordinateur. Ni son HEAD, ni son
index ni ses fichiers ne sont modifiés par la réservation : un index Git temporaire
sert à construire le commit du compteur. Les nouveaux fichiers que des développeurs
ont poussés sur main entre-temps sont préservés dans le commit distant, mais ne
remplacent pas silencieusement les sources choisies pour le build en cours.

Deux identifiants sont donc conservés :

| Variable CI | Signification |
| --- | --- |
| `INDEX_SOURCE_COMMIT` | HEAD réellement compilé, à utiliser pour le tag de la Release |
| `INDEX_COUNTER_COMMIT` | Commit distant enregistrant cette réservation sur main |

`GITHUB_SHA` conserve sa signification d’origine. Android écrit ces valeurs dans
`build-info.json` ; Windows dans `documentation/version.json` (`source_commit`,
`counter_commit`). Le compteur fournit aussi `INDEX_VERSION`, `INDEX_BUILD_NAME`
et `INDEX_BUILD_NUMBER`. Les fichiers publiés gardent les noms existants :
`IndeX_<version>_windows_x64_portable.zip` ou
`IndeX_<version>_android_arm64_release.apk` / `_diagnostic.apk`.

Les réservations automatiques apparaîtront dans l’historique de `main` sous
« Réserver IndeX … ». Faire un `git pull --ff-only` avant de pousser des changements
locaux si main a avancé depuis une construction. Ne pas écraser ces commits.

## Constructions locales

Le compteur local reste `dist/build-version-counter.json`, ignoré par Git et
indépendant du compteur officiel. `package_windows.ps1` le réserve si aucune
version CI n’a été fournie. Un build APK intermédiaire peut compiler sans
réservation officielle. Les distributions à partager viennent de la CI.

Un verrou exclusif `dist/version-reservation.lock` protège les appels locaux.
Après un arrêt brutal, vérifier qu’aucun processus ne tourne avant de retirer
un verrou résiduel. Ne pas supprimer le compteur local pour réutiliser un numéro.

## Vérification

```text
python -m unittest discover -s tools/versioning -p 'test_*.py'
```

Les tests utilisent uniquement des dépôts Git locaux temporaires. Ils vérifient
incréments et majeurs, limites de padding, conservation de l’historique, migration
CRLF, fusion des maxima, suppression atomique, refus d’un compteur absent/invalide,
refus d’une suppression protégée, courses sur les deux branches, préservation du
checkout/index et des nouveaux commits main, export des SHA de traçabilité.
Ils ne réservent aucun numéro sur GitHub et ne suppriment aucune branche réelle.


## Correctif Windows — encodage des fichiers de test

Le run Windows `113934417860` a réservé 0.7.03 puis échoué pendant les tests
Python : le fichier temporaire contenant « nouvelle fonctionnalité » était écrit
avec l’encodage Windows-1252 par défaut et relu par Git en UTF-8. Ce défaut
concernait le test de préservation du nouveau code, pas la réservation distante.

Les lectures/écritures texte des tests et des fichiers locaux du compteur sont
maintenant explicitement UTF-8 ; le helper de subprocess texte du second checkout
précise également cet encodage. Un test impose un encodage par défaut Windows-1252
même sous Linux : il reproduit le UnicodeDecodeError avant correction et passe
après. **16 tests réussis** dans l’environnement Linux. La vérification native
Windows reste le prochain workflow, sans réattribuer le numéro 0.7.03 consommé.


## Mise à jour des actions Node.js 24 — 7 novembre 2026

Actions mises à jour sur les workflows Windows et Android :

| Action | Version retenue |
| --- | --- |
| `actions/checkout` | `v6` |
| `actions/setup-python` | `v6` |
| `actions/setup-java` | `v5` (Android) |
| `actions/upload-artifact` | `v6` |
| `actions/cache` | `v5` (signature de diagnostic Android) |
| `android-actions/setup-android` | `v4` |

Les métadonnées et notes de migration amont de ces versions indiquent Node.js 24.
Le minimum des actions officielles est le runner 2.327.1 ; le runner 2.338.2
consigné dans les dernières constructions est supérieur. `checkout@v6` conserve
les commandes Git authentifiées depuis le shell, avec les identifiants dans
un fichier temporaire du runner. Le script de réservation n’utilise pas Docker.
`subosito/flutter-action@v2` est une action composite utilisant `actions/cache@v5` ;
elle est conservée avec Flutter 3.47.7. Python 3.12, Java 21, SDK Android 36,
NDK 28.2.13676358, signature, noms d’artefacts, clé de cache de diagnostic,
permissions et déclenchement manuel sont conservés. `setup-android@v4` actualise
ses outils de ligne de commande par défaut ; les plateformes/build-tools/NDK
restent explicitement sélectionnés dans le workflow.

La validation des workflows hébergés et des artefacts exige un nouveau lancement
du coordinateur avec **Windows et Android** depuis le commit mis à jour ; les
contrôles locaux ne remplacent pas ces deux constructions.

Contrôles locaux de cette révision : **17 tests de versionnement** et **5 tests
de distribution Android** réussis ; les réservations 0.9.00 à 0.9.10 sont
vérifiées dans des dépôts temporaires, avec codes 9001 à 9011 et anciens
compteurs préservés. `actionlint` 1.7.7 valide les deux workflows (analyse shellcheck
non exécutée). Les paramètres `with` sont comparés aux métadonnées amont de chaque
action ; tous sont reconnus. Les dépendances Flutter verrouillées sont résolues
hors ligne avec succès. Aucun build GitHub, numéro officiel ou artefact
distribuable n’a été créé par ces contrôles.


## Validation du coordinateur commun

18 tests de versionnement et 5 tests de distribution Android réussis. Le test CLI
vérifie que les sorties inter-jobs correspondent exactement à l’environnement du
build, avec une seule réservation distante et le SHA source initial ; un échec
de réservation n’exporte aucune version et libère le verrou local. Les 3 workflows
sont validés par `actionlint` 1.7.7 (sans shellcheck). Le graphe YAML est contrôlé :
une seule réservation, dépendances sur son job, mêmes entrées pour les deux
plateformes, checkout fixé au SHA source, jetons de lecture et secrets Android
transmis seulement au constructeur Android. Aucun compteur officiel modifié,
aucune construction GitHub lancée. La paire native et la relance des seuls jobs
échoués restent à vérifier dans GitHub Actions après commit/push.


## Version dans les propriétés Windows

Depuis le 7 novembre 2026, les exécutables du lanceur portable et du runner Flutter
utilisent la version publique dans les champs textuels **FileVersion** et
**ProductVersion** : par exemple `0.9.02`, sans `+9003` ni quatrième numéro de
construction. Les ressources numériques Windows imposent quatre nombres :
`0,9,2,0` dans cet exemple, qui peuvent apparaître comme `0.9.2.0` dans certains
outils Windows. Ce zéro final est structurel ; ce n’est pas un compteur technique.
Un champ numérique ne peut pas conserver le zéro initial de `02`.

Le calcul CMake partagé est appliqué aux deux cibles et utilise les trois nombres
Flutter réellement compilés ainsi que `minor_width` de la politique versionnée.
Il ne se fonde pas sur un INDEX_VERSION ambiant : les tests d’intégration debug
peuvent compiler la version du pubspec alors que la CI a réservé un autre mineur.
Le packaging release refuse l’archive si les chaînes des deux exécutables ne
correspondent pas exactement à la version réservée ou si leurs ressources
numériques ne correspondent pas aux trois composantes officielles suivies de 0.
Les champs de construction dans Flutter/Android et `documentation/version.json`
conservent leur numéro technique pour la traçabilité et les mises à jour Android.

Vérifications locales : **21 tests de versionnement réussis**, dont trois tests
CMake exécutant réellement le calcul (padding, passage à 10/100, limites des
composantes Windows et refus d’une politique invalide). CMake 3.31.10 utilisé
hors dépôt ; le test est signalé ignoré si CMake manque. Syntaxe PowerShell du
packaging validée. Aucune compilation native Windows depuis Linux : les contrôles
PE sont exécutés par le packaging lors du prochain workflow Windows. Cette
modification ne change pas les exécutables déjà distribués.
