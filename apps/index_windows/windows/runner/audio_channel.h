#ifndef INDEX_AUDIO_CHANNEL_H_
#define INDEX_AUDIO_CHANNEL_H_
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>
#include <windows.h>
#include <mmsystem.h>
#include <memory>
class AudioChannel {
 public:
  explicit AudioChannel(flutter::BinaryMessenger* messenger);
  ~AudioChannel();
 private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  MCIDEVICEID device_ = 0;
  bool was_playing_ = false;
  void Handle(const flutter::MethodCall<flutter::EncodableValue>& call,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  DWORD Status(DWORD item, MCIERROR* error);
};
#endif
