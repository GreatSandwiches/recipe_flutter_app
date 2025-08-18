import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SpoonacularService {
  static const String _baseUrl = 'https://api.spoonacular.com';
  
  static String? get _apiKey => dotenv.env['SPOONACULAR_API_KEY'];

  static bool _isInvalidKey(String? key) => key == null || key.isEmpty || key.startsWith('YOUR_') || key.contains('YOUR_SPOONACULAR_API_KEY');

  static String _requireApiKey() {
    if (_isInvalidKey(_apiKey)) {
      throw Exception('Spoonacular API key not configured. Set SPOONACULAR_API_KEY in .env then fully restart the app.');
    }
    return _apiKey!;
  }

  static Exception _httpError(String context, http.Response r) {
    final snippet = r.body.isEmpty
        ? ''
        : ' Body: ${r.body.length > 140 ? '${r.body.substring(0, 140)}...' : r.body}';
    if (r.statusCode == 401) {
      return Exception('Unauthorized (401) during $context. Likely invalid or missing API key.$snippet');
    }
    if (r.statusCode == 402) {
      return Exception('Quota exceeded (402) during $context. Check Spoonacular plan/usage.$snippet');
    }
    if (r.statusCode == 429) {
      return Exception('Rate limited (429) during $context. Slow down requests.$snippet');
    }
    return Exception('Failed to $context: ${r.statusCode}.$snippet');
  }

  // Search recipes by ingredients
  static Future<List<Map<String, dynamic>>> searchRecipesByIngredients(String ingredients) async {
    final key = _requireApiKey();

    final url = Uri.parse('$_baseUrl/recipes/findByIngredients')
        .replace(queryParameters: {
      'ingredients': ingredients,
      'number': '10',
      'ranking': '2',
      'ignorePantry': 'true',
      'apiKey': key,
    });

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw _httpError('search recipes by ingredients', response);
    }
  }

  // Get recipe details by ID
  static Future<Map<String, dynamic>> getRecipeDetails(int recipeId) async {
    final key = _requireApiKey();

    final url = Uri.parse('$_baseUrl/recipes/$recipeId/information')
        .replace(queryParameters: {
      'includeNutrition': 'false',
      'apiKey': key,
    });

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw _httpError('get recipe details', response);
    }
  }

  // Search recipes by querys
  static Future<List<Map<String, dynamic>>> searchRecipes(String query) async {
    final key = _requireApiKey();

    final url = Uri.parse('$_baseUrl/recipes/complexSearch')
        .replace(queryParameters: {
      'query': query,
      'number': '10',
      'addRecipeInformation': 'true',
      'fillIngredients': 'true',
      'apiKey': key,
    });

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return (data['results'] as List).cast<Map<String, dynamic>>();
    } else {
      throw _httpError('search recipes', response);
    }
  }

  // Get random recipes
  static Future<List<Map<String, dynamic>>> getRandomRecipes(int number) async {
    final key = _requireApiKey();

    final url = Uri.parse('$_baseUrl/recipes/random')
        .replace(queryParameters: {
      'number': number.toString(),
      'apiKey': key,
    });

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return (data['recipes'] as List).cast<Map<String, dynamic>>();
    } else {
      throw _httpError('get random recipes', response);
    }
  }
}