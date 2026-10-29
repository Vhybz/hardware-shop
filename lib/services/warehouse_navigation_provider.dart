import 'package:flutter_riverpod/flutter_riverpod.dart';

final warehouseNavigationIndexProvider = StateProvider<int>((ref) => 0);

// Legacy alias
final butcherNavigationIndexProvider = warehouseNavigationIndexProvider;
