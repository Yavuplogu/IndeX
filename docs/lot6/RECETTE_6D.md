> Décision du 5 novembre 2026 — série **0.7.01** : l’emplacement privé
> « IndeX · MP3 » est supprimé, ainsi que son bouton et le fournisseur Android.
> Aucun accès de récupération n’est conservé. Choisir un dossier MP3 visible
> dans le sélecteur Android. Aucun fichier existant n’est supprimé par ce retrait.
> Le stockage privé du profil (favoris, progression, réglages) reste nécessaire
> et distinct. Les exports JSON utilisent toujours une destination choisie.
> Identifiant `fr.index.app` et clé durable conservés.

# Fiche de recette Android — Lot 6D

## Validation utilisateur de la version 0.7.01

L’utilisateur confirme que tous les points applicables de recette sont vérifiés,
y compris **la mise à jour signée sans désinstallation**, et déclare l’application
fonctionnelle sur les appareils suivants :

| Appareil | Version Android déclarée | Version IndeX |
| --- | --- | --- |
| Google Pixel 9 | 17 | 0.7.01 |
| Google Pixel 10 | 17 | 0.7.01 |
| OnePlus 15 | 17 | 0.7.01 |
| Samsung Galaxy S21 | 14 | 0.7.01 |

Il s’agit des résultats communiqués par l’utilisateur, pas de tests matériels
exécutés dans le cloud. Aucun relevé détaillé par scénario/appareil, capture
réseau, SHA-256 de l’APK ou URL du run n’a été fourni ici ; ne pas les inventer.
Les appareils et versions plus anciens non cités ne sont pas qualifiés par cette
validation. Le Lot 6D est **validé fonctionnellement par l’utilisateur pour 0.7.01** ;
publication GitHub toujours distincte. Les changements ultérieurs de l’en-tête
À propos et du lien GitHub nécessitent une vérification sur le prochain build.

## État et identification

Le 4 novembre 2026, l’utilisateur confirme la validation du **dernier 6C** sur son
téléphone et autorise le 6D. Cette validation est acquise ; elle n’est pas présentée
comme une recette exécutée depuis Linux. Les contrôles automatisés du 6D et leurs
résultats sont dans [le bilan](bilan-6D.md).

Pour chaque APK release candidat, consigner :

| Donnée | À renseigner sur le candidat |
| --- | --- |
| Version publique / versionCode | Rapport `release-apk.json` |
| Identifiant définitif | `fr.index.app` (depuis le 5 novembre) |
| Commit construit / run Actions | URL du run |
| SHA-256 APK et certificat | Rapport et fichier `.sha256` |
| Modèle(s), Android/API, RAM, forme de l’icône | Appareil(s) effectivement utilisé(s) |
| Fournisseur SAF / stockage externe ou privé | Nom et emplacement |
| Testeur, date, résultat et incident éventuel | Ne pas remplacer par « compilation réussie » |

Objectif de couverture : Android 7–9/API 24–28, 11–13/API 30–33 et 14–16/API 34–36.
Si une tranche ne peut pas être testée, la déclarer **non qualifiée** au lieu de
revendiquer une validation universelle. La validation 0.7.01 sur les quatre appareils ci-dessus complète celle du 6C.

## Scénarios de clôture

| Test | Attendu | État du candidat release |
| --- | --- | --- |
| Installation vierge sans TXT/CSV/MP3 | 716 fiches, FTS5, catalogue intégré, liste absente grisée | Validé par l’utilisateur en 0.7.01 |
| Mode avion, dossier local | Recherche multichamp, favoris, écoute et transfert JSON sans réseau | Validé par l’utilisateur en 0.7.01 |
| MP3 de régression de `MP3_Files/MP3_Bugs` | Lecture, pause, seeks et durées cohérents, sans blocage | Validé par l’utilisateur en 0.7.01 |
| MP3 absents, droits SAF révoqués/restaurés | Diagnostic exploitable, suivi préservé, nouveau choix possible | Validé par l’utilisateur en 0.7.01 |
| Téléchargement volontaire | Choix dossier, nom système, annulation/collision sans écrasement | Validé par l’utilisateur en 0.7.01 |
| Stockage insuffisant (copies/profil de test) | Erreur sélectionnable, pas de fichier publié incomplet, suivi intact | Validé par l’utilisateur en 0.7.01 |
| Transfert Windows → Android → Windows | JSON v2, conflit groupé cohérent, reset/favoris, import répété sans duplication | Validé par l’utilisateur en 0.7.01 |
| Rotation, clavier, grandes polices, thèmes | Pas de débordement, fiche/menus utilisables, recherche gauche en paysage | Validé par l’utilisateur en 0.7.01 |
| Écran éteint/arrière-plan, notification, appel/message, casque | Lecture et reprise conformes, pause utilisateur jamais annulée | Validé par l’utilisateur en 0.7.01 |
| Seek fin (souris/tactile et ±10 s), réécoute et auto-suivant | Écouté au terme, nouvelle écoute remise à zéro, suivant non écouté | Validé par l’utilisateur en 0.7.01 |
| Arrêt processus/redémarrage téléphone | Dernier checkpoint durable récupéré, pas de lecture forcée | Validé par l’utilisateur en 0.7.01 |
| Mise à jour release N → N+1, même clé, sans désinstaller | VersionCode supérieur, suivi/favoris/réglages et droits SAF conservés | Mise à jour signée validée par l’utilisateur |
| Passage ancien identifiant → `fr.index.app` | Installation indépendante, JSON exporté/importé et nouveau choix SAF ; MP3 privés sauvegardés avant retrait de l’ancienne | Validé par l’utilisateur en 0.7.01 |
| Passage debug → release avec certificat différent | Refus normal d’update ; sauvegarde externe avant réinstallation manuelle | Validation globale utilisateur ; détail de transition non fourni |
| Réseau au repos (capture si disponible) | Aucun trafic propre à IndeX hors téléchargement explicite | Revue statique faite, capture non réalisée |

Les scénarios détaillés restent dans [RECETTE_ANDROID.md](RECETTE_ANDROID.md).
N’effectuer les essais destructifs (stockage saturé, retrait de permission,
désinstallation, arrêt forcé) que sur des copies après sauvegarde externe.

## Décision de diffusion

La recette fonctionnelle et la mise à jour signée du 6D sont validées par
l’utilisateur en 0.7.01. Les conditions ci-dessous décrivent les éléments de
distribution à conserver, sans remettre en cause cette validation. Sa clôture nécessite la clé
release sauvegardée par son propriétaire, un APK contrôlé signé par cette clé,
les résultats physiques du candidat et une mise à jour N → N+1. Les essais sans
appareil restent distincts. La publication GitHub n’est pas déclenchée par cette
fiche ; elle reste soumise à une demande explicite.
