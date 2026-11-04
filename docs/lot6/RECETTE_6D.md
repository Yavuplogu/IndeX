# Fiche de recette Android — Lot 6D

## État et identification

Le 4 novembre 2026, l’utilisateur confirme la validation du **dernier 6C** sur son
téléphone et autorise le 6D. Cette validation est acquise ; elle n’est pas présentée
comme une recette exécutée depuis Linux. Les contrôles automatisés du 6D et leurs
résultats sont dans [le bilan](bilan-6D.md).

Pour chaque APK release candidat, consigner :

| Donnée | À renseigner sur le candidat |
| --- | --- |
| Version publique / versionCode | Rapport `release-apk.json` |
| Commit construit / run Actions | URL du run |
| SHA-256 APK et certificat | Rapport et fichier `.sha256` |
| Modèle(s), Android/API, RAM, forme de l’icône | Appareil(s) effectivement utilisé(s) |
| Fournisseur SAF / stockage externe ou privé | Nom et emplacement |
| Testeur, date, résultat et incident éventuel | Ne pas remplacer par « compilation réussie » |

Objectif de couverture : Android 7–9/API 24–28, 11–13/API 30–33 et 14–16/API 34–36.
Si une tranche ne peut pas être testée, la déclarer **non qualifiée** au lieu de
revendiquer une validation universelle. Le téléphone déjà validé au 6C reste une
preuve utilisateur utile ; son modèle et sa version exacte ne sont pas encore consignés.

## Scénarios de clôture

| Test | Attendu | État du candidat release |
| --- | --- | --- |
| Installation vierge sans TXT/CSV/MP3 | 716 fiches, FTS5, catalogue intégré, liste absente grisée | À consigner |
| Mode avion, dossier local | Recherche multichamp, favoris, écoute et transfert JSON sans réseau | À consigner |
| MP3 de régression de `MP3_Files/MP3_Bugs` | Lecture, pause, seeks et durées cohérents, sans blocage | À consigner |
| MP3 absents, droits SAF révoqués/restaurés | Diagnostic exploitable, suivi préservé, nouveau choix possible | À consigner |
| Téléchargement volontaire | Choix dossier, nom système, annulation/collision sans écrasement | À consigner |
| Stockage insuffisant (copies/profil de test) | Erreur sélectionnable, pas de fichier publié incomplet, suivi intact | À consigner |
| Transfert Windows → Android → Windows | JSON v2, conflit groupé cohérent, reset/favoris, import répété sans duplication | À consigner |
| Rotation, clavier, grandes polices, thèmes | Pas de débordement, fiche/menus utilisables, recherche gauche en paysage | Dernier 6C validé ; vérifier release |
| Écran éteint/arrière-plan, notification, appel/message, casque | Lecture et reprise conformes, pause utilisateur jamais annulée | Dernier 6C validé ; vérifier release |
| Seek fin (souris/tactile et ±10 s), réécoute et auto-suivant | Écouté au terme, nouvelle écoute remise à zéro, suivant non écouté | Dernier 6C validé ; vérifier release |
| Arrêt processus/redémarrage téléphone | Dernier checkpoint durable récupéré, pas de lecture forcée | À consigner |
| Mise à jour release N → N+1, même clé, sans désinstaller | VersionCode supérieur, suivi/favoris/réglages et droits SAF conservés | Deux releases nécessaires |
| Passage debug → release avec certificat différent | Refus normal d’update ; sauvegarde externe avant réinstallation manuelle | À consigner si applicable |
| Réseau au repos (capture si disponible) | Aucun trafic propre à IndeX hors téléchargement explicite | Revue statique faite, capture non réalisée |

Les scénarios détaillés restent dans [RECETTE_ANDROID.md](RECETTE_ANDROID.md).
N’effectuer les essais destructifs (stockage saturé, retrait de permission,
désinstallation, arrêt forcé) que sur des copies après sauvegarde externe.

## Décision de diffusion

Le 6D peut avancer sans nouvelle validation du 6C. Sa clôture nécessite la clé
release sauvegardée par son propriétaire, un APK contrôlé signé par cette clé,
les résultats physiques du candidat et une mise à jour N → N+1. Les essais sans
appareil restent distincts. La publication GitHub n’est pas déclenchée par cette
fiche ; elle reste soumise à une demande explicite.
