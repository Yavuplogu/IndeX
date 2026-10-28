#include "../../third_party/just_audio_windows/windows/playback_state.hpp"
#include <cassert>
#include <atomic>
#include <memory>
#include <thread>
#include "../../third_party/just_audio_windows/windows/notification_queue.hpp"
int main() {
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
