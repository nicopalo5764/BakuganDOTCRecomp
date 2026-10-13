// Native Windows launcher. No game data or translated guest code is embedded.
#include <windows.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <shellapi.h>
#include <bcrypt.h>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>
#include <array>
#include <stdexcept>
#include "compatibility.h"

namespace fs = std::filesystem;
namespace {
fs::path exeDir, settingsFile;
HWND folderEdit{}, modeBox{}, sizeBox{}, effectBox{}, rememberBox{};
HFONT font{};
int dpi = 96;
const wchar_t* sizes[] = {L"1280 x 720", L"1600 x 900", L"1920 x 1080", L"2560 x 1440", L"3840 x 2160"};
const int widths[] = {1280,1600,1920,2560,3840}, heights[] = {720,900,1080,1440,2160};
const wchar_t* effects[] = {L"none", L"fxaa", L"fxaa_extreme"};
struct Settings { std::wstring folder; int mode = 0, size = 0, effect = 0; bool show = true; } settings;

// User-facing text. The language follows the Windows UI language (Spanish or
// English) and can be forced with --lang=es / --lang=en.
struct Strings {
  const wchar_t* windowTitle;
  const wchar_t* subtitle;
  const wchar_t* folderLabel;
  const wchar_t* browse;
  const wchar_t* browseTitle;
  const wchar_t* displayLabel;
  const wchar_t* windowed;
  const wchar_t* fullscreen;
  const wchar_t* sizeLabel;
  const wchar_t* sizeNote;
  const wchar_t* effectLabel;
  const wchar_t* effectOff;
  const wchar_t* effectNote;
  const wchar_t* showAtStartup;
  const wchar_t* showAtStartupNote;
  const wchar_t* play;
  const wchar_t* errMissingXex;
  const wchar_t* errBadXex;
  const wchar_t* errBadFile;
  const wchar_t* errBadFileHint;
  const wchar_t* errIncompletePackage;
  const wchar_t* errLaunchFailed;
  const wchar_t* errLaunchFailedHint;
  const wchar_t* errReadWrite;
  const wchar_t* errInit;
};
const Strings kSpanish{
  L"Bakugan: Defenders of the Core — Configuración",
  L"Selecciona tu copia del juego y cómo quieres abrirlo.",
  L"Carpeta del juego original",
  L"Examinar…",
  L"Selecciona la carpeta de tu copia extraída de Xbox 360",
  L"Pantalla",
  L"Ventana",
  L"Pantalla completa (escritorio)",
  L"Tamaño de ventana",
  L"El tamaño de ventana no cambia la resolución interna del juego.",
  L"Suavizado de bordes (experimental)",
  L"Desactivado",
  L"Puede suavizar también textos y detalles. Se aplica al abrir el juego.",
  L"Mostrar esta configuración al iniciar",
  L"Puedes volver usando el acceso directo «Configurar».",
  L"Jugar",
  L"Selecciona la carpeta extraída del juego que contiene default.xex.",
  L"Esta versión de default.xex no es compatible o el archivo está modificado. Consulta README.md para identificar la copia admitida.",
  L"Falta un archivo del juego o su tamaño no coincide: ",
  L". Revisa la extracción de tu copia.",
  L"El paquete está incompleto: falta ",
  L"Windows no pudo iniciar el juego. Código: ",
  L". Consulta los requisitos y las políticas de seguridad del equipo.",
  L"No se pudieron leer los archivos o guardar los ajustes. Comprueba los permisos y la carpeta seleccionada.",
  L"No se pudo inicializar el configurador o leer los archivos.",
};
const Strings kEnglish{
  L"Bakugan: Defenders of the Core — Settings",
  L"Select your copy of the game and how you want to open it.",
  L"Original game folder",
  L"Browse…",
  L"Select the folder of your extracted Xbox 360 copy",
  L"Display",
  L"Windowed",
  L"Fullscreen (desktop resolution)",
  L"Window size",
  L"Window size does not change the game's internal resolution.",
  L"Anti-aliasing (experimental)",
  L"Off",
  L"May also soften text and fine details. Applied when the game starts.",
  L"Show these settings at startup",
  L"You can come back using the \x201C" L"Configure\x201D shortcut.",
  L"Play",
  L"Select the extracted game folder that contains default.xex.",
  L"This version of default.xex is not supported or the file has been modified. See README.md to identify the supported copy.",
  L"A game file is missing or its size does not match: ",
  L". Check your extraction.",
  L"The package is incomplete. Missing: ",
  L"Windows could not start the game. Code: ",
  L". Check the requirements and this computer's security policies.",
  L"Could not read the files or save the settings. Check permissions and the selected folder.",
  L"Could not initialize the launcher or read its files.",
};
const Strings* ui = &kEnglish;
void SelectLanguage(const std::wstring& forced) {
  if (forced == L"es") { ui = &kSpanish; return; }
  if (forced == L"en") { ui = &kEnglish; return; }
  ui = PRIMARYLANGID(GetUserDefaultUILanguage()) == LANG_SPANISH ? &kSpanish : &kEnglish;
}

int Scale(int n) { return MulDiv(n, dpi, 96); }
void Error(HWND parent, const std::wstring& message) {
  MessageBoxW(parent, message.c_str(), L"Bakugan DOTC", MB_OK | MB_ICONERROR);
}
std::wstring Text(HWND control) {
  std::wstring value(GetWindowTextLengthW(control) + 1, L'\0');
  GetWindowTextW(control, value.data(), static_cast<int>(value.size()));
  value.resize(wcslen(value.c_str()));
  return value;
}
void LoadSettings() {
  std::vector<wchar_t> path(32768);
  GetPrivateProfileStringW(L"Launcher", L"GameFolder", L"", path.data(),
                          static_cast<DWORD>(path.size()), settingsFile.c_str());
  settings.folder = path.data();
  settings.mode = GetPrivateProfileIntW(L"Launcher", L"Fullscreen", 0, settingsFile.c_str()) == 1;
  int size = GetPrivateProfileIntW(L"Launcher", L"WindowSize", 0, settingsFile.c_str());
  settings.size = size >= 0 && size < 5 ? size : 0;
  int effect = GetPrivateProfileIntW(L"Launcher", L"PostEffect", 0, settingsFile.c_str());
  settings.effect = effect >= 0 && effect < 3 ? effect : 0;
  settings.show = GetPrivateProfileIntW(L"Launcher", L"Show", 1, settingsFile.c_str()) != 0;
}
void SaveSettings() {
  // UTF-16 preserves game paths containing non-ASCII characters.
  std::wstring data = L"[Launcher]\r\nGameFolder=" + settings.folder +
      L"\r\nFullscreen=" + std::to_wstring(settings.mode) +
      L"\r\nWindowSize=" + std::to_wstring(settings.size) +
      L"\r\nPostEffect=" + std::to_wstring(settings.effect) +
      L"\r\nShow=" + (settings.show ? L"1" : L"0") + L"\r\n";
  std::ofstream output(settingsFile, std::ios::binary | std::ios::trunc);
  const unsigned char bom[] = {0xff, 0xfe};
  output.write(reinterpret_cast<const char*>(bom), sizeof(bom));
  output.write(reinterpret_cast<const char*>(data.data()), data.size() * sizeof(wchar_t));
  output.close();
  if (!output) throw std::runtime_error("settings write failed");
}
std::wstring Sha256(const fs::path& file) {
  struct Hash {
    BCRYPT_ALG_HANDLE algorithm{}; BCRYPT_HASH_HANDLE handle{};
    ~Hash() { if(handle) BCryptDestroyHash(handle); if(algorithm) BCryptCloseAlgorithmProvider(algorithm,0); }
  } hash;
  auto check = [](NTSTATUS status) { if (status < 0) throw std::runtime_error("SHA-256 failed"); };
  check(BCryptOpenAlgorithmProvider(&hash.algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0));
  check(BCryptCreateHash(hash.algorithm, &hash.handle, nullptr, 0, nullptr, 0, 0));
  std::ifstream input(file, std::ios::binary);
  if (!input) throw std::runtime_error("Cannot open XEX");
  std::array<char, 65536> buffer{};
  while (input.read(buffer.data(), buffer.size()) || input.gcount())
    check(BCryptHashData(hash.handle, reinterpret_cast<PUCHAR>(buffer.data()), static_cast<ULONG>(input.gcount()), 0));
  if (!input.eof()) throw std::runtime_error("Cannot read XEX");
  std::array<unsigned char, 32> digest{};
  check(BCryptFinishHash(hash.handle, digest.data(), static_cast<ULONG>(digest.size()), 0));
  std::wstring result;
  for (auto byte : digest) { result += L"0123456789abcdef"[byte >> 4]; result += L"0123456789abcdef"[byte & 15]; }
  return result;
}
std::wstring Validate(const fs::path& folder) {
  std::error_code ec;
  auto xex = folder / L"default.xex";
  if (!fs::is_regular_file(xex, ec)) return ui->errMissingXex;
  if (fs::file_size(xex, ec) != kXexSize || ec || Sha256(xex) != kXexHash)
    return ui->errBadXex;
  for (const auto& file : kRequiredFiles) {
    if (fs::file_size(folder / file.name, ec) != file.size || ec)
      return ui->errBadFile + std::wstring(file.name) + ui->errBadFileHint;
  }
  return L"";
}
// Windows command-line quoting: preserves backslashes preceding quotes/end.
std::wstring Quote(const std::wstring& value) {
  std::wstring result = L"\""; unsigned slashes = 0;
  for (wchar_t c : value) {
    if (c == L'\\') { ++slashes; continue; }
    result.append(c == L'\"' ? slashes * 2 + 1 : slashes, L'\\');
    slashes = 0; result += c;
  }
  result.append(slashes * 2, L'\\'); return result + L"\"";
}
bool Launch(HWND window) {
  try {
    auto problem = Validate(settings.folder);
    if (!problem.empty()) { Error(window, problem); return false; }
    for (const auto* file : {L"bakugandotc.exe", L"rexruntime.dll", L"rexgpu-xenos.dll"}) {
      if (!fs::is_regular_file(exeDir / file)) { Error(window, ui->errIncompletePackage + std::wstring(file)); return false; }
    }
    SaveSettings();
    auto game = exeDir / L"bakugandotc.exe";
    std::wstring command = Quote(game.wstring()) + L" --game_data_root=" + Quote(settings.folder) +
        L" --gpu_plugin=xenos --fullscreen=" + (settings.mode ? L"true" : L"false") +
        L" --window_width=" + std::to_wstring(widths[settings.size]) +
        L" --window_height=" + std::to_wstring(heights[settings.size]) +
        L" --swap_post_effect=" + effects[settings.effect] + L" --log_level=info";
    STARTUPINFOW startup{sizeof(startup)}; PROCESS_INFORMATION process{};
    if (!CreateProcessW(game.c_str(), command.data(), nullptr, nullptr, FALSE, 0, nullptr,
                        exeDir.c_str(), &startup, &process)) {
      Error(window, ui->errLaunchFailed + std::to_wstring(GetLastError()) + ui->errLaunchFailedHint);
      return false;
    }
    CloseHandle(process.hThread); CloseHandle(process.hProcess); return true;
  } catch (const std::exception&) {
    Error(window, ui->errReadWrite);
    return false;
  }
}
void Browse(HWND window) {
  IFileDialog* picker = nullptr;
  if (FAILED(CoCreateInstance(CLSID_FileOpenDialog, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&picker)))) return;
  DWORD options{}; picker->GetOptions(&options);
  picker->SetOptions(options | FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM | FOS_PATHMUSTEXIST);
  picker->SetTitle(ui->browseTitle);
  if (SUCCEEDED(picker->Show(window))) {
    IShellItem* item = nullptr;
    if (SUCCEEDED(picker->GetResult(&item))) {
      PWSTR path = nullptr;
      if (SUCCEEDED(item->GetDisplayName(SIGDN_FILESYSPATH, &path))) {
        SetWindowTextW(folderEdit, path); CoTaskMemFree(path);
      }
      item->Release();
    }
  }
  picker->Release();
}
HWND Control(HWND parent, const wchar_t* type, const wchar_t* text, DWORD style,
             int x, int y, int width, int height, int id = 0) {
  auto control = CreateWindowExW(0, type, text, WS_CHILD | WS_VISIBLE | style, Scale(x), Scale(y),
      Scale(width), Scale(height), parent, reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)), GetModuleHandleW(nullptr), nullptr);
  SendMessageW(control, WM_SETFONT, reinterpret_cast<WPARAM>(font), TRUE); return control;
}
LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
  switch (message) {
  case WM_CTLCOLORSTATIC:
    SetBkMode(reinterpret_cast<HDC>(wparam), TRANSPARENT);
    return reinterpret_cast<LRESULT>(GetSysColorBrush(COLOR_WINDOW));
  case WM_CREATE: {
    Control(window,L"STATIC",L"Bakugan: Defenders of the Core",0,24,20,600,28);
    Control(window,L"STATIC",ui->subtitle,0,24,54,600,24);
    Control(window,L"STATIC",ui->folderLabel,0,24,90,600,24);
    folderEdit = Control(window,L"EDIT",settings.folder.c_str(),WS_BORDER|WS_TABSTOP|ES_AUTOHSCROLL,24,116,470,28);
    Control(window,L"BUTTON",ui->browse,WS_TABSTOP,508,115,116,30,101);
    Control(window,L"STATIC",ui->displayLabel,0,24,164,250,24);
    modeBox = Control(window,L"COMBOBOX",L"",WS_TABSTOP|CBS_DROPDOWNLIST,24,190,275,140,102);
    SendMessageW(modeBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(ui->windowed));
    SendMessageW(modeBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(ui->fullscreen));
    SendMessageW(modeBox,CB_SETCURSEL,settings.mode,0);
    Control(window,L"STATIC",ui->sizeLabel,0,325,164,280,24);
    sizeBox = Control(window,L"COMBOBOX",L"",WS_TABSTOP|CBS_DROPDOWNLIST,325,190,299,180);
    for (const auto* size : sizes) SendMessageW(sizeBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(size));
    SendMessageW(sizeBox,CB_SETCURSEL,settings.size,0); EnableWindow(sizeBox,!settings.mode);
    Control(window,L"STATIC",ui->sizeNote,0,24,230,600,24);
    Control(window,L"STATIC",ui->effectLabel,0,24,263,600,24);
    effectBox = Control(window,L"COMBOBOX",L"",WS_TABSTOP|CBS_DROPDOWNLIST,24,290,600,140);
    for (const auto* effect : {ui->effectOff, L"FXAA", L"FXAA Extreme"})
      SendMessageW(effectBox,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(effect));
    SendMessageW(effectBox,CB_SETCURSEL,settings.effect,0);
    Control(window,L"STATIC",ui->effectNote,0,24,330,600,24);
    rememberBox = Control(window,L"BUTTON",ui->showAtStartup,WS_TABSTOP|BS_AUTOCHECKBOX,24,370,580,26);
    SendMessageW(rememberBox,BM_SETCHECK,settings.show ? BST_CHECKED : BST_UNCHECKED,0);
    Control(window,L"STATIC",ui->showAtStartupNote,0,24,403,600,24);
    Control(window,L"BUTTON",ui->play,WS_TABSTOP|BS_DEFPUSHBUTTON,484,443,140,38,IDOK);
    Control(window,L"STATIC",kVersion,0,24,455,330,24);
    return 0;
  }
  case WM_COMMAND:
    if (LOWORD(wparam)==101) Browse(window);
    if (LOWORD(wparam)==102 && HIWORD(wparam)==CBN_SELCHANGE)
      EnableWindow(sizeBox,SendMessageW(modeBox,CB_GETCURSEL,0,0)==0);
    if (LOWORD(wparam)==IDOK) {
      settings.folder=Text(folderEdit);
      settings.mode=static_cast<int>(SendMessageW(modeBox,CB_GETCURSEL,0,0));
      settings.size=static_cast<int>(SendMessageW(sizeBox,CB_GETCURSEL,0,0));
      settings.effect=static_cast<int>(SendMessageW(effectBox,CB_GETCURSEL,0,0));
      settings.show=SendMessageW(rememberBox,BM_GETCHECK,0,0)==BST_CHECKED;
      if(Launch(window)) DestroyWindow(window);
    }
    return 0;
  case WM_DESTROY: PostQuitMessage(0); return 0;
  }
  return DefWindowProcW(window,message,wparam,lparam);
}
}
int WINAPI wWinMain(HINSTANCE instance,HINSTANCE,PWSTR,int show) {
  // Headless validation must not open windows or write user settings.
  int argumentCount=0; auto arguments=CommandLineToArgvW(GetCommandLineW(),&argumentCount);
  bool configure=false;
  std::wstring language;
  for(int i=1;arguments && i<argumentCount;++i) {
    std::wstring argument=arguments[i];
    if(argument.rfind(L"--lang=",0)==0) language=argument.substr(7);
    else if(argument==L"--lang" && i+1<argumentCount) language=arguments[i+1];
  }
  SelectLanguage(language);
  for(int i=1;arguments && i<argumentCount;++i) {
    if(std::wstring(arguments[i])==L"--configure") configure=true;
    if(std::wstring(arguments[i])==L"--validate") {
      int status=2;
      try { if(i+1<argumentCount) status=Validate(arguments[i+1]).empty() ? 0 : 2; }
      catch(const std::exception&) { status=3; }
      LocalFree(arguments); return status;
    }
  }
  if(arguments) LocalFree(arguments);
  SetProcessDPIAware();
  HRESULT com=CoInitializeEx(nullptr,COINIT_APARTMENTTHREADED);
  int result = 0;
  try {
    std::vector<wchar_t> module(32768);
    if (!GetModuleFileNameW(nullptr,module.data(),static_cast<DWORD>(module.size()))) throw std::runtime_error("module path");
    exeDir=fs::path(module.data()).parent_path();
    PWSTR local=nullptr;
    if(FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData,0,nullptr,&local))) throw std::runtime_error("user directory");
    fs::path userDir=fs::path(local)/L"BakuganDOTCRecomp"; CoTaskMemFree(local);
    fs::create_directories(userDir); settingsFile=userDir/L"launcher.ini"; LoadSettings();
    if(!configure && !settings.show && Launch(nullptr)) { }
    else {
      HDC screen=GetDC(nullptr); dpi=GetDeviceCaps(screen,LOGPIXELSX); ReleaseDC(nullptr,screen);
      font=CreateFontW(-Scale(16),0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,0,0,CLEARTYPE_QUALITY,0,L"Segoe UI");
      WNDCLASSW type{}; type.lpfnWndProc=WindowProc; type.hInstance=instance;
      type.lpszClassName=L"BakuganDOTCLauncher"; type.hCursor=LoadCursorW(nullptr,IDC_ARROW);
      type.hIcon=LoadIconW(instance,MAKEINTRESOURCEW(1));
      type.hbrBackground=reinterpret_cast<HBRUSH>(COLOR_WINDOW+1); RegisterClassW(&type);
      RECT area{0,0,Scale(650),Scale(505)}; DWORD style=WS_OVERLAPPED|WS_CAPTION|WS_SYSMENU|WS_MINIMIZEBOX;
      AdjustWindowRect(&area,style,FALSE);
      HWND window=CreateWindowExW(0,type.lpszClassName,ui->windowTitle,style,CW_USEDEFAULT,CW_USEDEFAULT,
          area.right-area.left,area.bottom-area.top,nullptr,nullptr,instance,nullptr);
      if(!window) throw std::runtime_error("window creation");
      ShowWindow(window,show); MSG message{};
      while(GetMessageW(&message,nullptr,0,0)>0) {
        if(!IsDialogMessageW(window,&message)) {TranslateMessage(&message);DispatchMessageW(&message);}
      }
      DeleteObject(font);
    }
  } catch(const std::exception&) { Error(nullptr,ui->errInit); result=1; }
  if(SUCCEEDED(com)) CoUninitialize(); return result;
}
