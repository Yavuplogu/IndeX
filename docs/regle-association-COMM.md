# Association MP3–TXT par deux commentaires COMM concordants

> **Règle historique remplacée le 26 octobre 2026.** L'application associe désormais
> exclusivement par les noms du journal, sans lire COMM : voir la
> [règle actuelle](regle-association-noms-journal.md). Le texte ci-dessous décrit
> les audits et décisions antérieurs, sans gouverner le scan actuel.

**Décision utilisateur adoptée — 23 octobre 2026.**

Cette règle complète le [cahier des charges V1.4](Cahier_des_charges_IndeX_Codex_V1.4.md).
Elle remplace, dans ses §4.1, §4.3 et tests associés, le rejet systématique dès que
deux commentaires COMM contiennent des identifiants différents. La copie originale
du cahier des charges reste inchangée pour traçabilité. La présente règle prévaut
sur ce point ; les autres protections contre les associations ambiguës sont maintenues.

La lecture des COMM et la résolution de preuve sont **implémentées et testées au Lot 1**
dans le cœur Dart. L'association globale aux fiches et la persistance sont livrées au
Lot 2 ; les interfaces restent aux lots suivants. Voir les bilans du
[Lot 1](lot1/bilan.md) et du [Lot 2](lot2/bilan.md).

## 1. Lecture et comptage des commentaires

Lire toutes les trames ID3 `COMM` de **chaque MP3**, sans se limiter à la première,
à une langue ou à une description particulière. Conserver pour chacune langue,
description, texte brut et position/indice de trame dans le diagnostic.

Une valeur exploitable est un nom historique de fichier `.mp3`, normalisé selon
les règles d'identité du projet : NFC, espaces parasites et éventuels guillemets
d'encadrement retirés, comparaison ASCII sans casse pour le format historique connu.
Ne pas comparer les titres et ne pas extraire arbitrairement un nom au milieu d'un
texte libre. Les commentaires de durée, réalisation ou autre texte sans identifiant
MP3 sont non candidats et ne participent pas au comptage.

Deux commentaires sont concordants s'ils désignent le **même nom historique après
cette normalisation prudente**. Les valeurs brutes restent conservées. Compter des
trames distinctes, pas deux occurrences du nom dans le texte d'une même trame, ni
deux lectures successives de la même trame. Une paire anglais/français compte bien
comme deux trames ; la diversité des langues n'est pas une condition obligatoire.

## 2. Règle de sélection par paire concordante

Pour un MP3, regrouper les trames candidates par nom historique normalisé :

| Situation | Résultat de la résolution ID3 |
|---|---|
| Un seul identifiant est présent dans au moins deux trames | Retenir cet identifiant ; ignorer pour la sélection les autres commentaires, même s'ils portent un autre nom MP3 isolé |
| Plusieurs identifiants disposent chacun d'au moins deux trames | Conflit non résolu : aucune sélection automatique, même si l'un a davantage de commentaires |
| Aucune paire, mais un seul identifiant candidat non contradictoire | Conserver la règle antérieure de correspondance ID3 unique |
| Aucune paire et plusieurs identifiants candidats différents | Conflit non résolu : aucune sélection automatique |
| Aucun commentaire exploitable | Absence de preuve ID3 : autoriser les replis par nom prévus en V1.4 |

La règle n'est pas un vote à majorité absolue : `A, A, B, C` retient A ;
`A, A, A, B, B` reste ambigu, puisque deux identifiants ont une paire concordante.
Un commentaire ignoré n'est ni supprimé ni réécrit dans le MP3 : il est seulement
écarté du choix et conservé dans les diagnostics avec la raison de son exclusion.

**Limite acceptée :** deux commentaires identiques peuvent reproduire la même erreur
de tag. La paire est une règle de décision demandée par l'utilisateur, pas deux
preuves indépendantes de l'identité du contenu sonore. La V1 ne reconnaît pas
automatiquement les paroles ou le contenu audio.

## 3. Prise en compte pour l'association MP3–TXT

La résolution COMM produit d'abord un identifiant historique candidat, pas un lien
déduit du nom actuel du fichier. Le moteur de matching utilise ensuite ce résultat :

1. Comparer l'identifiant retenu au champ TXT `FICHIER MP3 D'ORIGINE`, avec la même
   normalisation prudente. Pour un catalogue embarqué, comparer à la clé historique
   déjà extraite du TXT lors de sa construction ; aucun TXT externe n'est nécessaire
   chez l'utilisateur final.
2. Si cet identifiant désigne un seul épisode/TXT et qu'aucun autre MP3 n'entre en
   concurrence pour cette association automatique, confirmer l'association locale
   avec `matching_method = id3_comment`. Cette preuve ID3 prime sur le nom courant
   du MP3, les noms connus du CSV et les similarités de titre.
3. Si la paire retenue ne correspond à aucune fiche, signaler « Identifiant ID3
   inconnu ». Ne pas associer à une autre fiche par titre ou nom en ignorant cette
   preuve ; proposer une résolution manuelle ou l'ajout de la fiche correspondante.
4. Plusieurs TXT/épisodes partageant l'identifiant, ou plusieurs MP3 candidats au
   même épisode, restent une ambiguïté inter-fichiers. La règle des deux COMM ne
   supprime pas ces contrôles et ne permet pas d'attribution arbitraire.
5. Une résolution ID3 conflictuelle bloque les replis automatiques. En l'absence
   totale de commentaire exploitable, appliquer l'ordre existant : nom historique,
   nom `TITRE SYSTEME` du catalogue, puis titre normalisé provisoire.

Un CSV marqué `CONFIRMEE` ne remplace jamais la lecture du MP3 local. Conserver
séparément `journal_status` et `local_verification_status`. Une paire effectivement
relue peut confirmer la vérification locale ; le statut historique du journal reste
inchangé, y compris s'il indique une ancienne anomalie. Signaler alors cet écart.

### Exemple de résultat à transmettre et persister

Extrait d'un résultat `MatchDecision.toJson()` du Lot 2 pour la paire A/A avec un
commentaire B écarté (les références locales et les autres champs du rapport sont omis) :

```json
{
  "episode_id": "mrx:mr_x_2013_04_27.mp3",
  "matching_method": "id3_comment",
  "status": "confirmed",
  "local_verification_status": "CONFIRMEE",
  "evidence_rule": "comm_pair_v1",
  "supporting_frames": [0, 1],
  "ignored_comments": [{
    "index": 2,
    "reason": "Identifiant isolé écarté au profit de la paire concordante."
  }]
}
```

Les indices renvoient à la liste complète des commentaires conservée dans le
diagnostic, avec leurs valeurs brutes et raisons d'exclusion. Le statut `confirmed`
n'est confirmé **qu'après** les contrôles de correspondance unique entre fichiers.
La règle ID3 unique sans paire reste identifiable séparément dans les preuves, par
exemple `evidence_rule = comm_unique_v1`. Les liens locaux stockent cette preuve dans
`evidence_json`, avec leur méthode et `matching_status`. Seules les décisions confirmées
deviennent des liens automatiques ; les autres restent dans le rapport de scan.
Les épisodes, liens et preuves restent indépendants des statuts d'écoute et favoris.

## 4. Cas de recette à ajouter aux lots 1 et 2

Dans ce tableau, A et B désignent deux noms historiques différents ; « texte » est
un commentaire sans nom MP3. Les confirmations supposent une fiche correspondante
unique et l'absence de concurrence entre fichiers.

| Commentaires d'un MP3 | Résultat attendu |
|---|---|
| A en anglais, A en français, texte | Association par A, texte ignoré |
| A, A, B | Association par A, B ignoré et tracé |
| A, A, B, C | Association par A, B et C ignorés et tracés |
| A, A, B, B | Conflit, aucune association automatique |
| A, A, A, B, B | Conflit, pas de sélection au nombre maximal |
| A, B | Conflit, pas de repli par nom/titre |
| A seul, texte | Correspondance ID3 unique conservée |
| Texte seul, ou aucune COMM | Replis autorisés selon V1.4 |
| Une seule trame contenant deux occurrences de A | Ne constitue pas une paire |
| A, A ; fiche A absente et nom courant évoquant B | Identifiant inconnu, aucune association automatique à B |
| A, A ; deux fiches A ou deux MP3 candidats à A | Ambiguïté inter-fichiers, résolution explicite |

Permuter l'ordre des trames doit donner la même décision. Vérifier également la
normalisation, les limites de lecture et les langues/descriptions identiques ou
différentes, sans modifier les octets ni les tags des sources. Utiliser des copies
temporaires pour les variantes synthétiques. La fixture réelle « Le Masque de fer »
contient deux COMM physiques A/A. Le commentaire « texte » présenté par Mutagen dans
l'audit initial est synthétisé à partir d'ID3v1, pas une troisième COMM physique ;
il ne doit pas compter comme une voix. A/A/texte et les contradictions sont exercés
par des fixtures synthétiques dédiées (voir la correction dans le bilan du Lot 1).

Les résultats d'audit déjà enregistrés restent des observations du corpus d'origine.
Les sondes actuelles de `tools/lot0` ne constituent pas des tests d'implémentation de
cette nouvelle règle. Les tests de lecture ID3 et résolution sont livrés au Lot 1 ;
les tests de matching inter-fichiers sont désormais livrés au Lot 2.
