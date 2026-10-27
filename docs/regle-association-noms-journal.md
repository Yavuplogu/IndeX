# Association MP3 — noms du journal comme autorité

**Décision utilisateur du 26 octobre 2026, appliquée au Lot 4.** Cette règle
remplace les règles d'association par COMM et les replis par titre des lots
précédents et du cahier des charges V1.4 archivé. La règle COMM historique reste
documentée pour comprendre les audits antérieurs ; elle n'intervient plus dans
l'application.

## Autorité et comparaison

Le journal vérifié est intégré au catalogue SQLite livré. L'utilisateur n'a pas
besoin de CSV ni de TXT externes pour associer ses MP3. Seuls les champs du journal
courant alimentent la liste des noms autorisés ; une fiche sans journal ou un
ancien alias système conservé pour audit ne crée aucune nouvelle concordance.

Pour chaque fichier `.mp3` découvert :

1. Comparer son nom complet, extension incluse, au champ **FICHIER MP3 D'ORIGINE**.
2. Si aucune fiche ne correspond, essayer **TITRE SYSTEME**.
3. Une concordance unique est acceptée. Plusieurs fiches au premier niveau sont
   un conflit terminal : le deuxième niveau ne sert pas à contourner l'ambiguïté.
4. Sans concordance, signaler un nom inconnu. Aucun essai par titre, date seule,
   suppression de ponctuation, distance approximative ou commentaire ID3.
5. Si plusieurs fichiers du scan visent le même épisode, signaler tous les fichiers
   comme conflictuels, y compris des exemplaires sous les deux conventions de nom
   ou dans des sous-dossiers distincts. Aucun choix arbitraire du premier fichier.

La seule normalisation est **Unicode NFC et insensibilité à la casse**. Les accents,
les espaces (y compris doublés), apostrophes et autres signes restent significatifs.
Ainsi `C.I.A..mp3` et `C.I.A.mp3` sont différents ; un suffixe `(copie)` n'est pas ignoré.
Le nom ne devient jamais l'identité métier : celle-ci reste `mrx:<nom historique>`.

## Tags et portée de la preuve

Le scan ne lit plus les tags : une langue COMM invalide, un identifiant contradictoire,
un tag absent ou tronqué ne bloque donc pas l'association par nom. Aucun tag ou
fichier n'est modifié. Les parseurs ID3 et leurs tests restent disponibles uniquement
pour l'audit technique indépendant.

Un résultat `confirmed` signifie **association par nom exact et unique** ; il ne
certifie pas le contenu audio. Les décisions utilisent `original_filename` ou
`catalog_filename`, avec `evidence_rule=journal_filename_v1`,
`local_verification_status=NON_VERIFIEE` et `audio_content_verified=false`.
Le champ historique `CORRESPONDANCE ID3` du CSV est conservé comme provenance et
n'intervient pas dans la décision. Un MP3 mal nommé peut donc être lié à la mauvaise
fiche : vérifier l'enregistrement demande une écoute ou une validation distincte.

## Choix manuels, anciens liens et scans incomplets

Les associations manuelles confirmées sont prioritaires, par fichier et par épisode.
Leur fichier est retiré de la recherche automatique et ne crée pas de faux doublon
pour une autre fiche. Un autre fichier visant une fiche déjà associée manuellement
est signalé sans remplacer ce choix. Les rapports affichent la décision réellement
enregistrée, y compris les choix manuels.

Au prochain scan complet, les liens automatiques du périmètre sont réévalués.
Une ancienne association COMM sans concordance de nom est désactivée, avec sa preuve
historique conservée. Une association devenue conflictuelle n'est plus disponible
comme association validée. Si un fichier précédemment attribué automatiquement à
une autre fiche a désormais une concordance unique avec le journal, son lien peut
être réattribué et l'événement `audio_link_reassigned` est enregistré. **Les favoris,
statuts et progressions restent sur leurs identités d'épisodes d'origine ; ils ne
sont ni supprimés ni transférés vers une autre fiche.** Le lien manuel n'est jamais
réattribué par ce mécanisme.

Un scan incomplet conserve les anciens liens et ne valide aucune nouvelle association
automatique : le diagnostic indique `audio_scan_incomplete`. Une indisponibilité
ne justifie pas une perte de données. Un déplacement ou renommage conforme aux deux
champs autorisés peut retrouver la fiche au scan suivant, sans perdre son suivi.

## Catalogue mis à jour

Les sources de `main` au commit `f126478` sont intégrées dans
`corpus-2026-10-26-noms-journal-r3` (seed SQLite v4, FTS5). Les onze noms corrigés,
dont les Hmongs du Laos, Le colonel B. et L’affaire L., sont présents ; les
716 identités sont inchangées. Le catalogue contient toujours 716 épisodes,
603 résumés, 1896 références et 614 musiques, sans audio ni données personnelles.

Le rapport conserve **29 avertissements historiques**, sans erreur, quarantaine
ou fiche à vérifier. La divergence précédemment signalée est résolue dans `main` :
`2003-10-25 Les Hmongs du Laos et la C.I.A..txt` concorde avec le journal et le
nom MP3 `2003-10-25 Les Hmongs du Laos et la C.I.A..mp3`.

Le catalogue intégré est importé à l'ouverture avec préservation du suivi et des
choix manuels. Les anciens seeds v2/v3 restent acceptés en lecture seule ; la base
utilisateur v4 ne change pas de schéma pour cette règle.

## Retrait explicite d’un lien local — 27 octobre 2026

Dernière révision utilisateur du 27 octobre : après confirmation, Enlever
l’association supprime le lien local et les données utilisateur de cet épisode
(favori, statut, position et durée). Ses octets et son nom restent inchangés. La référence figure
alors dans une exclusion locale persistante (`audio_unlinked_refs_v1`) : les scans,
complets ou incomplets, ne la réassocient pas automatiquement. Le rapport indique
`unknown`, `matching_method=manual_unlinked`, `evidence_rule=manual_unlinked`.
Un choix Associer… explicite lève cette exclusion et enregistre un lien manuel,
sans restaurer le favori ou le suivi supprimés.
Ce réglage porte sur une référence locale, pas sur l’identité documentaire ni sur
un transfert JSON entre appareils. Les autres règles de concordance ne changent pas.
