import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/sale_model.dart';
import '../models/product.dart';
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../models/system_models.dart';
import '../models/warehouse_models.dart';
import '../models/sale_return_model.dart';
import '../models/supplier_return_model.dart';
import '../screens/admin/product_activity_report_screen.dart';

class ReportService {
  static const _primaryMaroon = PdfColor.fromInt(0xFF18181B); // Hardware Dark Onyx Black

  static Future<void> generateDailySalesReport(List<SaleRecord> sales, DateTime date) async {
    final doc = pw.Document();
    final todaySales = sales.where((s) => 
      s.isActive &&
      s.timestamp.year == date.year && 
      s.timestamp.month == date.month && 
      s.timestamp.day == date.day
    ).toList();

    final totalRevenue = todaySales.fold(0.0, (sum, s) => sum + s.totalAmount);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader('Daily Sales Report', date),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummarySection({
            'Total Transactions': todaySales.length.toString(),
            'Gross Revenue': 'GHS ${totalRevenue.toStringAsFixed(2)}',
          }),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _primaryMaroon),
            cellAlignment: pw.Alignment.centerLeft,
            headers: ['Time', 'Invoice ID', 'Customer', 'Items', 'Total (GHS)'],
            data: todaySales.map((s) => [
              DateFormat('HH:mm').format(s.timestamp),
              s.id.substring(s.id.length - 8).toUpperCase(),
              s.customerName ?? 'Walk-in',
              s.items.length.toString(),
              s.totalAmount.toStringAsFixed(2),
            ]).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: 'Daily_Sales_${DateFormat('yyyyMMdd').format(date)}');
  }

  static Future<void> generateMonthlyRevenueSummary(List<SaleRecord> sales, DateTime date) async {
    final doc = pw.Document();
    final monthlySales = sales.where((s) => 
      s.isActive &&
      s.timestamp.year == date.year && 
      s.timestamp.month == date.month
    ).toList();

    final totalRevenue = monthlySales.fold(0.0, (sum, s) => sum + s.totalAmount);
    final totalDiscounts = monthlySales.fold(0.0, (sum, s) => sum + s.totalDiscount);
    
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader('Monthly Revenue Summary - ${DateFormat('MMMM yyyy').format(date)}', DateTime.now()),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummarySection({
            'Total Orders': monthlySales.length.toString(),
            'Gross Revenue': 'GHS ${totalRevenue.toStringAsFixed(2)}',
            'Promo Savings': 'GHS ${totalDiscounts.toStringAsFixed(2)}',
          }),
          pw.SizedBox(height: 20),
          pw.Text('Revenue Breakdown by Day', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _primaryMaroon),
            headers: ['Date', 'Transactions', 'Daily Total (GHS)'],
            data: _groupSalesByDay(monthlySales).entries.map((e) => [
              e.key,
              e.value['count'].toString(),
              e.value['total'].toStringAsFixed(2),
            ]).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: 'Monthly_Revenue_${DateFormat('yyyyMM').format(date)}');
  }

  static Future<void> generateInventoryAudit(List<Product> products) async {
    final doc = pw.Document();
    
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader('Inventory Audit Report', DateTime.now()),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummarySection({
            'Total Products': products.length.toString(),
            'Low Stock Items': products.where((p) => p.stockQuantity <= p.lowStockThreshold).length.toString(),
          }),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _primaryMaroon),
            headers: ['Category', 'Product Name', 'Current Stock', 'Unit', 'Retail Price'],
            data: products.map((p) => [
              p.category,
              p.name,
              p.stockQuantity.toStringAsFixed(1),
              p.unit,
              p.retailPrice.toStringAsFixed(2),
            ]).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: 'Inventory_Audit_${DateFormat('yyyyMMdd').format(DateTime.now())}');
  }

  static Future<void> generateExpenseLedger(List<ExpenseRecord> expenses) async {
    final doc = pw.Document();
    final operationalExpenses = expenses.where((e) => e.isOperationalExpense).toList();
    final total = operationalExpenses.fold(0.0, (sum, e) => sum + e.amount);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader('Business Expense Ledger', DateTime.now()),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummarySection({
            'Total Expenses': 'GHS ${total.toStringAsFixed(2)}',
            'Entries': operationalExpenses.length.toString(),
          }),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _primaryMaroon),
            headers: ['Date', 'Category', 'Description', 'Amount (GHS)'],
            data: operationalExpenses.map((e) => [
              DateFormat('yyyy-MM-dd').format(e.date),
              e.category,
              e.title,
              e.amount.toStringAsFixed(2),
            ]).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: 'Expense_Ledger');
  }

  static Future<void> generateCustomerDebtStatement(List<SaleRecord> sales) async {
    final doc = pw.Document();
    final debtSales = sales.where((s) => s.isActive && s.balance > 0).toList();
    final totalDebt = debtSales.fold(0.0, (sum, s) => sum + s.balance);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader('Customer Debt Statement', DateTime.now()),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummarySection({
            'Total Outstanding': 'GHS ${totalDebt.toStringAsFixed(2)}',
            'Pending Invoices': debtSales.length.toString(),
          }),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _primaryMaroon),
            headers: ['Customer', 'Phone', 'Invoice Date', 'Total', 'Owed (GHS)'],
            data: debtSales.map((s) => [
              s.customerName ?? 'N/A',
              s.customerPhone ?? 'N/A',
              DateFormat('yyyy-MM-dd').format(s.timestamp),
              s.totalAmount.toStringAsFixed(2),
              s.balance.toStringAsFixed(2),
            ]).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: 'Debt_Statement');
  }

  static Future<void> generateStaffPerformanceReport(List<SaleRecord> sales, List<UserAccount> staff) async {
    final doc = pw.Document();
    
    final Map<String, Map<String, dynamic>> performance = {};
    for (final s in sales) {
      if (!s.isActive) continue;
      final name = s.cashierName;
      performance.putIfAbsent(name, () => {'total': 0.0, 'count': 0});
      performance[name]!['total'] += s.totalAmount;
      performance[name]!['count'] += 1;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader('Staff Performance Metrics', DateTime.now()),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _primaryMaroon),
            headers: ['Staff Member', 'Sales Count', 'Total Generated (GHS)', 'Avg/Sale'],
            data: performance.entries.map((e) => [
              e.key,
              e.value['count'].toString(),
              e.value['total'].toStringAsFixed(2),
              (e.value['total'] / e.value['count']).toStringAsFixed(2),
            ]).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: 'Staff_Performance');
  }

  static Future<void> generateTaxComplianceReport({
    required DateTime date,
    required double totalSales,
    required double totalExpenses,
    required double grossProfit,
    required Map<String, double> taxBreakdown,
    bool isQuarterly = false,
  }) async {
    final doc = pw.Document();
    final periodName = isQuarterly 
        ? 'Q${((date.month - 1) / 3).floor() + 1} ${date.year}' 
        : DateFormat('MMMM yyyy').format(date);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader('GRA Tax Compliance Report', date),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummarySection({
            'Reporting Period': periodName,
            'Type': isQuarterly ? 'QUARTERLY FILING' : 'MONTHLY FILING',
            'Status': 'OFFICIAL RECORD',
          }),
          pw.SizedBox(height: 20),
          
          pw.Text('Profit & Loss Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Description', 'Amount (GHS)'],
            data: [
              ['Total Gross Sales', totalSales.toStringAsFixed(2)],
              ['Total Operational Expenses', totalExpenses.toStringAsFixed(2)],
              ['Gross Profit (Pre-Tax)', grossProfit.toStringAsFixed(2)],
            ],
          ),
          
          pw.SizedBox(height: 30),
          pw.Text('GRA TAX COMPLIANCE SUMMARY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: _primaryMaroon)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _primaryMaroon),
            headers: ['Tax Component', 'Calculation Base', 'Calculated Amount (GHS)'],
            data: [
              ['VAT (Value Added Tax)', '20% of Sales', taxBreakdown['VAT (20% Sales)']!.toStringAsFixed(2)],
              ['Income Tax', '20% of Profit', taxBreakdown['Income Tax (20% Profit)']!.toStringAsFixed(2)],
              ['TOTAL TAX PAYABLE', '', taxBreakdown['TOTAL']!.toStringAsFixed(2)],
            ],
          ),
          
          pw.SizedBox(height: 40),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('NET PROFIT AFTER TAX', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.Text('GHS ${(grossProfit - taxBreakdown['TOTAL']!).toStringAsFixed(2)}', 
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: _primaryMaroon)),
            ],
          ),
          
          pw.SizedBox(height: 60),
          pw.Row(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 150, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 5),
                  pw.Text('Manager Signature', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Spacer(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Printed on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: 'Tax_Compliance_${DateFormat('yyyyMM').format(date)}');
  }

  static Future<void> generateCosmeticsComplianceCertificate() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (context) => pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(40),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _primaryMaroon, width: 4),
            ),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text('BUILDING MATERIALS QUALITY & SAFETY CERTIFICATE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _primaryMaroon)),
                pw.SizedBox(height: 20),
                pw.Text('This is to certify that Adom Mmoroso ENT. POS workstation operations comply with all material quality guidelines, safety protocols, and storage standards.', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 11)),
                pw.SizedBox(height: 40),
                pw.Text('STATUS: VERIFIED & CERTIFIED', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.green)),
                pw.SizedBox(height: 60),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Date: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Quality Manager Signature: _________________', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: 'Building_Materials_Quality_Certificate');
  }

  static Future<void> generateInventorySOP() async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        header: (context) => _buildHeader('Warehouse Inventory SOP v3.0', DateTime.now()),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.Header(level: 0, text: 'Standard Operating Procedure: Warehouse & Retail Stock Management'),
          pw.SizedBox(height: 10),
          pw.Paragraph(text: '1. Goods Receiving & Intake: All incoming shipments must be verified against supplier invoices, scanned via barcode, and recorded in Warehouse Intake.'),
          pw.Paragraph(text: '2. Batch Expiry & Tracking: Expiry dates must be entered for applicable batches. Stock dispatch follows strict FIFO (First In, First Out).'),
          pw.Paragraph(text: '3. Store Replenishment & Dispatch: Low-stock shop alerts must trigger store dispatches from warehouse batches before shop inventory depletes.'),
          pw.Paragraph(text: '4. Barcode Verification: All products entering or leaving the workstation must be scanned with USB/Bluetooth or camera barcode scanners.'),
          pw.Paragraph(text: '5. Discrepancy & Waste Audits: Any damaged, broken, or defective hardware materials must be logged immediately under Waste Management for reconciliation.'),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: 'Inventory_SOP_v3.0');
  }

  static Future<void> generateTillLedgerReport(List<TillMovement> history) async {
    final doc = pw.Document();
    
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader('Till & Cash Movement Ledger', DateTime.now()),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummarySection({
            'Final Balance': 'GHS ${history.isEmpty ? "0.00" : history.first.runningBalance.toStringAsFixed(2)}',
            'Total Entries': history.length.toString(),
          }),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _primaryMaroon),
            headers: ['Time', 'Action', 'Reference', 'Amount (GHS)', 'Balance (GHS)'],
            data: history.map((m) => [
              DateFormat('MM/dd HH:mm').format(m.timestamp),
              m.title,
              m.description,
              '${m.type == TillMovementType.cashOut ? "-" : "+"} ${m.amount.toStringAsFixed(2)}',
              m.runningBalance.toStringAsFixed(2),
            ]).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: 'Till_Ledger_${DateFormat('yyyyMMdd').format(DateTime.now())}');
  }

  static Future<void> generateDailyTillClosureReceipt({
    required DateTime closureDate,
    required double physicalCashSales,
    required double physicalCashDebt,
    required double totalPhysicalCash,
    required double momoTotal,
    required double bankTotal,
    required double grossRevenue,
    required double closingAmount,
    String? note,
    String? closedBy,
  }) async {
    final doc = pw.Document();
    final diff = closingAmount - totalPhysicalCash;
    String varianceText = 'BALANCED (0.00)';
    if (diff > 0.01) {
      varianceText = 'OVER (+GHS ${diff.toStringAsFixed(2)})';
    } else if (diff < -0.01) {
      varianceText = 'SHORT (-GHS ${(-diff).toStringAsFixed(2)})';
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader('Daily Sales Closure & Cash Reconciliation', closureDate),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummarySection({
            'Closure Date': DateFormat('EEEE, MMM dd, yyyy').format(closureDate),
            'Physical Cash Counted': 'GHS ${closingAmount.toStringAsFixed(2)}',
            'Expected Till Cash': 'GHS ${totalPhysicalCash.toStringAsFixed(2)}',
            'Cash Variance': varianceText,
          }),
          pw.SizedBox(height: 20),
          pw.Text('Payment Channel Breakdown', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _primaryMaroon),
            headers: ['Payment Channel', 'Direct Sales (GHS)', 'Debt Collections (GHS)', 'Total Revenue (GHS)'],
            data: [
              ['Physical Cash in Drawer', physicalCashSales.toStringAsFixed(2), physicalCashDebt.toStringAsFixed(2), totalPhysicalCash.toStringAsFixed(2)],
              ['Mobile Money (MoMo)', (momoTotal - 0).toStringAsFixed(2), '0.00', momoTotal.toStringAsFixed(2)],
              ['Bank Transfers / Deposits', (bankTotal - 0).toStringAsFixed(2), '0.00', bankTotal.toStringAsFixed(2)],
              ['GROSS TOTAL REVENUE', '', '', grossRevenue.toStringAsFixed(2)],
            ],
          ),
          pw.SizedBox(height: 25),
          pw.Text('Cash Reconciliation & Verification', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Metric', 'Amount (GHS)'],
            data: [
              ['Expected Physical Cash in Drawer', totalPhysicalCash.toStringAsFixed(2)],
              ['Actual Physical Cash Counted', closingAmount.toStringAsFixed(2)],
              ['Reconciliation Variance', varianceText],
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            pw.SizedBox(height: 15),
            pw.Text('Closure Note / Remarks: $note', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
          ],
          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 150, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text('Cashier / Shift Supervisor Signature', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(width: 150, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text('CEO / Manager Signature', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Till_Closure_${DateFormat('yyyyMMdd').format(closureDate)}',
    );
  }

  static Future<void> generateProductActivityReport({
    required List<ProductActivityReportData> reportData,
    required DateTime startDate,
    required DateTime endDate,
    required String branchName,
  }) async {
    final doc = pw.Document();

    double intakesKg = 0.0, intakesUnits = 0.0;
    double soldKg = 0.0, soldUnits = 0.0;
    double stockKg = 0.0, stockUnits = 0.0;
    final totalRevenue = reportData.fold(0.0, (sum, d) => sum + d.totalRevenue);
    final totalProfit = reportData.fold(0.0, (sum, d) => sum + d.totalProfit);

    for (final d in reportData) {
      final u = d.product.unit.trim().toLowerCase();
      final isKg = u == 'kg' || u == 'kgs' || u == 'kilogram' || u == 'kilograms';
      if (isKg) {
        intakesKg += d.totalIntakeQty;
        soldKg += d.totalQtySold;
        stockKg += d.remainingStock;
      } else {
        intakesUnits += d.totalIntakeQty;
        soldUnits += d.totalQtySold;
        stockUnits += d.remainingStock;
      }
    }

    String formatQtySummary(double kg, double units) {
      if (units > 0 && kg > 0) {
        return '${units % 1 == 0 ? units.toInt() : units.toStringAsFixed(1)} units (+ ${kg.toStringAsFixed(1)} kg)';
      } else if (units > 0) {
        return '${units % 1 == 0 ? units.toInt() : units.toStringAsFixed(1)} units';
      } else if (kg > 0) {
        return '${kg.toStringAsFixed(1)} kg';
      } else {
        return '0 Pcs';
      }
    }

    final dateRangeStr = '${DateFormat('MMM dd, yyyy').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader('CEO Executive Product Activity Report', DateTime.now()),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummarySection({
            'Report Period': dateRangeStr,
            'Branch / Entity': branchName,
            'Products Evaluated': reportData.length.toString(),
            'Total Quantity Intaked': formatQtySummary(intakesKg, intakesUnits),
            'Total Quantity Sold': formatQtySummary(soldKg, soldUnits),
            'Gross Revenue Generated': 'GHS ${totalRevenue.toStringAsFixed(2)}',
            'Estimated Net Profit': 'GHS ${totalProfit.toStringAsFixed(2)}',
            'Current Stock Remaining': formatQtySummary(stockKg, stockUnits),
          }),
          pw.SizedBox(height: 15),
          pw.Text('Itemized Product Movement & Financial Analysis',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _primaryMaroon),
            cellAlignment: pw.Alignment.centerLeft,
            headers: ['Product Name', 'Category', 'Intaked Qty', 'Qty Sold', 'Revenue (GHS)', 'Profit (GHS)', 'Remaining Stock'],
            data: reportData.map((d) => [
              d.product.name,
              d.product.category,
              d.totalIntakeQty > 0 
                  ? '+${d.totalIntakeQty % 1 == 0 ? d.totalIntakeQty.toInt() : d.totalIntakeQty.toStringAsFixed(1)} ${d.product.unit}' 
                  : '${d.totalIntakeQty % 1 == 0 ? d.totalIntakeQty.toInt() : d.totalIntakeQty.toStringAsFixed(1)} ${d.product.unit}',
              '${d.totalQtySold % 1 == 0 ? d.totalQtySold.toInt() : d.totalQtySold.toStringAsFixed(1)} ${d.product.unit}',
              d.totalRevenue.toStringAsFixed(2),
              d.totalProfit.toStringAsFixed(2),
              '${d.remainingStock % 1 == 0 ? d.remainingStock.toInt() : d.remainingStock.toStringAsFixed(1)} ${d.product.unit}',
            ]).toList(),
          ),
          pw.SizedBox(height: 30),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Report Generated For: Executive CEO Review', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('System Generated Official Report', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Printed On: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'CEO_Product_Activity_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}',
    );
  }

  static Future<void> generateWarehouseLowStockReport(List<Product> products, {String? branchName}) async {
    final doc = pw.Document();
    final lowStockItems = products.where((p) => !p.isDeleted && (p.needsDispatch || p.warehouseQuantity < 10)).toList();

    final totalShopLow = products.where((p) => !p.isDeleted && p.needsDispatch).length;
    final totalWhsLow = products.where((p) => !p.isDeleted && p.warehouseQuantity < 10).length;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader('Warehouse Low Stock & Dispatch Priority Report', DateTime.now()),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummarySection({
            'Entity / Branch': branchName ?? 'Main HQ',
            'Low Shop Stock Items': '$totalShopLow Products',
            'Low Warehouse Items': '$totalWhsLow Products',
            'Evaluated Items': '${lowStockItems.length}',
          }),
          pw.SizedBox(height: 15),
          pw.Text('Items Requiring Store Dispatch or Supplier Intake',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _primaryMaroon),
            headers: ['Product Name', 'Category', 'SKU / Barcode', 'Shop Stock', 'Warehouse Stock', 'Min Alert', 'Urgency / Status'],
            data: lowStockItems.map((p) {
              String status = 'IN STOCK';
              if (p.needsDispatch && p.warehouseQuantity > 0) {
                status = 'HIGH: DISPATCH NOW';
              } else if (p.needsDispatch && p.warehouseQuantity <= 0) {
                status = 'SUPPLIER INTAKE NEEDED';
              } else if (p.warehouseQuantity < 10) {
                status = 'LOW WHS STOCK';
              }

              return [
                p.name,
                p.category,
                p.sku ?? p.id.substring(0, 8),
                p.stockControlStoreDisplay,
                p.stockControlWarehouseDisplay,
                '${p.minStoreStock.toInt()} Pcs',
                status,
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Warehouse_Low_Stock_${DateFormat('yyyyMMdd').format(DateTime.now())}',
    );
  }

  static Future<void> generateWarehouseValuationReport(List<Product> products, {String? branchName}) async {
    final doc = pw.Document();
    final activeProducts = products.where((p) => !p.isDeleted).toList();

    double totalWhsCost = 0.0;
    double totalWhsRetail = 0.0;
    double totalWhsPcs = 0.0;

    for (final p in activeProducts) {
      totalWhsCost += p.warehouseQuantity * p.costPrice;
      totalWhsRetail += p.warehouseQuantity * p.retailPrice;
      totalWhsPcs += p.warehouseQuantity;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader('Warehouse Inventory & Valuation Report', DateTime.now()),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummarySection({
            'Entity / Branch': branchName ?? 'Main HQ',
            'Catalog Products': '${activeProducts.length}',
            'Total WHS Stock': '${totalWhsPcs.toInt()} Pcs',
            'Total Cost Valuation': 'GHS ${totalWhsCost.toStringAsFixed(2)}',
            'Total Retail Value': 'GHS ${totalWhsRetail.toStringAsFixed(2)}',
          }),
          pw.SizedBox(height: 15),
          pw.Text('Itemized Warehouse Stock Valuation Ledger',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _primaryMaroon),
            headers: ['Product Name', 'Category', 'SKU', 'Warehouse Stock', 'Cost Price', 'Retail Price', 'Total Cost Value'],
            data: activeProducts.map((p) => [
              p.name,
              p.category,
              p.sku ?? p.id.substring(0, 8),
              p.stockControlWarehouseDisplay,
              'GHS ${p.costPrice.toStringAsFixed(2)}',
              'GHS ${p.retailPrice.toStringAsFixed(2)}',
              'GHS ${(p.warehouseQuantity * p.costPrice).toStringAsFixed(2)}',
            ]).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Warehouse_Valuation_${DateFormat('yyyyMMdd').format(DateTime.now())}',
    );
  }

  static Future<void> generateWarehouseDispatchReport(List<WarehouseDispatchRecord> dispatches, {String? branchName}) async {
    final doc = pw.Document();
    double totalPcsDispatched = 0.0;
    for (final d in dispatches) {
      totalPcsDispatched += d.totalQuantity;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader('Warehouse Store Dispatch & Requisition Report', DateTime.now()),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummarySection({
            'Entity / Branch': branchName ?? 'Main HQ',
            'Dispatch Records': '${dispatches.length}',
            'Total Units Dispatched': '${totalPcsDispatched.toInt()} Pcs',
          }),
          pw.SizedBox(height: 15),
          pw.Text('Store Replenishment Dispatch Log',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _primaryMaroon),
            headers: ['Dispatch #', 'Date', 'Destination Store', 'Items Count', 'Total Qty', 'Dispatched By'],
            data: dispatches.map((d) => [
              d.dispatchNumber,
              DateFormat('yyyy-MM-dd HH:mm').format(d.date),
              d.destinationStore,
              '${d.items.length} items',
              '${d.totalQuantity.toInt()} Pcs',
              d.dispatchedBy,
            ]).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Warehouse_Dispatches_${DateFormat('yyyyMMdd').format(DateTime.now())}',
    );
  }

  static Future<void> generateWarehouseIntakeReport(List<WarehouseIntakeRecord> intakes, {String? branchName}) async {
    final doc = pw.Document();
    double totalPcsReceived = 0.0;
    for (final i in intakes) {
      totalPcsReceived += i.totalQuantity;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader('Warehouse Goods Receiving & Intake Log Report', DateTime.now()),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummarySection({
            'Entity / Branch': branchName ?? 'Main HQ',
            'Intake Shipments': '${intakes.length}',
            'Total Quantity Received': '${totalPcsReceived.toInt()} Pcs',
          }),
          pw.SizedBox(height: 15),
          pw.Text('Shipment Goods Intake Ledger',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _primaryMaroon),
            headers: ['Intake #', 'Date', 'Supplier / Source', 'Items Received', 'Total Quantity', 'Notes / Ref'],
            data: intakes.map((i) => [
              i.intakeNumber,
              DateFormat('yyyy-MM-dd HH:mm').format(i.date),
              i.supplierName,
              '${i.items.length} items',
              '${i.totalQuantity.toInt()} Pcs',
              i.notes ?? 'N/A',
            ]).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Warehouse_Intakes_${DateFormat('yyyyMMdd').format(DateTime.now())}',
    );
  }

  static Future<void> generateGoodsReceivedNote(WarehouseIntakeRecord intake, {String? branchName}) async {
    final doc = pw.Document();
    final double totalPcs = intake.totalQuantity;
    final double totalBoxes = totalPcs / 120.0;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader('GOODS RECEIVED NOTE (GRN)', intake.date),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummarySection({
            'GRN Tracking #': intake.intakeNumber,
            'Supplier / Importer': intake.supplierName,
            'Arrival Date & Time': DateFormat('yyyy-MM-dd HH:mm').format(intake.date),
            'Received By': intake.receivedBy ?? 'Warehouse Receiving Staff',
            'Total Product Items': '${intake.items.length} Products',
            'Total Stock Units': '${totalPcs.toInt()} Pcs (~${totalBoxes.toStringAsFixed(1)} Boxes)',
          }),
          pw.SizedBox(height: 15),
          if (intake.notes != null && intake.notes!.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                'Notes / Invoice Reference: ${intake.notes}',
                style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
              ),
            ),
            pw.SizedBox(height: 15),
          ],
          pw.Text('Detailed Goods Intake Item Ledger', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _primaryMaroon),
            headers: ['#', 'SKU / Product Name', 'Category', 'Batch #', 'Qty Received', 'Warehouse Shelf', 'Expiry Date'],
            data: intake.items.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final item = entry.value;
              return [
                '$idx',
                '${item.productName}\n[SKU: ${item.sku}]',
                item.category,
                '#${item.batchNumber}',
                '${item.quantityReceived.toInt()} Pcs',
                item.warehouseLocation ?? 'Section A',
                item.expiryDate != null ? DateFormat('yyyy-MM-dd').format(item.expiryDate!) : 'N/A',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 35),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 200, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text('Supplier / Driver Signature', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Name: ____________________', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 200, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text('Warehouse Receiving Manager', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Signature & Official Stamp', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'GRN_${intake.intakeNumber}_${DateFormat('yyyyMMdd').format(intake.date)}',
    );
  }

  static Future<void> generateReturnSlip(SaleReturnRecord returnRecord, {String? branchName}) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader('RETURN & REFUND VOUCHER', returnRecord.createdAt),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummarySection({
            'Return Voucher #': returnRecord.returnNumber,
            'Original Invoice ID': returnRecord.originalSaleId,
            'Customer Name': returnRecord.customerName ?? 'Walk-in Customer',
            'Processed By': returnRecord.processedBy,
            'Total Refund Amount': 'GHS ${returnRecord.totalRefundAmount.toStringAsFixed(2)}',
            'Refund Method': returnRecord.refundMethod.toUpperCase(),
          }),
          pw.SizedBox(height: 15),
          pw.Text('Returned Product Items Ledger', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _primaryMaroon),
            headers: ['#', 'Product Item', 'Qty Returned', 'Unit Price', 'Refund Total', 'Return Reason', 'Stock Action'],
            data: returnRecord.items.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final item = entry.value;
              return [
                '$idx',
                '${item.product.name}\n[SKU: ${item.product.sku ?? item.product.id.substring(0, 8)}]',
                '${item.quantityReturned.toInt()} ${item.selectedUnit ?? item.product.unit}',
                'GHS ${item.priceAtSale.toStringAsFixed(2)}',
                'GHS ${item.totalRefund.toStringAsFixed(2)}',
                item.reason.name.toUpperCase(),
                item.returnToStock ? 'RESTORED TO STOCK' : 'LOGGED AS LOSS/DAMAGE',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 35),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 200, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text('Customer Signature', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 200, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text('Store Manager Authorization', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'RETURN_VOUCHER_${returnRecord.returnNumber}_${DateFormat('yyyyMMdd').format(returnRecord.createdAt)}',
    );
  }

  static Future<void> generateSupplierReturnNote(SupplierReturnRecord returnRecord, {String? branchName}) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader('SUPPLIER RETURN NOTE (SRN)', returnRecord.createdAt),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSummarySection({
            'SRN Tracking #': returnRecord.returnNumber,
            'Original Intake Receipt #': returnRecord.intakeNumber,
            'Supplier / Source': returnRecord.supplierName,
            'Processed By': returnRecord.processedBy,
            'Total Returned Quantity': '${returnRecord.totalQuantity.toInt()} Pcs',
            'Return Reason': returnRecord.reason.replaceAll('_', ' ').toUpperCase(),
          }),
          pw.SizedBox(height: 15),
          pw.Text('Returned Goods Item Ledger', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _primaryMaroon),
            headers: ['#', 'Product Item', 'Category / SKU', 'Batch #', 'Qty Returned', 'Reason'],
            data: returnRecord.items.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final item = entry.value;
              return [
                '$idx',
                item.productName,
                item.sku,
                '#${item.batchNumber}',
                '${item.quantityReturned.toInt()} Pcs',
                item.reason.replaceAll('_', ' ').toUpperCase(),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 35),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 200, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text('Supplier / Driver Signature', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 200, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text('Warehouse Manager Signature', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'SRN_${returnRecord.returnNumber}_${DateFormat('yyyyMMdd').format(returnRecord.createdAt)}',
    );
  }

  static Map<String, Map<String, dynamic>> _groupSalesByDay(List<SaleRecord> sales) {
    final Map<String, Map<String, dynamic>> groups = {};
    for (final s in sales) {
      if (!s.isActive) continue;
      final day = DateFormat('yyyy-MM-dd').format(s.timestamp);
      groups[day] = groups[day] ?? {'count': 0, 'total': 0.0};
      groups[day]!['count'] += 1;
      groups[day]!['total'] += s.totalAmount;
    }
    return groups;
  }

  static pw.Widget _buildHeader(String title, DateTime date) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ADOM MMOROSO ENT. (BUILDING MATERIALS & HARDWARE)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15, color: _primaryMaroon)),
                pw.Text('Building Materials & Hardware Enterprise • Ghana', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Text('Report Date: ${DateFormat('yyyy-MM-dd').format(date)}', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
        pw.Divider(thickness: 2, color: _primaryMaroon),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1, color: PdfColors.grey300),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Generated by MS Management System', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSummarySection(Map<String, String> data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: data.entries.map((e) => pw.Column(
          children: [
            pw.Text(e.key, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Text(e.value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ],
        )).toList(),
      ),
    );
  }
}

