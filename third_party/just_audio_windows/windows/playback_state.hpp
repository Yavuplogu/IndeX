#pragma once
#include <cstdint>

// Protocole ProcessingStateMessage de just_audio : idle/loading/buffering/ready/completed.
inline int IndexProcessingState(bool failed, bool none, bool opening,
                                bool buffering, int64_t position, int64_t duration) {
  if (failed || none) return 0;
  if (opening) return 1;
  if (buffering) return 2;
  // La durée peut encore être inconnue : 0 == 0 n'est pas une fin de piste.
  if (duration > 0 && position >= duration) return 4;
  return 3;
}
