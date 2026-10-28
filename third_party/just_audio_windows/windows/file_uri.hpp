#pragma once
#include <algorithm>
#include <stdexcept>
#include <string>

inline int IndexHexDigit(char c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return -1;
}

inline std::string IndexDecodeUriBytes(const std::string& value) {
  std::string result;
  for (size_t i = 0; i < value.size(); ++i) {
    char c = value[i];
    if (c == '%') {
      if (i + 2 >= value.size()) throw std::invalid_argument("URI file: incomplete percent escape");
      const int hi = IndexHexDigit(value[i + 1]), lo = IndexHexDigit(value[i + 2]);
      if (hi < 0 || lo < 0) throw std::invalid_argument("URI file: invalid percent escape");
      c = static_cast<char>((hi << 4) | lo);
      i += 2;
    }
    if (c == '\0') throw std::invalid_argument("URI file: null byte");
    result += c; // '+' est un nom de fichier, jamais un espace.
  }
  return result;
}

inline bool IndexIsFileUri(const std::string& uri) {
  if (uri.size() < 5) return false;
  std::string scheme = uri.substr(0, 5);
  for (char& c : scheme) if (c >= 'A' && c <= 'Z') c = static_cast<char>(c + ('a' - 'A'));
  return scheme == "file:";
}

// Décodage UTF-8 exactement une fois, sans normalisation des noms/accents.
inline std::string IndexWindowsPathFromFileUri(const std::string& uri) {
  if (!IndexIsFileUri(uri) || uri.substr(5, 2) != "//" || uri.find_first_of("?#") != std::string::npos)
    throw std::invalid_argument("URI file: absolute file URI required");
  const size_t slash = uri.find('/', 7);
  if (slash == std::string::npos) throw std::invalid_argument("URI file: missing path");
  auto host = IndexDecodeUriBytes(uri.substr(7, slash - 7));
  auto path = IndexDecodeUriBytes(uri.substr(slash));
  std::string lower = host;
  for (char& c : lower) if (c >= 'A' && c <= 'Z') c = static_cast<char>(c + ('a' - 'A'));
  if (!host.empty() && lower != "localhost") {
    if (host.find_first_of("/\\:@") != std::string::npos || path.size() <= 1)
      throw std::invalid_argument("URI file: invalid UNC authority");
    path = "//" + host + path;
  } else {
    const bool drive = path.size() >= 4 && path[0] == '/' && path[2] == ':' && path[3] == '/' &&
      ((path[1] >= 'A' && path[1] <= 'Z') || (path[1] >= 'a' && path[1] <= 'z'));
    if (!drive) throw std::invalid_argument("URI file: missing Windows drive");
    path.erase(0, 1);
  }
  std::replace(path.begin(), path.end(), '/', '\\');
  return path;
}
