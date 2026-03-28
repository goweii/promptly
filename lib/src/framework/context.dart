part of 'framework.dart';

final _defaultConsole = dc.Console();

dc.Console get defaultConsole => _defaultConsole;

/// [Context] is used by [StateComponent] and [State] to actually render
/// things to the console, and to act as a state store during rendering,
/// which will store things such as the number or renderings done and the
/// amount of lines used by a specific render, so that the [State] can
/// clear old lines and render new stuffs automatically.
class Context {
  /// Resets the Console.
  static void reset() {
    _defaultConsole.showCursor();
    _defaultConsole.resetColorAttributes();
  }

  final _console = _defaultConsole;

  int _renderCount = 0;

  /// Indicates how many times the [Context] has rendered.
  int get renderCount => _renderCount;

  /// Increases the [renderCount] by one.
  void increaseRenderCount() => _renderCount++;

  /// Sets the [renderCount] to `0`.
  void resetRenderCount() => _renderCount = 0;

  int _linesCount = 0;

  /// Indicates how many lines the context is used for rendering.
  int get linesCount => _linesCount;

  /// Increases the [linesCount] by one.
  void increaseLinesCount() => _linesCount++;

  /// Sets the [linesCount] to `0`.
  void resetLinesCount() => _linesCount = 0;

  /// Removes the lines from the last render and reset the lines count.
  void wipe() {
    erasePreviousLine(linesCount);
    resetLinesCount();
  }

  /// Returns terminal width in terms of characters.
  int get windowWidth => _console.windowWidth;

  /// Shows the cursor.
  void showCursor() => _console.showCursor();

  /// Hide the cursor.
  void hideCursor() => _console.hideCursor();

  /// Writes a string to the console.
  void write(String text) => _console.write(text);

  /// Writes a string to the console with a new line at the end.
  void writeError(String text) => _console.writeErrorLine(text);

  /// Increases the number of lines written for the current render,
  /// and writes a line to the the console.
  void writeln([String? text]) {
    // for (final line in text?.split('\n') ?? []) {

    // }
    increaseLinesCount();
    _console.writeLine(text);
  }

  void writeLine([String? text]) => writeLine(text);

  /// Erase one line above the current cursor by default.
  ///
  /// If the argument [n] is supplied, it will repeat the process
  /// to [n] times.
  void erasePreviousLine([int n = 1]) {
    for (var i = 0; i < n; i++) {
      _console.cursorUp();
      _console.eraseLine();
    }
  }

  void cleanScreen() {
    _console.clearScreen();
    _console.resetCursorPosition();
  }

  /// Reads a key press, same as dart_console library's
  /// `readKey()` function but this function handles the `Ctrl+C` key
  /// press to immediately exit from the process.
  dc.Key readKey() => _handleKey(_console.readKey());

  /// Reads a line, same as dart_console library's `readLine()` function,
  /// and it's partially taken from the source code of it and modified
  /// for custom use cases, such as accepting initial text as an argument,
  /// and allowing to disable rendering the key press, to use in the [Password]
  /// component.
  String readLine({
    String initialText = '',
    bool noRender = false,
  }) {
    var buffer = initialText;
    var index = buffer.length;

    final screenRow = _console.cursorPosition?.row ?? 0;
    final screenColOffset = _console.cursorPosition?.col ?? 0;
    final bufferMaxLength = _console.windowWidth - screenColOffset - 3;

    if (buffer.isNotEmpty && !noRender) {
      write(buffer);
    }

    final utf8Buffer = <int>[];

    while (true) {
      final key = readKey();

      if (key.isControl) {
        utf8Buffer.clear();
        switch (key.controlChar) {
          case dc.ControlCharacter.enter:
            writeln();
            return buffer;
          case dc.ControlCharacter.backspace:
          case dc.ControlCharacter.ctrlH:
            if (index > 0) {
              buffer = buffer.substring(0, index - 1) + buffer.substring(index);
              index--;
            }
          case dc.ControlCharacter.delete:
          case dc.ControlCharacter.ctrlD:
            if (index < buffer.length - 1) {
              buffer = buffer.substring(0, index) + buffer.substring(index + 1);
            }
          case dc.ControlCharacter.ctrlU:
            buffer = '';
            index = 0;
          case dc.ControlCharacter.ctrlK:
            buffer = buffer.substring(0, index);
          case dc.ControlCharacter.arrowLeft:
          case dc.ControlCharacter.ctrlB:
            index = index > 0 ? index - 1 : index;
          case dc.ControlCharacter.arrowRight:
          case dc.ControlCharacter.ctrlF:
            index = index < buffer.length ? index + 1 : index;
          case dc.ControlCharacter.wordLeft:
            if (index > 0) {
              final bufferLeftOfCursor = buffer.substring(0, index - 1);
              final lastSpace = bufferLeftOfCursor.lastIndexOf(' ');
              index = lastSpace != -1 ? lastSpace + 1 : 0;
            }
          case dc.ControlCharacter.home:
          case dc.ControlCharacter.ctrlA:
            index = 0;
          case dc.ControlCharacter.end:
          case dc.ControlCharacter.ctrlE:
            index = buffer.length;
          default:
            break;
        }
      } else {
        if (buffer.length < bufferMaxLength) {
          final prefix = buffer.substring(0, index);
          final suffix = buffer.substring(index);
          utf8Buffer.addAll(key.char.codeUnits);
          try {
            final text = utf8.decode(utf8Buffer);
            buffer = prefix + text + suffix;
            utf8Buffer.clear();
            index += text.length;
          } catch (_) {
            continue;
          }
        }
      }

      if (!noRender) {
        _console.hideCursor(); // Prevents the cursor jumping being seen
        _console.cursorPosition = dc.Coordinate(screenRow, screenColOffset);
        _console.eraseCursorToEnd();
        write(buffer);
        _console.cursorPosition = dc.Coordinate(
          screenRow,
          screenColOffset + _getDisplayWidth(buffer.substring(0, index)),
        );
        _console.showCursor();
      }
    }
  }

  dc.Key _handleKey(dc.Key key) {
    if (key.isControl && key.controlChar == dc.ControlCharacter.ctrlC) {
      reset();
      exit(1);
    }
    return key;
  }
}

/// Unlike a normal [Context], [BufferContext] writes lines to a specified
/// [StringBuffer] and run a reload function on every line written.
///
/// Useful when waiting for a rendering context when there is multiple
/// of them rendering at the same time. [MultipleSpinner] component used it
/// so when [Spinner]s are being rendered, they get rendered to a [String].
/// It later used the [setState] function to rendered the whole [String]
/// containing multiple [BufferContext]s to the console.
class BufferContext extends Context {
  /// Constructs a [BufferContext] with given properties.
  BufferContext({
    required this.buffer,
    required this.setState,
  });

  /// Buffer stores the lines written to the context.
  final StringBuffer buffer;

  /// Runs everytime something was written to the buffer.
  final void Function() setState;

  @override
  void writeln([String? text]) {
    buffer.clear();
    buffer.write(text);
    setState();
  }
}

/// Resets the Terminal to default values.
void Function() reset = Context.reset;

String setColor(int value) => ansi.ansiSetColor(value);
String setExtendedColor(int color) => ansi.ansiSetExtendedForegroundColor(color);
String setExtendedBackgroundColor(int color) => ansi.ansiSetExtendedBackgroundColor(color);
String resetColor() => ansi.ansiResetColor;
String setTextStyles({
  bool bold = false,
  bool faint = false,
  bool italic = false,
  bool underscore = false,
  bool blink = false,
  bool inverted = false,
  bool invisible = false,
  bool strikethru = false,
}) =>
    ansi.ansiSetTextStyles(
      bold: bold,
      faint: faint,
      italic: italic,
      underscore: underscore,
      blink: blink,
      inverted: inverted,
      invisible: invisible,
      strikethru: strikethru,
    );

/// Checks if a **single character** is a **full-width character** (occupies 2 columns).
/// Authoritative standard: Unicode East Asian Width (EAW)
bool _isFullWidthCharacter(String char) {
  if (char.isEmpty) return false;
  // Only handle single visual characters (avoid combining characters/corrupted text)
  if (char.characters.length != 1) return false;

  final code = char.runes.first;

  // 1. CJK Unified Ideographs (all Chinese characters)
  if (code >= 0x4E00 && code <= 0x9FFF) return true;
  // 2. Japanese Hiragana and Katakana
  if (code >= 0x3040 && code <= 0x30FF) return true;
  // 3. Korean Hangul Syllables
  if (code >= 0xAC00 && code <= 0xD7AF) return true;
  // 4. Full-width punctuation marks
  if (code >= 0x3000 && code <= 0x303F) return true;
  // 5. Full-width letters/digits/symbols (Ａ Ｂ Ｃ １２３！＠＃)
  if (code >= 0xFF00 && code <= 0xFFEF) return true;
  // 6. Emoji & special symbols (occupy 2 columns in terminal)
  if (code >= 0x1F600 && code <= 0x1F64F) return true; // Emoticons
  if (code >= 0x1F300 && code <= 0x1F5FF) return true; // Icons
  // 7. Full-width space (especially important)
  if (code == 0x3000) return true;

  return false;
}

/// Calculates the actual display width of a string in the **terminal**.
/// (Solves cursor offset issues)
int _getDisplayWidth(String text) {
  int width = 0;
  for (final char in text.characters) {
    width += _isFullWidthCharacter(char) ? 2 : 1;
  }
  return width;
}
