#pragma once
#include <functional>
#include <mutex>
#include <string>
#include <utility>
#include <vector>

// Les callbacks WinRT ne touchent ni AudioPlayer ni le messager Flutter.
// Ils gardent uniquement un weak_ptr vers cette file, vidée sur le thread UI.
class IndexAudioNotifications {
 public:
  using Error = std::pair<std::string, std::string>;
  explicit IndexAudioNotifications(std::function<void()> wake) : wake_(std::move(wake)) {}
  void Signal() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!stopped_) wake_();
  }
  void SignalError(std::string code, std::string message) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (stopped_) return;
    errors_.emplace_back(std::move(code), std::move(message));
    wake_();
  }
  std::vector<Error> TakeErrors() {
    std::lock_guard<std::mutex> lock(mutex_);
    auto errors = std::move(errors_);
    errors_.clear();
    return errors;
  }
  void Stop() {
    std::lock_guard<std::mutex> lock(mutex_);
    stopped_ = true;
    errors_.clear();
    wake_ = {};
  }
 private:
  std::mutex mutex_;
  bool stopped_ = false;
  std::function<void()> wake_;
  std::vector<Error> errors_;
};
