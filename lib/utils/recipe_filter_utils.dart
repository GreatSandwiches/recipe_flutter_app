import 'package:flutter/material.dart';

import '../models/recipe_search_options.dart';
import '../widgets/recipe_filter_sheet.dart';

RecipeSearchOptions normaliseRecipeSearchOptions(RecipeSearchOptions options) {
  final int number = options.number <= 0
      ? kDefaultRecipeFilters.number
      : options.number;
  return options.copyWith(
    fillIngredients: true,
    addRecipeInformation: true,
    instructionsRequired: true,
    sort: options.sort ?? kDefaultRecipeFilters.sort,
    sortDirection: options.sortDirection ?? kDefaultRecipeFilters.sortDirection,
    number: number,
  );
}

List<Widget> buildActiveFilterChips({
  required RecipeSearchOptions filters,
  required ValueChanged<RecipeSearchOptions> onFiltersChanged,
}) {
  final List<Widget> chips = [];

  void addChip(String label, RecipeSearchOptions Function() updateBuilder) {
    chips.add(
      Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        child: InputChip(
          label: Text(label),
          onDeleted: () => onFiltersChanged(updateBuilder()),
        ),
      ),
    );
  }

  for (final cuisine in filters.cuisines) {
    addChip('Cuisine: ${_titleCase(cuisine)}', () {
      final next = List<String>.from(filters.cuisines)..remove(cuisine);
      return filters.copyWith(cuisines: next);
    });
  }

  for (final diet in filters.diets) {
    addChip('Diet: ${_titleCase(diet)}', () {
      final next = List<String>.from(filters.diets)..remove(diet);
      return filters.copyWith(diets: next);
    });
  }

  for (final intolerance in filters.intolerances) {
    addChip('No ${_titleCase(intolerance)}', () {
      final next = List<String>.from(filters.intolerances)..remove(intolerance);
      return filters.copyWith(intolerances: next);
    });
  }

  for (final type in filters.mealTypes) {
    addChip('Type: ${_titleCase(type)}', () {
      final next = List<String>.from(filters.mealTypes)..remove(type);
      return filters.copyWith(mealTypes: next);
    });
  }

  for (final excluded in filters.excludeIngredients) {
    addChip('Exclude: ${_titleCase(excluded)}', () {
      final next = List<String>.from(filters.excludeIngredients)
        ..remove(excluded);
      return filters.copyWith(excludeIngredients: next);
    });
  }

  if (filters.maxReadyTime != null) {
    addChip('<= ${filters.maxReadyTime} min', () {
      return filters.copyWith(maxReadyTime: null);
    });
  }

  if (filters.numericFilters.containsKey('maxCalories')) {
    addChip('<= ${filters.numericFilters['maxCalories']!.round()} kcal', () {
      final next = Map<String, num>.from(filters.numericFilters)
        ..remove('maxCalories');
      return filters.copyWith(numericFilters: next);
    });
  }

  if (filters.numericFilters.containsKey('minProtein')) {
    addChip('Protein ≥ ${filters.numericFilters['minProtein']!.round()} g', () {
      final next = Map<String, num>.from(filters.numericFilters)
        ..remove('minProtein');
      return filters.copyWith(numericFilters: next);
    });
  }

  if (filters.sort != null &&
      filters.sort!.isNotEmpty &&
      filters.sort != kDefaultRecipeFilters.sort) {
    final label = kRecipeSortOptions[filters.sort!] ?? filters.sort!;
    addChip('Sort: $label', () {
      return filters.copyWith(sort: kDefaultRecipeFilters.sort);
    });
  }

  if (!filters.ignorePantry) {
    addChip('Use pantry items', () {
      return filters.copyWith(ignorePantry: true);
    });
  }

  return chips;
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return value
      .split(' ')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}
