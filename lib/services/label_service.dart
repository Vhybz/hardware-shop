import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transfer_models.dart';
import '../core/utils.dart';
import 'package:intl/intl.dart';

class LabelService {
  static Future<void> printTransferLabel(StockTransfer transfer) async {
    try {
      final doc = pw.Document();
      final font = await PdfGoogleFonts.notoSansRegular();
      final boldFont = await PdfGoogleFonts.notoSansBold();
      _addTransferPage(doc, transfer, font, boldFont);

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Label_${transfer.id}',
      );
    } catch (e) {
      debugPrint('Label Printing Error: $e');
    }
  }

  static Future<void> printMultipleTransferLabels(List<StockTransfer> transfers) async {
    try {
      final doc = pw.Document();
      final font = await PdfGoogleFonts.notoSansRegular();
      final boldFont = await PdfGoogleFonts.notoSansBold();
      for (final t in transfers) {
        _addTransferPage(doc, t, font, boldFont);
      }

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Batch_Labels_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      debugPrint('Multi-Label Printing Error: $e');
    }
  }

  static void _addTransferPage(pw.Document doc, StockTransfer transfer, pw.Font font, pw.Font boldFont) {
    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(50 * PdfPageFormat.mm, 35 * PdfPageFormat.mm),
        build: (pw.Context context) {
          final dest = transfer.isIndividual 
              ? (transfer.customerName ?? 'Individual') 
              : transfer.destination;
          
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(transfer.productName.toUpperCase(), 
                  style: pw.TextStyle(font: boldFont, fontSize: 8),
                  textAlign: pw.TextAlign.center),
                pw.Text('Weight: ${WeightConverter.formatShort(transfer.weight, unit: transfer.unit)}', style: pw.TextStyle(font: font, fontSize: 7)),
                pw.SizedBox(height: 1),
                pw.Container(
                  height: 25,
                  width: 25,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: transfer.id,
                    drawText: false,
                  ),
                ),
                pw.SizedBox(height: 1),
                pw.Text('ID: ${transfer.id.length > 8 ? transfer.id.substring(transfer.id.length - 8) : transfer.id}', 
                  style: pw.TextStyle(font: boldFont, fontSize: 5)),
                pw.Text('To: $dest', style: pw.TextStyle(font: font, fontSize: 6), overflow: pw.TextOverflow.clip, maxLines: 1),
                if (transfer.isIndividual && transfer.customerPhone != null)
                   pw.Text('Tel: ${transfer.customerPhone}', style: pw.TextStyle(font: font, fontSize: 5)),
                pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(transfer.transferTime), style: pw.TextStyle(font: font, fontSize: 5)),
              ],
            ),
          );
        },
      ),
    );
  }
}
