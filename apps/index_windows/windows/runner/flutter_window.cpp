#include "flutter_window.h"
#include <filesystem>
#include <cwchar>
#include <system_error>

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
        if (call.method_name() == "publishDownload" || call.method_name() == "renameMp3" || call.method_name() == "publishExport") {
          const bool renaming = call.method_name() == "renameMp3";
          const bool exporting = call.method_name() == "publishExport";
          const auto* args = call.arguments() ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
          auto path = [args](const char* key) -> std::wstring {
            if (!args) return {};
            const auto found = args->find(flutter::EncodableValue(key));
            if (found == args->end()) return {};
            const auto* value = std::get_if<std::string>(&found->second);
            if (!value || value->empty() || value->size() > 32767 || value->find('\0') != std::string::npos) return {};
            const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value->data(), static_cast<int>(value->size()), nullptr, 0);
            if (size <= 0) return {};
            std::wstring converted(static_cast<size_t>(size), L'\0');
            MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value->data(), static_cast<int>(value->size()), converted.data(), size);
            return converted;
          };
          const auto source = std::filesystem::path(path(renaming ? "source" : "partial"));
          const auto target = std::filesystem::path(path("target"));
          std::error_code directory_error;
          if (!source.is_absolute() || !target.is_absolute() ||
              (!renaming && (source.filename() != L"payload.part" ||
                source.parent_path().filename().wstring().find(exporting ? L".index-export-" : L".index-download-") != 0)) ||
              (renaming && (_wcsicmp(source.extension().c_str(), L".mp3") != 0)) ||
              (renaming && _wcsicmp(target.extension().c_str(), L".mp3") != 0) ||
              (exporting && _wcsicmp(target.extension().c_str(), L".json") != 0) ||
              !std::filesystem::equivalent(renaming ? source.parent_path() : source.parent_path().parent_path(), target.parent_path(), directory_error)) {
            result->Error(renaming ? "invalid_rename" : "invalid_download", "Chemins de publication invalides.");
            return;
          }
          const DWORD attributes = GetFileAttributesW(source.c_str());
          if (attributes == INVALID_FILE_ATTRIBUTES || (attributes & (FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DIRECTORY))) {
            result->Error("invalid_source", "Le fichier source est inaccessible ou non regulier.");
            return;
          }
          // Aucun MOVEFILE_REPLACE_EXISTING : une cible concurrente est conservée.
          if (!MoveFileExW(source.c_str(), target.c_str(), MOVEFILE_WRITE_THROUGH)) {
            const DWORD error = GetLastError();
            result->Error(error == ERROR_FILE_EXISTS || error == ERROR_ALREADY_EXISTS ? "target_exists" : "publish_failed",
                          "Operation du MP3 impossible (code Windows " + std::to_string(error) + "). Aucun fichier existant remplace.");
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
