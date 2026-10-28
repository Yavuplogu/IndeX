# Correctifs IndeX — 0.2.3+index.1

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
