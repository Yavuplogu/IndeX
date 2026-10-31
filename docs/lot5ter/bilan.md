# Lot 5 ter — export/import manuel JSON Windows

Lancement explicite le **31 octobre 2026**, après validation utilisateur du dernier
build du Lot 5 bis. Majeur **0.6 conservé**, mineur réservé par chaque build comme
auparavant. Android reste en pause ; Lot 6 non lancé. Aucun nouveau package runtime.

## Décisions et réalisation

- Cœur `ListeningSync` : contrat JSON v1, snapshots de lecture, validation bornée,
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
  date, comptes, valeurs locales/importées et conflits sans présélection ; inconnus
  signalés. Confirmation désactivée tant que des conflits restent sans réponse.
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
