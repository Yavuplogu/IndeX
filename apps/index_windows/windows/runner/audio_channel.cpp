#include "audio_channel.h"
#include <flutter/standard_method_codec.h>
#include <string>
#include <digitalv.h>
#include <variant>
AudioChannel::AudioChannel(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "index/audio", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) { Handle(call, std::move(result)); });
}
AudioChannel::~AudioChannel() {
  CloseDevice();
}
MCIERROR AudioChannel::CloseDevice() {
  if (!device_) return 0;
  MCI_GENERIC_PARMS args{};
  const MCIERROR error = mciSendCommandW(device_, MCI_CLOSE, MCI_WAIT,
      reinterpret_cast<DWORD_PTR>(&args));
  if (!error) { device_ = 0; was_playing_ = false; }
  return error;
}
DWORD AudioChannel::Status(DWORD item, MCIERROR* error) {
  MCI_STATUS_PARMS args{}; args.dwItem = item;
  *error = mciSendCommandW(device_, MCI_STATUS, MCI_STATUS_ITEM | MCI_WAIT, reinterpret_cast<DWORD_PTR>(&args));
  return static_cast<DWORD>(args.dwReturn);
}
void AudioChannel::Handle(const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& method = call.method_name();
  MCIERROR error = 0;
  if (method == "open") {
    const auto* raw = call.arguments() ? std::get_if<std::string>(call.arguments()) : nullptr;
    if (!raw || raw->empty() || raw->size() > 32767 || raw->find('\0') != std::string::npos) { result->Error("audio_path", "Chemin audio invalide."); return; }
    // Dart fournit un chemin local Windows, jamais une URL distante.
    const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, raw->data(), static_cast<int>(raw->size()), nullptr, 0);
    if (size <= 0) { result->Error("audio_path", "Chemin Unicode invalide."); return; }
    std::wstring path(static_cast<size_t>(size), L'\0');
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, raw->data(), static_cast<int>(raw->size()), path.data(), size);
    error = CloseDevice();
    if (error) {
      result->Error("audio_native", "Impossible de liberer le lecteur Windows (MCI " + std::to_string(error) + ").");
      return;
    }
    // Le pilote mpegvideo attend les structures digital-video completes.
    MCI_DGV_OPEN_PARMSW args{}; args.lpstrDeviceType = L"mpegvideo"; args.lpstrElementName = path.c_str();
    error = mciSendCommandW(0, MCI_OPEN, MCI_OPEN_TYPE | MCI_OPEN_ELEMENT | MCI_WAIT, reinterpret_cast<DWORD_PTR>(&args));
    if (!error) {
      device_ = args.wDeviceID;
      MCI_DGV_SET_PARMS format{}; format.dwTimeFormat = MCI_FORMAT_MILLISECONDS;
      error = mciSendCommandW(device_, MCI_SET, MCI_SET_TIME_FORMAT | MCI_WAIT, reinterpret_cast<DWORD_PTR>(&format));
    }
    was_playing_ = false;
  } else if (method == "release") {
    error = CloseDevice();
  } else if (!device_) { result->Error("audio_closed", "Aucun audio ouvert."); return;
  } else if (method == "play") {
    // Meme sans MCI_FROM/MCI_TO, le bloc de parametres est obligatoire.
    MCI_PLAY_PARMS args{};
    error = mciSendCommandW(device_, MCI_PLAY, 0, reinterpret_cast<DWORD_PTR>(&args));
    was_playing_ = !error;
  } else if (method == "pause") {
    const DWORD mode = Status(MCI_STATUS_MODE, &error);
    if (!error && mode == MCI_MODE_PLAY) {
      MCI_GENERIC_PARMS args{};
      error = mciSendCommandW(device_, MCI_PAUSE, MCI_WAIT, reinterpret_cast<DWORD_PTR>(&args));
    }
    was_playing_ = false;
  } else if (method == "seek") {
    int64_t value = 0;
    if (const auto* v = std::get_if<int32_t>(call.arguments())) value = *v;
    else if (const auto* v64 = std::get_if<int64_t>(call.arguments())) value = *v64;
    else { result->Error("audio_seek", "Position invalide."); return; }
    if (value < 0 || value > MAXDWORD) { result->Error("audio_seek", "Position hors limites."); return; }
    MCI_SEEK_PARMS args{}; args.dwTo = static_cast<DWORD>(value);
    error = mciSendCommandW(device_, MCI_SEEK, MCI_TO | MCI_WAIT, reinterpret_cast<DWORD_PTR>(&args));
  } else if (method == "volume") {
    const auto* level = std::get_if<double>(call.arguments());
    if (!level || *level < 0 || *level > 1) { result->Error("audio_volume", "Volume invalide."); return; }
    MCI_DGV_SETAUDIO_PARMS args{}; args.dwItem = MCI_DGV_SETAUDIO_VOLUME; args.dwValue = static_cast<DWORD>(*level * 1000);
    error = mciSendCommandW(device_, MCI_SETAUDIO, MCI_DGV_SETAUDIO_ITEM | MCI_DGV_SETAUDIO_VALUE | MCI_WAIT, reinterpret_cast<DWORD_PTR>(&args));
  } else if (method == "snapshot") {
    const DWORD position = Status(MCI_STATUS_POSITION, &error);
    if (error) { result->Error("audio_status", "Position audio indisponible."); return; }
    const DWORD duration = Status(MCI_STATUS_LENGTH, &error);
    if (error) { result->Error("audio_status", "Duree audio indisponible."); return; }
    const DWORD mode = Status(MCI_STATUS_MODE, &error);
    if (!error) {
      const bool playing = mode == MCI_MODE_PLAY;
      const bool ended = was_playing_ && !playing && duration > 0 && position + 500 >= duration;
      result->Success(flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue("position"), flutter::EncodableValue(static_cast<int64_t>(position))},
        {flutter::EncodableValue("duration"), flutter::EncodableValue(static_cast<int64_t>(duration))},
        {flutter::EncodableValue("playing"), flutter::EncodableValue(playing)},
        {flutter::EncodableValue("ended"), flutter::EncodableValue(ended)}})); return;
    }
  } else { result->NotImplemented(); return; }
  if (error) {
    wchar_t message[256]{};
    std::string detail;
    if (mciGetErrorStringW(error, message, 256)) {
      const int size = WideCharToMultiByte(CP_UTF8, 0, message, -1, nullptr, 0, nullptr, nullptr);
      if (size > 1) {
        detail.resize(static_cast<size_t>(size));
        WideCharToMultiByte(CP_UTF8, 0, message, -1, detail.data(), size, nullptr, nullptr);
        detail.pop_back();
      }
    }
    result->Error("audio_native", "Echec du lecteur Windows [" + method + "] (MCI " +
        std::to_string(error) + "). " + detail);
  }
  else result->Success();
}
