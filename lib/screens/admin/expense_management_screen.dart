import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/uuid_utils.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/role_pop_scope.dart';
import '../../services/expense_provider.dart';
import '../../models/expense_model.dart';
import '../../services/menu_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/user_provider.dart';
import '../../models/user_model.dart';
import '../../services/receipt_service.dart';

class ExpenseManagementScreen extends ConsumerStatefulWidget {
  const ExpenseManagementScreen({super.key});

  @override
  ConsumerState<ExpenseManagementScreen> createState() => _ExpenseManagementScreenState();
}

class _ExpenseManagementScreenState extends ConsumerState<ExpenseManagementScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _datePreset = 'All Time'; // 'All Time', 'Today', 'This Week', 'This Month', 'Custom'
  DateTimeRange? _customDateRange;
  String _receiptFilter = 'All'; // 'All', 'With Receipt', 'No Receipt'
  String _sortBy = 'Date (Newest)'; // 'Date (Newest)', 'Date (Oldest)', 'Amount (Highest)', 'Amount (Lowest)'
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedCategory = 'All';
      _datePreset = 'All Time';
      _customDateRange = null;
      _receiptFilter = 'All';
      _sortBy = 'Date (Newest)';
    });
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedCategory != 'All' ||
      _datePreset != 'All Time' ||
      _receiptFilter != 'All' ||
      _sortBy != 'Date (Newest)';

  List<ExpenseRecord> _getFilteredExpenses(List<ExpenseRecord> allExpenses) {
    final now = DateTime.now();
    final query = _searchQuery.trim().toLowerCase();

    return allExpenses.where((e) {
      // 1. Search filter
      if (query.isNotEmpty) {
        final matchesTitle = e.title.toLowerCase().contains(query);
        final matchesCat = e.category.toLowerCase().contains(query);
        final matchesNotes = e.notes?.toLowerCase().contains(query) ?? false;
        final matchesAmount = e.amount.toString().contains(query);
        if (!matchesTitle && !matchesCat && !matchesNotes && !matchesAmount) {
          return false;
        }
      }

      // 2. Category filter
      if (_selectedCategory == 'All') {
        if (!e.isOperationalExpense) return false;
      } else if (e.category != _selectedCategory) {
        return false;
      }

      // 3. Date range filter
      if (_datePreset == 'Today') {
        if (e.date.year != now.year || e.date.month != now.month || e.date.day != now.day) {
          return false;
        }
      } else if (_datePreset == 'This Week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final endOfWeek = start.add(const Duration(days: 7));
        if (e.date.isBefore(start) || !e.date.isBefore(endOfWeek)) {
          return false;
        }
      } else if (_datePreset == 'This Month') {
        if (e.date.year != now.year || e.date.month != now.month) {
          return false;
        }
      } else if (_datePreset == 'Custom' && _customDateRange != null) {
        final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
        final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
        if (e.date.isBefore(start) || e.date.isAfter(end)) {
          return false;
        }
      }

      // 4. Receipt attachment filter
      if (_receiptFilter == 'With Receipt' && e.receiptUrl == null) {
        return false;
      } else if (_receiptFilter == 'No Receipt' && e.receiptUrl != null) {
        return false;
      }

      return true;
    }).toList()
      ..sort((a, b) {
        switch (_sortBy) {
          case 'Date (Oldest)':
            return a.date.compareTo(b.date);
          case 'Amount (Highest)':
            return b.amount.compareTo(a.amount);
          case 'Amount (Lowest)':
            return a.amount.compareTo(b.amount);
          case 'Date (Newest)':
          default:
            return b.date.compareTo(a.date);
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());

    final theme = Theme.of(context);
    final expenseState = ref.watch(expenseProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    const currentRoute = '/admin/expenses';

    final filteredExpenses = _getFilteredExpenses(expenseState.records);

    return RolePopScope(
      currentRoute: currentRoute,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: const MainAppBar(title: 'Business Expenses'),
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
                    const SizedBox(height: AppSpacing.xl),
                    _buildMonthlySummary(context, expenseState.records),
                    const SizedBox(height: AppSpacing.xl),
                    _buildFilterBar(context, expenseState, filteredExpenses, expenseState.records.length),
                    _buildExpenseList(context, ref, filteredExpenses),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.activePrimaryRole == UserRole.admin || user?.activePrimaryRole == UserRole.superAdmin;
    
    return Flex(
      direction: isMobile ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expense Tracking', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            Text('Manage operational costs and taxes', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
          ],
        ),
        if (isMobile) const SizedBox(height: AppSpacing.m),
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            if (isAdmin)
              OutlinedButton.icon(
                onPressed: () => _showAddCategoryDialog(context, ref),
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('Categories', style: TextStyle(fontSize: 12)),
              ),
            ElevatedButton.icon(
              onPressed: () => _showExpenseDialog(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Expense', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthlySummary(BuildContext context, List<ExpenseRecord> expenses) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final monthExpensesList = expenses
        .where((e) => e.date.month == now.month && e.date.year == now.year)
        .toList();
    final thisMonthExpenses = monthExpensesList.fold(0.0, (sum, e) => sum + e.amount);
    
    final todayExpenses = expenses
        .where((e) => DateUtils.isSameDay(e.date, now))
        .fold(0.0, (sum, e) => sum + e.amount);

    return LayoutBuilder(builder: (context, constraints) {
      final useColumn = constraints.maxWidth < 600;
      
      Widget card1 = Container(
        padding: const EdgeInsets.all(AppSpacing.l),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryMaroon, AppColors.primaryMaroon.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.l),
          boxShadow: [
            BoxShadow(color: AppColors.primaryMaroon.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${DateFormat('MMMM yyyy').format(now)} Expenses', 
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('₵ ${thisMonthExpenses.toStringAsFixed(2)}', 
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  Text('${monthExpensesList.length} entries this month', 
                    style: const TextStyle(color: Colors.white60, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      );

      Widget card2 = Container(
        padding: const EdgeInsets.all(AppSpacing.l),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.today_rounded, color: Colors.orange, size: 28),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's Expenses", 
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('₵ ${todayExpenses.toStringAsFixed(2)}', 
                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w900)),
                  Text(DateFormat('EEEE, MMM dd').format(now), 
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      );

      if (useColumn) {
        return Column(
          children: [
            card1,
            const SizedBox(height: AppSpacing.m),
            card2,
          ],
        );
      }

      return Row(
        children: [
          Expanded(child: card1),
          const SizedBox(width: AppSpacing.m),
          Expanded(child: card2),
        ],
      );
    });
  }

  Widget _buildFilterBar(BuildContext context, ExpenseState expenseState, List<ExpenseRecord> filteredExpenses, int totalCount) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    // Combine system categories and any unique categories present in expense records
    final allCategories = <String>{
      'All',
      ...expenseState.categories,
      ...expenseState.records.map((e) => e.category)
    }.toList();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.l),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.m),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_alt_outlined, size: 20, color: AppColors.textLight),
                const SizedBox(width: 8),
                Text('Filter & Search Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
                const Spacer(),
                if (_hasActiveFilters)
                  TextButton.icon(
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.clear_all, size: 16, color: Colors.red),
                    label: const Text('Reset Filters', style: TextStyle(fontSize: 12, color: Colors.red)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            // Search Input
            TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by title, category, notes, or amount...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.m),
            // Quick Category Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: allCategories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(cat, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      selectedColor: theme.colorScheme.primaryContainer,
                      checkmarkColor: theme.colorScheme.primary,
                      onSelected: (selected) {
                        setState(() => _selectedCategory = selected ? cat : 'All');
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.m),

            // Dropdowns row / grid
            Wrap(
              spacing: AppSpacing.m,
              runSpacing: AppSpacing.m,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Category Filter
                SizedBox(
                  width: isMobile ? double.infinity : 170,
                  child: DropdownButtonFormField<String>(
                    initialValue: allCategories.contains(_selectedCategory) ? _selectedCategory : 'All',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: allCategories.map((c) => DropdownMenuItem<String>(value: c, child: Text(c, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v ?? 'All'),
                  ),
                ),
                // Date Preset Filter
                SizedBox(
                  width: isMobile ? double.infinity : 150,
                  child: DropdownButtonFormField<String>(
                    initialValue: _datePreset,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Date Range',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: ['All Time', 'Today', 'This Week', 'This Month', 'Custom'].map((d) => DropdownMenuItem<String>(value: d, child: Text(d, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) async {
                      if (v == 'Custom') {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                          initialDateRange: _customDateRange ?? DateTimeRange(
                            start: DateTime.now().subtract(const Duration(days: 30)),
                            end: DateTime.now(),
                          ),
                        );
                        if (picked != null) {
                          setState(() {
                            _datePreset = 'Custom';
                            _customDateRange = picked;
                          });
                        }
                      } else {
                        setState(() {
                          _datePreset = v ?? 'All Time';
                          _customDateRange = null;
                        });
                      }
                    },
                  ),
                ),
                // Receipt Attachment Filter
                SizedBox(
                  width: isMobile ? double.infinity : 150,
                  child: DropdownButtonFormField<String>(
                    initialValue: _receiptFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Receipt Image',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: ['All', 'With Receipt', 'No Receipt'].map((r) => DropdownMenuItem<String>(value: r, child: Text(r, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setState(() => _receiptFilter = v ?? 'All'),
                  ),
                ),
                // Sort By
                SizedBox(
                  width: isMobile ? double.infinity : 170,
                  child: DropdownButtonFormField<String>(
                    initialValue: _sortBy,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Sort By',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: ['Date (Newest)', 'Date (Oldest)', 'Amount (Highest)', 'Amount (Lowest)'].map((s) => DropdownMenuItem<String>(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setState(() => _sortBy = v ?? 'Date (Newest)'),
                  ),
                ),
              ],
            ),
            if (_datePreset == 'Custom' && _customDateRange != null) ...[
              const SizedBox(height: 8),
              Chip(
                avatar: const Icon(Icons.date_range, size: 14),
                label: Text(
                  '${DateFormat('MMM dd, yyyy').format(_customDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_customDateRange!.end)}',
                  style: const TextStyle(fontSize: 11),
                ),
                onDeleted: () => setState(() {
                  _datePreset = 'All Time';
                  _customDateRange = null;
                }),
              ),
            ],
            const SizedBox(height: AppSpacing.m),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // Filter summary bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Showing ${filteredExpenses.length} of $totalCount records',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        'Sum: ₵ ${filteredExpenses.fold(0.0, (sum, e) => sum + e.amount).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: filteredExpenses.isEmpty
                      ? null
                      : () => ReceiptService.printExpenseReport(
                            filteredExpenses,
                            title: 'Business Expenses Report${_selectedCategory != "All" ? " - $_selectedCategory" : ""}',
                          ),
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: Text(isMobile ? 'PDF' : 'Export PDF', style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseList(BuildContext context, WidgetRef ref, List<ExpenseRecord> expenses) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.activePrimaryRole == UserRole.admin || user?.activePrimaryRole == UserRole.superAdmin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Records (${expenses.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        const SizedBox(height: AppSpacing.m),
        if (expenses.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text(
                    _hasActiveFilters ? 'No expenses match the selected filters.' : 'No expenses recorded yet.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (_hasActiveFilters) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _resetFilters,
                      child: const Text('Clear Filters'),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final exp = expenses[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                        child: Icon(
                          exp.category == 'Bank Deposit' ? Icons.account_balance : Icons.receipt_long, 
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exp.title, 
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    exp.category, 
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                                  ),
                                ),
                                Text(
                                  '• ${DateFormat('MMM dd, yyyy').format(exp.date)}', 
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₵ ${exp.amount.toStringAsFixed(2)}', 
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.red),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (exp.receiptUrl != null)
                                InkWell(
                                  onTap: () => _showReceiptViewer(context, exp.receiptUrl!),
                                  borderRadius: BorderRadius.circular(4),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.image_outlined, color: Colors.blue, size: 18),
                                  ),
                                ),
                              if (isAdmin) ...[
                                InkWell(
                                  onTap: () => _showExpenseDialog(context, ref, expense: exp),
                                  borderRadius: BorderRadius.circular(4),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.edit_note, color: Colors.blue, size: 18),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _confirmDeleteExpense(context, ref, exp),
                                  borderRadius: BorderRadius.circular(4),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _confirmDeleteExpense(BuildContext context, WidgetRef ref, ExpenseRecord exp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Are you sure you want to delete "${exp.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ref.read(expenseProvider.notifier).deleteExpense(exp.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showReceiptViewer(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(title: const Text('Receipt Image'), leading: const CloseButton()),
            Flexible(child: Image.network(url, fit: BoxFit.contain)),
          ],
        ),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
        title: const Text('Add Expense Category'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Category Name', hintText: 'e.g. Licensing'),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                ref.read(expenseProvider.notifier).addCategory(controller.text);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showExpenseDialog(BuildContext context, WidgetRef ref, {ExpenseRecord? expense}) {
    final isEdit = expense != null;
    final user = ref.read(currentUserProvider);
    final isAdmin = user?.activePrimaryRole == UserRole.admin || user?.activePrimaryRole == UserRole.superAdmin;

    if (isEdit && !isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cashiers are only permitted to record new expenses.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: expense?.title ?? '');
    final amountController = TextEditingController(text: expense?.amount.toString() ?? '');
    final otherCategoryController = TextEditingController();
    final expenseState = ref.read(expenseProvider);
    final theme = Theme.of(context);
    
    // Determine initial category
    String selectedCategory = 'Other';
    if (isEdit) {
      if (expenseState.categories.contains(expense.category)) {
        selectedCategory = expense.category;
      } else {
        selectedCategory = 'Other';
        otherCategoryController.text = expense.category;
      }
    } else {
      selectedCategory = expenseState.categories.first;
    }
    
    Uint8List? localReceiptBytes;
    String? localReceiptName;
    bool localIsUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: Text(isEdit ? 'Edit Business Expense' : 'Add Business Expense'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Expense Title', hintText: 'e.g. ECG Bill - May'),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s\-]'))],
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      ...expenseState.categories.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))),
                      const DropdownMenuItem<String>(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => selectedCategory = v!),
                  ),
                  if (selectedCategory == 'Other') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: otherCategoryController,
                      decoration: const InputDecoration(labelText: 'Specify Category', hintText: 'Enter new category name'),
                      validator: (v) => (selectedCategory == 'Other' && (v == null || v.isEmpty)) ? 'Required' : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount', 
                      hintText: 'e.g. 150.00',
                      prefixText: '₵ '
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (!isEdit || (isEdit && expense.receiptUrl == null))
                    _buildReceiptPicker(context, localReceiptBytes, (bytes, name) {
                      setState(() {
                        localReceiptBytes = bytes;
                        localReceiptName = name;
                      });
                    })
                  else if (isEdit && expense.receiptUrl != null)
                    Column(
                      children: [
                        const Text('Receipt already attached', style: TextStyle(fontSize: 10, color: Colors.green)),
                        TextButton(
                          onPressed: () => _showReceiptViewer(context, expense.receiptUrl!),
                          child: const Text('View Current Receipt'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: localIsUploading ? null : () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: localIsUploading ? null : () async {
                if (formKey.currentState!.validate()) {
                  setState(() => localIsUploading = true);
                  try {
                    String? receiptUrl = isEdit ? expense.receiptUrl : null;
                    if (localReceiptBytes != null) {
                      final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}_$localReceiptName';
                      receiptUrl = await ref.read(expenseProvider.notifier).uploadReceipt(localReceiptBytes!, fileName);
                    }

                    final String categoryToSave = selectedCategory == 'Other' 
                        ? otherCategoryController.text.trim() 
                        : selectedCategory;

                    // If 'Other' was used, also add it to global categories for future use in this session
                    if (selectedCategory == 'Other') {
                      ref.read(expenseProvider.notifier).addCategory(categoryToSave);
                    }

                    final user = ref.read(currentUserProvider);
                    final userName = user?.name ?? 'Admin';

                    if (isEdit) {
                      final updatedExp = expense.copyWith(
                        title: titleController.text.trim(),
                        category: categoryToSave,
                        amount: double.tryParse(amountController.text) ?? 0,
                        receiptUrl: receiptUrl,
                      );
                      await ref.read(expenseProvider.notifier).updateExpense(updatedExp);
                    } else {
                      final String validUuid = UuidUtils.generate();
                      final newExp = ExpenseRecord(
                        id: validUuid,
                        title: titleController.text.trim(),
                        category: categoryToSave,
                        amount: double.tryParse(amountController.text) ?? 0,
                        date: DateTime.now(),
                        receiptUrl: receiptUrl,
                        notes: 'Recorded by: $userName',
                      );
                      await ref.read(expenseProvider.notifier).addExpense(newExp);
                    }
                    
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    debugPrint('Expense Save Error: $e');
                  } finally {
                    if (context.mounted) setState(() => localIsUploading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white),
              child: localIsUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(isEdit ? 'Update Expense' : 'Save Expense'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptPicker(BuildContext context, Uint8List? bytes, Function(Uint8List, String) onPicked) {
    return InkWell(
      onTap: () async {
        final picker = ImagePicker();
        final image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );
        if (image != null) {
          final b = await image.readAsBytes();
          onPicked(b, image.name);
        }
      },
      child: Container(
        height: 80,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.withValues(alpha: 0.05),
        ),
        child: bytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Image.memory(bytes, fit: BoxFit.cover, width: double.infinity),
                  Container(color: Colors.black26),
                  const Center(child: Icon(Icons.check_circle, color: Colors.white)),
                ],
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_long, color: Colors.grey),
                const SizedBox(height: 4),
                const Text('Attach Receipt Image (Optional)', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
      ),
    );
  }
}
