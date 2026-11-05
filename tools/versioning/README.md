# Versionnement IndeX — compteurs centralisés sur main

## Série actuelle

Série bêta **0.7**, premier numéro **0.7.01**, mineur affiché sur au moins deux
chiffres : 0.7.08, 0.7.09, 0.7.10, puis 0.7.99, 0.7.100. Ne pas changer le majeur
ou passer en finale sans ordre utilisateur. `version.json` fixe la politique.
Flutter reçoit la forme SemVer sans zéro initial (0.7.1). L’interface et le nom
des artefacts reçoivent la version publique (0.7.01).

`build_number_base: 7000` et `first_minor: 1` donnent les codes techniques 7001,
7002, etc., supérieurs aux APK de la série 0.6. Windows et Android conservent
le compteur et le verrou de concurrence communs. Une construction officielle
réserve un numéro avant les tests : un échec ultérieur consomme ce numéro.

## Stockage sur main

Décision utilisateur : centraliser le versionnement sur `main`. Le script,
la politique et **`tools/versioning/counters.json`** y sont désormais réunis.
Ce fichier contient le dernier mineur réservé par série, pas le prochain numéro.
Ne jamais le supprimer, le réduire ou supprimer ses anciennes séries.

La migration préparée importe les valeurs effectivement lues dans l’ancienne
branche : `0.5: 16`, `0.6: 29`, `0.7: 1`. Le prochain numéro est donc 0.7.02 si
aucune nouvelle réservation n’intervient avant le premier nouveau build.
Les anciens historiques ne sont pas réinitialisés.

Les workflows Windows/Android restent exclusivement manuels (`workflow_dispatch`),
avec `contents: write` et le même groupe `index-windows-version-counter`.
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
5. Exporter le numéro et les identifiants de traçabilité aux étapes de construction.

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

Après migration, **utiliser Run workflow sur le main actuel**. Ne pas relancer
un ancien run utilisant l’ancien script : une révision historique ne connaît pas
le compteur centralisé et pourrait recréer l’ancienne branche. Les anciennes
révisions restent dans l’historique Git, elles ne sont pas modifiées rétroactivement.

## Code compilé et traçabilité

Le checkout du run reste celui sélectionné au lancement. Ni son HEAD, ni son
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
