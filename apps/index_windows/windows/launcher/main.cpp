#include <windows.h>

#include <string>
#include <vector>

int APIENTRY wWinMain(HINSTANCE, HINSTANCE, wchar_t* arguments, int) {
  std::vector<wchar_t> module(32768);
  const DWORD length = GetModuleFileNameW(nullptr, module.data(), static_cast<DWORD>(module.size()));
  if (length == 0 || length >= module.size()) return ERROR_BAD_PATHNAME;
  const std::wstring path(module.data(), length);
  const std::wstring directory = path.substr(0, path.find_last_of(L"\\/")) + L"\\application";
  const std::wstring executable = directory + L"\\IndeX.exe";
  std::wstring command = L"\"" + executable + L"\" " + arguments;
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  // Preserve redirected diagnostics when launched by the packaging smoke test.
  startup.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
  startup.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
  startup.hStdError = GetStdHandle(STD_ERROR_HANDLE);
  const bool redirected =
      (startup.hStdOutput != nullptr && startup.hStdOutput != INVALID_HANDLE_VALUE) ||
      (startup.hStdError != nullptr && startup.hStdError != INVALID_HANDLE_VALUE);
  if (redirected) startup.dwFlags = STARTF_USESTDHANDLES;
  PROCESS_INFORMATION child{};
  if (!CreateProcessW(executable.c_str(), command.data(), nullptr, nullptr, redirected ? TRUE : FALSE, 0,
                      nullptr, directory.c_str(), &startup, &child)) {
    const DWORD error = GetLastError();
    MessageBoxW(nullptr,
      L"Impossible de lancer IndeX. Extrayez toute l’archive et conservez le dossier application à côté de IndeX.exe.",
      L"IndeX", MB_OK | MB_ICONERROR);
    return static_cast<int>(error);
  }
  CloseHandle(child.hThread);
  const DWORD wait = WaitForSingleObject(child.hProcess, INFINITE);
  DWORD code = ERROR_PROCESS_ABORTED;
  if (wait == WAIT_OBJECT_0) GetExitCodeProcess(child.hProcess, &code);
  CloseHandle(child.hProcess);
  return static_cast<int>(code);
}
