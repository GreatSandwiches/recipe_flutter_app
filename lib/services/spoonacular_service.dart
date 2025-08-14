import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SpoonacularService {
  static const String _baseUrl = 'https://api.spoonacular.com';
  
  static String? get _apiKey => dotenv.env['SPOONACULAR_API_KEY'];

  // Search recipes by ingredients
  static Future<List<Map<String, dynamic>>> searchRecipesByIngredients(String ingredients) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Spoonacular API key not found');
    }

    final url = Uri.parse('$_baseUrl/recipes/findByIngredients')
        .replace(queryParameters: {
      'ingredients': ingredients,
      'number': '10',
      'ranking': '2',
      'ignorePantry': 'true',
      'apiKey': _apiKey!,
    });

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to search recipes: ${response.statusCode}');
    }
  }

  // Get recipe details by ID
  static Future<Map<String, dynamic>> getRecipeDetails(int recipeId) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Spoonacular API key not found');
    }

    final url = Uri.parse('$_baseUrl/recipes/$recipeId/information')
        .replace(queryParameters: {
      'includeNutrition': 'false',
      'apiKey': _apiKey!,
    });

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get recipe details: ${response.statusCode}');
    }
  }

  // Search recipes by query
  static Future<List<Map<String, dynamic>>> searchRecipes(String query) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Spoonacular API key not found');
    }

    final url = Uri.parse('$_baseUrl/recipes/complexSearch')
        .replace(queryParameters: {
      'query': query,
      'number': '10',
      'addRecipeInformation': 'true',
      'fillIngredients': 'true',
      'apiKey': _apiKey!,
    });

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return (data['results'] as List).cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to search recipes: ${response.statusCode}');
    }
  }
}