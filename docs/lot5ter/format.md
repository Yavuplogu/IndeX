# Transfert manuel IndeX — contrat JSON v2

Format `index-listening-sync`, schema_version **2**. Schéma documentaire :
[format.schema.json](format.schema.json), exemple : [exemple.json](exemple.json).
Le parseur Dart applique ces règles hors ligne ; il ne télécharge aucun schéma.
Le schéma formel ne remplace pas les contrôles calendaires, d’identité, de taille,
de causalité et de position/durée ci-dessous.

## Enveloppe et limites

JSON UTF-8, maximum **5 Mio**, profondeur **12**, **10 000 épisodes** ; aucun champ
supplémentaire accepté. format/schema_version, export_id (`e_` + 32 hex), exported_at
(ISO UTC avec Z), source_device_id (`d_` + 32 hex, pseudonyme local stable),
catalog_version (texte ≤200 caractères), source_platform (`windows`, `android` ou
`unknown`) et episodes sont obligatoires.
Chaque élément contient episode_id canonique `mrx:<nom MP3 historique>` (≤259
caractères, unique dans le fichier), et fields avec exactement favorite/status/position.
Les noms système et emplacements actuels des MP3 ne participent pas à l’identité.

Chaque champ : `value` et `clock`, carte appareil → compteur entier **1…1 000 000 000**,
maximum **32 appareils**. Carte vide autorisée uniquement pour la valeur initiale :
favorite=false ; status={listening_status:NON_ECOUTE,completed_at:null} ;
position={position_ms:0,duration_ms:null,last_played_at:null}. Un champ absent est
invalide : un retrait n’est jamais représenté par l’omission d’un favori.

- favorite.value : booléen, sans autre information.
- status.value : listening_status NON_ECOUTE/EN_COURS/ECOUTE et completed_at nullable.
  Une date de fin non nulle exige ECOUTE ; un ancien état ECOUTE sans date reste valide.
- position.value : position_ms entier ≥0, duration_ms entier >0 ou null,
  last_played_at date UTC ou null. Limite position/durée **7 jours**, position ≤ durée
  lorsqu’elle est connue. Les trois valeurs forment ensemble le champ de reprise.
- Dates : année à quatre chiffres, calendrier valide, secondes et fractions ≤6
  décimales facultatives, UTC Z. Ni ces dates ni exported_at n’ordonnent la fusion.

Pas de MP3, TXT, SQLite, URL/chemin local, permission, lien audio, thème ou journal
technique dans le contrat. Pas de secret, nom de machine ni identifiant matériel.
L’export décrit les états durablement enregistrés, pas le tampon audio en cours.

## Causalité et fusion

Les compteurs sont propres à chaque champ et appareil. Une modification locale
avance son compteur en conservant les versions connues des autres appareils.
Les triggers SQLite enregistrent valeurs et versions dans la transaction d’écriture
du suivi ; une suppression du suivi écrit les valeurs de retrait (tombstones).
Les actions explicites de reset marquent également état/reprise même déjà à zéro.
La création de valeurs initiales non modifiées conserve une carte vide pour que
le seul ajout d’un favori ne crée pas une fausse modification d’écoute.

A domine B si tous ses compteurs sont ≥ à B et au moins un est supérieur. À l’import :

- version entrante dominante : appliquer ce champ ; version locale dominante : conserver ;
- versions égales et même valeur : aucun changement ; valeurs contradictoires : rejet ;
- versions concurrentes et même valeur : réunir leurs contextes sans changer la valeur ;
- versions concurrentes différentes : conflit, choix explicite local/fichier. Réunir
  les contextes et avancer la version locale de résolution pour dominer les deux.

Aucune résolution par date ou maximum de position. Le favori reste indépendant.
État et reprise sont désormais une unité logique « Écoute » : état, progression,
durée et dates proviennent ensemble du même appareil ou du même fichier. Une
reprise plus basse peut être choisie, avec son état associé. Un ancien export ne peut pas effacer un retrait/reset
causalement plus récent. Les informations inconnues ne sont pas assimilées à un autre
épisode : elles sont listées et ignorées, le journal d’import conserve leurs identités.
Un nouvel export permettra de les retenter après actualisation du catalogue.

L’empreinte SHA-256 du contenu JSON canonique (clés triées, ordre des épisodes conservé)
est conservée par export_id. Même export déjà importé : aucun effet, aucune nouvelle
sauvegarde ni date d’état régénérée. Même identifiant avec contenu différent : rejet.
Cette empreinte sert à l’intégrité/idempotence ; elle n’est pas une signature d’auteur.

## Persistance et installation

Schéma utilisateur v7 : sync_device, sync_fields, sync_imports. Le suivi existant
est conservé et reçoit des versions de référence locales ; l’historique antérieur
n’est pas inventé. Des profils anciens indépendants peuvent donc présenter des
conflits légitimes lors du premier échange. Le seed documentaire livré reste v4.
Un seed généré v7 ne contient aucun appareil, changement ou import personnel.

Chaque installation indépendante doit créer son propre profil. Déplacer la version
portable ou ses données conserve son identité. Copier/restaurer un même profil puis
le modifier simultanément dans plusieurs endroits n’est pas le modèle de transfert
pris en charge ; utiliser le JSON entre profils indépendants. Une même version avec
valeurs différentes est rejetée, sans tentative de réparer automatiquement un profil
cloné. Ne pas utiliser des copies concurrentes du même dossier utilisateur.

L’aperçu est un snapshot de lecture et ne fusionne rien. Une révision locale protège
sa fraîcheur ; lecteur libéré explicitement, puis sauvegarde cohérente avant une
transaction unique d’application. Une modification pendant la sauvegarde invalide
l’aperçu. Échec/rollback : états, contextes et journal d’import reviennent ensemble.
Les préférences, associations et fichiers locaux ne sont jamais remplacés.

Le format et la fusion sont indépendants de Flutter. Windows est activé ; Android
nécessitera le sélecteur SAF, la publication locale et une recette physique séparée.


## Présentation et nom de fichier — révision du 31 octobre

Le nom externe est IndeX_suivi_AAAAMMJJ_HHMMSS.json (date/heure locales, seconde),
sans UUID. Cela ne change pas export_id ni les dates UTC du contenu. Un export déjà présent à la même seconde est conservé : réessayer une
seconde plus tard. Les conflits restent causaux ; le panneau sélectionne désormais
le fichier importé par défaut selon la demande utilisateur, avec modification
individuelle/globale possible et confirmation globale toujours obligatoire.
Un reset général ne modifie pas les favoris et marque tous les états/reprises
NON_ECOUTE/0 comme changements explicites, même pour les épisodes jamais commencés.

## Révision du 1er novembre 2026 : écoute liée et provenance

Les horloges restent stockées et transportées par champ. Pour l’écoute, comparer
le produit des horloges état/reprise : chaque couple (champ, appareil) constitue
une dimension. Ne jamais additionner ni prendre le maximum des compteurs entre
ces champs. Une domination dans des sens opposés constitue un conflit du groupe,
même si aucun champ isolé n’était concurrent. Des valeurs de groupe identiques
peuvent réunir leurs contextes. Une résolution choisit les deux valeurs de la même
source, joint chaque contexte et avance les deux versions locales. Les anciens
choix séparés état/reprise sont refusés. Cette règle empêche de créer un mélange
entre deux suivis ; elle ne répare pas un état déjà incohérent dans un fichier.

L’aperçu présente un cadre par épisode, avec choix séparés uniquement pour le
favori et l’écoute. Les compteurs et filtres comptent des épisodes, classés dans
une catégorie exclusive : conflit, modification entrante, versions réunies,
conservé localement, puis identique. Les conflits sont présentés en premier.
Un épisode identique est résumé sans répéter ses champs initiaux.

Les nouveaux exports v2 indiquent source_platform, sans déduire la plateforme
de l’identifiant pseudonyme. Les v1 restent importables : « Plateforme non
renseignée (ancien export) ». Les v2 unknown affichent « Plateforme non
renseignée ». L’empreinte d’un ancien document est conservée sans ajouter de
champ, pour préserver l’idempotence des imports antérieurs. Les anciens lecteurs
v1 ne lisent pas les nouveaux exports v2 : mettre à jour les deux installations.
Les schémas et exemples v1 sont archivés dans [format-v1.schema.json](format-v1.schema.json)
et [exemple-v1.json](exemple-v1.json). Le schéma SQLite reste v7, le seed v4.
