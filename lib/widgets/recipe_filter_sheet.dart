import 'package:flutter/material.dart';

import '../models/recipe_search_options.dart';

const List<String> kCuisineOptions = [
  'African',
  'American',
  'British',
  'Caribbean',
  'Chinese',
  'French',
  'German',
  'Greek',
  'Indian',
  'Italian',
  'Japanese',
  'Korean',
  'Mediterranean',
  'Mexican',
  'Middle Eastern',
  'Nordic',
  'Spanish',
  'Thai',
  'Vietnamese',
];

const List<String> kDietOptions = [
  'gluten free',
  'ketogenic',
  'vegetarian',
  'vegan',
  'pescetarian',
  'paleo',
  'primal',
  'whole30',
];

const List<String> kIntoleranceOptions = [
  'dairy',
  'egg',
  'gluten',
  'grain',
  'peanut',
  'seafood',
  'sesame',
  'shellfish',
  'soy',
  'sulfite',
  'tree nut',
  'wheat',
];

const List<String> kMealTypeOptions = [
  'main course',
  'side dish',
  'dessert',
  'appetizer',
  'salad',
  'bread',
  'breakfast',
  'soup',
  'beverage',
  'snack',
];

const Map<String, String> kRecipeSortOptions = {
  'max-used-ingredients': 'Use most of my ingredients',
  'min-missing-ingredients': 'Missing the fewest extras',
  'time': 'Fastest to make',
  'popularity': 'Most popular',
  'healthiness': 'Healthiest',
  'price': 'Budget friendly',
  'calories': 'Lowest calories',
  'protein': 'Highest protein',
};

const RecipeSearchOptions kDefaultRecipeFilters = RecipeSearchOptions(
  fillIngredients: true,
  addRecipeInformation: true,
  instructionsRequired: true,
  ignorePantry: true,
  sort: 'max-used-ingredients',
  sortDirection: 'desc',
  number: 12,
);

Future<RecipeSearchOptions?> showRecipeFilterSheet({
  required BuildContext context,
  required RecipeSearchOptions initialOptions,
}) {
  return showModalBottomSheet<RecipeSearchOptions>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _RecipeFiltersSheet(initialOptions: initialOptions),
  );
}

class _RecipeFiltersSheet extends StatefulWidget {
  const _RecipeFiltersSheet({required this.initialOptions});

  final RecipeSearchOptions initialOptions;

  @override
  State<_RecipeFiltersSheet> createState() => _RecipeFiltersSheetState();
}

class _RecipeFiltersSheetState extends State<_RecipeFiltersSheet> {
  late Set<String> _cuisines;
  late Set<String> _diets;
  late Set<String> _intolerances;
  late Set<String> _mealTypes;
  late bool _ignorePantry;
  late bool _addInstructions;
  late bool _addNutrition;
  late String _sort;
  late String _sortDirection;
  int? _maxReadyTime;
  final TextEditingController _excludeController = TextEditingController();
  final TextEditingController _maxCaloriesController = TextEditingController();
  final TextEditingController _minProteinController = TextEditingController();
  double _resultsCount = kDefaultRecipeFilters.number.toDouble();

  static const List<int> _readyTimeOptions = [15, 20, 30, 45, 60, 90];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialOptions;
    _cuisines = initial.cuisines.toSet();
    _diets = initial.diets.toSet();
    _intolerances = initial.intolerances.toSet();
    _mealTypes = initial.mealTypes.toSet();
    _ignorePantry = initial.ignorePantry;
    _addInstructions = initial.addRecipeInstructions;
    _addNutrition = initial.addRecipeNutrition;
    _sort = initial.sort ?? kDefaultRecipeFilters.sort!;
    _sortDirection =
        initial.sortDirection ?? kDefaultRecipeFilters.sortDirection!;
    _maxReadyTime = initial.maxReadyTime;
    _resultsCount = initial.number.toDouble();

    if (initial.excludeIngredients.isNotEmpty) {
      _excludeController.text = initial.excludeIngredients.join(', ');
    }

    final maxCalories = initial.numericFilters['maxCalories'];
    if (maxCalories != null) {
      _maxCaloriesController.text = maxCalories.toString();
    }
    final minProtein = initial.numericFilters['minProtein'];
    if (minProtein != null) {
      _minProteinController.text = minProtein.toString();
    }
  }

  @override
  void dispose() {
    _excludeController.dispose();
    _maxCaloriesController.dispose();
    _minProteinController.dispose();
    super.dispose();
  }

  void _toggleValue(Set<String> set, String value) {
    if (set.contains(value)) {
      set.remove(value);
    } else {
      set.add(value);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      builder: (context, controller) {
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, kDefaultRecipeFilters);
                      },
                      child: const Text('Reset'),
                    ),
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final exclude = _splitInput(_excludeController.text);
                        final numeric = <String, num>{};
                        final maxCalories = num.tryParse(
                          _maxCaloriesController.text,
                        );
                        if (maxCalories != null) {
                          numeric['maxCalories'] = maxCalories;
                        }
                        final minProtein = num.tryParse(
                          _minProteinController.text,
                        );
                        if (minProtein != null) {
                          numeric['minProtein'] = minProtein;
                        }

                        Navigator.pop(
                          context,
                          RecipeSearchOptions(
                            cuisines: _cuisines.toList(),
                            diets: _diets.toList(),
                            intolerances: _intolerances.toList(),
                            mealTypes: _mealTypes.toList(),
                            excludeIngredients: exclude,
                            maxReadyTime: _maxReadyTime,
                            sort: _sort,
                            sortDirection: _sortDirection,
                            ignorePantry: _ignorePantry,
                            addRecipeInstructions: _addInstructions,
                            addRecipeNutrition: _addNutrition,
                            addRecipeInformation: true,
                            fillIngredients: true,
                            number: _resultsCount.round(),
                            numericFilters: numeric,
                          ),
                        );
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const _SectionTitle('Cuisine'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final cuisine in kCuisineOptions)
                            FilterChip(
                              label: Text(cuisine),
                              selected: _cuisines.contains(
                                cuisine.toLowerCase(),
                              ),
                              onSelected: (_) {
                                _toggleValue(_cuisines, cuisine.toLowerCase());
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _SectionTitle('Dietary preference'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final diet in kDietOptions)
                            FilterChip(
                              label: Text(diet),
                              selected: _diets.contains(diet),
                              onSelected: (_) {
                                _toggleValue(_diets, diet);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _SectionTitle('Intolerances'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final intolerance in kIntoleranceOptions)
                            FilterChip(
                              label: Text(intolerance),
                              selected: _intolerances.contains(intolerance),
                              onSelected: (_) {
                                _toggleValue(_intolerances, intolerance);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _SectionTitle('Meal type'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final type in kMealTypeOptions)
                            FilterChip(
                              label: Text(type),
                              selected: _mealTypes.contains(type),
                              onSelected: (_) {
                                _toggleValue(_mealTypes, type);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _SectionTitle('Max ready time'),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Any'),
                            selected: _maxReadyTime == null,
                            onSelected: (_) {
                              setState(() {
                                _maxReadyTime = null;
                              });
                            },
                          ),
                          for (final time in _readyTimeOptions)
                            ChoiceChip(
                              label: Text('<= $time min'),
                              selected: _maxReadyTime == time,
                              onSelected: (_) {
                                setState(() {
                                  _maxReadyTime = time;
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _SectionTitle('Sorting'),
                      DropdownButtonFormField<String>(
                        value: kRecipeSortOptions.containsKey(_sort)
                            ? _sort
                            : kDefaultRecipeFilters.sort,
                        items: kRecipeSortOptions.entries
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _sort = value;
                            _sortDirection = value == 'time' ? 'asc' : 'desc';
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('Sort direction'),
                          const SizedBox(width: 16),
                          DropdownButton<String>(
                            value: _sortDirection,
                            items: const [
                              DropdownMenuItem(
                                value: 'asc',
                                child: Text('Ascending'),
                              ),
                              DropdownMenuItem(
                                value: 'desc',
                                child: Text('Descending'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _sortDirection = value;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _SectionTitle('Exclude ingredients'),
                      TextField(
                        controller: _excludeController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. peanuts, anchovies',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _SectionTitle('Nutrition goals'),
                      TextField(
                        controller: _maxCaloriesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max calories (per serving)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _minProteinController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Min protein (grams)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _SectionTitle('Results per search'),
                      Slider(
                        min: 6,
                        max: 24,
                        divisions: 9,
                        value: _resultsCount.clamp(6, 24),
                        label: '${_resultsCount.round()} recipes',
                        onChanged: (value) {
                          setState(() {
                            _resultsCount = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Ignore pantry staples'),
                        subtitle: const Text(
                          'Remove items like salt, water, flour from ingredient matching',
                        ),
                        value: _ignorePantry,
                        onChanged: (value) {
                          setState(() {
                            _ignorePantry = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Include step-by-step instructions'),
                        subtitle: const Text(
                          'Adds analysed steps when available',
                        ),
                        value: _addInstructions,
                        onChanged: (value) {
                          setState(() {
                            _addInstructions = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Include nutrition breakdown'),
                        subtitle: const Text(
                          'Adds macros & calories (uses more API quota)',
                        ),
                        value: _addNutrition,
                        onChanged: (value) {
                          setState(() {
                            _addNutrition = value;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static List<String> _splitInput(String value) {
    if (value.trim().isEmpty) {
      return const [];
    }
    return value
        .split(',')
        .map((e) => e.trim())
        .where((element) => element.isNotEmpty)
        .toList();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }
}
