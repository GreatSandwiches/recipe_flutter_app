import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart'; // for debugPrint

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

  // --- Ingredient Utilities ---
  static List<String> _normalizeIngredients(List<String> ingredients) {
    final seen = <String>{};
    final normalized = <String>[];
    for (var ing in ingredients) {
      var v = ing.trim().toLowerCase();
      if (v.isEmpty) continue;
      // naive plural -> singular (very light heuristic)
      if (v.endsWith('es') && v.length > 4) {
        // tomatoes -> tomato, potatoes -> potato
        if (v.endsWith('oes')) v = v.substring(0, v.length - 2); // drop 'es'
      } else if (v.endsWith('s') && v.length > 3 && !v.endsWith('ss')) {
        v = v.substring(0, v.length - 1);
      }
      if (seen.add(v)) normalized.add(v);
    }
    return normalized;
  }

  // Advanced search with full feature set (A-F from improvement plan)
  static Future<List<Map<String, dynamic>>> searchRecipesByIngredientsAdvanced(
    List<String> ingredients, {
    int number = 25,
    int minUsed = 1,
    int maxMissing = 10,
    bool maximizeUsed = true,
    bool ignorePantry = true,
    bool fallbackComplexSearch = true,
    int fallbackMinResults = 5,
  }) async {
    final key = _requireApiKey();
    final normalized = _normalizeIngredients(ingredients);
    if (normalized.isEmpty) return [];

    final ingParam = normalized.join(',');
    final findUrl = Uri.parse('$_baseUrl/recipes/findByIngredients').replace(queryParameters: {
      'ingredients': ingParam,
      'number': number.toString(),
      'ranking': maximizeUsed ? '1' : '2',
      'ignorePantry': ignorePantry.toString(),
      'apiKey': key,
    });

    final findResponse = await http.get(findUrl);
    if (findResponse.statusCode != 200) {
      throw _httpError('search recipes by ingredients (advanced)', findResponse);
    }
    final List<dynamic> raw = json.decode(findResponse.body);
    var list = raw.cast<Map<String, dynamic>>();

    // Client-side filtering & sorting
    list = list.where((r) {
      final used = (r['usedIngredientCount'] ?? 0) as int;
      final missed = (r['missedIngredientCount'] ?? 0) as int;
      return used >= minUsed && missed <= maxMissing;
    }).toList();

    list.sort((a, b) {
      final usedA = (a['usedIngredientCount'] ?? 0) as int;
      final usedB = (b['usedIngredientCount'] ?? 0) as int;
      final missedA = (a['missedIngredientCount'] ?? 0) as int;
      final missedB = (b['missedIngredientCount'] ?? 0) as int;
      // Desc used, Asc missed
      final usedComp = usedB.compareTo(usedA);
      if (usedComp != 0) return usedComp;
      return missedA.compareTo(missedB);
    });

    // Fallback to complexSearch if not enough good results
    if (fallbackComplexSearch && list.length < fallbackMinResults) {
      final complexUrl = Uri.parse('$_baseUrl/recipes/complexSearch').replace(queryParameters: {
        'includeIngredients': ingParam,
        'number': (number).toString(),
        'addRecipeInformation': 'true',
        'fillIngredients': 'true',
        'sort': maximizeUsed ? 'max-used-ingredients' : 'min-missing-ingredients',
        'apiKey': key,
      });
      final complexResp = await http.get(complexUrl);
      if (complexResp.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(complexResp.body);
        final complexResults = (data['results'] as List).cast<Map<String, dynamic>>();
        // Merge by id
        final existingIds = list.map((e) => e['id']).toSet();
        for (final r in complexResults) {
          if (!existingIds.contains(r['id'])) {
            list.add(r);
          }
        }
        // Re-sort if complex search adds usedIngredientCount fields (may differ: complexSearch returns 'missedIngredientCount'? Not always) - guard.
        list.sort((a, b) {
          final usedA = (a['usedIngredientCount'] ?? 0) as int;
          final usedB = (b['usedIngredientCount'] ?? 0) as int;
          final missedA = (a['missedIngredientCount'] ?? 0) as int;
          final missedB = (b['missedIngredientCount'] ?? 0) as int;
          final usedComp = usedB.compareTo(usedA);
          if (usedComp != 0) return usedComp;
          return missedA.compareTo(missedB);
        });
      } else {
        // Do not throw; keep initial list.
      }
    }

    assert(() {
      debugPrint('[SpoonacularService] Advanced search ingredients="$ingParam" returned ${list.length} results (raw=${raw.length}). Top 3:');
      for (var i = 0; i < list.length && i < 3; i++) {
        final r = list[i];
        debugPrint('  • ${r['title']} (used=${r['usedIngredientCount']}, missed=${r['missedIngredientCount']})');
      }
      return true;
    }());

    return list;
  }

  // Legacy simple wrapper kept for compatibility; now uses improved defaults + sorting.
  static Future<List<Map<String, dynamic>>> searchRecipesByIngredients(String ingredients) async {
    final key = _requireApiKey();
    final url = Uri.parse('$_baseUrl/recipes/findByIngredients')
        .replace(queryParameters: {
      'ingredients': ingredients,
      'number': '25', // increased
      'ranking': '1', // prefer maximizing used ingredients
      'ignorePantry': 'true',
      'apiKey': key,
    });

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      final list = data.cast<Map<String, dynamic>>();
      // Sort & filter basic (used >0)
      final filtered = list.where((r) => (r['usedIngredientCount'] ?? 0) > 0).toList();
      filtered.sort((a, b) {
        final usedA = (a['usedIngredientCount'] ?? 0) as int;
        final usedB = (b['usedIngredientCount'] ?? 0) as int;
        final missedA = (a['missedIngredientCount'] ?? 0) as int;
        final missedB = (b['missedIngredientCount'] ?? 0) as int;
        final usedComp = usedB.compareTo(usedA);
        if (usedComp != 0) return usedComp;
        return missedA.compareTo(missedB);
      });
      assert(() {
        debugPrint('[SpoonacularService] Legacy search ingredients="$ingredients" returned ${filtered.length}/${list.length} after filter.');
        return true;
      }());
      return filtered;
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

  // Search recipes by query
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