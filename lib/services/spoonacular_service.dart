import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/recipe_search_options.dart';
import '../utils/smart_search_parser.dart';

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
  static Future<RecipeSearchResponse> searchRecipesByIngredients(
    List<String> ingredients, {
    RecipeSearchOptions? options,
  }) async {
    final sortedUnique =
        ingredients
            .map((ing) => ing.trim().toLowerCase())
            .where((ing) => ing.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (sortedUnique.isEmpty) {
      return const RecipeSearchResponse(
        results: [],
        totalResults: 0,
        offset: 0,
        number: 0,
      );
    }

    final request = (options ?? const RecipeSearchOptions()).copyWith(
      includeIngredients: sortedUnique,
      fillIngredients: true,
      addRecipeInformation: true,
      instructionsRequired: true,
      ignorePantry: options?.ignorePantry ?? true,
      number: options?.number ?? _defaultRecipeCount,
      sort: options?.sort ?? 'max-used-ingredients',
      sortDirection: options?.sortDirection ?? 'desc',
    );

    final response = await complexSearch(request);

    if (response.results.length >= (request.number)) {
      final ranked = [...response.results]..sort(_compareByIngredientUsage);
      final limited = ranked.length > request.number
          ? ranked.sublist(0, request.number)
          : ranked;
      return response.copyWith(results: limited);
    }

    if (request.hasNonIngredientFilters) {
      final ranked = [...response.results]..sort(_compareByIngredientUsage);
      final limited = ranked.length > request.number
          ? ranked.sublist(0, request.number)
          : ranked;
      return response.copyWith(results: limited);
    }

    final fallback = await _findByIngredients(
      sortedUnique,
      request.number,
      ignorePantry: request.ignorePantry,
    );

    final Map<int, Map<String, dynamic>> combined = {};
    void ingest(List<Map<String, dynamic>> source) {
      for (final item in source) {
        final id = switch (item['id']) {
          int value => value,
          num value => value.toInt(),
          _ => null,
        };
        if (id == null || combined.containsKey(id)) continue;
        combined[id] = item;
      }
    }

    ingest(response.results);
    ingest(fallback);

    final ranked = combined.values.toList()..sort(_compareByIngredientUsage);

    final limited = ranked.length > request.number
        ? ranked.sublist(0, request.number)
        : ranked;

    return response.copyWith(results: limited);
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

  static Future<Map<String, dynamic>> getRecipeNutritionWidget(
    int recipeId,
  ) async {
    final key = _requireApiKey();
    final url = Uri.parse(
      '$_baseUrl/recipes/$recipeId/nutritionWidget.json',
    ).replace(queryParameters: {'apiKey': key});

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw _httpError('get recipe nutrition widget', response);
    }
  }

  static Future<Map<String, dynamic>> getRecipeCostBreakdown(
    int recipeId,
  ) async {
    final key = _requireApiKey();
    final url = Uri.parse(
      '$_baseUrl/recipes/$recipeId/priceBreakdownWidget.json',
    ).replace(queryParameters: {'apiKey': key});

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw _httpError('get recipe cost breakdown', response);
    }
  }

  // Search recipes by query
  static Future<List<Map<String, dynamic>>> searchRecipes(String query) async {
    final response = await smartSearchRecipes(
      query,
      baseOptions: const RecipeSearchOptions(
        addRecipeInformation: true,
        fillIngredients: true,
        instructionsRequired: true,
        number: 10,
      ),
    );
    return response.results;
  }

  static Future<RecipeSearchResponse> smartSearchRecipes(
    String keyword, {
    RecipeSearchOptions? baseOptions,
    List<String>? includeIngredients,
    SmartSearchResult? parsedResult,
  }) async {
    final base = baseOptions ?? const RecipeSearchOptions();
    final parsed = parsedResult ?? SmartSearchParser.parse(keyword);
    var request = parsed.applyTo(base);

    if (includeIngredients != null) {
      request = request.copyWith(includeIngredients: includeIngredients);
    }

    if (includeIngredients != null && includeIngredients.isNotEmpty) {
      return searchRecipesByIngredients(includeIngredients, options: request);
    }

    return complexSearch(request);
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

  static Future<List<Map<String, dynamic>>> _findByIngredients(
    List<String> ingredients,
    int number, {
    bool ignorePantry = true,
    int ranking = 2,
  }) async {
    final url = Uri.parse('$_baseUrl/recipes/findByIngredients').replace(
      queryParameters: {
        'ingredients': ingredients.join(','),
        'number': number.toString(),
        'ranking': ranking.toString(),
        'ignorePantry': ignorePantry.toString(),
        'apiKey': _requireApiKey(),
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

  static Future<RecipeSearchResponse> complexSearch(
    RecipeSearchOptions options,
  ) async {
    final url = Uri.parse(
      '$_baseUrl/recipes/complexSearch',
    ).replace(queryParameters: options.toQueryParameters(_requireApiKey()));

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final results = ((data['results'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      return RecipeSearchResponse(
        results: results,
        totalResults: (data['totalResults'] as num?)?.toInt() ?? results.length,
        offset: (data['offset'] as num?)?.toInt() ?? options.offset,
        number: (data['number'] as num?)?.toInt() ?? options.number,
      );
    }

    throw _httpError('complex search', response);
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
