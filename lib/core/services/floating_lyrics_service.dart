import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import '../utils/debug_log.dart';

// ═══════════════════════════════════════════════════════════════
//  Win32 Constants
// ═══════════════════════════════════════════════════════════════

const _WS_POPUP        = 0x80000000;
const _WS_VISIBLE      = 0x10000000;
const _WS_EX_LAYERED   = 0x00080000;
const _WS_EX_TOPMOST   = 0x00000008;
const _WS_EX_TOOLWINDOW= 0x00000080;
const _WS_EX_NOACTIVATE= 0x08000000;

const _SWP_NOMOVE      = 0x0002;
const _SWP_NOSIZE      = 0x0001;
const _SWP_NOACTIVATE  = 0x0010;
const _SWP_SHOWWINDOW  = 0x0040;

const _LWA_ALPHA       = 0x00000002;
const _LWA_COLORKEY    = 0x00000001;

const _GWL_EXSTYLE     = -20;
const _GWL_STYLE       = -16;

const _WM_NCHITTEST    = 0x0084;
const _WM_PAINT        = 0x000F;
const _WM_LBUTTONDOWN  = 0x0201;
const _WM_LBUTTONUP    = 0x0202;
const _WM_MOUSEMOVE    = 0x0200;
const _WM_RBUTTONUP    = 0x0205;
const _WM_TIMER        = 0x0113;
const _WM_DESTROY      = 0x0002;
const _WM_CLOSE        = 0x0010;
const _WM_COMMAND      = 0x0111;

const _HTCAPTION       = 2;
const _HTCLIENT        = 1;

const _IDC_ARROW       = 32512;

const _COLOR_WINDOW    = 5;
const _CF_TEXT         = 1;

const _ANSI_VAR_FONT   = 12;
const _DEFAULT_QUALITY  = 0;
const _ANTIALIASED_QUALITY = 4;

const _SRCCOPY         = 0x00CC0020;

const _TRANSPARENT     = 1;
const _OPAQUE          = 2;

const _WM_USER         = 0x0400;
const _WM_UPDATE_TEXT  = _WM_USER + 1;
const _WM_UPDATE_COLOR = _WM_USER + 2;

// ═══════════════════════════════════════════════════════════════
//  Win32 API Bindings
// ═══════════════════════════════════════════════════════════════

typedef _CreateWindowExWNative = Pointer<Void> Function(
    Uint32, Pointer<Utf16>, Pointer<Utf16>, Uint32,
    Int32, Int32, Int32, Int32,
    Pointer<Void>, Pointer<Void>, Pointer<Void>, Pointer<Void>);
typedef _CreateWindowExWDart = Pointer<Void> Function(
    int, Pointer<Utf16>, Pointer<Utf16>, int,
    int, int, int, int,
    Pointer<Void>, Pointer<Void>, Pointer<Void>, Pointer<Void>);

typedef _DefWindowProcWNative = IntPtr Function(
    Pointer<Void>, Uint32, IntPtr, IntPtr);
typedef _DefWindowProcWDart = int Function(
    Pointer<Void>, int, int, int);

typedef _RegisterClassExWNative = Uint16 Function(Pointer<Void>);
typedef _RegisterClassExWDart = int Function(Pointer<Void>);

typedef _ShowWindowNative = Int32 Function(Pointer<Void>, Int32);
typedef _ShowWindowDart = int Function(Pointer<Void>, int);

typedef _SetWindowPosNative = Int32 Function(
    Pointer<Void>, Pointer<Void>, Int32, Int32, Int32, Int32, Uint32);
typedef _SetWindowPosDart = int Function(
    Pointer<Void>, Pointer<Void>, int, int, int, int, int);

typedef _SetLayeredWindowAttributesNative = Int32 Function(
    Pointer<Void>, Uint32, Uint8, Uint32);
typedef _SetLayeredWindowAttributesDart = int Function(
    Pointer<Void>, int, int, int);

typedef _GetWindowLongWNative = Int32 Function(Pointer<Void>, Int32);
typedef _GetWindowLongWDart = int Function(Pointer<Void>, int);

typedef _SetWindowLongWNative = Int32 Function(Pointer<Void>, Int32, Int32);
typedef _SetWindowLongWDart = int Function(Pointer<Void>, int, int);

typedef _LoadCursorWNative = Pointer<Void> Function(Pointer<Void>, IntPtr);
typedef _LoadCursorWDart = Pointer<Void> Function(Pointer<Void>, int);

typedef _PostQuitMessageNative = Void Function(Int32);
typedef _PostQuitMessageDart = void Function(int);

typedef _GetDCNative = Pointer<Void> Function(Pointer<Void>);
typedef _GetDCDart = Pointer<Void> Function(Pointer<Void>);

typedef _ReleaseDCNative = Int32 Function(Pointer<Void>, Pointer<Void>);
typedef _ReleaseDCDart = int Function(Pointer<Void>, Pointer<Void>);

typedef _CreateFontWNative = Pointer<Void> Function(
    Int32, Int32, Int32, Int32, Int32, Uint32, Uint32, Uint32,
    Uint32, Uint32, Uint32, Uint32, Uint32, Pointer<Utf16>);
typedef _CreateFontWDart = Pointer<Void> Function(
    int, int, int, int, int, int, int, int,
    int, int, int, int, int, Pointer<Utf16>);

typedef _SelectObjectNative = Pointer<Void> Function(
    Pointer<Void>, Pointer<Void>);
typedef _SelectObjectDart = Pointer<Void> Function(
    Pointer<Void>, Pointer<Void>);

typedef _SetTextColorNative = Int32 Function(Pointer<Void>, Uint32);
typedef _SetTextColorDart = int Function(Pointer<Void>, int);

typedef _SetBkModeNative = Int32 Function(Pointer<Void>, Int32);
typedef _SetBkModeDart = int Function(Pointer<Void>, int);

typedef _TextOutWNative = Int32 Function(
    Pointer<Void>, Int32, Int32, Pointer<Utf16>, Int32);
typedef _TextOutWDart = int Function(
    Pointer<Void>, int, int, Pointer<Utf16>, int);

typedef _GetTextExtentPoint32WNative = Int32 Function(
    Pointer<Void>, Pointer<Utf16>, Int32, Pointer<Void>);
typedef _GetTextExtentPoint32WDart = int Function(
    Pointer<Void>, Pointer<Utf16>, int, Pointer<Void>);

typedef _FillRectNative = Int32 Function(
    Pointer<Void>, Pointer<Void>, Pointer<Void>);
typedef _FillRectDart = int Function(
    Pointer<Void>, Pointer<Void>, Pointer<Void>);

typedef _CreateSolidBrushNative = Pointer<Void> Function(Uint32);
typedef _CreateSolidBrushDart = Pointer<Void> Function(int);

typedef _DeleteObjectNative = Int32 Function(Pointer<Void>);
typedef _DeleteObjectDart = int Function(Pointer<Void>);

typedef _DeleteDCNative = Int32 Function(Pointer<Void>);
typedef _DeleteDCDart = int Function(Pointer<Void>);

typedef _CreateCompatibleDCNative = Pointer<Void> Function(Pointer<Void>);
typedef _CreateCompatibleDCDart = Pointer<Void> Function(Pointer<Void>);

typedef _CreateCompatibleBitmapNative = Pointer<Void> Function(
    Pointer<Void>, Int32, Int32);
typedef _CreateCompatibleBitmapDart = Pointer<Void> Function(
    Pointer<Void>, int, int);

typedef _UpdateLayeredWindowNative = Int32 Function(
    Pointer<Void>, Pointer<Void>, Pointer<Void>, Pointer<Void>,
    Pointer<Void>, Pointer<Void>, Uint32, Pointer<Void>, Uint32);
typedef _UpdateLayeredWindowDart = int Function(
    Pointer<Void>, Pointer<Void>, Pointer<Void>, Pointer<Void>,
    Pointer<Void>, Pointer<Void>, int, Pointer<Void>, int);

typedef _GetSystemMetricsNative = Int32 Function(Int32);
typedef _GetSystemMetricsDart = int Function(int);

typedef _DestroyWindowNative = Int32 Function(Pointer<Void>);
typedef _DestroyWindowDart = int Function(Pointer<Void>);

typedef _PeekMessageWNative = Int32 Function(
    Pointer<Void>, Pointer<Void>, Uint32, Uint32, Uint32);
typedef _PeekMessageWDart = int Function(
    Pointer<Void>, Pointer<Void>, int, int, int);

typedef _TranslateMessageNative = Int32 Function(Pointer<Void>);
typedef _TranslateMessageDart = int Function(Pointer<Void>);

typedef _DispatchMessageWNative = IntPtr Function(Pointer<Void>);
typedef _DispatchMessageWDart = int Function(Pointer<Void>);

typedef _InvalidateRectNative = Int32 Function(
    Pointer<Void>, Pointer<Void>, Int32);
typedef _InvalidateRectDart = int Function(
    Pointer<Void>, Pointer<Void>, int);

typedef _SendMessageWNative = IntPtr Function(
    Pointer<Void>, Uint32, IntPtr, IntPtr);
typedef _SendMessageWDart = int Function(
    Pointer<Void>, int, int, int);

typedef _PostMessageWNative = Int32 Function(
    Pointer<Void>, Uint32, IntPtr, IntPtr);
typedef _PostMessageWDart = int Function(
    Pointer<Void>, int, int, int);

typedef _SetTimerNative = IntPtr Function(
    Pointer<Void>, IntPtr, Uint32, Pointer<Void>);
typedef _SetTimerDart = int Function(
    Pointer<Void>, int, int, Pointer<Void>);

typedef _KillTimerNative = Int32 Function(Pointer<Void>, IntPtr);
typedef _KillTimerDart = int Function(Pointer<Void>, int);

typedef _GetModuleHandleWNative = Pointer<Void> Function(Pointer<Utf16>);
typedef _GetModuleHandleWDart = Pointer<Void> Function(Pointer<Utf16>);

typedef _BeginPaintNative = Pointer<Void> Function(
    Pointer<Void>, Pointer<Void>);
typedef _BeginPaintDart = Pointer<Void> Function(
    Pointer<Void>, Pointer<Void>);

typedef _EndPaintNative = Int32 Function(Pointer<Void>, Pointer<Void>);
typedef _EndPaintDart = int Function(Pointer<Void>, Pointer<Void>);

typedef _BitBltNative = Int32 Function(
    Pointer<Void>, Int32, Int32, Int32, Int32,
    Pointer<Void>, Int32, Int32, Uint32);
typedef _BitBltDart = int Function(
    Pointer<Void>, int, int, int, int,
    Pointer<Void>, int, int, int);

typedef _RectangleNative = Int32 Function(
    Pointer<Void>, Int32, Int32, Int32, Int32);
typedef _RectangleDart = int Function(
    Pointer<Void>, int, int, int, int);

typedef _RoundRectNative = Int32 Function(
    Pointer<Void>, Int32, Int32, Int32, Int32, Int32, Int32);
typedef _RoundRectDart = int Function(
    Pointer<Void>, int, int, int, int, int, int);

typedef _SetWindowRgnNative = Int32 Function(
    Pointer<Void>, Pointer<Void>, Int32);
typedef _SetWindowRgnDart = int Function(
    Pointer<Void>, Pointer<Void>, int);

typedef _CreateRoundRectRgnNative = Pointer<Void> Function(
    Int32, Int32, Int32, Int32, Int32, Int32);
typedef _CreateRoundRectRgnDart = Pointer<Void> Function(
    int, int, int, int, int, int);

typedef _GetWindowRectNative = Int32 Function(
    Pointer<Void>, Pointer<Void>);
typedef _GetWindowRectDart = int Function(
    Pointer<Void>, Pointer<Void>);

// ═══════════════════════════════════════════════════════════════
//  Win32 Structures
// ═══════════════════════════════════════════════════════════════

final class _WNDCLASSEXW extends Struct {
  @Uint32() external int cbSize;
  @Uint32() external int style;
  external Pointer<Void> lpfnWndProc;
  @Int32() external int cbClsExtra;
  @Int32() external int cbWndExtra;
  external Pointer<Void> hInstance;
  external Pointer<Void> hIcon;
  external Pointer<Void> hCursor;
  external Pointer<Void> hbrBackground;
  external Pointer<Utf16> lpszMenuName;
  external Pointer<Utf16> lpszClassName;
  external Pointer<Void> hIconSm;
}

final class _POINT extends Struct {
  @Int32() external int x;
  @Int32() external int y;
}

final class _RECT extends Struct {
  @Int32() external int left;
  @Int32() external int top;
  @Int32() external int right;
  @Int32() external int bottom;
}

final class _SIZE extends Struct {
  @Int32() external int cx;
  @Int32() external int cy;
}

final class _MSG extends Struct {
  external Pointer<Void> hwnd;
  @Uint32() external int message;
  @IntPtr() external int wParam;
  @IntPtr() external int lParam;
  @Uint32() external int time;
  external _POINT pt;
}

final class _PAINTSTRUCT extends Struct {
  external Pointer<Void> hdc;
  @Int32() external int fErase;
  external _RECT rcPaint;
  @Int32() external int fRestore;
  @Int32() external int fIncUpdate;
  @Array(32) external Array<Uint8> rgbReserved;
}

final class _BLENDFUNCTION extends Struct {
  @Uint8() external int BlendOp;
  @Uint8() external int BlendFlags;
  @Uint8() external int SourceConstantAlpha;
  @Uint8() external int AlphaFormat;
}

// ═══════════════════════════════════════════════════════════════
//  Floating Lyrics Window Service
// ═══════════════════════════════════════════════════════════════

class FloatingLyricsService {
  static final _user32 = DynamicLibrary.open('user32.dll');
  static final _gdi32 = DynamicLibrary.open('gdi32.dll');
  static final _kernel32 = DynamicLibrary.open('kernel32.dll');

  // Win32 API functions
  static final _createWindowExW = _user32.lookupFunction<
      _CreateWindowExWNative, _CreateWindowExWDart>('CreateWindowExW');
  static final _defWindowProcW = _user32.lookupFunction<
      _DefWindowProcWNative, _DefWindowProcWDart>('DefWindowProcW');
  static final _registerClassExW = _user32.lookupFunction<
      _RegisterClassExWNative, _RegisterClassExWDart>('RegisterClassExW');
  static final _showWindow = _user32.lookupFunction<
      _ShowWindowNative, _ShowWindowDart>('ShowWindow');
  static final _setWindowPos = _user32.lookupFunction<
      _SetWindowPosNative, _SetWindowPosDart>('SetWindowPos');
  static final _setLayeredWindowAttributes = _user32.lookupFunction<
      _SetLayeredWindowAttributesNative,
      _SetLayeredWindowAttributesDart>('SetLayeredWindowAttributes');
  static final _getWindowLongW = _user32.lookupFunction<
      _GetWindowLongWNative, _GetWindowLongWDart>('GetWindowLongW');
  static final _setWindowLongW = _user32.lookupFunction<
      _SetWindowLongWNative, _SetWindowLongWDart>('SetWindowLongW');
  static final _loadCursorW = _user32.lookupFunction<
      _LoadCursorWNative, _LoadCursorWDart>('LoadCursorW');
  static final _postQuitMessage = _user32.lookupFunction<
      _PostQuitMessageNative, _PostQuitMessageDart>('PostQuitMessage');
  static final _getDC = _user32.lookupFunction<
      _GetDCNative, _GetDCDart>('GetDC');
  static final _releaseDC = _user32.lookupFunction<
      _ReleaseDCNative, _ReleaseDCDart>('ReleaseDC');
  static final _fillRect = _user32.lookupFunction<
      _FillRectNative, _FillRectDart>('FillRect');
  static final _destroyWindow = _user32.lookupFunction<
      _DestroyWindowNative, _DestroyWindowDart>('DestroyWindow');
  static final _peekMessageW = _user32.lookupFunction<
      _PeekMessageWNative, _PeekMessageWDart>('PeekMessageW');
  static final _translateMessage = _user32.lookupFunction<
      _TranslateMessageNative, _TranslateMessageDart>('TranslateMessage');
  static final _dispatchMessageW = _user32.lookupFunction<
      _DispatchMessageWNative, _DispatchMessageWDart>('DispatchMessageW');
  static final _invalidateRect = _user32.lookupFunction<
      _InvalidateRectNative, _InvalidateRectDart>('InvalidateRect');
  static final _sendMessageW = _user32.lookupFunction<
      _SendMessageWNative, _SendMessageWDart>('SendMessageW');
  static final _postMessageW = _user32.lookupFunction<
      _PostMessageWNative, _PostMessageWDart>('PostMessageW');
  static final _setTimer = _user32.lookupFunction<
      _SetTimerNative, _SetTimerDart>('SetTimer');
  static final _killTimer = _user32.lookupFunction<
      _KillTimerNative, _KillTimerDart>('KillTimer');
  static final _getModuleHandleW = _kernel32.lookupFunction<
      _GetModuleHandleWNative, _GetModuleHandleWDart>('GetModuleHandleW');
  static final _beginPaint = _user32.lookupFunction<
      _BeginPaintNative, _BeginPaintDart>('BeginPaint');
  static final _endPaint = _user32.lookupFunction<
      _EndPaintNative, _EndPaintDart>('EndPaint');
  static final _getSystemMetrics = _user32.lookupFunction<
      _GetSystemMetricsNative, _GetSystemMetricsDart>('GetSystemMetrics');
  static final _getWindowRect = _user32.lookupFunction<
      _GetWindowRectNative, _GetWindowRectDart>('GetWindowRect');
  static final _setWindowRgn = _user32.lookupFunction<
      _SetWindowRgnNative, _SetWindowRgnDart>('SetWindowRgn');

  static final _createFontW = _gdi32.lookupFunction<
      _CreateFontWNative, _CreateFontWDart>('CreateFontW');
  static final _selectObject = _gdi32.lookupFunction<
      _SelectObjectNative, _SelectObjectDart>('SelectObject');
  static final _setTextColor = _gdi32.lookupFunction<
      _SetTextColorNative, _SetTextColorDart>('SetTextColor');
  static final _setBkMode = _gdi32.lookupFunction<
      _SetBkModeNative, _SetBkModeDart>('SetBkMode');
  static final _textOutW = _gdi32.lookupFunction<
      _TextOutWNative, _TextOutWDart>('TextOutW');
  static final _getTextExtentPoint32W = _gdi32.lookupFunction<
      _GetTextExtentPoint32WNative,
      _GetTextExtentPoint32WDart>('GetTextExtentPoint32W');
  static final _createSolidBrush = _gdi32.lookupFunction<
      _CreateSolidBrushNative, _CreateSolidBrushDart>('CreateSolidBrush');
  static final _deleteObject = _gdi32.lookupFunction<
      _DeleteObjectNative, _DeleteObjectDart>('DeleteObject');
  static final _deleteDC = _gdi32.lookupFunction<
      _DeleteDCNative, _DeleteDCDart>('DeleteDC');
  static final _createCompatibleDC = _gdi32.lookupFunction<
      _CreateCompatibleDCNative, _CreateCompatibleDCDart>('CreateCompatibleDC');
  static final _createCompatibleBitmap = _gdi32.lookupFunction<
      _CreateCompatibleBitmapNative,
      _CreateCompatibleBitmapDart>('CreateCompatibleBitmap');
  static final _bitBlt = _gdi32.lookupFunction<
      _BitBltNative, _BitBltDart>('BitBlt');
  static final _roundRect = _gdi32.lookupFunction<
      _RoundRectNative, _RoundRectDart>('RoundRect');
  static final _createRoundRectRgn = _gdi32.lookupFunction<
      _CreateRoundRectRgnNative, _CreateRoundRectRgnDart>('CreateRoundRectRgn');

  // State
  static Pointer<Void>? _hwnd;
  static bool _visible = false;
  static String _currentText = '';
  static int _fontSize = 22;
  static int _fontColor = 0x00FFFFFF; // White (BGR)
  static int _bgColor = 0xCC1A1A1A;  // Dark semi-transparent (BGR)
  static int _bgAlpha = 200;          // 0-255
  static bool _initialized = false;
  static bool _running = false;

  // Callback for close event
  static Function()? onClosed;

  // ── Public API ──

  static bool get isVisible => _visible;

  static void setText(String text) {
    _currentText = text;
    if (_hwnd != null && _visible) {
      // Post message to trigger repaint
      _postMessageW(_hwnd!, _WM_UPDATE_TEXT, 0, 0);
    }
  }

  static void setFontColor(int colorBgr) {
    _fontColor = colorBgr;
    if (_hwnd != null && _visible) {
      _postMessageW(_hwnd!, _WM_UPDATE_TEXT, 0, 0);
    }
  }

  static void setFontSize(int size) {
    _fontSize = size;
    if (_hwnd != null && _visible) {
      _postMessageW(_hwnd!, _WM_UPDATE_TEXT, 0, 0);
    }
  }

  static void setBgAlpha(int alpha) {
    _bgAlpha = alpha.clamp(0, 255);
    if (_hwnd != null) {
      _setLayeredWindowAttributes(_hwnd!, 0, _bgAlpha, _LWA_ALPHA);
    }
  }

  static void show() {
    if (_visible) return;
    if (!_initialized) {
      _init();
    }
    if (_hwnd != null) {
      _showWindow(_hwnd!, 5); // SW_SHOW
      _setWindowPos(_hwnd!, nullptr, 0, 0, 0, 0,
          _SWP_NOMOVE | _SWP_NOSIZE | _SWP_NOACTIVATE | _SWP_SHOWWINDOW);
      _visible = true;
      DebugLog.log('Floating lyrics: shown');
    }
  }

  static void hide() {
    if (!_visible || _hwnd == null) return;
    _showWindow(_hwnd!, 0); // SW_HIDE
    _visible = false;
    DebugLog.log('Floating lyrics: hidden');
  }

  static void toggle() {
    if (_visible) {
      hide();
    } else {
      show();
    }
  }

  static void dispose() {
    _running = false;
    if (_hwnd != null) {
      _destroyWindow(_hwnd!);
      _hwnd = null;
    }
    _visible = false;
    _initialized = false;
    DebugLog.log('Floating lyrics: disposed');
  }

  // ── Internal ──

  static void _init() {
    try {
      _registerWindowClass();
      _createWindow();
      _initialized = true;
      _running = true;
      DebugLog.log('Floating lyrics: initialized');
    } catch (e) {
      DebugLog.log('Floating lyrics init error: $e');
    }
  }

  static void _registerWindowClass() {
    final className = 'VibeFloatingLyrics\0'.toNativeUtf16();
    final hInstance = _getModuleHandleW(nullptr);

    final wc = calloc<_WNDCLASSEXW>();
    wc.ref.cbSize = sizeOf<_WNDCLASSEXW>();
    wc.ref.style = 0x0003; // CS_HREDRAW | CS_VREDRAW
        wc.ref.lpfnWndProc = Pointer.fromFunction<_WndProcNative>(_wndProc, 0).cast();
    wc.ref.cbClsExtra = 0;
    wc.ref.cbWndExtra = 0;
    wc.ref.hInstance = hInstance;
    wc.ref.hIcon = nullptr;
    wc.ref.hCursor = _loadCursorW(nullptr, _IDC_ARROW);
    wc.ref.hbrBackground = nullptr;
    wc.ref.lpszMenuName = nullptr;
    wc.ref.lpszClassName = className;
    wc.ref.hIconSm = nullptr;

    _registerClassExW(wc.cast());

    calloc.free(className);
    calloc.free(wc);
  }

  static void _createWindow() {
    final className = 'VibeFloatingLyrics\0'.toNativeUtf16();
    final windowName = 'Vibe Lyrics\0'.toNativeUtf16();

    // Position at bottom-right of screen
    final screenW = _getSystemMetrics(0); // SM_CXSCREEN
    final screenH = _getSystemMetrics(1); // SM_CYSCREEN
    final winW = 500;
    final winH = 50;
    final winX = (screenW - winW) ~/ 2;
    final winY = screenH - 150;

    _hwnd = _createWindowExW(
      _WS_EX_LAYERED | _WS_EX_TOPMOST | _WS_EX_TOOLWINDOW | _WS_EX_NOACTIVATE,
      className,
      windowName,
      _WS_POPUP | _WS_VISIBLE,
      winX, winY, winW, winH,
      nullptr, nullptr, nullptr, nullptr,
    );

    if (_hwnd == nullptr) {
      calloc.free(className);
      calloc.free(windowName);
      DebugLog.log('Floating lyrics: CreateWindowEx failed');
      return;
    }

    // Set layered window attributes (alpha transparency)
    _setLayeredWindowAttributes(_hwnd!, 0, _bgAlpha, _LWA_ALPHA);

    // Set rounded corners via region
    final rgn = _createRoundRectRgn(0, 0, winW, winH, 12, 12);
    _setWindowRgn(_hwnd!, rgn, 1);
    _deleteObject(rgn);

    calloc.free(className);
    calloc.free(windowName);
  }

  // ── Window Procedure ──

  // _wndProcPtr is passed via wc.ref.lpfnWndProc in _registerWindowClass

  static int _wndProc(
      Pointer<Void> hwnd, int msg, int wParam, int lParam) {
    switch (msg) {
      case _WM_PAINT:
        _onPaint(hwnd);
        return 0;

      case _WM_UPDATE_TEXT:
        _invalidateRect(hwnd, nullptr.cast(), 0);
        return 0;

      case _WM_NCHITTEST:
        // Make entire window draggable
        final result = _defWindowProcW(hwnd, msg, wParam, lParam);
        if (result == _HTCLIENT) return _HTCAPTION;
        return result;

      case _WM_RBUTTONUP:
        // Right-click to close
        hide();
        onClosed?.call();
        return 0;

      case _WM_CLOSE:
        hide();
        onClosed?.call();
        return 0;

      case _WM_DESTROY:
        _postQuitMessage(0);
        return 0;

      default:
        return _defWindowProcW(hwnd, msg, wParam, lParam);
    }
  }

  // ── Paint ──

  static final _psSize = sizeOf<_PAINTSTRUCT>();
  static final _rectSize = sizeOf<_RECT>();
  static final _sizeSize = sizeOf<_SIZE>();

  static void _onPaint(Pointer<Void> hwnd) {
    final ps = calloc<_PAINTSTRUCT>();
    final hdc = _beginPaint(hwnd, ps.cast());

    // Get window dimensions
    final rect = calloc<_RECT>();
    _getWindowRect(hwnd, rect.cast());
    final w = rect.ref.right - rect.ref.left;
    final h = rect.ref.bottom - rect.ref.top;

    // Create double buffer
    final memDC = _createCompatibleDC(hdc);
    final memBmp = _createCompatibleBitmap(hdc, w, h);
    final oldBmp = _selectObject(memDC, memBmp);

    // Draw background with rounded rect
    final bgBrush = _createSolidBrush(_bgColor);
    final oldBrush = _selectObject(memDC, bgBrush);
    final bgPen = _createSolidBrush(_bgColor); // Use brush as "pen"
    // SetBkColor(memDC, _bgColor);
    _roundRect(memDC, 0, 0, w, h, 12, 12);
    _selectObject(memDC, oldBrush);
    _deleteObject(bgBrush);

    // Draw text
    if (_currentText.isNotEmpty) {
      final fontName = 'Microsoft YaHei\0'.toNativeUtf16();
      final font = _createFontW(
        _fontSize, 0, 0, 0, 700, // FW_BOLD
        0, 0, 0, 1, // DEFAULT_CHARSET
        0, _ANTIALIASED_QUALITY, 0, 0,
        fontName,
      );
      final oldFont = _selectObject(memDC, font);

      _setTextColor(memDC, _fontColor);
      _setBkMode(memDC, _TRANSPARENT);

      final textPtr = _currentText.toNativeUtf16();
      final textLen = _currentText.length;

      // Measure text for centering
      final textSize = calloc<_SIZE>();
      _getTextExtentPoint32W(memDC, textPtr, textLen, textSize.cast());
      final textW = textSize.ref.cx;
      final textH = textSize.ref.cy;
      final x = ((w - textW) / 2).round().clamp(0, w);
      final y = ((h - textH) / 2).round().clamp(0, h);

      _textOutW(memDC, x, y, textPtr, textLen);

      _selectObject(memDC, oldFont);
      _deleteObject(font);
      calloc.free(fontName);
      calloc.free(textPtr);
      calloc.free(textSize);
    }

    // Blit to screen
    _bitBlt(hdc, 0, 0, w, h, memDC, 0, 0, _SRCCOPY);

    // Cleanup
    _selectObject(memDC, oldBmp);
    _deleteObject(memBmp);
    _deleteDC(memDC);

    _endPaint(hwnd, ps.cast());
    calloc.free(rect);
    calloc.free(ps);
  }
}

// Native callback type for WndProc
typedef _WndProcNative = IntPtr Function(
    Pointer<Void> hwnd, Uint32 msg, IntPtr wParam, IntPtr lParam);