import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';

class DocumentNotifier extends StateNotifier<List<DocumentRecord>> {
  DocumentNotifier() : super([]);

  Future<void> deleteDocument(DocumentRecord doc) async {
    state = state.where((d) => d.id != doc.id).toList();
  }

  Future<void> uploadAndAddDocument(
      Uint8List bytes, String fileName, String title, String description) async {
    final doc = DocumentRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      branchCode: 'MAIN',
      title: title,
      description: description,
      fileUrl: '',
      createdAt: DateTime.now(),
    );
    state = [...state, doc];
  }

  Future<void> updateDocument(DocumentRecord doc,
      {Uint8List? newBytes,
      String? newFileName,
      String? title,
      String? description}) async {
    final updated = DocumentRecord(
      id: doc.id,
      branchCode: doc.branchCode,
      title: title ?? doc.title,
      description: description ?? doc.description,
      fileUrl: doc.fileUrl,
      createdAt: doc.createdAt,
    );
    state = [
      for (final d in state)
        if (d.id == doc.id) updated else d
    ];
  }
}

final documentProvider =
    StateNotifierProvider<DocumentNotifier, List<DocumentRecord>>((ref) {
  return DocumentNotifier();
});
