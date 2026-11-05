#include "flutter_window.h"
#include <filesystem>
#include <cwchar>
#include <system_error>

#include <optional>
#include <shellapi.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

namespace {
std::wstring DeletionArgument(const flutter::EncodableMap* args, const char* key) {
  if (!args) return {};
  const auto it = args->find(flutter::EncodableValue(key));
  if (it == args->end()) return {};
  const auto* text = std::get_if<std::string>(&it->second);
  if (!text || text->empty() || text->find('\0') != std::string::npos || text->size() > 32767) return {};
  const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text->data(), static_cast<int>(text->size()), nullptr, 0);
  if (size <= 0) return {};
  std::wstring value(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text->data(), static_cast<int>(text->size()), value.data(), size);
  return value;
}
std::wstring DeletionFinalPath(HANDLE file) {
  const DWORD size = GetFinalPathNameByHandleW(file, nullptr, 0, FILE_NAME_NORMALIZED);
  if (!size) return {};
  std::wstring path(size, L'\0');
  const DWORD written = GetFinalPathNameByHandleW(file, path.data(), size, FILE_NAME_NORMALIZED);
  if (!written || written >= size) return {};
  path.resize(written);
  return path;
}
struct DeletionHandle {
  HANDLE value;
  explicit DeletionHandle(HANDLE handle) : value(handle) {}
  ~DeletionHandle() { if (value != INVALID_HANDLE_VALUE) CloseHandle(value); }
};
}  // namespace

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
        if (call.method_name() == "inspectAudioDeletion" || call.method_name() == "deleteHeardAudio") {
          const bool deleting = call.method_name() == "deleteHeardAudio";
          const auto* args = call.arguments() ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
          const auto path = DeletionArgument(args, "path");
          const auto scope = DeletionArgument(args, "scope");
          if (path.empty() || scope.empty() || !std::filesystem::path(path).is_absolute() || !std::filesystem::path(scope).is_absolute()) {
            result->Error("invalid_delete", "Chemin ou dossier MP3 invalide."); return;
          }
          DeletionHandle root(CreateFileW(scope.c_str(), FILE_READ_ATTRIBUTES,
              FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr, OPEN_EXISTING,
              FILE_FLAG_BACKUP_SEMANTICS, nullptr));
          DeletionHandle file(CreateFileW(path.c_str(), FILE_READ_ATTRIBUTES | (deleting ? DELETE : 0),
              deleting ? FILE_SHARE_READ : FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
              nullptr, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr));
          const DWORD file_error = GetLastError();
          if (!deleting && root.value != INVALID_HANDLE_VALUE && file.value == INVALID_HANDLE_VALUE &&
              (file_error == ERROR_FILE_NOT_FOUND || file_error == ERROR_PATH_NOT_FOUND)) {
            result->Success(flutter::EncodableValue(flutter::EncodableMap{
              {flutter::EncodableValue("exists"), flutter::EncodableValue(false)},
              {flutter::EncodableValue("eligible"), flutter::EncodableValue(false)}
            })); return;
          }
          if (root.value == INVALID_HANDLE_VALUE || file.value == INVALID_HANDLE_VALUE) {
            result->Error("delete_access", "Fichier ou dossier absent, inaccessible ou utilise par un autre programme."); return;
          }
          BY_HANDLE_FILE_INFORMATION info{};
          if (!GetFileInformationByHandle(file.value, &info) || (info.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT))) {
            result->Error("delete_type", "Seul un MP3 regulier, sans lien symbolique, est admis."); return;
          }
          auto root_path = DeletionFinalPath(root.value);
          const auto file_path = DeletionFinalPath(file.value);
          if (!root_path.empty() && root_path.back() != L'\\') root_path += L'\\';
          const bool scoped = !root_path.empty() && file_path.size() > root_path.size() &&
              _wcsnicmp(root_path.c_str(), file_path.c_str(), root_path.size()) == 0 &&
              _wcsicmp(std::filesystem::path(file_path).extension().c_str(), L".mp3") == 0;
          const bool eligible = scoped && !(info.dwFileAttributes & FILE_ATTRIBUTE_READONLY);
          const auto identity = std::to_string(info.dwVolumeSerialNumber) + ":" +
              std::to_string(info.nFileIndexHigh) + ":" + std::to_string(info.nFileIndexLow);
          const auto signature = identity + ":" + std::to_string(info.nFileSizeHigh) + ":" +
              std::to_string(info.nFileSizeLow) + ":" + std::to_string(info.ftLastWriteTime.dwHighDateTime) + ":" +
              std::to_string(info.ftLastWriteTime.dwLowDateTime);
          if (deleting) {
            const auto expected = DeletionArgument(args, "signature");
            const std::wstring actual(signature.begin(), signature.end());
            if (!eligible || expected != actual) {
              result->Error("stale_delete", "Fichier modifie ou hors du dossier : suppression refusee."); return;
            }
            FILE_DISPOSITION_INFO disposition{}; disposition.DeleteFile = TRUE;
            // Suppression par handle verrouille, jamais par un nouveau parcours du chemin.
            if (!SetFileInformationByHandle(file.value, FileDispositionInfo, &disposition, sizeof(disposition))) {
              result->Error("delete_failed", "Suppression impossible (droits, protection ou fichier utilise)."); return;
            }
            result->Success(); return;
          }
          result->Success(flutter::EncodableValue(flutter::EncodableMap{
            {flutter::EncodableValue("exists"), flutter::EncodableValue(true)},
            {flutter::EncodableValue("eligible"), flutter::EncodableValue(eligible)},
            {flutter::EncodableValue("identity"), flutter::EncodableValue(identity)},
            {flutter::EncodableValue("signature"), flutter::EncodableValue(signature)},
            {flutter::EncodableValue("reason"), flutter::EncodableValue(eligible ? "" : "Fichier protege ou hors du dossier MP3 choisi.")}
          })); return;
        }
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
        if (call.method_name() == "openGithub") {
          const auto opened = reinterpret_cast<INT_PTR>(ShellExecuteW(
              GetHandle(), L"open", L"https://github.com/Yavuplogu/IndeX",
              nullptr, nullptr, SW_SHOWNORMAL));
          if (opened <= 32) {
            result->Error("open_failed", "Impossible d'ouvrir le lien GitHub.");
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
