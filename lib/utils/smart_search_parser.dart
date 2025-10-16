import 'dart:math' as math;

import '../models/recipe_search_options.dart';

/// Parses natural-language recipe queries into [RecipeSearchOptions]
/// modifiers that align with Spoonacular's Complex Search parameters.
///
/// Reference: https://spoonacular.com/food-api/docs#Search-Recipes-Complex
class SmartSearchParser {
  const SmartSearchParser._();

  static SmartSearchResult parse(String rawQuery) {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) {
      return const SmartSearchResult(cleanedQuery: '');
    }

    final corrected = _applyCommonCorrections(trimmed);
    final state = _SmartSearchState(original: corrected);

    var cleaned = corrected;

    void removeMatches(RegExp pattern, void Function(Match) onMatch) {
      cleaned = cleaned.replaceAllMapped(pattern, (match) {
        onMatch(match);
        return ' ';
      });
    }

    // Time-based cues ("under 30 minutes", "ready in 20 min", "30-minute")
    removeMatches(
      RegExp(
        r'\b(?:under|less than|within)\s+(\d{1,3})\s*'
        r'(hours?|hrs?|minutes?|mins?|h|m)\b',
        caseSensitive: false,
      ),
      (match) {
        final amount = int.tryParse(match.group(1) ?? '');
        if (amount == null) {
          return;
        }
        final unit = (match.group(2) ?? '').toLowerCase();
        final minutes = unit.startsWith('h') ? amount * 60 : amount;
        state.setMaxReadyTime(minutes);
      },
    );

    removeMatches(
      RegExp(
        r'\bready\s+in\s+(\d{1,3})\s*'
        r'(hours?|hrs?|minutes?|mins?|h|m)\b',
        caseSensitive: false,
      ),
      (match) {
        final amount = int.tryParse(match.group(1) ?? '');
        if (amount == null) {
          return;
        }
        final unit = (match.group(2) ?? '').toLowerCase();
        final minutes = unit.startsWith('h') ? amount * 60 : amount;
        state.setMaxReadyTime(minutes);
      },
    );

    removeMatches(
      RegExp(
        r'\b(\d{1,3})\s*[- ]?(?:minute|min)\b'
        r'(?:\s*(?:meal|meals|recipe|recipes|dinner|dinners|lunch|'
        r'lunches|breakfast|dessert|snack|snacks))?',
        caseSensitive: false,
      ),
      (match) {
        final amount = int.tryParse(match.group(1) ?? '');
        if (amount == null) {
          return;
        }
        state.setMaxReadyTime(amount);
      },
    );

    removeMatches(
      RegExp(r'\b(\d{1,2})\s*[- ]?(?:hour|hr)\b', caseSensitive: false),
      (match) {
        final amount = int.tryParse(match.group(1) ?? '');
        if (amount == null) {
          return;
        }
        state.setMaxReadyTime(amount * 60);
      },
    );

    // Calorie-focused phrases
    removeMatches(
      RegExp(
        r'\b(?:under|less than|below)\s+(\d{2,4})\s*(?:calories|kcal)\b',
        caseSensitive: false,
      ),
      (match) {
        final amount = int.tryParse(match.group(1) ?? '');
        if (amount != null) {
          state.addNumericFilter('maxCalories', amount);
        }
      },
    );

    removeMatches(
      RegExp(
        r'\b(?:\d{2,4})\s*(?:calorie|calories|kcal)\s*'
        r'(?:meal|recipe|option|ideas?)\b',
        caseSensitive: false,
      ),
      (match) {
        final digits = RegExp(r'\d+').stringMatch(match.group(0) ?? '');
        final amount = int.tryParse(digits ?? '');
        if (amount != null) {
          state.addNumericFilter('maxCalories', amount);
        }
      },
    );

    cleaned = _normalizeSpaces(cleaned);

    if (cleaned.isEmpty) {
      cleaned = corrected;
    }

    final lower = cleaned.toLowerCase();
    final lowerOriginal = corrected.toLowerCase();

    // Diet keywords
    state.maybeAddDiet(lowerOriginal, r'\bvegan\b', 'vegan');
    state.maybeAddDiet(lowerOriginal, r'\bvegetarian\b', 'vegetarian');
    state.maybeAddDiet(lowerOriginal, r'\bpesc(?:a|e)tarian\b', 'pescetarian');
    state.maybeAddDiet(lowerOriginal, r'\bpaleo\b', 'paleo');
    state.maybeAddDiet(lowerOriginal, r'\bketo\b', 'ketogenic');
    state.maybeAddDiet(lowerOriginal, r'\bketogenic\b', 'ketogenic');
    state.maybeAddDiet(lowerOriginal, r'\bwhole30\b', 'whole30');
    state.maybeAddDiet(lowerOriginal, r'\blow\s*fodmap\b', 'low fodmap');
    state.maybeAddDiet(lowerOriginal, r'\bplant[- ]?based\b', 'vegan');

    // Intolerances / allergies
    state.maybeAddIntolerance(lowerOriginal, r'\bdairy[- ]?free\b', 'dairy');
    state.maybeAddIntolerance(lowerOriginal, r'\bgluten[- ]?free\b', 'gluten');
    state.maybeAddIntolerance(lowerOriginal, r'\bwheat[- ]?free\b', 'gluten');
    state.maybeAddIntolerance(lowerOriginal, r'\begg[- ]?free\b', 'egg');
    state.maybeAddIntolerance(lowerOriginal, r'\bsoy[- ]?free\b', 'soy');
    state.maybeAddIntolerance(lowerOriginal, r'\bpeanut[- ]?free\b', 'peanut');
    state.maybeAddIntolerance(lowerOriginal, r'\bnut[- ]?free\b', 'tree nut');
    state.maybeAddIntolerance(
      lowerOriginal,
      r'\bshellfish[- ]?free\b',
      'shellfish',
    );

    // Numeric nutrition cues
    if (RegExp(r'\blow\s+carb\b').hasMatch(lowerOriginal) ||
        RegExp(r'\blow[- ]carb\b').hasMatch(lowerOriginal)) {
      state.addNumericFilter('maxCarbs', 30);
    }
    if (RegExp(r'\blow\s+calor(?:ie|ies)\b').hasMatch(lowerOriginal) ||
        RegExp(r'\blow[- ]calor(?:ie|ies)\b').hasMatch(lowerOriginal)) {
      state.addNumericFilter('maxCalories', 450);
    }
    if (RegExp(r'\blow\s+sugar\b').hasMatch(lowerOriginal) ||
        RegExp(r'\bsugar[- ]?free\b').hasMatch(lowerOriginal)) {
      state.addNumericFilter('maxSugar', 12);
    }
    if (RegExp(r'\blow\s+sodium\b').hasMatch(lowerOriginal) ||
        RegExp(r'\blow[- ]sodium\b').hasMatch(lowerOriginal)) {
      state.addNumericFilter('maxSodium', 800);
    }
    if (RegExp(r'\bhigh\s+protein\b').hasMatch(lowerOriginal) ||
        RegExp(r'\bprotein[- ]rich\b').hasMatch(lowerOriginal)) {
      state.addNumericFilter('minProtein', 20);
    }
    if (RegExp(r'\bhigh\s+fiber\b').hasMatch(lowerOriginal) ||
        RegExp(r'\bfibre\b').hasMatch(lowerOriginal)) {
      state.addNumericFilter('minFiber', 5);
    }
    if (RegExp(r'\blow\s+fat\b').hasMatch(lowerOriginal) ||
        RegExp(r'\blow[- ]fat\b').hasMatch(lowerOriginal)) {
      state.addNumericFilter('maxFat', 20);
    }

    // Meal types
    if (RegExp(r'\bbrunch\b').hasMatch(lowerOriginal) ||
        RegExp(r'\bbreakfast\b').hasMatch(lowerOriginal)) {
      state.addMealType('breakfast');
      state.ensureFallback('breakfast recipes');
    }
    if (RegExp(r'\blunch\b').hasMatch(lowerOriginal)) {
      state.addMealType('lunch');
      state.ensureFallback('lunch recipes');
    }
    if (RegExp(r'\bdinner\b').hasMatch(lowerOriginal) ||
        RegExp(r'\bsupper\b').hasMatch(lowerOriginal)) {
      state.addMealType('dinner');
      state.addMealType('main course');
      state.ensureFallback('dinner recipes');
    }
    if (RegExp(r'\bmain\s+course\b').hasMatch(lowerOriginal) ||
        RegExp(r'\bentrée\b').hasMatch(lowerOriginal)) {
      state.addMealType('main course');
    }
    if (RegExp(r'\bappetizer\b').hasMatch(lowerOriginal) ||
        RegExp(r'\bstarter\b').hasMatch(lowerOriginal)) {
      state.addMealType('appetizer');
      state.ensureFallback('appetizer recipes');
    }
    if (RegExp(r'\bside\s+dish\b').hasMatch(lowerOriginal) ||
        RegExp(r'\bside\b').hasMatch(lower)) {
      state.addMealType('side dish');
      state.ensureFallback('side dish recipes');
    }
    if (RegExp(r'\bsalad\b').hasMatch(lowerOriginal)) {
      state.addMealType('salad');
      state.ensureFallback('salad recipes');
    }
    if (RegExp(r'\bsoup\b').hasMatch(lowerOriginal) ||
        RegExp(r'\bstew\b').hasMatch(lowerOriginal)) {
      state.addMealType('soup');
      state.ensureFallback('soup recipes');
    }
    if (RegExp(r'\bdessert\b').hasMatch(lowerOriginal) ||
        RegExp(r'\bsweet\s+treat\b').hasMatch(lowerOriginal)) {
      state.addMealType('dessert');
      state.ensureFallback('dessert recipes');
    }
    if (RegExp(r'\bsnack\b').hasMatch(lowerOriginal)) {
      state.addMealType('snack');
      state.ensureFallback('snack ideas');
    }
    if (RegExp(r'\bbeverage\b').hasMatch(lowerOriginal) ||
        RegExp(r'\bdrink\b').hasMatch(lowerOriginal) ||
        RegExp(r'\bcocktail\b').hasMatch(lowerOriginal) ||
        RegExp(r'\bsmoothie\b').hasMatch(lowerOriginal)) {
      state.addMealType('drink');
      state.ensureFallback('drink recipes');
    }

    // Equipment cues (air fryer, slow cooker etc.)
    if (RegExp(r'\bair\s*fryer\b').hasMatch(lowerOriginal)) {
      state.addEquipment('air fryer');
    }
    if (RegExp(r'\bslow\s*cooker\b').hasMatch(lowerOriginal) ||
        RegExp(r'\bcrockpot\b').hasMatch(lowerOriginal)) {
      state.addEquipment('slow cooker');
    }
    if (RegExp(r'\binstant\s*pot\b').hasMatch(lowerOriginal) ||
        RegExp(r'\bpressure\s*cooker\b').hasMatch(lowerOriginal)) {
      state.addEquipment('pressure cooker');
    }
    if (RegExp(r'\bgrill(?:ed|ing)?\b').hasMatch(lowerOriginal)) {
      state.addEquipment('grill');
    }
    if (RegExp(r'\broaster\b').hasMatch(lowerOriginal) ||
        RegExp(r'\broasted\b').hasMatch(lowerOriginal)) {
      state.addEquipment('oven');
    }
    if (RegExp(r'\bblender\b').hasMatch(lowerOriginal)) {
      state.addEquipment('blender');
    }

    // Cuisine cues to help Spoonacular narrow results
    const cuisineMap = {
      'italian': 'italian',
      'mexican': 'mexican',
      'thai': 'thai',
      'indian': 'indian',
      'chinese': 'chinese',
      'korean': 'korean',
      'japanese': 'japanese',
      'mediterranean': 'mediterranean',
      'greek': 'greek',
      'french': 'french',
      'spanish': 'spanish',
      'middle eastern': 'middle eastern',
      'vietnamese': 'vietnamese',
      'caribbean': 'caribbean',
      'moroccan': 'moroccan',
      'german': 'german',
      'irish': 'irish',
      'american': 'american',
      'british': 'british',
      'latin': 'latin american',
    };

    cuisineMap.forEach((keyword, cuisine) {
      final pattern = RegExp(
        '\\b${RegExp.escape(keyword)}\\b',
        caseSensitive: false,
      );
      if (pattern.hasMatch(lowerOriginal)) {
        state.addCuisine(cuisine);
      }
    });

    // Speed cues for time defaults
    if (RegExp(r'\bquick\b').hasMatch(lowerOriginal) ||
        RegExp(r'\bfast\b').hasMatch(lowerOriginal) ||
        RegExp(r'\bweeknight\b').hasMatch(lowerOriginal)) {
      state.setMaxReadyTime(25);
    }
    if (RegExp(r'\bweekend\b').hasMatch(lowerOriginal)) {
      state.setMaxReadyTime(90);
    }

    // Sorting cues
    if (RegExp(r'\bpopular\b').hasMatch(lowerOriginal) ||
        RegExp(r'\btop rated\b').hasMatch(lowerOriginal) ||
        RegExp(r'\bbest\b').hasMatch(lowerOriginal)) {
      state.setSort('popularity', 'desc');
    }
    if (RegExp(r'\bhealthy\b').hasMatch(lowerOriginal) ||
        RegExp(r'\bnutritious\b').hasMatch(lowerOriginal)) {
      state.setSort('healthiness', 'desc');
    }
    if (RegExp(r'\bbudget\b').hasMatch(lowerOriginal) ||
        RegExp(r'\bcheap\b').hasMatch(lowerOriginal) ||
        RegExp(r'\binexpensive\b').hasMatch(lowerOriginal)) {
      state.setSort('price', 'asc');
    }

    final finalQuery = _normalizeSpaces(cleaned);
    return SmartSearchResult(
      cleanedQuery: finalQuery.isEmpty
          ? (state.fallbackQuery ?? _defaultFallbackQuery(state) ?? corrected)
          : finalQuery,
      diets: state.diets,
      intolerances: state.intolerances,
      mealTypes: state.mealTypes,
      cuisines: state.cuisines,
      equipment: state.equipment,
      numericFilters: state.numericFilters,
      maxReadyTime: state.maxReadyTime,
      sort: state.sort,
      sortDirection: state.sortDirection,
      requireNutrition: state.requireNutrition,
    );
  }
}

class SmartSearchResult {
  const SmartSearchResult({
    required this.cleanedQuery,
    this.diets = const <String>{},
    this.intolerances = const <String>{},
    this.mealTypes = const <String>{},
    this.cuisines = const <String>{},
    this.equipment = const <String>{},
    this.numericFilters = const <String, num>{},
    this.maxReadyTime,
    this.sort,
    this.sortDirection,
    this.requireNutrition = false,
  });

  final String cleanedQuery;
  final Set<String> diets;
  final Set<String> intolerances;
  final Set<String> mealTypes;
  final Set<String> cuisines;
  final Set<String> equipment;
  final Map<String, num> numericFilters;
  final int? maxReadyTime;
  final String? sort;
  final String? sortDirection;
  final bool requireNutrition;

  RecipeSearchOptions applyTo(RecipeSearchOptions base) {
    var next = base;

    final normalisedQuery = cleanedQuery.trim();
    if (normalisedQuery.isNotEmpty && normalisedQuery != base.query?.trim()) {
      next = next.copyWith(query: normalisedQuery);
    }

    if (diets.isNotEmpty && base.diets.isEmpty) {
      next = next.copyWith(diets: _mergeLists(base.diets, diets));
    }

    if (intolerances.isNotEmpty && base.intolerances.isEmpty) {
      next = next.copyWith(
        intolerances: _mergeLists(base.intolerances, intolerances),
      );
    }

    if (mealTypes.isNotEmpty && base.mealTypes.isEmpty) {
      next = next.copyWith(mealTypes: _mergeLists(base.mealTypes, mealTypes));
    }

    if (cuisines.isNotEmpty && base.cuisines.isEmpty) {
      next = next.copyWith(cuisines: _mergeLists(base.cuisines, cuisines));
    }

    if (equipment.isNotEmpty && base.equipment.isEmpty) {
      next = next.copyWith(equipment: _mergeLists(base.equipment, equipment));
    }

    if (maxReadyTime != null) {
      final current = base.maxReadyTime;
      final candidate = current == null
          ? maxReadyTime
          : math.min(current, maxReadyTime!);
      if (candidate != current) {
        next = next.copyWith(maxReadyTime: candidate);
      }
    }

    if (numericFilters.isNotEmpty) {
      final merged = Map<String, num>.from(base.numericFilters);
      var changed = false;
      numericFilters.forEach((key, value) {
        if (!merged.containsKey(key)) {
          merged[key] = value;
          changed = true;
          return;
        }
        final existing = merged[key]!;
        if (_isMaxKey(key)) {
          if (value < existing) {
            merged[key] = value;
            changed = true;
          }
        } else if (_isMinKey(key)) {
          if (value > existing) {
            merged[key] = value;
            changed = true;
          }
        }
      });
      if (changed) {
        next = next.copyWith(numericFilters: merged);
      }
    }

    if (sort != null &&
        (base.sort == null || base.sort == 'max-used-ingredients')) {
      next = next.copyWith(sort: sort);
      if (sortDirection != null) {
        next = next.copyWith(sortDirection: sortDirection);
      }
    }

    if (requireNutrition && !base.addRecipeNutrition) {
      next = next.copyWith(addRecipeNutrition: true);
    }

    return next;
  }
}

class _SmartSearchState {
  _SmartSearchState({required this.original});

  final String original;
  final Set<String> diets = <String>{};
  final Set<String> intolerances = <String>{};
  final Set<String> mealTypes = <String>{};
  final Set<String> cuisines = <String>{};
  final Set<String> equipment = <String>{};
  final Map<String, num> numericFilters = <String, num>{};
  int? maxReadyTime;
  String? sort;
  String? sortDirection;
  bool requireNutrition = false;
  String? fallbackQuery;

  void setMaxReadyTime(int minutes) {
    if (minutes <= 0) {
      return;
    }
    maxReadyTime = maxReadyTime == null
        ? minutes
        : math.min(maxReadyTime!, minutes);
  }

  void addNumericFilter(String key, num value) {
    numericFilters[key] = value;
    if (_requiresNutrition(key)) {
      requireNutrition = true;
    }
  }

  void maybeAddDiet(String lower, String pattern, String diet) {
    if (RegExp(pattern, caseSensitive: false).hasMatch(lower)) {
      diets.add(diet);
    }
  }

  void maybeAddIntolerance(String lower, String pattern, String intolerance) {
    if (RegExp(pattern, caseSensitive: false).hasMatch(lower)) {
      intolerances.add(intolerance);
    }
  }

  void addMealType(String type) {
    mealTypes.add(type);
  }

  void addCuisine(String cuisine) {
    cuisines.add(cuisine);
  }

  void addEquipment(String item) {
    equipment.add(item);
  }

  void ensureFallback(String suggestion) {
    fallbackQuery ??= suggestion;
  }

  void setSort(String nextSort, String direction) {
    sort = nextSort;
    sortDirection = direction;
  }
}

List<String> _mergeLists(List<String> base, Iterable<String> additions) {
  final ordered = <String>{};
  for (final item in base) {
    ordered.add(item);
  }
  for (final add in additions) {
    if (add.trim().isEmpty) {
      continue;
    }
    ordered.add(add.trim());
  }
  return ordered.toList(growable: false);
}

bool _isMaxKey(String key) => key.toLowerCase().startsWith('max');

bool _isMinKey(String key) => key.toLowerCase().startsWith('min');

bool _requiresNutrition(String key) {
  const nutritionKeys = {
    'minprotein',
    'maxcarbs',
    'maxfat',
    'maxsugar',
    'minsugar',
    'maxsodium',
    'minfiber',
  };
  return nutritionKeys.contains(key.toLowerCase());
}

String _normalizeSpaces(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String? _defaultFallbackQuery(_SmartSearchState state) {
  if (state.mealTypes.contains('dessert')) {
    return 'dessert recipes';
  }
  if (state.mealTypes.contains('breakfast')) {
    return 'breakfast recipes';
  }
  if (state.mealTypes.contains('lunch')) {
    return 'lunch recipes';
  }
  if (state.mealTypes.contains('dinner') ||
      state.mealTypes.contains('main course')) {
    return 'dinner recipes';
  }
  if (state.mealTypes.contains('snack')) {
    return 'snack ideas';
  }
  if (state.mealTypes.contains('drink')) {
    return 'drink recipes';
  }
  if (state.cuisines.isNotEmpty) {
    return '${state.cuisines.first} recipes';
  }
  if (state.diets.isNotEmpty) {
    return '${state.diets.first} recipes';
  }
  return null;
}

String _applyCommonCorrections(String input) {
  const corrections = {
    'pinapple': 'pineapple',
    'zuchini': 'zucchini',
    'avacado': 'avocado',
    'expresso': 'espresso',
    'browine': 'brownie',
    'chesse': 'cheese',
    'tommato': 'tomato',
    'pumkin': 'pumpkin',
    'buscuits': 'biscuits',
    'pizzza': 'pizza',
  };

  return input.replaceAllMapped(RegExp(r'\b([A-Za-z]+)\b'), (match) {
    final original = match.group(0)!;
    final key = original.toLowerCase();
    final replacement = corrections[key];
    if (replacement == null) {
      return original;
    }
    if (_isAllCaps(original)) {
      return replacement.toUpperCase();
    }
    if (_isTitleCase(original)) {
      return replacement[0].toUpperCase() + replacement.substring(1);
    }
    return replacement;
  });
}

bool _isAllCaps(String value) {
  return value == value.toUpperCase();
}

bool _isTitleCase(String value) {
  if (value.isEmpty) {
    return false;
  }
  final head = value[0];
  if (head != head.toUpperCase()) {
    return false;
  }
  final tail = value.substring(1);
  return tail == tail.toLowerCase();
}
