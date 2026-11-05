# Lot 6 — Portage Android et qualification

Décision du 1er novembre 2026 : réaffecter le Lot 6 à la préparation puis au
portage Android. Lancement explicite du Lot 6 le 1er novembre 2026 :
étape 6A confirmée par l’utilisateur le 2 novembre, puis lancement explicite de 6B.
Le 3 novembre, validation utilisateur de 6B et du paysage, puis lancement de 6C.
Le découpage documentaire a été validé le 1er novembre 2026.
Les étapes seront exécutées successivement, avec bilan et validation avant
élargissement du périmètre.

## Situation de départ

L’utilisateur confirme que tous les points restants de la recette/distribution
Windows sont vérifiés, sauf la Release GitHub. C’est une validation utilisateur,
pas une nouvelle recette native exécutée depuis le cloud. La Release Windows
reste une tâche distincte, sans publication automatique ni passage en finale.

À réutiliser : Flutter/Dart, catalogue SQLite de 716 épisodes sans MP3 embarqué,
FTS5, associations par noms du journal, suivi, sauvegardes et moteur de fusion JSON
v2 (lecture v1). Conserver les identités métier et les règles Windows récentes.

État initial avant 6B (historique) : Android possédait une activité Kotlin, un accès
aux dossiers SAF, un lecteur
MediaPlayer, une UI adaptée partiellement aux petits écrans et un workflow APK
de test manuel. Il s’agit d’un socle à réévaluer, pas d’une version qualifiée :
- renommage, JSON et téléchargement étaient désactivés (portés en 6B selon les
  limites décrites dans [le bilan 6B](bilan-6B.md)) ;
- le lecteur de MainActivity est suspendu dans onStop, sans service de lecture
  continue en arrière-plan ;
- la configuration release utilisait la clé debug avant le 6D ; l’identifiant
  historique `fr.index.index_windows` est remplacé le 5 novembre par `fr.index.app`.

## 6A — Audit Android et décisions de plateforme

Recompiler le socle avec le lockfile, inventorier les écarts fonctionnalité par
fonctionnalité, préciser versions Android/architectures et appareils de recette.
Vérifier les packages, licences, API et contraintes des versions Android ciblées.
Décider de l’identifiant définitif avant une distribution pérenne, du stockage
privé du profil, des sélecteurs SAF, du moteur audio et du comportement écran
éteint/arrière-plan. Ne pas remplacer automatiquement le moteur Android par le
plugin Windows : mesurer le moteur existant sur les MP3 de régression.

Livrable : matrice Windows/Android, décisions et APK de diagnostic si compilable.
Porte : faisabilité démontrée sur appareil réel pour accès persistant au dossier,
lecture/recherche SQLite FTS5 et lecture/seek MP3 via références content://.
Une compilation ou un émulateur seul ne valide pas les comportements physiques.

## 6B — Stockage, fichiers et transfert

Révision du 3 novembre 2026 : le renommage Android est désactivé sur demande de
l’utilisateur, y compris dans le dossier géré IndeX. Fonction réservée à Windows,
mentionnée comme telle dans les Paramètres Android. Les exigences de renommage
Android ci-dessous décrivent l’objectif historique et ne sont plus un critère de
livraison ; conserver la compatibilité des anciens journaux. Les autres fonctions
6B et la porte de validation restent applicables.

Adapter les interfaces de plateforme aux documents SAF : permissions persistantes,
scan récursif, association manuelle, disparition et récupération d’accès. Garder
le suivi dans le stockage privé et permettre sa sauvegarde/transfert sans exposer
le SQLite à un fournisseur documentaire. Expliquer la perte des données privées
à la désinstallation et le rôle de l’export manuel.

Porter export/import JSON v2, téléchargement explicite et renommage contrôlé.
Choisir une destination d’export réalisable sous Android sans prétendre qu’un URI
est un chemin Windows. Publier les téléchargements après réception complète et
contrôle, sans écrasement. Éprouver les garanties de chaque fournisseur SAF :
renommage, collision, changement d’URI, interruption et réconciliation des liens.
Si un fournisseur ne garantit pas une opération sûre, la refuser avec diagnostic ;
ne pas simuler l’atomicité Windows ou contourner silencieusement une collision.

Livrable : opérations sur fichiers et transfert fiables sur copies de test.
Porte : permissions révoquées et interruptions sans perte de suivi ni écrasement ;
transferts Windows → Android → Windows avec conflits, reset et imports répétés.

## 6C — Interface mobile et lecture

Adapter navigation liste/fiche/lecteur, panneaux, clavier tactile, bouton Retour,
rotation et tailles de texte ; préserver thèmes, filtres, favoris, recherche et
toutes les fonctions essentielles. Ne pas recopier les commandes de fenêtre et
les chemins portables Windows dans les parcours Android.

Raccorder le moteur audio retenu aux règles de suivi actuelles : checkpoints,
réécoute, arrêt/reset, seek jusqu’à la fin, aléatoire et suivant non écouté.
Si la lecture continue écran éteint est retenue en 6A, implémenter service média,
notification/commandes système, focus audio et permissions adaptées aux versions
ciblées. Tester appels, casque retiré, autres lecteurs et arrêt du processus.
Ne pas dépendre uniquement de la fermeture pour persister le suivi.

Livrable : version mobile fonctionnelle avec parité documentée.
Porte : usage et reprise fiables sur appareil réel, sans régression Windows.

## 6D — Recette et distribution Android

Recette sur les appareils et versions retenus : installation vierge sans TXT/CSV,
716 fiches/FTS5, mode avion (hors téléchargement volontaire), MP3 de régression,
stockage insuffisant, mise à jour conservant suivi et accès, redémarrage, cycle
de vie et transferts réels. Auditer permissions, accès réseau et licences.

Préparer APK de diffusion signé avec une clé durable conservée hors dépôt, codes
de version croissants, sommes SHA-256, guide et notes de version. Une clé debug
ne qualifie pas une distribution finale. Le canal initial peut être une Release
GitHub ; Google Play et AAB ne sont pas imposés par ce plan. L’identité et la clé
doivent être conservées pour les mises à jour. Aucun secret ne doit être commité.

Livrable : APK qualifié et dossier de recette. Publication uniquement sur demande.

## Organisation et limites

Un Lot 6 avec quatre étapes suffit : pas besoin de rouvrir les Lots 5 bis/ter ni
de créer une seconde application indépendante. Éviter une seule livraison massive :
SAF et le cycle de vie audio peuvent imposer des choix structurants. Les étapes
peuvent préparer certaines tâches en parallèle, mais leurs portes restent ordonnées.
Le majeur reste 0.6 tant qu’aucune nouvelle instruction explicite ne le change ;
le portage ne vaut pas passage en version finale. Avant un APK distribuable,
aligner son versionnement sur la politique du projet sans réinitialiser le compteur.
iOS demeure exclu. Aucun nouveau package runtime ajouté. Les adaptateurs 6B sont
implémentés ; 6B et le paysage sont validés par l’utilisateur sur son appareil.
Le dernier 6C est validé par l’utilisateur le 4 novembre 2026 ; le 6D est lancé.
La préparation release est décrite dans [le bilan 6D](bilan-6D.md), avec
[signature/distribution](DISTRIBUTION_ANDROID.md) et [recette du candidat](RECETTE_6D.md). Voir [l’audit 6A](audit-6A.md)
et [la recette](RECETTE_ANDROID.md).
