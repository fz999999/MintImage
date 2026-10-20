#pragma once
// Minimal stand-in for <atlbase.h> used only when the C++ ATL component is not
// installed with the MSVC toolchain.
//
// The only ATL facility used by the plugins we build (currently
// flutter_local_notifications_windows) is the CW2A(wide, codePage) string
// conversion macro. This header provides a small, UTF-16 -> narrow converter
// with the same call shape, implemented on top of WideCharToMultiByte so that
// behaviour matches ATL's CW2A.

#ifndef MINTIMAGE_ATL_SHIM_ATLBASE_H_
#define MINTIMAGE_ATL_SHIM_ATLBASE_H_

#include <windows.h>

#include <vector>

class CW2A {
 public:
  explicit CW2A(const wchar_t* text, UINT code_page = CP_ACP) {
    if (text == nullptr) {
      buffer_.push_back('\0');
      return;
    }
    const int length = ::WideCharToMultiByte(
        code_page, 0, text, -1, nullptr, 0, nullptr, nullptr);
    if (length <= 0) {
      buffer_.push_back('\0');
      return;
    }
    buffer_.resize(static_cast<std::size_t>(length));
    if (::WideCharToMultiByte(
            code_page, 0, text, -1, buffer_.data(), length, nullptr, nullptr) <= 0) {
      buffer_.assign(1, '\0');
    }
  }

  operator const char*() const { return buffer_.data(); }

 private:
  std::vector<char> buffer_;
};

#endif  // MINTIMAGE_ATL_SHIM_ATLBASE_H_
