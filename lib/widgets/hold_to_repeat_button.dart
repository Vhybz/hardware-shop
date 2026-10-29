import 'dart:async';
import 'package:flutter/material.dart';

/// A button widget that triggers [onPressed] immediately on touch down
/// and continuously auto-repeats as long as it remains held down.
/// Also provides instant tactile scale feedback when pressed.
class HoldToRepeatButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const HoldToRepeatButton({
    super.key,
    required this.child,
    this.onPressed,
    this.borderRadius,
    this.padding = const EdgeInsets.all(8),
    this.color,
  });

  @override
  State<HoldToRepeatButton> createState() => _HoldToRepeatButtonState();
}

class _HoldToRepeatButtonState extends State<HoldToRepeatButton> {
  Timer? _timer;
  Timer? _initialDelayTimer;
  bool _isPressed = false;

  void _startRepeating() {
    if (widget.onPressed == null) return;

    // Trigger immediately on touch-down
    widget.onPressed!();

    _initialDelayTimer?.cancel();
    _timer?.cancel();

    // After 250ms delay, start rapid auto-repeat (every 70ms)
    _initialDelayTimer = Timer(const Duration(milliseconds: 250), () {
      int count = 0;
      _timer = Timer.periodic(const Duration(milliseconds: 70), (timer) {
        if (!mounted || widget.onPressed == null) {
          _stopRepeating();
          return;
        }
        widget.onPressed!();
        count++;

        // Accelerate even faster after 10 repeats (~1 second of holding)
        if (count == 10) {
          _timer?.cancel();
          _timer = Timer.periodic(const Duration(milliseconds: 40), (t) {
            if (!mounted || widget.onPressed == null) {
              _stopRepeating();
              return;
            }
            widget.onPressed!();
          });
        }
      });
    });
  }

  void _stopRepeating() {
    _initialDelayTimer?.cancel();
    _timer?.cancel();
    _initialDelayTimer = null;
    _timer = null;
    if (_isPressed && mounted) {
      setState(() {
        _isPressed = false;
      });
    }
  }

  @override
  void dispose() {
    _stopRepeating();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onPressed != null;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: isEnabled
            ? (_) {
                setState(() => _isPressed = true);
                _startRepeating();
              }
            : null,
        onTapUp: isEnabled ? (_) => _stopRepeating() : null,
        onTapCancel: isEnabled ? () => _stopRepeating() : null,
        child: AnimatedScale(
          scale: _isPressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 50),
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: widget.borderRadius,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
