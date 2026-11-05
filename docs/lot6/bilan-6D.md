## Actualisation du 5 novembre 2026 — 0.7.01

Retrait demandé du fournisseur « IndeX · MP3 » du manifeste, du bouton d’option,
de son message dans Fichiers et de la commande native managedTree. Aucun accès
historique n’est réservé, aucune suppression de MP3 n’est effectuée. Les fonctions
internes de publication privée JSON restent nécessaires et ne sont pas exposées
par un fournisseur. Les téléchargements MP3 acceptent les fournisseurs locaux
Android, sans l’ancien fournisseur IndeX. Le profil privé reste inchangé.

Série publique 0.7.01 (Flutter 0.7.1), premier code technique 7001 pour conserver
la progression Android depuis 0.6. Alias, certificat et identifiant inchangés.
Tests de versionnement couvrant le changement de majeur et l’historique : 8
réussis ; tests de distribution : 5 réussis, dont refus de l’ancien fournisseur
s’il réapparaît dans le manifeste. Analyse Flutter et 9 tests ciblés Android (documents, export/import JSON,
téléchargement et interface) réussis. Compilation release finale réussie avec clé jetable de validation retirée après
le test : fournisseur absent du manifeste réel, refus des anciennes URI présent
dans le DEX compilé, versionName 0.7.1 et versionCode 7001 contrôlés. SHA-256 de
cet APK local de contrôle : `e022a25b746c8ddf4f23e0dba773721663570d6eef5631da4b2fbc2add01275a`.
Aucune recette physique ou nouvelle construction CI n’est revendiquée.

# Lot 6D — préparation de recette et distribution Android

Lancé le **4 novembre 2026**, après validation utilisateur du dernier 6C.
Le lot avance sans rouvrir cette validation. La chaîne de distribution est
préparée ; la clôture physique du candidat release reste à consigner.

## Actualisation du 5 novembre 2026 — identité définitive et icône

Sur instruction utilisateur, adopter **`fr.index.app`** avant distribution durable.
Application ID et namespace Gradle, packages et chemins Java/Kotlin, manifeste,
actions média et fournisseur `fr.index.app.documents` alignés. La mention du
fournisseur privé dans l’interface et les tests/contrôles de distribution suivent
la nouvelle identité. Le contrôle release refuse aussi l’ancienne identité et
une ancienne autorité documentaire. Aucun changement d’identité Windows, des
schémas ou du compteur. Les résultats du 4 novembre ci-dessous restent historiques.

Android crée une nouvelle installation indépendante, même à signature identique.
Les deux applications peuvent coexister. Export/import JSON, nouveau choix SAF
et copie externe des MP3 privés sont documentés avant retrait de l’ancienne.
Un keystore déjà créé reste valable : aucun changement des secrets, de l’alias
ou de l’empreinte GitHub requis pour ce changement de package.

X de l’icône Android réduit de **12 %**, centré ; fond beige adaptatif conservé,
replis Android 7/7.1 alignés. Icône blanche de notification et logo dans l’UI
inchangés. Vérification de la géométrie et du XML, APK diagnostic compilé :
identité/activité/service/fournisseur vérifiés dans le manifeste réel et absence
des anciennes classes dans les DEX. Pas de recette sur téléphone depuis Linux.

Vérifications du 5 novembre :

- 257 tests du cœur et 94 tests Flutter, analyses/format : réussis ;
  tests Java des publications
  privées et des interruptions audio : réussis.
- 5 tests de distribution : réussis, avec refus de l’ancienne identité et d’un
  ancien fournisseur documentaire.
- APK diagnostic : compilation et inspection réussies, SHA-256
  `e11ecb112767adcf86836fafa9acaf984cf728ca76f293cf1c1a7122ddaaac22`.
- APK release ARM64 : compilation et inspection réelle `aapt`/`apksigner` réussies,
  SHA-256 `838d63a4648422e2b9a4480ad2e21120e9a64c5747704d87e74cfcd283087952`.
  Clé jetable de validation, retirée après essai ; pas une clé de distribution.
  Version locale `0.6.0-validation`, aucune réservation officielle.
- YAML du workflow valide ; copies des guides liées incluses dans l’artefact
  release pour garder leur consultation possible après décompression.
- Sources natives déplacées comparées au commit précédent : seuls le package et
  ses identifiants changent. Schémas, seed et lockfiles inchangés.

Guide détaillé de création sur PC Windows :
[SIGNATURE_ANDROID_DEPUIS_WINDOWS.md](SIGNATURE_ANDROID_DEPUIS_WINDOWS.md).
Temurin n’est pas imposé si un autre JDK compatible est déjà disponible.

## Décisions et réalisation

- Identifiant `fr.index.index_windows`, Android API 24 minimum/cible 36 ARM64,
  catalogue 716 épisodes et schémas existants conservés. Aucun MP3 embarqué.
- Aucun changement du code fonctionnel partagé Windows/Android ou package runtime.
  Le majeur reste 0.6 bêta, compteur et verrou Windows/Android inchangés.
- Workflow Android **manuel** renommé Verification Android Lot 6D, choix diagnostic
  (défaut, cache de clé test et nom d’artefact conservés) ou release.
- Gradle n’utilise plus la clé debug pour une release. Configuration de signature
  exigée, keystore décodé dans le temporaire du runner, droit 0600, retrait même
  en échec, aucun cache de clé release ni inclusion dans les artefacts.
- APK release AOT signé, contrôlé par `apksigner` et `aapt` : certificat SHA-256
  attendu, identifiant/version/API, absence de debuggable/testOnly, sauvegarde
  Android désactivée, permissions fusionnées strictement autorisées, ARM64 seul,
  catalogue/manifeste exacts et notices, aucun MP3/profil/keystore.
- Livrable CI : APK versionné, SHA-256, rapport, commit/run de provenance,
  notices, guide, notes et fiche de recette. Aucune publication GitHub automatique.
- Différence diagnostic/release et transition de certificat documentées : export
  JSON externe et sauvegarde des MP3 privés **avant** une éventuelle réinstallation.

Premier essai release : échec Java, registrant Flutter conservant le plugin
`integration_test` alors que Gradle exclut les dépendances de développement.
Cause vérifiée dans Flutter 3.47.7 : `--no-pub` empêche la régénération du registrant
pour le mode release. Le script vérifie d’abord le lockfile puis laisse Flutter
régénérer ce registrant. Second essai : compilation/signature/inspection réussies.
Aucun ajout du plugin de tests à la release, aucune modification du SDK ou lockfile.

## Vérifications réalisées dans le cloud Linux

- `python3 -m unittest discover -s tools/lot6 -p 'test_*.py'` : **5 tests réussis**,
  refus de certificats/versions/permissions inattendus, APK debug, catalogue altéré,
  fichiers sensibles et architecture supplémentaire ; secrets temporaires protégés,
  refus du script sans configuration de signature.
- `tools/lot6/test_private_moves.sh` et `test_audio_interruptions.sh` avec JDK 21 :
  réussis. Les règles de stockage et reprise audio du 6C sont préservées.
- `bash tools/lot4/check.sh` : réussi, 7 tests Python versionnement,
  **257 tests Dart cœur** et **94 tests Flutter** réussis, format et analyses sans
  problème. Tests exécutés sous Linux, pas une recette native Windows.
- YAML du workflow et Python intégré de packaging parsés ; syntaxe bash vérifiée.
  Extraction réelle des notices (1 375 762 octets) et création de provenance : réussies.
- Build local **release ARM64 de validation** : `tools/lot6/build_release.sh`,
  avec clé jetable explicitement distincte d’une clé de distribution, réussi.
  Pas de réservation d’un numéro officiel : code local 1, version Flutter 0.6.0,
  version UI `0.6.0-validation`. APK d’environ 24 Mo, pas destiné à diffusion.
- SHA-256 de cet APK local :
  `a6751b4e5f1c272d841a0fe9573a775fcb7672fc65b3896bdcc294ef2e9b0895`.
  Certificat temporaire :
  `f72b9de14bbd9a8a230bceb5d8fe487efe1168f64cddb92ce508ceb4bdf249f2`.
  Ces empreintes ne sont **pas** la future identité de distribution.
- Inspection réelle de l’APK signé : réussie. Même APK présenté avec une autre
  empreinte : refusé. Copie altérée après signature : refusée par `apksigner`.
- Reconstruction diagnostic avec `bash tools/lot5/build_android.sh`, sans clé
  release : réussie, inspection réussie et SHA-256 identique au dernier diagnostic
  (`6cb357aec2227ef4ff6a7b0e27499efd1908d74c7de6198a2f698dd1b9f4248a`).
  Le mode test est préservé. La clé jetable de validation release a été retirée
  après les essais ; aucune clé de distribution n’a été créée.
- Gradle `:app:assembleRelease --dry-run` sans configuration : refus explicite
  « Signature release absente », aucun repli vers debug.

## À terminer avant clôture et diffusion

1. Le propriétaire crée, sauvegarde et configure sa **clé durable** et les secrets
   Actions selon [le guide](DISTRIBUTION_ANDROID.md). Aucune clé définitive n’a été
   créée dans un environnement cloud éphémère ; aucun secret n’est à fournir ici.
2. Lancer une release CI sur la révision contrôlée et conserver ses empreintes.
3. Consigner la recette du candidat et la mise à jour release N → N+1 dans
   [RECETTE_6D.md](RECETTE_6D.md), avec modèles/versions réellement testés.
   Le dernier 6C est validé par l’utilisateur ; cela ne prouve pas encore une
   installation/mise à jour avec la nouvelle signature release sur téléphone.
4. Publication GitHub uniquement sur instruction ultérieure. Pas de changement
   de majeur ni passage en finale, pas de Google Play ou iOS ajouté.

L’audit statique réseau/permissions et les licences sont détaillés dans le guide.
Aucune capture réseau sur téléphone, recette matérielle supplémentaire ou
validation Windows native n’a été exécutée depuis Linux.
