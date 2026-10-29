#include "flutter_window.h"

#include <optional>
#include <shellapi.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  folder_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "index/local_folders",
      &flutter::StandardMethodCodec::GetInstance());
  folder_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "openContactEmail") {
          const auto opened = reinterpret_cast<INT_PTR>(ShellExecuteW(
              GetHandle(), L"open", L"mailto:index.en9nr@passinbox.com",
              nullptr, nullptr, SW_SHOWNORMAL));
          if (opened <= 32) {
            result->Error("mail_unavailable", "Impossible d'ouvrir la messagerie.");
          } else {
            result->Success();
          }
          return;
        }
        if (call.method_name() != "openDirectory") {
          result->NotImplemented();
          return;
        }
        const auto* path = call.arguments() ? std::get_if<std::string>(call.arguments()) : nullptr;
        if (!path || path->empty() || path->size() > 32767 || path->find('\0') != std::string::npos) {
          result->Error("invalid_path", "Chemin de dossier invalide.");
          return;
        }
        const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path->data(), static_cast<int>(path->size()), nullptr, 0);
        if (size <= 0) {
          result->Error("invalid_path", "Chemin Unicode invalide.");
          return;
        }
        std::wstring folder(static_cast<size_t>(size), L'\0');
        MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path->data(), static_cast<int>(path->size()), folder.data(), size);
        const DWORD attributes = GetFileAttributesW(folder.c_str());
        if (attributes == INVALID_FILE_ATTRIBUTES || !(attributes & FILE_ATTRIBUTE_DIRECTORY)) {
          result->Error("missing_directory", "Dossier inaccessible.");
          return;
        }
        const auto opened = reinterpret_cast<INT_PTR>(ShellExecuteW(
            GetHandle(), L"open", folder.c_str(), nullptr, nullptr, SW_SHOWNORMAL));
        if (opened <= 32) {
          result->Error("open_failed", "Impossible d'ouvrir le dossier.");
          return;
        }
        result->Success();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Dart/window_manager shows the window after its close listener and window
  // options are ready. Do not expose a half-initialized window on first frame.
  // Request that first frame even while the native window remains hidden.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  folder_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      if (flutter_controller_ && flutter_controller_->engine()) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
