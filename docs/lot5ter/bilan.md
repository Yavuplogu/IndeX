# Lot 5 ter — export/import manuel JSON Windows

Lancement explicite le **31 octobre 2026**, après validation utilisateur du dernier
build du Lot 5 bis. Majeur **0.6 conservé**, mineur réservé par chaque build comme
auparavant. Android reste en pause ; Lot 6 non lancé. Aucun nouveau package runtime.

## Décisions et réalisation

- Cœur `ListeningSync` : contrat JSON v2 (lecture v1 conservée), snapshots de lecture, validation bornée,
  plan de fusion immuable, choix local/fichier par conflit, application transactionnelle.
  Voir [format.md](format.md), schéma et exemple JSON.
- Migration utilisateur v7 : sync_device, sync_fields, sync_imports. Triggers par champ
  pour les favoris, état et reprise, y compris DELETE lors de désassociation. Actions
  explicites de reset dans la transaction de PortableSession. Les mutations du lecteur
  sont ainsi suivies sans réécrire son moteur. Seed documentaire v4 laissé intact.
- Horloges vectorielles par champ, sans comparaison des dates pour choisir une valeur.
  Favori, état d’écoute, reprise (position/durée/dernière écoute) se fusionnent séparément.
  Résolution d’un conflit = réunion des contextes + événement de résolution local.
  Retraits/reset conservés. Valeurs initiales non modifiées ne créent pas de faux conflits.
- Export sous user/exports, fichier temporaire privé borné, écriture flush puis
  `publishExport` Windows via MoveFileExW sans remplacement. Le JSON final est au
  complet avant publication. Aucun dossier externe proposé par défaut et aucun MP3
  transféré. Nettoyage des temporaires à erreur ; résidu éventuel jamais importé automatiquement.
- Import depuis sélecteur de fichier JSON. Panneau commun clair/sombre : provenance,
  date, comptes, valeurs locales/importées et conflits (présélection fichier importé
  depuis la nouvelle demande du 31 octobre) ; inconnus
  signalés. Tous les conflits ont un choix visible, modifiable ; la confirmation
  globale reste obligatoire.
  Fermer avant confirmation ne modifie pas les états importés.
- Piste chargée : pause/sauvegarde/libération explicite avant préparation d’un import.
  Cela évite un checkpoint du moteur écrasant la reprise fraîchement importée.
  Révision vérifiée avant et après sauvegarde, puis dans la transaction d’application.
- Sauvegarde existante SQLite backup API, FK/FTS/integrity_check avant fusion ; deux
  générations dans sauvegardes/. Transaction unique incluant états, versions, journal
  et désactivation temporaire des triggers de suivi. Un échec annule le tout, y compris
  cette désactivation. Aucun remplacement du fichier SQLite utilisateur.
- Empreinte canonique de l’export et export_id en journal : import répété sans effet,
  contenu modifié avec le même identifiant refusé. Mises à jour du catalogue compatibles
  par identité stable ; inconnus ignorés explicitement, sans affecter un autre épisode.

## Risques et limites

La fusion ne remplace pas une synchronisation de dossiers. Utiliser des profils
indépendants pour les installations indépendantes ; les copies concurrentes d’un même
profil peuvent partager des identités et versions et ne sont pas un transfert JSON.
Un fichier de suivi n’est pas signé ; l’utilisateur choisit sa provenance. Les tailles,
compteurs, types, dates, champs et identités sont validés ; aucun contenu importé n’est
exécuté, aucune URL n’est ouverte, aucune requête réseau n’est effectuée.

Les clocks sont bornées à 32 appareils et les fichiers à 5 Mio ; un dépassement est
refusé, sans tronquer l’historique causal. L’historique antérieur à la migration n’est
pas reconstitué par les dates : des conflits au premier échange restent possibles.
Le format Windows est prêt à partager ; aucun transfert SAF ou test physique Android
n’est revendiqué tant que le portage reste en pause.

## Vérifications et recette restante

Tests cœur : profils indépendants, échanges aller/retour, modifications de champs
indépendantes, concurrents et choix des deux branches, horloges désynchronisées,
retour à zéro, retrait de favori/désassociation, import répété et ancien export,
aperçu périmé, sauvegarde impossible, modification pendant sauvegarde, échec en milieu
de transaction, inconnus, formats/types/tailles/profondeurs invalides, export atomique
injecté, migration v6 avec tous les états conservés, identité stable et renommage sans
changement du suivi. Tests UI : export, annulation d’aperçu, choix conflictuel,
confirmation, sauvegarde et mise à jour de la bibliothèque. Smoke Windows étendu pour
publication JSON complète, cible existante et extension non JSON refusées.

Restent à exécuter sur Windows : compilation et smoke natif CI, puis sélection
réelle de fichier, permission/disque plein, transfert entre deux profils Windows,
arrêt forcé pendant fusion et reprise, grande collection, régression lecteur et
renommage. Les contrôles Linux ne qualifient pas le paquet Windows. Aucun commit/push
ou numéro de distribution n’est créé par les tests locaux.

## Contrôles exécutés le 31 octobre 2026

```sh
. /workspace/toolchains/activate-flutter.sh
bash tools/lot4/check.sh
```

Sur Linux : **239 tests Dart, 53 tests Flutter et 6 tests Python réussis**, formatage
et analyses statiques conformes. La suite ciblée de transfert compte 18 tests du cœur ;
l’exemple documenté y est décodé par le même parseur que l’application. Schéma formel
et exemple validés séparément avec Draft 2020-12. Le corpus et le seed intégrés ne sont
pas modifiés ; leur régénération reproductible avec le schéma courant reste contrôlée
par la suite existante. Aucun paquet runtime ni changement de majeur ajouté.

Le backend de publication et le smoke test Windows ont été préparés, mais ne sont
pas compilés/exécutés sur cet hôte Linux. La recette Windows décrite ci-dessus demeure
nécessaire ; aucun export/import Android réel n’est revendiqué.

## Premier build Lot 5 ter — assertion de chemin Windows

Les logs `logs_111726673702.zip` du commit `cd361ad` concernent le build **0.6.3**.
Les tests du cœur donnent **237 réussites, 1 ignoré (SIGKILL POSIX), 1 échec**.
L’échec est l’assertion de dossier dans le test d’export JSON : le dossier retourné
se termine par `/exports`, l’attente exige `\exports`. Windows accepte les deux
séparateurs ; cette comparaison textuelle ne vérifiait pas correctement le dossier.
Les tests Flutter et la compilation/recette native ne sont pas atteints.

Le test compare désormais l’identité physique du parent de l’export avec le dossier
exports attendu, en conservant toutes les assertions de contenu JSON, nom sans
espaces, suivi inchangé et nettoyage après échec. Aucun code de production, format
JSON, seed ou donnée utilisateur modifié par cette correction. La numérotation
publique à deux chiffres demandée séparément reste en attente dans le même checkout ;
le compteur des builds n’est pas réinitialisé et 0.6.3 reste consommé.

Vérification locale de cette correction : analyse Dart sans problème, **18 tests
ciblés du transfert réussis** et **7 tests Python du versionnement réussis**.
Une nouvelle exécution Windows demeure nécessaire ; la suite Flutter n’est pas
rejouée pour ce seul changement d’assertion dans les tests du cœur.


## Révision des panneaux et des exports — 31 octobre 2026

Les conflits sont triés avant les autres résultats. Filtres par type, valeurs
libellées Cet appareil / Fichier importé, pourcentages et dates locales lisibles.
L’utilisateur demande explicitement la présélection **Utiliser le fichier importé**
pour tous les conflits ; cette règle remplace la présentation initiale sans
présélection. Les commandes globales changent tous les conflits, même filtrés.
La fusion conserve une confirmation globale et journalise les réponses effectives ;
le contrat causal et les contrôles d’aperçu périmé ne changent pas.

Après succès, afficher seulement le message de réussite et Fermer. La liste de
résultats défile avec ses informations et filtres pour rester utilisable dans une
fenêtre étroite. Le nom d’export est désormais IndeX_suivi_AAAAMMJJ_HHMMSS.json
en heure locale ; le contenu garde son identifiant unique et ses dates UTC.
Une collision à la seconde est refusée, y compris par publication native atomique
sans remplacement ; le JSON existant reste intact. Le reset global de progression
conserve les favoris et écrit les versions de reset dans la transaction entière.


Vérification de la révision lecteur/panneaux : `bash tools/lot4/check.sh` réussit
sur Linux avec **239 tests Dart, 61 tests Flutter et 7 tests Python**, analyses
statiques et formatage conformes. Couverture ajoutée : glissements à 119000,
119900 et 120000 ms avec attente du vrai ended (pause exclue), saut des épisodes
écoutés dans les deux modes automatiques, arrêt sans candidat, reset global
confirmé/annulé et rollback en milieu de transaction, filtres des panneaux,
commandes globales sur plusieurs conflits, bilan minimal après import, nom court
et collision d’export, liseré réel au survol du titre lecteur. La recette Windows
sur MP3 réels, notamment le glissement au terme, reste nécessaire après build.
Aucun changement de majeur ou du contrat JSON et aucune modification du corpus.


### Révision du 1er novembre 2026 — transfert et présentation

Le transfert fusionne l’écoute comme un ensemble : état, position, durée et dates
proviennent de la même source. Le favori reste indépendant. Un cadre par épisode
remplace les cadres par champ ; les filtres comptent des épisodes, avec priorité
conflit > modification > versions réunies > conservé > identique. Le choix par
défaut reste le fichier importé et la confirmation globale reste obligatoire.
Les nouveaux JSON v2 indiquent Windows/Android ; les anciens v1 sont acceptés avec
plateforme non renseignée. Mettre à jour les deux installations avant d’échanger
des v2. Voir [le contrat](../lot5ter/format.md). Aucun changement SQLite/seed.
Le panneau de renommage conserve ses dimensions quand on filtre. Le liseré
du lecteur entoure uniquement le titre et sa date, dans la largeur disponible.

Validation de cette révision sous Linux : `bash tools/lot4/check.sh` réussi,
243 tests Dart, 61 tests Flutter et 7 tests Python ; analyses sans problème.
Les schémas et exemples JSON v1/v2 ont également été validés localement.
Les tests couvrent les choix d’écoute des deux sources, le refus des choix
séparés, les causalités croisées, le favori indépendant, l’idempotence v1,
la provenance Windows/Android et les dimensions du panneau/liseré.
La recette sur l’exécutable Windows reste à effectuer après construction.
