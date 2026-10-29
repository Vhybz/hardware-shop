import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';

class CalculatorDialog extends StatefulWidget {
  final Function(double)? onResultUsed;
  const CalculatorDialog({super.key, this.onResultUsed});

  @override
  State<CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<CalculatorDialog> {
  String _display = "0";
  String _topText = "";
  double? _firstOperand;
  String? _operator;
  bool _shouldResetDisplay = false;

  final List<String> _history = [];
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
        _onPressed("0");
      } else if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
        _onPressed("1");
      } else if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
        _onPressed("2");
      } else if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
        _onPressed("3");
      } else if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
        _onPressed("4");
      } else if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
        _onPressed("5");
      } else if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) {
        _onPressed("6");
      } else if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) {
        _onPressed("7");
      } else if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) {
        _onPressed("8");
      } else if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) {
        _onPressed("9");
      } else if (key == LogicalKeyboardKey.add || (key == LogicalKeyboardKey.equal && HardwareKeyboard.instance.isShiftPressed)) {
        _onPressed("+");
      } else if (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract) {
        _onPressed("-");
      } else if (key == LogicalKeyboardKey.asterisk || key == LogicalKeyboardKey.numpadMultiply) {
        _onPressed("×");
      } else if (key == LogicalKeyboardKey.slash || key == LogicalKeyboardKey.numpadDivide) {
        _onPressed("÷");
      } else if (key == LogicalKeyboardKey.period || key == LogicalKeyboardKey.numpadDecimal) {
        _onPressed(".");
      } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        _onPressed("=");
      } else if (key == LogicalKeyboardKey.backspace) {
        _onPressed("⌫");
      } else if (key == LogicalKeyboardKey.escape) {
        _onPressed("AC");
      }
    }
  }

  void _onPressed(String cmd) {
    HapticFeedback.selectionClick();
    setState(() {
      if (cmd == "AC") {
        _display = "0";
        _topText = "";
        _firstOperand = null;
        _operator = null;
        _shouldResetDisplay = false;
      } else if (cmd == "⌫") {
        if (_display.length > 1) {
          _display = _display.substring(0, _display.length - 1);
        } else {
          _display = "0";
        }
      } else if (cmd == "=") {
        if (_firstOperand != null && _operator != null) {
          double secondOperand = double.tryParse(_display) ?? 0;
          double result = _calculate(_firstOperand!, secondOperand, _operator!);

          _topText = "${_format(_firstOperand!)} $_operator ${_format(secondOperand)} =";
          _display = _format(result);

          _history.insert(0, "$_topText $_display");
          if (_history.length > 8) {
            _history.removeLast();
          }

          _firstOperand = null;
          _operator = null;
          _shouldResetDisplay = true;
        }
      } else if (cmd == "%") {
        double val = (double.tryParse(_display) ?? 0) / 100;
        _display = _format(val);
      } else if ("+-×÷".contains(cmd)) {
        double currentVal = double.tryParse(_display) ?? 0;

        if (_firstOperand != null && _operator != null && !_shouldResetDisplay) {
          _firstOperand = _calculate(_firstOperand!, currentVal, _operator!);
          _display = _format(_firstOperand!);
        } else {
          _firstOperand = currentVal;
        }

        _operator = cmd;
        _topText = "${_format(_firstOperand!)} $cmd";
        _shouldResetDisplay = true;
      } else if (cmd == "00") {
        if (_shouldResetDisplay) {
          _display = "0";
          _shouldResetDisplay = false;
        } else if (_display != "0") {
          _display += "00";
        }
      } else {
        // Digits and decimal
        if (_shouldResetDisplay) {
          _display = cmd == "." ? "0." : cmd;
          _shouldResetDisplay = false;
        } else {
          if (cmd == "." && _display.contains(".")) return;
          if (_display == "0" && cmd != ".") {
            _display = cmd;
          } else {
            _display += cmd;
          }
        }
      }
    });
  }

  double _calculate(double n1, double n2, String op) {
    switch (op) {
      case "+":
        return n1 + n2;
      case "-":
        return n1 - n2;
      case "×":
        return n1 * n2;
      case "÷":
        return n2 == 0 ? 0 : n1 / n2;
      default:
        return n2;
    }
  }

  String _format(double v) {
    if (v.isInfinite || v.isNaN) return "Error";
    if (v == v.toInt()) return v.toInt().toString();
    String s = v.toStringAsFixed(4);
    while (s.endsWith("0")) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith(".")) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.m),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                )
              ],
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.m),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(theme),
                  _buildDisplay(theme, isDark),
                  if (_history.isNotEmpty) _buildHistory(theme),
                  _buildKeypad(theme),
                  if (widget.onResultUsed != null) _buildInjectButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Icon(Icons.calculate_outlined, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              'CALCULATOR',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: theme.colorScheme.primary,
                letterSpacing: 1.0,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: 'Copy Result',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _display));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied result to clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.history_toggle_off_rounded, size: 18),
              tooltip: 'Clear History',
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(6),
              onPressed: () {
                setState(() => _history.clear());
              },
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Close',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplay(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.m, AppSpacing.m, AppSpacing.s),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: isDark ? Colors.black45 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(AppRadius.s),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _topText.isEmpty ? " " : _topText,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              _display,
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                fontFamily: 'monospace',
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(ThemeData theme) {
    return Container(
      height: 32,
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
        itemCount: _history.length,
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => setState(() {
            final parts = _history[i].split(" = ");
            _display = parts.last;
            _topText = "${parts.first} =";
            _shouldResetDisplay = true;
          }),
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.s),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
            ),
            child: Center(
              child: Text(
                _history[i],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(ThemeData theme) {
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, 0, AppSpacing.m, AppSpacing.m),
      child: Column(
        children: [
          _row(["AC", "⌫", "%", "÷"], [Colors.red.shade700, Colors.amber.shade800, primaryColor, primaryColor]),
          _row(["7", "8", "9", "×"], [null, null, null, primaryColor]),
          _row(["4", "5", "6", "-"], [null, null, null, primaryColor]),
          _row(["1", "2", "3", "+"], [null, null, null, primaryColor]),
          _row(["00", "0", ".", "="], [null, null, null, AppColors.accentGreen]),
        ],
      ),
    );
  }

  Widget _row(List<String> keys, List<Color?> colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: keys.asMap().entries.map((e) {
          final i = e.key;
          final key = e.value;
          final color = colors[i];
          final isEquals = key == "=";
          final isActionKey = "AC⌫%÷×-+=".contains(key);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Material(
                color: isEquals
                    ? AppColors.accentGreen
                    : (isActionKey
                        ? (color?.withValues(alpha: 0.1) ?? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08))
                        : Theme.of(context).cardColor),
                borderRadius: BorderRadius.circular(AppRadius.s),
                child: InkWell(
                  onTap: () => _onPressed(key),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.s),
                      border: Border.all(
                        color: isEquals
                            ? AppColors.accentGreen
                            : Theme.of(context).dividerColor.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Center(
                      child: key == "⌫"
                          ? Icon(Icons.backspace_outlined, size: 18, color: colors[i] ?? Colors.amber.shade800)
                          : Text(
                              key,
                              style: TextStyle(
                                fontSize: isActionKey ? 18 : 17,
                                fontWeight: FontWeight.bold,
                                color: isEquals
                                    ? Colors.white
                                    : (color ?? Theme.of(context).colorScheme.onSurface),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInjectButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, 0, AppSpacing.m, AppSpacing.m),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            widget.onResultUsed!(double.tryParse(_display) ?? 0);
            Navigator.pop(context);
          },
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text(
            'USE RESULT',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}
