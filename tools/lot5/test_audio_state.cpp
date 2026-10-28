#include "../../third_party/just_audio_windows/windows/playback_state.hpp"
#include <cassert>
#include "../../third_party/just_audio_windows/windows/file_uri.hpp"
#include <atomic>
#include <memory>
#include <thread>
#include "../../third_party/just_audio_windows/windows/notification_queue.hpp"
int main() {
  assert(IndexWindowsPathFromFileUri("file:///C:/Mes%20MP3/Ha%C3%AFti%20(2%20sur%202).mp3") == u8"C:\\Mes MP3\\Haïti (2 sur 2).mp3");
  assert(IndexWindowsPathFromFileUri("file:///E:/Le%20tr%C3%A9sor%20sovi%C3%A9tique.mp3") == u8"E:\\Le trésor soviétique.mp3");
  assert(IndexWindowsPathFromFileUri("file:///E:/Rhod%C3%A9sie%20(1%20sur%202).mp3") == u8"E:\\Rhodésie (1 sur 2).mp3");
  assert(IndexWindowsPathFromFileUri("file:///C:/nom%2520%23%25%2B.mp3") == "C:\\nom%20#%+.mp3");
  assert(IndexWindowsPathFromFileUri("file:///C:/L'accord+test.mp3") == "C:\\L'accord+test.mp3");
  assert(IndexWindowsPathFromFileUri("file://server/Mes%20MP3/No%C3%ABl.mp3") == u8"\\\\server\\Mes MP3\\Noël.mp3");
  assert(IndexWindowsPathFromFileUri("file://localhost/C:/x.mp3") == "C:\\x.mp3");
  // NFD conservé, aucune modification de l'orthographe réelle du fichier.
  assert(IndexWindowsPathFromFileUri("file:///C:/e%CC%81.mp3") == std::string("C:\\e\xcc\x81.mp3"));
  for (const auto* invalid : {"https://host/x.mp3", "file:///C:/x%00.mp3", "file:///C:/x%ZZ.mp3", "file:///C:/x%", "file:///C:/x.mp3?q=1", "file:///relatif.mp3", "file://user@host/share/x"}) {
    bool rejected = false;
    try { IndexWindowsPathFromFileUri(invalid); } catch (const std::invalid_argument&) { rejected = true; }
    assert(rejected);
  }

  std::atomic<int> wake{0};
  auto queue = std::make_shared<IndexAudioNotifications>([&wake] { ++wake; });
  std::thread state([queue] { for (int i = 0; i < 100; ++i) queue->Signal(); });
  std::thread errors([queue] { for (int i = 0; i < 100; ++i) queue->SignalError("decode", "detail"); });
  state.join();
  errors.join();
  assert(wake == 200);
  assert(queue->TakeErrors().size() == 100);
  assert(queue->TakeErrors().empty());
  queue->Stop();
  std::thread late([queue] { queue->Signal(); queue->SignalError("late", "ignored"); });
  late.join();
  assert(wake == 200);
  assert(queue->TakeErrors().empty());
  std::weak_ptr<IndexAudioNotifications> weak = queue;
  queue.reset();
  assert(weak.expired());

  assert(IndexProcessingState(false, false, false, false, 0, 0) == 3);
  assert(IndexProcessingState(false, false, true, false, 0, 0) == 1);
  assert(IndexProcessingState(false, false, false, true, 10, 120) == 2);
  assert(IndexProcessingState(false, false, false, false, 0, 120) == 3);
  assert(IndexProcessingState(false, false, false, false, 120, 120) == 4);
  assert(IndexProcessingState(true, false, true, false, 0, 0) == 0);
  // Durée et position en 100 ns : des émissions longues dépassent int32_t.
  assert(IndexProcessingState(false, false, false, false, 2309000000000LL, 2309000000000LL) == 4);
}
