# Correctifs IndeX — 0.2.3+index.2

Copie de just_audio_windows 0.2.3, sous MIT (LICENSE original conservé).
`UPSTREAM.json` décrit l’archive et les empreintes originales. Ne pas modifier
le cache pub : le projet utilise cette dépendance locale versionnée.

Motif : certains chargements restent sans notification exploitable jusqu’au
timeout. Le code upstream n’écoute que PlaybackStateChanged, perd les événements
antérieurs à l’abonnement Dart, et transmet les erreurs en erreurs EventChannel
que just_audio 0.10.6 ignore dans son abonnement aux événements natifs.

Modifications de windows/player.hpp et du plugin :

- Les callbacks WinRT ne transmettent plus de messages Flutter sur un thread
  secondaire. Une file protégée est signalée par PostMessage à la fenêtre racine ;
  le délégué Flutter la vide sur le thread UI. Les callbacks ne gardent qu’un
  weak_ptr vers la file, arrêtée à Dispose ; aucun pointeur de lecteur n’est
  déréférencé par le thread secondaire. Le plugin ignore les messages de lecteurs
  détruits et libère ses lecteurs avant la destruction de Flutter/COM.
- Dernier événement conservé et rejoué à l’abonnement, accès au cache/sink protégé
  par mutex ; retrait explicite du handler à la destruction du sink.
- Notifications MediaOpened et NaturalDurationChanged ajoutées, révoquées avant
  destruction, avec diffusion de l’état.
- MediaFailed/ItemFailed produisent un événement normal avec état idle et
  errorCode 1001/errorMessage (code natif et message conservés). Cela permet à
  just_audio de sortir de loading et d’exposer l’erreur, même si la session
  WinRT ne permet plus de lire position/durée.
- Exceptions hresult_error/std::exception du chargement converties en réponse
  MethodChannel en erreur, sans laisser échapper l’exception C++.
- État terminé seulement pour une durée connue strictement positive ; le cas
  position=durée=0 est ready, pas completed. Calcul isolé dans playback_state.hpp.

Le projet ne remplace aucun décodeur Windows, ne convertit aucun MP3 et ne modifie
aucun tag. Les correctifs de notification ne garantissent pas qu’un fichier
refusé par WinRT sera décodé : l’erreur réelle doit alors apparaître et être
journalisée. Les huit fichiers MP3_Bugs constituent la recette Windows restante.

Contrôle C++ portable : depuis la racine IndeX,
`g++ -std=c++17 -pthread -Wall -Wextra -Werror tools/lot5/test_audio_state.cpp -o /tmp/index-audio-state-test`
puis `/tmp/index-audio-state-test`. Ceci valide la classification d’état et la file entre threads, pas le
plugin Windows complet ni le décodage WinRT.


## index.2 — accès exact aux MP3 locaux

Signalement : `(1001) sourceNotSupportedError: The system cannot find the file specified`
pour trois fichiers malgré le correctif de notifications. Cette erreur ne prouve
pas un défaut d’encodage MP3. Les URI file ne passent plus par CreateFromUri :
`file_uri.hpp` extrait le chemin absolu, décode les octets UTF-8 exactement une
fois, préserve accents NFC/NFD, espaces, `%`, `+`, parenthèses et chemins UNC.
Le chemin est converti en UTF-16, ouvert par `CreateRandomAccessStreamOnFile` en
`Windows.Storage.FileAccessMode::Read`, puis transmis à
`MediaSource::CreateFromStream(..., L"audio/mpeg")`. Shcore.lib est une API système
Windows (pas de binaire tiers supplémentaire). Aucun chargement complet en RAM,
aucune copie, écriture ou conversion du MP3. Le flux permet les seeks.

Les URL non file gardent leur chemin upstream (l’application IndeX les refuse).
La voie locale de ce fork est prévue pour les MP3, seul format proposé par IndeX.
La source MediaSource conserve la référence du flux ; elle est libérée avec le lecteur.
Le test C++ portable couvre aussi le décodage des chemins, caractères spéciaux,
NFD, UNC et erreurs de pourcentage/NUL. La lecture par flux WinRT reste à valider
sur Windows ; ce test n’en fait pas la preuve.
