import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SpoonacularService {
  static const String _baseUrl = 'https://api.spoonacular.com';
  static const int _defaultRecipeCount = 12;

  static String? get _apiKey => dotenv.env['SPOONACULAR_API_KEY'];

  static bool _isInvalidKey(String? key) =>
      key == null ||
      key.isEmpty ||
      key.startsWith('YOUR_') ||
      key.contains('YOUR_SPOONACULAR_API_KEY');

  static String _requireApiKey() {
    if (_isInvalidKey(_apiKey)) {
      throw Exception(
        'Spoonacular API key not configured. Set SPOONACULAR_API_KEY in .env then fully restart the app.',
      );
    }
    return _apiKey!;
  }

  static Exception _httpError(String context, http.Response r) {
    final snippet = r.body.isEmpty
        ? ''
        : ' Body: ${r.body.length > 140 ? '${r.body.substring(0, 140)}...' : r.body}';
    if (r.statusCode == 401) {
      return Exception(
        'Unauthorized (401) during $context. Likely invalid or missing API key.$snippet',
      );
    }
    if (r.statusCode == 402) {
      return Exception(
        'Quota exceeded (402) during $context. Check Spoonacular plan/usage.$snippet',
      );
    }
    if (r.statusCode == 429) {
      return Exception(
        'Rate limited (429) during $context. Slow down requests.$snippet',
      );
    }
    return Exception('Failed to $context: ${r.statusCode}.$snippet');
  }

  // Search recipes by ingredients
  static Future<List<Map<String, dynamic>>> searchRecipesByIngredients(
    List<String> ingredients,
  ) async {
    final key = _requireApiKey();

    final sortedUnique =
        ingredients
            .map((ing) => ing.trim().toLowerCase())
            .where((ing) => ing.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (sortedUnique.isEmpty) {
      return const [];
    }

    final desiredCount = _defaultRecipeCount;
    final Map<int, Map<String, dynamic>> collected = {};

    void _ingest(List<Map<String, dynamic>> source) {
      for (final recipe in source) {
        final id = switch (recipe['id']) {
          int value => value,
          num value => value.toInt(),
          _ => null,
        };
        if (id == null || collected.containsKey(id)) continue;
        collected[id] = recipe;
      }
    }

    final complexResults = await _complexSearchByIngredients(
      sortedUnique,
      key,
      desiredCount,
    );
    _ingest(complexResults);

    if (collected.length < desiredCount) {
      final fallbackResults = await _findByIngredients(
        sortedUnique,
        key,
        desiredCount,
      );
      _ingest(fallbackResults);
    }

    final ranked = collected.values.toList()..sort(_compareByIngredientUsage);

    return ranked;
  }

  // Get recipe details by ID
  static Future<Map<String, dynamic>> getRecipeDetails(int recipeId) async {
    final key = _requireApiKey();

    final url = Uri.parse(
      '$_baseUrl/recipes/$recipeId/information',
    ).replace(queryParameters: {'includeNutrition': 'false', 'apiKey': key});

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

    final url = Uri.parse('$_baseUrl/recipes/complexSearch').replace(
      queryParameters: {
        'query': query,
        'number': '10',
        'addRecipeInformation': 'true',
        'fillIngredients': 'true',
        'apiKey': key,
      },
    );

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

    final url = Uri.parse(
      '$_baseUrl/recipes/random',
    ).replace(queryParameters: {'number': number.toString(), 'apiKey': key});

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return (data['recipes'] as List).cast<Map<String, dynamic>>();
    } else {
      throw _httpError('get random recipes', response);
    }
  }

  static Future<List<Map<String, dynamic>>> _complexSearchByIngredients(
    List<String> ingredients,
    String apiKey,
    int number,
  ) async {
    final url = Uri.parse('$_baseUrl/recipes/complexSearch').replace(
      queryParameters: {
        'includeIngredients': ingredients.join(','),
        'number': number.toString(),
        'sort': 'max-used-ingredients',
        'sortDirection': 'desc',
        'fillIngredients': 'true',
        'addRecipeInformation': 'true',
        'instructionsRequired': 'true',
        'ignorePantry': 'true',
        'apiKey': apiKey,
      },
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final results = (data['results'] as List?) ?? const [];
      return results
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    throw _httpError('search recipes by ingredients (complex)', response);
  }

  static Future<List<Map<String, dynamic>>> _findByIngredients(
    List<String> ingredients,
    String apiKey,
    int number,
  ) async {
    final url = Uri.parse('$_baseUrl/recipes/findByIngredients').replace(
      queryParameters: {
        'ingredients': ingredients.join(','),
        'number': number.toString(),
        'ranking': '2',
        'ignorePantry': 'true',
        'apiKey': apiKey,
      },
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    throw _httpError('search recipes by ingredients (fallback)', response);
  }

  static int _compareByIngredientUsage(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    int getUsed(Map<String, dynamic> m) =>
        (m['usedIngredientCount'] as num?)?.toInt() ?? 0;
    int getMissed(Map<String, dynamic> m) =>
        (m['missedIngredientCount'] as num?)?.toInt() ?? 0;
    int getReady(Map<String, dynamic> m) =>
        (m['readyInMinutes'] as num?)?.toInt() ?? 0;

    final usedDiff = getUsed(b) - getUsed(a);
    if (usedDiff != 0) return usedDiff;

    final missedDiff = getMissed(a) - getMissed(b);
    if (missedDiff != 0) return missedDiff;

    final readyDiff = getReady(a) - getReady(b);
    if (readyDiff != 0) return readyDiff;

    final titleA = (a['title'] as String?) ?? '';
    final titleB = (b['title'] as String?) ?? '';
    return titleA.compareTo(titleB);
  }
}
