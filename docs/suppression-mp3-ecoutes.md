# Supprimer les MP3 des épisodes écoutés

Fonction Windows et Android, ajoutée après la validation utilisateur de 0.7.01.
La version distribuée suivante garde la série 0.7 et reçoit le prochain mineur
réservé par la CI. Aucun changement de schéma SQLite, de format JSON ou de package.

## Utilisation

1. Ouvrir **Paramètres → Fichiers audio → Supprimer les MP3 écoutés**.
2. Examiner l’aperçu et les chemins. Il utilise les associations existantes du
   catalogue, sans créer de lien par nom pour décider d’une suppression.
3. Les filtres affichent tous les résultats, ceux à supprimer, exclus, absents,
   supprimés, en échec ou à vérifier. Ils ne changent pas le périmètre de l’action :
   la confirmation concerne tous les fichiers proposés, même masqués par un filtre.
4. **Confirmer la suppression** ouvre une confirmation supplémentaire avec le
   nombre de fichiers. **Annuler** ne modifie aucun fichier ni suivi.
5. **Supprimer définitivement** effectue l’opération, fichier par fichier. La
   suppression ne garantit aucun passage par une corbeille et n’est pas annulable.

La fenêtre conserve ses dimensions sous filtrage. En paysage ou avec une petite
hauteur, l’en-tête et les actions défilent séparément et la liste reste visible.
Couleurs, cadres, filtres et typographie reprennent le panneau de renommage.
Messages, références et journal sont copiables.

## Périmètre et données conservées

Seuls les liens disponibles et confirmés d’épisodes **Écouté** sont proposés.
Le fichier doit être dans le dossier MP3 configuré ; les sous-dossiers sont
admis pour les fichiers déjà associés. Un fichier extérieur, non confirmé,
ambigu, inaccessible ou chargé dans le lecteur est exclu. Une piste en pause
est également chargée. **Libérer la piste chargée** sauvegarde et décharge le
lecteur sans utiliser Arrêt/reset ; un nouvel aperçu est alors préparé.

La fonction ne fait pas appel au retrait d’association : elle conserve le statut
Écouté, la progression, les favoris et les autres données utilisateur. Le lien
local est marqué indisponible puis le dossier est réanalysé pour actualiser les
listes et compteurs. Il n’y a pas de remise à zéro ni d’exclusion permanente de
réassociation : un MP3 retrouvé ou téléchargé pourra redevenir disponible au scan.

Les épisodes Non écouté et En cours ne sont jamais des cibles. Un même document
lié par plusieurs grants SAF, ou un alias physique identifié sous Windows, est
contrôlé pour éviter une suppression ambiguë. Les fichiers sont revalidés après
l’aperçu : statut, lien, disponibilité, dossier, identité, taille/date et lecteur.
Un aperçu ne peut être utilisé qu’une seule fois et ne peut changer de profil.
Les téléchargements actifs et opérations de publication/renommage non réconciliées
empêchent le démarrage de la suppression.

## Adaptateurs natifs

**Windows** : vérification d’un MP3 régulier sans lien symbolique/reparse point,
chemin final résolu dans le dossier choisi, volume et identifiant de fichier,
taille et date de modification. La suppression ouvre un handle avec droit DELETE
et sans partage en écriture/suppression, revérifie l’empreinte de métadonnées et
utilise `SetFileInformationByHandle(FileDispositionInfo)`. Pas de shell, de
suppression de dossier ou de nouvelle résolution du chemin pour effacer.
Les fichiers protégés ou utilisés par un autre programme peuvent être refusés.

**Android** : URI SAF conservée opaque ; même fournisseur et périmètre du tree,
document distinct du dossier racine, nom MP3, type non répertoire, métadonnées
connues et droit d’écriture. Le fournisseur doit annoncer FLAG_SUPPORTS_DELETE.
`DocumentsContract.deleteDocument` utilise les droits existants du dossier ;
aucune permission globale de stockage, nouveau package ou accès à l’ancien
emplacement privé n’est ajouté. Un refus ou retrait d’autorisation est rapporté.
Les métadonnées et le grant sont revérifiés dans l’appel natif destructif.

L’empreinte utilisée ici est une identité et des métadonnées, pas une preuve
cryptographique du contenu audio. Les API d’un fournisseur SAF externe ne
permettent pas une transaction commune avec SQLite ni une garantie universelle
contre une modification externe entre la dernière vérification et l’effacement.
L’application applique les contrôles décrits, refuse les situations non vérifiables
et n’annonce pas une atomicité globale de tout le lot.

## Échecs et interruptions

Le journal `heard_audio_deletion_v1` est local dans `local_settings`. Avant chaque
appel natif, une transaction SQLite durable marque le lien indisponible et écrit
l’intention `deleting`. Après l’appel, le résultat est enregistré. Aucune donnée
d’écoute n’est supprimée. En cas d’échec, la disponibilité n’est rétablie que si
la présence du même fichier est confirmée ; le scan réconcilie ensuite l’état.

Le bouton **Dernier journal** affiche les résultats, sélectionnables. Une entrée
`deleting` après un arrêt brutal signifie **à vérifier**, pas suppression certaine.
Aucune opération destructive n’est reprise automatiquement. Relancer une analyse
dans Fichiers puis examiner un nouvel aperçu avant toute nouvelle confirmation.
Le journal conserve le dernier lot ; ce n’est pas une sauvegarde des MP3.

## Vérification

- Tests du cœur sur fichiers temporaires : aperçu sans effet, statuts et favoris
  intacts, journal avant l’appel natif, alias, piste chargée, fichier/état/lien
  modifiés, permissions perdues, échecs partiels et interruption simulée.
- Tests widgets Windows/Android simulés : accès depuis Paramètres, filtres,
  dimensions stables en portrait/paysage, annulation, confirmation et scan après
  suppression. Les suppressions ne touchent que les fichiers temporaires des tests.
- Recette native Windows existante étendue : fichier Unicode temporaire, refus
  d’une ancienne empreinte et d’un périmètre extérieur, suppression confirmée.
  Elle sera exécutée sur Windows par son workflow ; pas qualifiée depuis Linux.
- Sur téléphone, tester avec des copies : fournisseur local, lecteur chargé/en
  pause, droits révoqués, MP3 absents, réouverture après interruption et conservation
  du suivi. La compilation APK ne remplace pas cette recette physique.


## Résultats automatisés de cette modification

`bash tools/lot4/check.sh` : 16 tests Python du versionnement, **267 tests Dart**
et **97 tests Flutter** réussis ; format et analyses sans problème. Les 10 nouveaux
tests du cœur et les 2 tests widgets de suppression font partie de ces suites.
Après optimisation du cache de résolution des chemins par lot, les 10 tests du
cœur ont été rejoués avec succès. APK Android diagnostic compilé et inspecté,
aucun MP3 embarqué. Ces vérifications sont effectuées sous Linux ; le test natif
Windows ajouté à la recette et la recette réelle Android restent à exécuter
sur les plateformes correspondantes. La validation historique 0.7.01 ne couvre
pas automatiquement ce nouveau comportement destructif.
