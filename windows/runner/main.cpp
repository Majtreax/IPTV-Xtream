#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"IPTV Xtream", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    if (msg.message == WM_KEYDOWN) {
      if (msg.wParam == VK_F11) {
        HWND hwnd = ::GetAncestor(msg.hwnd, GA_ROOT);
        static bool is_fullscreen = true;
        if (is_fullscreen) {
          ::SetWindowLong(hwnd, GWL_STYLE, WS_OVERLAPPEDWINDOW | WS_VISIBLE);
          int screen_width = ::GetSystemMetrics(SM_CXSCREEN);
          int screen_height = ::GetSystemMetrics(SM_CYSCREEN);
          int x = (screen_width - 1280) / 2;
          int y = (screen_height - 720) / 2;
          ::SetWindowPos(hwnd, HWND_TOP, x, y, 1280, 720, SWP_FRAMECHANGED);
          is_fullscreen = false;
        } else {
          ::SetWindowLong(hwnd, GWL_STYLE, WS_POPUP | WS_VISIBLE);
          int width = ::GetSystemMetrics(SM_CXSCREEN);
          int height = ::GetSystemMetrics(SM_CYSCREEN);
          ::SetWindowPos(hwnd, HWND_TOP, 0, 0, width, height, SWP_FRAMECHANGED);
          is_fullscreen = true;
        }
        continue;
      }
    }
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
