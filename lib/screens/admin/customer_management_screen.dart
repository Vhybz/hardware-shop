import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/role_pop_scope.dart';
import '../../services/customer_provider.dart';
import '../../models/customer_model.dart';
import '../../services/menu_service.dart';
import '../../services/user_provider.dart';
import '../../core/uuid_utils.dart';
import '../../models/customer_metrics.dart';
import '../../services/customer_metrics_provider.dart';
import '../../widgets/add_restock_request_dialog.dart';

enum CustomerFilterType {
  all,
  pending,
  special,
  favorites,
  wholesalers,
  bulkPurchasers,
  hasPoints,
  frequent,
}

enum CustomerSortOption {
  nameAsc,
  nameDesc,
  pointsDesc,
  visitsDesc,
  discountDesc,
}

class CustomerManagementScreen extends ConsumerStatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  ConsumerState<CustomerManagementScreen> createState() => _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends ConsumerState<CustomerManagementScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  CustomerFilterType _selectedFilter = CustomerFilterType.all;
  CustomerSortOption _selectedSort = CustomerSortOption.nameAsc;
  String? _selectedLocation;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());

    final theme = Theme.of(context);
    final customers = ref.watch(customerProvider);
    final metrics = ref.watch(customerMetricsProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    const currentRoute = '/admin/customers';

    // Extract unique locations for filtering
    final availableLocations = customers
        .map((c) => c.location?.trim())
        .where((loc) => loc != null && loc.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();

    // Counts for filter chips
    final totalCount = customers.length;
    final specialCount = customers.where((c) => c.isSpecial).length;
    final pendingCount = customers.where((c) => c.isPendingApproval).length;
    final favCount = customers.where((c) => c.isFavorite).length;
    final wholesalerCount = customers.where((c) => c.isWholesaler).length;
    final bulkCount = customers.where((c) => c.isBulkPurchaser).length;
    final pointsCount = customers.where((c) => c.loyaltyPoints > 0).length;
    final frequentCount = customers.where((c) => c.visitCount >= 3).length;

    // Filter customers
    final filteredCustomers = customers.where((c) {
      // 1. Search Query
      final query = _searchQuery.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matchesName = c.name.toLowerCase().contains(query);
        final matchesPhone = c.phone.contains(query) || (c.phone2?.contains(query) ?? false);
        final matchesLocation = c.location?.toLowerCase().contains(query) ?? false;
        final matchesBusiness = c.businessName?.toLowerCase().contains(query) ?? false;
        if (!matchesName && !matchesPhone && !matchesLocation && !matchesBusiness) {
          return false;
        }
      }

      // 2. Type Filter Chip
      switch (_selectedFilter) {
        case CustomerFilterType.all:
          break;
        case CustomerFilterType.pending:
          if (!c.isPendingApproval) return false;
          break;
        case CustomerFilterType.special:
          if (!c.isSpecial) return false;
          break;
        case CustomerFilterType.favorites:
          if (!c.isFavorite) return false;
          break;
        case CustomerFilterType.wholesalers:
          if (!c.isWholesaler) return false;
          break;
        case CustomerFilterType.bulkPurchasers:
          if (!c.isBulkPurchaser) return false;
          break;
        case CustomerFilterType.hasPoints:
          if (c.loyaltyPoints <= 0) return false;
          break;
        case CustomerFilterType.frequent:
          if (c.visitCount < 3) return false;
          break;
      }

      // 3. Location Dropdown Filter
      if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
        if ((c.location?.trim() ?? '') != _selectedLocation) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sorting
    switch (_selectedSort) {
      case CustomerSortOption.nameAsc:
        filteredCustomers.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case CustomerSortOption.nameDesc:
        filteredCustomers.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case CustomerSortOption.pointsDesc:
        filteredCustomers.sort((a, b) => b.loyaltyPoints.compareTo(a.loyaltyPoints));
        break;
      case CustomerSortOption.visitsDesc:
        filteredCustomers.sort((a, b) => b.visitCount.compareTo(a.visitCount));
        break;
      case CustomerSortOption.discountDesc:
        filteredCustomers.sort((a, b) => (b.specialDiscountPercentage ?? 0).compareTo(a.specialDiscountPercentage ?? 0));
        break;
    }

    return RolePopScope(
      currentRoute: currentRoute,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: const MainAppBar(title: 'Customer Directory'),
        drawer: isDesktop ? null : Drawer(
          child: AppSidebar(
            userId: user.id,
            userName: user.name,
            userRole: user.activePrimaryRole.name.toUpperCase(),
            currentRoute: currentRoute,
            items: MenuService.getMenuItemsForUser(user),
            onTap: (route) => MenuService.navigate(context, ref, route, currentRoute),
          ),
        ),
        body: Row(
          children: [
            if (isDesktop)
              AppSidebar(
                userId: user.id,
                userName: user.name,
                userRole: user.activePrimaryRole.name.toUpperCase(),
                currentRoute: currentRoute,
                items: MenuService.getMenuItemsForUser(user),
                onTap: (route) => MenuService.navigate(context, ref, route, currentRoute),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, ref),
                    const SizedBox(height: AppSpacing.m),
                    _buildFilterAndSearchSection(
                      context,
                      theme,
                      availableLocations,
                      totalCount,
                      pendingCount,
                      specialCount,
                      favCount,
                      wholesalerCount,
                      bulkCount,
                      pointsCount,
                      frequentCount,
                      filteredCustomers.length,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _buildMetricsSummary(context, metrics),
                    const SizedBox(height: AppSpacing.xl),
                    _buildCustomerGrid(context, ref, filteredCustomers),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterAndSearchSection(
    BuildContext context,
    ThemeData theme,
    List<String> locations,
    int totalCount,
    int pendingCount,
    int specialCount,
    int favCount,
    int wholesalerCount,
    int bulkCount,
    int pointsCount,
    int frequentCount,
    int resultCount,
  ) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final bool hasActiveFilter = _selectedFilter != CustomerFilterType.all ||
        _searchQuery.isNotEmpty ||
        _selectedLocation != null ||
        _selectedSort != CustomerSortOption.nameAsc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Search Bar & Controls Row
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Search Input
            SizedBox(
              width: isMobile ? double.infinity : 380,
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search by Name, Phone or Location...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.cardTheme.color,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                  ),
                ),
              ),
            ),

            // Sort Dropdown
            SizedBox(
              width: isMobile ? (locations.isNotEmpty ? 175 : double.infinity) : 200,
              child: DropdownButtonFormField<CustomerSortOption>(
                initialValue: _selectedSort,
                isExpanded: true,
                isDense: true,
                decoration: InputDecoration(
                  labelText: 'Sort By',
                  prefixIcon: const Icon(Icons.sort_rounded, size: 18),
                  prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                  filled: true,
                  fillColor: theme.cardTheme.color,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                  ),
                ),
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                items: const [
                  DropdownMenuItem(value: CustomerSortOption.nameAsc, child: Text('Name (A-Z)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: CustomerSortOption.nameDesc, child: Text('Name (Z-A)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: CustomerSortOption.pointsDesc, child: Text('Most Points', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: CustomerSortOption.visitsDesc, child: Text('Most Visits', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: CustomerSortOption.discountDesc, child: Text('Highest VIP %', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSort = val);
                },
              ),
            ),

            // Location Filter Dropdown
            if (locations.isNotEmpty)
              SizedBox(
                width: isMobile ? 175 : 200,
                child: DropdownButtonFormField<String?>(
                  initialValue: _selectedLocation,
                  isExpanded: true,
                  isDense: true,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                    prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                    filled: true,
                    fillColor: theme.cardTheme.color,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                      borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                    ),
                  ),
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null, 
                      child: Text('All Locations', overflow: TextOverflow.ellipsis),
                    ),
                    ...locations.map(
                      (loc) => DropdownMenuItem<String?>(
                        value: loc,
                        child: Text(loc, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedLocation = val),
                ),
              ),
          ],
        ),

        const SizedBox(height: 12),

        // 2. Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'All Customers',
                count: totalCount,
                icon: Icons.people_alt_rounded,
                selected: _selectedFilter == CustomerFilterType.all,
                color: theme.colorScheme.primary,
                onSelected: () => setState(() => _selectedFilter = CustomerFilterType.all),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Pending Approvals',
                count: pendingCount,
                icon: Icons.how_to_reg_rounded,
                selected: _selectedFilter == CustomerFilterType.pending,
                color: Colors.orange,
                onSelected: () => setState(() => _selectedFilter = _selectedFilter == CustomerFilterType.pending ? CustomerFilterType.all : CustomerFilterType.pending),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Special VIP',
                count: specialCount,
                icon: Icons.star_rounded,
                selected: _selectedFilter == CustomerFilterType.special,
                color: Colors.amber,
                onSelected: () => setState(() => _selectedFilter = _selectedFilter == CustomerFilterType.special ? CustomerFilterType.all : CustomerFilterType.special),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Favorites',
                count: favCount,
                icon: Icons.favorite_rounded,
                selected: _selectedFilter == CustomerFilterType.favorites,
                color: Colors.deepOrangeAccent,
                onSelected: () => setState(() => _selectedFilter = _selectedFilter == CustomerFilterType.favorites ? CustomerFilterType.all : CustomerFilterType.favorites),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Wholesalers',
                count: wholesalerCount,
                icon: Icons.store_rounded,
                selected: _selectedFilter == CustomerFilterType.wholesalers,
                color: Colors.purpleAccent,
                onSelected: () => setState(() => _selectedFilter = _selectedFilter == CustomerFilterType.wholesalers ? CustomerFilterType.all : CustomerFilterType.wholesalers),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Bulk Buyers',
                count: bulkCount,
                icon: Icons.inventory_2_outlined,
                selected: _selectedFilter == CustomerFilterType.bulkPurchasers,
                color: Colors.teal,
                onSelected: () => setState(() => _selectedFilter = _selectedFilter == CustomerFilterType.bulkPurchasers ? CustomerFilterType.all : CustomerFilterType.bulkPurchasers),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Loyalty Points',
                count: pointsCount,
                icon: Icons.loyalty_rounded,
                selected: _selectedFilter == CustomerFilterType.hasPoints,
                color: Colors.blueAccent,
                onSelected: () => setState(() => _selectedFilter = _selectedFilter == CustomerFilterType.hasPoints ? CustomerFilterType.all : CustomerFilterType.hasPoints),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'Frequent (3+)',
                count: frequentCount,
                icon: Icons.repeat_rounded,
                selected: _selectedFilter == CustomerFilterType.frequent,
                color: Colors.green,
                onSelected: () => setState(() => _selectedFilter = _selectedFilter == CustomerFilterType.frequent ? CustomerFilterType.all : CustomerFilterType.frequent),
              ),
            ],
          ),
        ),

        // 3. Active filter summary & Clear button
        if (hasActiveFilter) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Showing $resultCount of $totalCount customers',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedFilter = CustomerFilterType.all;
                    _selectedSort = CustomerSortOption.nameAsc;
                    _selectedLocation = null;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, size: 14, color: theme.colorScheme.error),
                      const SizedBox(width: 2),
                      Text(
                        'Reset Filters',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.error, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      avatar: Icon(icon, size: 14, color: selected ? Colors.white : color),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: selected ? Colors.white.withValues(alpha: 0.25) : color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : color,
              ),
            ),
          ),
        ],
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: color,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? Colors.white : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildMetricsSummary(BuildContext context, Map<String, CustomerMetric> metrics) {
    final theme = Theme.of(context);
    final vips = metrics.values.where((m) => m.performanceLabel == 'VIP').length;
    final regulars = metrics.values.where((m) => m.performanceLabel == 'Regular').length;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(width: 140, child: _buildSummaryCard('Total Customers', metrics.length.toString(), Icons.people, Colors.blue, theme, isFixed: true)),
                const SizedBox(width: 10),
                SizedBox(width: 140, child: _buildSummaryCard('VIPs & Favorites', vips.toString(), Icons.stars, Colors.purple, theme, isFixed: true)),
                const SizedBox(width: 10),
                SizedBox(width: 140, child: _buildSummaryCard('Regulars', regulars.toString(), Icons.repeat, Colors.green, theme, isFixed: true)),
              ],
            ),
          );
        }
        return Row(
          children: [
            _buildSummaryCard('Total Customers', metrics.length.toString(), Icons.people, Colors.blue, theme),
            const SizedBox(width: AppSpacing.m),
            _buildSummaryCard('VIPs & Favorites', vips.toString(), Icons.stars, Colors.purple, theme),
            const SizedBox(width: AppSpacing.m),
            _buildSummaryCard('Regulars', regulars.toString(), Icons.repeat, Colors.green, theme),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, ThemeData theme, {bool isFixed = false}) {
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(
              title, 
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    return isFixed ? card : Expanded(child: card);
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    
    return Flex(
      direction: isMobile ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Manage Regulars', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            Text('Maintain a directory of favorite and wholesale customers', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
          ],
        ),
        if (isMobile) const SizedBox(height: AppSpacing.m),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => AddRestockRequestDialog.show(context),
              icon: const Icon(Icons.notifications_active_rounded, size: 16, color: Colors.orange),
              label: const Text('Log Restock Request', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.orange.shade400),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddCustomerDialog(context, ref),
              icon: const Icon(Icons.person_add, size: 16),
              label: const Text('Add Customer', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomerGrid(BuildContext context, WidgetRef ref, List<Customer> customers) {
    final theme = Theme.of(context);
    final metrics = ref.watch(customerMetricsProvider);
    
    if (customers.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(40), child: Text(_searchQuery.isEmpty ? 'No customers in directory yet.' : 'No customers match your search.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))));
    }

    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1));
      final double childAspectRatio = crossAxisCount == 4
          ? 1.22
          : (crossAxisCount == 3 ? 1.28 : (crossAxisCount == 2 ? 1.35 : 1.55));

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: customers.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppSpacing.m,
          mainAxisSpacing: AppSpacing.m,
          childAspectRatio: childAspectRatio,
        ),
        itemBuilder: (context, index) {
          final c = customers[index];
          final m = metrics[c.phone];
          
          return Card(
            elevation: c.isFavorite ? 4 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.m),
              side: c.isFavorite ? BorderSide(color: Colors.orange.withValues(alpha: 0.5), width: 1) : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(
                          c.isFavorite ? Icons.star : Icons.person, 
                          color: c.isFavorite ? Colors.orange : theme.colorScheme.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    c.name, 
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (c.isSpecial)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.amber.shade700, width: 0.8),
                                    ),
                                    child: Text(
                                      '⭐ SPECIAL${c.specialDiscountPercentage != null ? " • ${c.specialDiscountPercentage!.toStringAsFixed(0)}%" : ""}',
                                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                    ),
                                  ),
                              ],
                            ),
                            if (m != null)
                              Row(
                                children: [
                                  Text(
                                    m.performanceLabel,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: m.performanceLabel == 'Bulk Buyer' ? Colors.orange.shade800 : (m.performanceLabel == 'VIP' ? Colors.purple : (m.performanceLabel == 'Regular' ? Colors.blue : Colors.grey)),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(width: 1, height: 8, color: Colors.grey.withValues(alpha: 0.3)),
                                  const SizedBox(width: 4),
                                  Text(
                                    c.isWholesaler ? 'WHOLESALER' : 'RETAILER',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: c.isWholesaler ? theme.colorScheme.primary : Colors.grey,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_vert, size: 20),
                        onSelected: (val) {
                          if (val == 'restock') {
                            AddRestockRequestDialog.show(context, customer: c);
                          } else if (val == 'fav') {
                            ref.read(customerProvider.notifier).toggleFavorite(c.id);
                          } else if (val == 'special') {
                            ref.read(customerProvider.notifier).toggleSpecial(c.id);
                          } else if (val == 'edit') {
                            _showEditCustomerDialog(context, ref, c);
                          } else if (val == 'del') {
                            _confirmDeleteCustomer(context, ref, c);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'restock', child: Row(children: [Icon(Icons.notifications_active_rounded, color: Colors.orange, size: 16), SizedBox(width: 8), Text('Log Restock Request')])),
                          PopupMenuItem(value: 'fav', child: Text(c.isFavorite ? 'Remove Favorite' : 'Mark as Favorite')),
                          PopupMenuItem(value: 'special', child: Text(c.isSpecial ? 'Remove Special (VIP)' : 'Mark as Special Customer')),
                          const PopupMenuItem(value: 'edit', child: Text('Edit Details')),
                          const PopupMenuItem(value: 'del', child: Text('Delete Record', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildMetricRow(Icons.phone_outlined, c.phone, theme),
                                if (c.phone2 != null && c.phone2!.isNotEmpty && c.phone2 != c.phone)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: _buildMetricRow(Icons.phone_iphone_rounded, c.phone2!, theme),
                                  ),
                                const SizedBox(height: 4),
                                _buildMetricRow(Icons.shopping_bag_outlined, 'Orders: ${m?.visitCount ?? 0}', theme),
                                const SizedBox(height: 4),
                                _buildMetricRow(Icons.payments_outlined, 'Spent: GHC${m?.totalSpend.toStringAsFixed(2) ?? '0.00'}', theme),
                                const SizedBox(height: 4),
                                _buildMetricRow(Icons.money_off_outlined, 'Debt: GHC${m?.totalDebt.toStringAsFixed(2) ?? '0.00'}', theme, color: (m?.totalDebt ?? 0) > 0.01 ? Colors.red : null),
                              ],
                            ),
                          ),
                          if (m != null && m.recentSpends.length > 1)
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 40,
                                child: _CustomerTrendGraph(spends: m.recentSpends),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 12, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          c.location ?? 'No location', 
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (c.isPendingApproval) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (c.businessName != null && c.businessName!.isNotEmpty)
                            Text('Shop: ${c.businessName}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _showApproveCustomerDialog(context, ref, c),
                                  icon: const Icon(Icons.check_circle_rounded, size: 12),
                                  label: const Text('APPROVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 26),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              OutlinedButton(
                                onPressed: () => ref.read(customerProvider.notifier).rejectCustomer(c.id),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 26),
                                ),
                                child: const Text('REJECT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    });
  }

  void _showApproveCustomerDialog(BuildContext context, WidgetRef ref, Customer customer) {
    final creditLimitController = TextEditingController(text: '5000');
    String selectedPriceTier = 'wholesale';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
          title: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.check_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Approve Customer Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(customer.name, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Business: ${customer.businessName ?? "N/A"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text('Phone: ${customer.phone}', style: const TextStyle(fontSize: 12)),
              Text('Location: ${customer.location ?? "N/A"}', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 14),
              TextFormField(
                controller: creditLimitController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Allowable Credit Limit (GHS)',
                  hintText: 'e.g. 5000',
                  prefixIcon: Icon(Icons.credit_card_rounded, size: 18),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedPriceTier,
                decoration: const InputDecoration(
                  labelText: 'Assigned Price Tier Category',
                  prefixIcon: Icon(Icons.sell_outlined, size: 18),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'retail', child: Text('Retail Pricing')),
                  DropdownMenuItem(value: 'wholesale', child: Text('Wholesale Pricing')),
                  DropdownMenuItem(value: 'vip', child: Text('VIP Wholesale Pricing')),
                ],
                onChanged: (val) {
                  if (val != null) setDlgState(() => selectedPriceTier = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final double credit = double.tryParse(creditLimitController.text.trim()) ?? 0.0;
                await ref.read(customerProvider.notifier).approveCustomer(
                  customer.id,
                  creditLimit: credit,
                  priceTier: selectedPriceTier,
                );
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${customer.name} approved & activated! Activation SMS sent.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('APPROVE & ACTIVATE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(IconData icon, String text, ThemeData theme, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color ?? theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text, 
            style: TextStyle(fontSize: 11, color: color ?? theme.colorScheme.onSurfaceVariant, fontWeight: color != null ? FontWeight.bold : FontWeight.normal),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _confirmDeleteCustomer(BuildContext context, WidgetRef ref, Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer?'),
        content: Text('Are you sure you want to remove ${customer.name} from the directory? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(customerProvider.notifier).deleteCustomer(customer.id);
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${customer.name} deleted successfully.'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditCustomerDialog(BuildContext context, WidgetRef ref, Customer customer) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: customer.name);
    final phoneController = TextEditingController(text: customer.phone);
    final phone2Controller = TextEditingController(text: customer.phone2 ?? '');
    final locationController = TextEditingController(text: customer.location ?? '');
    bool isFavorite = customer.isFavorite;
    bool isBulkPurchaser = customer.isBulkPurchaser;
    bool isWholesaler = customer.isWholesaler;
    bool isSpecial = customer.isSpecial;
    final discountController = TextEditingController(
      text: customer.specialDiscountPercentage != null ? customer.specialDiscountPercentage!.toString() : '',
    );
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: Text('Edit Customer: ${customer.name}'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController, 
                    decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController, 
                    decoration: const InputDecoration(labelText: 'Primary Phone', hintText: '10 digits', prefixIcon: Icon(Icons.phone_outlined)), 
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length != 10) return 'Exactly 10 digits required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phone2Controller, 
                    decoration: const InputDecoration(labelText: 'Alternative Phone (Optional)', prefixIcon: Icon(Icons.phone_iphone_rounded)), 
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: locationController, 
                    decoration: const InputDecoration(labelText: 'Location / Address', prefixIcon: Icon(Icons.location_on_outlined)),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Mark as Favorite'),
                    subtitle: const Text('Highlighted in directory'),
                    value: isFavorite,
                    onChanged: (val) => setState(() => isFavorite = val ?? false),
                    activeColor: theme.colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('Bulk Purchaser'),
                    subtitle: const Text('Regular bulk buyer status'),
                    value: isBulkPurchaser,
                    onChanged: (val) => setState(() => isBulkPurchaser = val ?? false),
                    activeColor: theme.colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('Special Customer (VIP)'),
                    subtitle: const Text('Eligible for exclusive discounts and promotions'),
                    value: isSpecial,
                    onChanged: (val) => setState(() => isSpecial = val ?? false),
                    activeColor: Colors.amber.shade800,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (isSpecial) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: discountController,
                      decoration: const InputDecoration(
                        labelText: 'Special Discount Percentage (%)',
                        hintText: 'e.g. 10 or 15',
                        prefixIcon: Icon(Icons.percent_rounded),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text('Customer Category', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              'RETAILER',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: !isWholesaler ? const Color(0xFF18181B) : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          selected: !isWholesaler,
                          selectedColor: const Color(0xFFF59E0B),
                          checkmarkColor: const Color(0xFF18181B),
                          onSelected: (v) => setState(() => isWholesaler = false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              'WHOLESALER',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isWholesaler ? const Color(0xFF18181B) : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          selected: isWholesaler,
                          selectedColor: const Color(0xFFF59E0B),
                          checkmarkColor: const Color(0xFF18181B),
                          onSelected: (v) => setState(() => isWholesaler = true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final updatedCustomer = customer.copyWith(
                    name: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                    phone2: phone2Controller.text.trim().isEmpty ? null : phone2Controller.text.trim(),
                    location: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                    isFavorite: isFavorite,
                    isBulkPurchaser: isBulkPurchaser,
                    isWholesaler: isWholesaler,
                    isSpecial: isSpecial,
                    specialDiscountPercentage: isSpecial ? double.tryParse(discountController.text.trim()) : null,
                  );
                  
                  try {
                    await ref.read(customerProvider.notifier).updateCustomer(updatedCustomer);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Customer details updated!'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating customer: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final phone2Controller = TextEditingController();
    final locationController = TextEditingController();
    bool isFavorite = false;
    bool isBulkPurchaser = false;
    bool isWholesaler = false;
    bool isSpecial = false;
    final discountController = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: const Text('Add Regular Customer'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController, 
                    decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController, 
                    decoration: const InputDecoration(labelText: 'Primary Phone', hintText: '10 digits', prefixIcon: Icon(Icons.phone_outlined)), 
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length != 10) return 'Exactly 10 digits required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phone2Controller, 
                    decoration: const InputDecoration(labelText: 'Alternative Phone (Optional)', prefixIcon: Icon(Icons.phone_iphone_rounded)), 
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: locationController, 
                    decoration: const InputDecoration(labelText: 'Location / Address', prefixIcon: Icon(Icons.location_on_outlined)),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Mark as Favorite'),
                    subtitle: const Text('Highlighted in directory'),
                    value: isFavorite,
                    onChanged: (val) => setState(() => isFavorite = val ?? false),
                    activeColor: theme.colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('Bulk Purchaser'),
                    subtitle: const Text('Regular bulk buyer status'),
                    value: isBulkPurchaser,
                    onChanged: (val) => setState(() => isBulkPurchaser = val ?? false),
                    activeColor: theme.colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('Special Customer (VIP)'),
                    subtitle: const Text('Eligible for exclusive discounts and promotions'),
                    value: isSpecial,
                    onChanged: (val) => setState(() => isSpecial = val ?? false),
                    activeColor: Colors.amber.shade800,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (isSpecial) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: discountController,
                      decoration: const InputDecoration(
                        labelText: 'Special Discount Percentage (%)',
                        hintText: 'e.g. 10 or 15',
                        prefixIcon: Icon(Icons.percent_rounded),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text('Customer Category', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              'RETAILER',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: !isWholesaler ? const Color(0xFF18181B) : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          selected: !isWholesaler,
                          selectedColor: const Color(0xFFF59E0B),
                          checkmarkColor: const Color(0xFF18181B),
                          onSelected: (v) => setState(() => isWholesaler = false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              'WHOLESALER',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isWholesaler ? const Color(0xFF18181B) : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          selected: isWholesaler,
                          selectedColor: const Color(0xFFF59E0B),
                          checkmarkColor: const Color(0xFF18181B),
                          onSelected: (v) => setState(() => isWholesaler = true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final String uniqueUuid = UuidUtils.generate();

                  final newCustomer = Customer(
                    id: uniqueUuid,
                    name: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                    phone2: phone2Controller.text.trim().isEmpty ? null : phone2Controller.text.trim(),
                    location: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                    isFavorite: isFavorite,
                    isBulkPurchaser: isBulkPurchaser,
                    isWholesaler: isWholesaler,
                    isSpecial: isSpecial,
                    specialDiscountPercentage: isSpecial ? double.tryParse(discountController.text.trim()) : null,
                  );
                  
                  try {
                    // Show loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );

                    await ref.read(customerProvider.notifier).addCustomer(newCustomer);
                    
                    if (context.mounted) {
                      Navigator.pop(context); // Pop loading
                      Navigator.pop(context); // Pop dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Customer saved and welcome SMS sent!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Pop loading
                      String errorMessage = 'Failed to save customer';
                      final String errorStr = e.toString().toLowerCase();
                      
                      if (errorStr.contains('unique') || errorStr.contains('already exists')) {
                        errorMessage = 'A customer with phone ${phoneController.text} already exists.';
                      } else {
                        errorMessage = 'Error: $e'; // Show the actual error
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(errorMessage, style: const TextStyle(fontSize: 12)), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
                      );
                      debugPrint('CUSTOMER SAVE ERROR: $e');
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white),
              child: const Text('Save Customer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerTrendGraph extends StatelessWidget {
  final List<double> spends;

  const _CustomerTrendGraph({required this.spends});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color lineColor = isDark
        ? (theme.colorScheme.primary.computeLuminance() < 0.2 ? Colors.amber : theme.colorScheme.primary)
        : (theme.colorScheme.primary.computeLuminance() > 0.45 ? const Color(0xFF0F172A) : theme.colorScheme.primary);
    
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: spends.length.toDouble() - 1,
        minY: spends.reduce((a, b) => a < b ? a : b) * 0.8,
        maxY: spends.reduce((a, b) => a > b ? a : b) * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              spends.length,
              (index) => FlSpot(index.toDouble(), spends[index]),
            ),
            isCurved: true,
            color: lineColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}
