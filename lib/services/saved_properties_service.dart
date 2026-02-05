// lib/services/saved_properties_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SavedPropertiesService {
  static const String _savedPropertiesKey = 'saved_properties';

  // Save a property
  Future<bool> saveProperty(Map<String, dynamic> property) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedProperties = await getSavedProperties();
      
      // Check if property already exists
      final exists = savedProperties.any((p) => p['id'] == property['id']);
      if (exists) {
        return true; // Already saved
      }
      
      // Add property with timestamp
      final propertyToSave = {
        ...property,
        'savedAt': DateTime.now().toIso8601String(),
      };
      
      savedProperties.add(propertyToSave);
      
      // Convert to JSON and save
      final jsonList = savedProperties.map((p) => json.encode(p)).toList();
      await prefs.setStringList(_savedPropertiesKey, jsonList);
      
      print('✅ Property saved: ${property['id']}');
      return true;
    } catch (e) {
      print('❌ Error saving property: $e');
      return false;
    }
  }

  // Remove a property
  Future<bool> removeProperty(String propertyId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedProperties = await getSavedProperties();
      
      // Remove the property
      savedProperties.removeWhere((p) => p['id'] == propertyId);
      
      // Save updated list
      final jsonList = savedProperties.map((p) => json.encode(p)).toList();
      await prefs.setStringList(_savedPropertiesKey, jsonList);
      
      print('✅ Property removed: $propertyId');
      return true;
    } catch (e) {
      print('❌ Error removing property: $e');
      return false;
    }
  }

  // Check if a property is saved
  Future<bool> isPropertySaved(String propertyId) async {
    final savedProperties = await getSavedProperties();
    return savedProperties.any((p) => p['id'] == propertyId);
  }

  // Get all saved properties
  Future<List<Map<String, dynamic>>> getSavedProperties() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_savedPropertiesKey) ?? [];
      
      return jsonList.map((jsonStr) {
        return json.decode(jsonStr) as Map<String, dynamic>;
      }).toList();
    } catch (e) {
      print('❌ Error getting saved properties: $e');
      return [];
    }
  }

  // Clear all saved properties
  Future<bool> clearAllSavedProperties() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_savedPropertiesKey);
      return true;
    } catch (e) {
      print('❌ Error clearing saved properties: $e');
      return false;
    }
  }
}