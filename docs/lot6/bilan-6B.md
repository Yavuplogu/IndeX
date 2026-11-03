# Lot 6B — Stockage Android, fichiers et transfert JSON

Lancé explicitement le **2 novembre 2026**, après confirmation utilisateur du
catalogue/recherche, des associations/lectures/seeks et de la conservation du
dossier et du suivi sur son téléphone. Cette confirmation valide la porte 6A ;
elle ne constitue pas une recette de toutes les versions Android. Windows reste
validé par l’utilisateur. Le Lot 6C (service média/écran verrouillé) n’est pas lancé.

## Réalisation et décisions

Aucun nouveau package runtime. Adaptateur Kotlin AndroidDocuments, fournisseur
local IndeXDocumentsProvider, interfaces DocumentOperation/DocumentMp3Renamer dans
le cœur et raccordement AppModel/UI. SQLite utilisateur v7, seed v4 de 716 épisodes,
JSON v2 avec lecture v1 et majeur 0.6 conservés. URI content:// opaques pour les
fournisseurs externes ; aucune déduction de leur chemin physique.

### JSON Windows ↔ Android

Export d’abord dans le dossier privé user/exports au nom court existant. Publication
interne par déplacement atomique contrôlé dans le stockage privé : sous le mutex
commun à tous les écrivains, vérifier l’absence de cible sans suivre les liens,
déplacer puis synchroniser les dossiers concernés. Une cible existante est refusée.
Ensuite ACTION_CREATE_DOCUMENT
permet d’enregistrer une copie externe avec contrôle SHA-256 après copie. Annuler
le sélecteur conserve la copie interne ; échouer ne modifie pas le suivi.
Sur un fournisseur SAF externe, la copie n’est pas une publication atomique au
sens Windows : un document JSON incomplet peut subsister si l’écriture échoue ou
si le processus est tué. Il ne doit pas être partagé ; le parseur rejettera une
copie tronquée. Ne pas présenter la copie SAF comme un MoveFileExW.

Import ACTION_OPEN_DOCUMENT (lecture), extension JSON, lecture native bornée à
5 Mio puis validation intégrale dans le parseur partagé. Aperçu et choix explicites
communs : écoute liée (statut/reprise/durée/dates), favori indépendant, conflits
présélectionnés fichier importé, backup avant transaction et contrôle de révision.
Un lecteur chargé doit toujours être libéré avant l’aperçu. Imports répétés sans
effet ; identifiant réutilisé avec contenu modifié rejeté. Aucun audio, chemin,
permission, association locale ou réglage transféré. Nouveaux exports Android
source_platform=android ; un test sous Linux avec android=true ne prouve pas ce
marquage physique et le test sur téléphone le vérifie séparément.

### Téléchargement MP3

Précontrôle du dossier et du nom avant réseau ; permissions persistantes de lecture
et écriture demandées au choix du dossier (une ancienne permission 6A peut exiger
une nouvelle sélection). Nouveaux fichiers MP3 écrits uniquement via les fournisseurs
locaux Android ExternalStorage/Downloads ou le fournisseur IndeX. Les fournisseurs
cloud/personnalisés restent lisibles si leur scan fonctionne, mais leur publication
MP3 est refusée avant téléchargement.

Le service HTTP existant écrit et valide d’abord le MP3 complet dans un temporaire
privé. Même limite 512 Mio, contrôle de format, progression, annulation, URL du
journal et nom système. Politique Android réappliquée à chaque redirection : HTTPS
ou HTTP sur rendezvousavecmrx.free.fr seulement. INTERNET ajouté au manifeste ;
cleartext natif limité à ce domaine, jamais TLS désactivé ni accès réseau automatique.

Dans le dossier géré IndeX, même déplacement privé contrôlé sans remplacement.
Ailleurs, créer un nouveau document SAF, vérifier son nom exact, copier le fichier
complet et comparer l’empreinte avant toute association. La création SAF peut
refuser une collision ou choisir un autre nom ; ce dernier cas est refusé. La
copie peut être visible dans le gestionnaire de fichiers pendant son écriture :
aucune atomicité externe revendiquée. Aucun fichier préexistant n’est tronqué ou
remplacé ; une copie ambiguë n’est jamais supprimée automatiquement.

Le journal natif AtomicFile index-publications.json est durable avant création.
L’entrée reste conservée jusqu’à l’acquittement après engagement de l’association
SQLite, avec identité du profil, épisode et choix initial. Après interruption, une
copie correspondant à l’empreinte complète est validée et associée si les choix
locaux sont toujours compatibles, même sans rescan global ; l’acquittement est
idempotent après une interruption entre SQLite et le journal natif. Un retrait
ou une réassociation intervenus après la demande mettent la publication en
quarantaine au lieu de restaurer silencieusement un choix. Les entrées appartenant
à un autre profil ne sont pas consommées. Une copie non validée est exclue du scan, diagnostiquée et le scan concerné reste
incomplet. Ne supprimer manuellement qu’une copie réellement incomplète après
vérification, jamais un original préexistant. Les dossiers distincts ne sont pas
bloqués par une publication en attente ailleurs. Les temporaires privés abandonnés
sont nettoyés au démarrage. Un marqueur SQLite force également la réconciliation
des publications au démarrage sans scan : les références en cache concernées
sont indisponibles, le favori et le suivi restent intacts. Un journal inaccessible
ne crée pas de profil vide et bloque prudemment les disponibilités en cache.

### Renommage contrôlé et dossier géré

SAF ne fournit pas universellement une primitive sans écrasement concurrent.
Le renommage est donc proposé seulement dans le fournisseur local optionnel
**IndeX · MP3**. Les autres fournisseurs donnent une raison Ignoré dans l’aperçu.
Ne pas remplacer cette restriction par renameDocument/renameTo sans preuve de
non-écrasement, ni par une copie/suppression des octets du MP3.

Le fournisseur expose seulement files/mp3, jamais le profil, les exports ou les
sauvegardes. Permission MANAGE_DOCUMENTS sur le fournisseur, grants URI SAF,
identifiants relatifs validés, chemins canoniques sans liens/sortie de racine.
Le bouton de choix du dossier géré est facultatif et demande confirmation :
**ses MP3 sont supprimés à la désinstallation ou après Effacer les données**.
Le résumé du fournisseur et Fichiers rappellent cette limite ; conserver les
originaux ailleurs. Aucun fichier existant n’est déplacé vers ce dossier.

Renommage même parent, nom historique → nom système uniquement : aperçu,
confirmation globale, collisions casse/NFC et doublons, choix manuels et lecteur
protégés, taille/mtime/SHA-256 contrôlés avant et après. Journal rename_runs/items
commun avant toute mutation ; aucune modification du suivi/favori ni des octets/ID3.
Le fournisseur vérifie la cible puis effectue un déplacement atomique et fsync
sous le même mutex que ses autres mutations. Il reste dans le processus de
l’application. La garantie de non-écrasement dépend de cet espace privé et du
mutex partagé ; elle ne s’applique jamais aux fournisseurs externes. La reprise
reconnaît une source absente et une cible complète. Pour les anciennes versions
utilisant des liens durs, la réconciliation conserve aussi le retrait de l’ancien
nom seulement avec le même inode et la même empreinte. Deux fichiers distincts, droits absents, modifications ou choix manuel
retiré/modifié restent bloqués sans changer les fichiers ni rétablir le suivi.
Le récupérateur Windows ignore content:// ; celui d’Android ne traite pas file://.
Un contrôle partagé protège aussi un MP3 associé manuellement à un autre épisode.

### Construction et signature de diagnostic

Workflow manuel Verification Android Lot 6B, même compteur et verrou que Windows.
Aucun lancement automatique ni publication Release. Le keystore debug est désormais
conservé dans le cache Actions pour les mises à jour de diagnostic suivantes ;
aucune clé n’est committée ni jointe aux artefacts. Cela ne récupère pas les clés
des anciens APK et un ancien certificat différent peut empêcher une mise à jour
directe. Ne pas désinstaller en supposant les données/MP3 privés sauvegardés.
La clé de distribution durable, indépendante de ce cache debug, reste au 6D.

## Vérification et porte de recette

Tests de protocoles sous Linux : DocumentMp3Renamer (états, collisions, changement
de source, lecteur, choix manuels, interruptions et deux inodes), AppModel Android
(JSON aller/retour, erreurs, sauvegardes, références locales, téléchargement réussi
ou refusé et récupération sans scan). Ces doubles ne prouvent pas un fournisseur
SAF physique. L’APK compile la véritable implémentation Kotlin et le contrôle
d’archive vérifie toujours seed et absence de MP3/profil.

Test supervisé android_storage_test.dart et [guide](RECETTE_ANDROID.md) pour copies
seulement. Restent à vérifier sur téléphone : droits lecture/écriture et révocation,
publication/collisions réelles, gestion des interruptions, renommage du fournisseur
IndeX, JSON dans les deux sens avec Windows et mises à jour signées.
Aucune qualification physique 6B ni passage au 6C implicite.


### Identité documentaire et accès multiples

Comparaison des grants par fournisseur + documentId opaque, sans convertir ce
dernier en chemin. Un scan complet peut actualiser le grant d’une association
manuelle vers le même document, sans changer l’épisode ni le suivi. Un retrait
puis une réassociation explicite via un autre grant enlève l’exclusion de cette
même identité ; deux épisodes ne peuvent pas recevoir manuellement ce même
document par des grants différents. Pendant une publication, les références
périmées de même nom chez ce fournisseur sont temporairement indisponibles ;
les références distinctes sont restaurées une fois la cible identifiée. Un échec
ambigu peut nécessiter une nouvelle analyse. Aucun nouveau lien ni actualisation
automatique de grant n’est validé sur un scan incomplet.


## Résultats observés sous Linux — 2 novembre 2026

- Vérifications cœur de `tools/lot4/check.sh` : **7 tests Python et 257 tests Dart
  réussis**, analyse cœur sans diagnostic et formatage conforme.
- Après suppression d’une assertion non-null inutile dans un nouveau test,
  `flutter analyze --no-pub --fatal-infos` : aucun diagnostic ;
  `flutter test --no-pub --reporter expanded --concurrency=1` : **72 tests réussis**.
  Tests Windows existants conservés, nouveaux tests Android incluant reprise
  entre publication/SQLite/acquittement et grants multiples.
- `bash tools/lot5/build_android.sh` : APK debug ARM64 compilé avec les véritables
  modules Kotlin ; seed/manifeste strictement identiques à la référence et aucun
  MP3/profil embarqué. Compilation locale intermédiaire 0.6.0+1, pas de réservation
  de distribution ni de nouveau majeur.
- AAPT : API minimum 24, cible 36, applicationId historique et ARM64 conservés.
  XML permissions/protection du provider/réseau, YAML des workflows et verrou
  partagé vérifiés. Aucun keystore dans Git ou l’archive. La restauration effective
  du cache de signature reste à confirmer par une exécution GitHub Actions.

Le test physique `android_storage_test.dart` est analysé statiquement ; aucun
appareil Android/essai SAF réel n’est revendiqué depuis ce cloud. La recette
Windows native et les échanges Windows ↔ Android physiques restent séparés de
ces vérifications. Aucun commit, push ni publication automatique effectué.


## Correctif du 3 novembre 2026 — export JSON refusé (EACCES)

Sur téléphone, `Os.link` échouait avec `link failed: EACCES` lors de la publication
interne du JSON, avant même le sélecteur externe. Le système refuse cette primitive ;
le message seul ne permet pas d’identifier la règle système exacte. Demander une
permission de dossier supplémentaire ne corrige pas cette opération privée.

Tous les nouveaux liens durs sont supprimés : export JSON, préparation du MP3,
publication MP3 gérée et renommage géré utilisent `PrivateFileMoves`. Ce protocole
valide le confinement canonique sous filesDir et refuse les liens symboliques,
vérifie la cible par lstat sous mutex partagé, puis utilise rename et fsync.
Tous les écrivains du fournisseur restent dans le même processus et prennent ce
mutex ; ne pas déplacer le fournisseur dans un processus séparé sans revoir le
protocole. Aucun changement Windows, aucun nouveau package ni droit de stockage.
Le journal de publication mémorise la cible avant le déplacement pour permettre
la reprise si la synchronisation échoue après la mutation.

Tests reproductibles : `bash tools/lot6/test_private_moves.sh` (JDK 21), aussi en
CI Android. Ils couvrent cible vide/non vide/dossier, liens symboliques, sortie de
racine, concurrence, échec avant déplacement et échec après déplacement. La recette
physique automatisée vérifie aussi la publication privée et le refus d’une cible
existante avant de poursuivre l’export JSON. Ces tests JVM ne qualifient pas le
système de fichiers du téléphone : retester l’export avec le nouvel APK.


Vérifications exécutées sur le correctif : test JVM réussi ; `flutter analyze`
sans anomalie ; 11 tests Flutter ciblés (`android_documents_test.dart` et
`android_publication_test.dart`) réussis. `bash tools/lot5/build_android.sh` réussit
et inspecte l’APK ARM64 : aucun MP3, seed inchangé. SHA-256 de cet APK intermédiaire
local : `c884c485b3d1d42ccdeb2c457dd2682c378fb5d774e9bdce4697d60c877ec10c`.
Aucun numéro de distribution réservé ; aucune recette physique exécutée ici.
