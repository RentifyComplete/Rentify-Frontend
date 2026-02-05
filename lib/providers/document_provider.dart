import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DocumentProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _uploadedDocuments = [];

  List<Map<String, dynamic>> get uploadedDocuments => _uploadedDocuments;

  DocumentProvider() {
    loadDocuments();
  }

  // Load documents from SharedPreferences
  Future<void> loadDocuments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? documentsJson = prefs.getString('uploaded_documents');

      if (documentsJson != null) {
        final List<dynamic> decoded = json.decode(documentsJson);
        _uploadedDocuments = decoded.map((doc) => Map<String, dynamic>.from(doc)).toList();
        notifyListeners();
        print('✅ Loaded ${_uploadedDocuments.length} documents from storage');
      }
    } catch (e) {
      print('❌ Error loading documents: $e');
    }
  }

  // Save documents to SharedPreferences
  Future<void> saveDocuments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String documentsJson = json.encode(_uploadedDocuments);
      await prefs.setString('uploaded_documents', documentsJson);
      print('✅ Saved ${_uploadedDocuments.length} documents to storage');
    } catch (e) {
      print('❌ Error saving documents: $e');
    }
  }

  // Add a new document
  Future<void> addDocument(Map<String, dynamic> document) async {
    _uploadedDocuments.add(document);
    await saveDocuments();
    notifyListeners();
  }

  // Delete a document
  Future<void> deleteDocument(int index) async {
    if (index >= 0 && index < _uploadedDocuments.length) {
      _uploadedDocuments.removeAt(index);
      await saveDocuments();
      notifyListeners();
    }
  }

  // Clear all documents
  Future<void> clearAllDocuments() async {
    _uploadedDocuments.clear();
    await saveDocuments();
    notifyListeners();
  }

  // Get document count
  int get documentCount => _uploadedDocuments.length;
}