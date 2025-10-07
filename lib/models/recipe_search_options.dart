class RecipeSearchOptions {
  const RecipeSearchOptions({
    this.query,
    this.includeIngredients = const [],
    this.excludeIngredients = const [],
    this.cuisines = const [],
    this.diets = const [],
    this.intolerances = const [],
    this.equipment = const [],
    this.mealTypes = const [],
    this.maxReadyTime,
    this.sort,
    this.sortDirection,
    this.instructionsRequired = false,
    this.addRecipeInformation = false,
    this.addRecipeInstructions = false,
    this.addRecipeNutrition = false,
    this.fillIngredients = false,
    this.ignorePantry = true,
    this.number = 12,
    this.offset = 0,
    this.numericFilters = const {},
  });

  final String? query;
  final List<String> includeIngredients;
  final List<String> excludeIngredients;
  final List<String> cuisines;
  final List<String> diets;
  final List<String> intolerances;
  final List<String> equipment;
  final List<String> mealTypes;
  final int? maxReadyTime;
  final String? sort;
  final String? sortDirection;
  final bool instructionsRequired;
  final bool addRecipeInformation;
  final bool addRecipeInstructions;
  final bool addRecipeNutrition;
  final bool fillIngredients;
  final bool ignorePantry;
  final int number;
  final int offset;
  final Map<String, num> numericFilters;

  static const Object _unset = Object();

  RecipeSearchOptions copyWith({
    Object? query = _unset,
    List<String>? includeIngredients,
    List<String>? excludeIngredients,
    List<String>? cuisines,
    List<String>? diets,
    List<String>? intolerances,
    List<String>? equipment,
    List<String>? mealTypes,
    Object? maxReadyTime = _unset,
    Object? sort = _unset,
    Object? sortDirection = _unset,
    bool? instructionsRequired,
    bool? addRecipeInformation,
    bool? addRecipeInstructions,
    bool? addRecipeNutrition,
    bool? fillIngredients,
    bool? ignorePantry,
    int? number,
    int? offset,
    Map<String, num>? numericFilters,
  }) {
    return RecipeSearchOptions(
      query: identical(query, _unset) ? this.query : query as String?,
      includeIngredients: includeIngredients ?? this.includeIngredients,
      excludeIngredients: excludeIngredients ?? this.excludeIngredients,
      cuisines: cuisines ?? this.cuisines,
      diets: diets ?? this.diets,
      intolerances: intolerances ?? this.intolerances,
      equipment: equipment ?? this.equipment,
      mealTypes: mealTypes ?? this.mealTypes,
      maxReadyTime: identical(maxReadyTime, _unset)
          ? this.maxReadyTime
          : maxReadyTime as int?,
      sort: identical(sort, _unset) ? this.sort : sort as String?,
      sortDirection: identical(sortDirection, _unset)
          ? this.sortDirection
          : sortDirection as String?,
      instructionsRequired: instructionsRequired ?? this.instructionsRequired,
      addRecipeInformation: addRecipeInformation ?? this.addRecipeInformation,
      addRecipeInstructions:
          addRecipeInstructions ?? this.addRecipeInstructions,
      addRecipeNutrition: addRecipeNutrition ?? this.addRecipeNutrition,
      fillIngredients: fillIngredients ?? this.fillIngredients,
      ignorePantry: ignorePantry ?? this.ignorePantry,
      number: number ?? this.number,
      offset: offset ?? this.offset,
      numericFilters: numericFilters ?? this.numericFilters,
    );
  }

  Map<String, String> toQueryParameters(String apiKey) {
    final params = <String, String>{
      'number': number.toString(),
      'offset': offset.toString(),
      'ignorePantry': ignorePantry.toString(),
      'instructionsRequired': instructionsRequired.toString(),
      'fillIngredients': fillIngredients.toString(),
      'apiKey': apiKey,
    };

    final effectiveAddInfo =
        addRecipeInformation || addRecipeInstructions || addRecipeNutrition;
    params['addRecipeInformation'] = effectiveAddInfo.toString();
    if (addRecipeInstructions) {
      params['addRecipeInstructions'] = 'true';
    }
    if (addRecipeNutrition) {
      params['addRecipeNutrition'] = 'true';
    }

    void assignList(String name, List<String> values) {
      final clean = _cleanList(values);
      if (clean.isNotEmpty) {
        params[name] = clean.join(',');
      }
    }

    if (query != null && query!.trim().isNotEmpty) {
      params['query'] = query!.trim();
    }

    assignList('includeIngredients', includeIngredients);
    assignList('excludeIngredients', excludeIngredients);
    assignList('cuisine', cuisines);
    assignList('diet', diets);
    assignList('intolerances', intolerances);
    assignList('equipment', equipment);

    if (mealTypes.isNotEmpty) {
      params['type'] = mealTypes.join(',');
    }

    if (maxReadyTime != null) {
      params['maxReadyTime'] = maxReadyTime!.toString();
    }

    if (sort != null && sort!.isNotEmpty) {
      params['sort'] = sort!;
    }

    if (sortDirection != null && sortDirection!.isNotEmpty) {
      params['sortDirection'] = sortDirection!;
    }

    for (final entry in numericFilters.entries) {
      params[entry.key] = entry.value.toString();
    }

    return params;
  }

  bool get hasNonIngredientFilters {
    return (query != null && query!.trim().isNotEmpty) ||
        excludeIngredients.isNotEmpty ||
        cuisines.isNotEmpty ||
        diets.isNotEmpty ||
        intolerances.isNotEmpty ||
        equipment.isNotEmpty ||
        mealTypes.isNotEmpty ||
        maxReadyTime != null ||
        (sort != null && sort != 'max-used-ingredients') ||
        numericFilters.isNotEmpty ||
        !ignorePantry ||
        addRecipeInstructions ||
        addRecipeNutrition;
  }

  static List<String> _cleanList(List<String> items) {
    final set = <String>{};
    for (final item in items) {
      final value = item.trim();
      if (value.isNotEmpty) {
        set.add(value);
      }
    }
    return set.toList();
  }
}

class RecipeSearchResponse {
  const RecipeSearchResponse({
    required this.results,
    required this.totalResults,
    required this.offset,
    required this.number,
  });

  final List<Map<String, dynamic>> results;
  final int totalResults;
  final int offset;
  final int number;

  RecipeSearchResponse copyWith({
    List<Map<String, dynamic>>? results,
    int? totalResults,
    int? offset,
    int? number,
  }) {
    return RecipeSearchResponse(
      results: results ?? this.results,
      totalResults: totalResults ?? this.totalResults,
      offset: offset ?? this.offset,
      number: number ?? this.number,
    );
  }
}
