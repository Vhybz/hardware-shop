import 'package:flutter/material.dart';

class WarehouseLoading extends StatefulWidget {
  final double size;
  const WarehouseLoading({super.key, this.size = 120});

  @override
  State<WarehouseLoading> createState() => _WarehouseLoadingState();
}

class _WarehouseLoadingState extends State<WarehouseLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.inventory_2_rounded,
          size: widget.size * 0.5,
          color: Colors.white,
        ),
      ),
    );
  }
}

// Legacy Alias
typedef ButcherLoading = WarehouseLoading;
