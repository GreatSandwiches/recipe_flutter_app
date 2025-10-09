import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe_search_options.dart';
import '../providers/ingredients_provider.dart';
import '../services/spoonacular_service.dart';
import '../utils/recipe_filter_utils.dart';
import '../utils/smart_search_parser.dart';
import '../widgets/recipe_filter_sheet.dart';
import 'recipe_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialFilters, this.initialKeyword});

  final RecipeSearchOptions? initialFilters;
  final String? initialKeyword;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _keywordController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _recipes = [];
  RecipeSearchResponse? _lastResponse;
  late RecipeSearchOptions _filters;
  List<String> _smartHighlights = const <String>[];
  String? _smartQueryDisplay;

  @override
  void initState() {
    super.initState();
    _filters = normaliseRecipeSearchOptions(
      widget.initialFilters ?? kDefaultRecipeFilters,
    );
    if (widget.initialKeyword != null && widget.initialKeyword!.isNotEmpty) {
      _keywordController.text = widget.initialKeyword!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ingProvider = context.read<IngredientsProvider>();
        if (ingProvider.ingredients.isEmpty) {
          _searchRecipes();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilters != oldWidget.initialFilters &&
        widget.initialFilters != null) {
      _filters = normaliseRecipeSearchOptions(widget.initialFilters!);
    }
    if (widget.initialKeyword != oldWidget.initialKeyword &&
        widget.initialKeyword != null) {
      _keywordController.text = widget.initialKeyword!;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ingProvider = context.watch<IngredientsProvider>();
    final text = ingProvider.ingredients.join(', ');
    if (_searchController.text != text) {
      _searchController.text = text;
      if (ingProvider.ingredients.isNotEmpty) {
        _searchRecipes();
      }
    }
  }

  Future<void> _searchRecipes() async {
    final ingProvider = context.read<IngredientsProvider>();
    final ingredients = List<String>.from(ingProvider.ingredients);
    final keyword = _keywordController.text.trim();
    if (ingredients.isEmpty && keyword.isEmpty) {
      setState(() {
        _isLoading = false;
        _smartHighlights = const <String>[];
        _smartQueryDisplay = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add ingredients or a keyword to search.'),
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _recipes = [];
      _lastResponse = null;
      _smartHighlights = const <String>[];
      _smartQueryDisplay = null;
    });
    try {
      final options = _filters.copyWith(
        includeIngredients: ingredients,
        offset: 0,
      );

      SmartSearchResult? smartResult;
      RecipeSearchOptions effectiveOptions = options;
      if (keyword.isNotEmpty) {
        smartResult = SmartSearchParser.parse(keyword);
        effectiveOptions = smartResult.applyTo(options);
      }

      final response = await SpoonacularService.smartSearchRecipes(
        keyword,
        baseOptions: options,
        includeIngredients: ingredients,
        parsedResult: smartResult,
      );
      final recipes = response.results;
      final highlights = _deriveSmartHighlights(
        baseOptions: options,
        appliedOptions: effectiveOptions,
      );
      final queryDisplay = _resolveSmartQueryDisplay(keyword, smartResult);
      if (!mounted) return;
      setState(() {
        _recipes = recipes;
        _isLoading = false;
        _lastResponse = response;
        _smartHighlights = highlights;
        _smartQueryDisplay = queryDisplay;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _smartHighlights = const <String>[];
        _smartQueryDisplay = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to search recipes: $e')));
    }
  }

  void _removeIngredient(String ing) async {
    final provider = context.read<IngredientsProvider>();
    await provider.remove(ing);
    if (!mounted) return;
    if (provider.ingredients.isNotEmpty) {
      _searchRecipes();
    } else {
      setState(() {
        _recipes = [];
        _smartHighlights = const <String>[];
        _smartQueryDisplay = null;
      });
    }
  }

  Future<void> _openFilters() async {
    final result = await showRecipeFilterSheet(
      context: context,
      initialOptions: _filters,
    );

    if (result != null && mounted) {
      setState(() {
        _filters = normaliseRecipeSearchOptions(result);
      });
      await _searchRecipes();
    }
  }

  List<Widget> _buildActiveFilters() {
    return buildActiveFilterChips(
      filters: _filters,
      onFiltersChanged: (next) {
        setState(() {
          _filters = normaliseRecipeSearchOptions(next);
        });
        _searchRecipes();
      },
    );
  }

  List<Widget> _buildRecipeFacts(Map<String, dynamic> recipe) {
    final used = (recipe['usedIngredientCount'] as num?)?.toInt();
    final missed = (recipe['missedIngredientCount'] as num?)?.toInt();
    final ready = (recipe['readyInMinutes'] as num?)?.toInt();
    final servings = (recipe['servings'] as num?)?.toInt();

    final facts = <Widget>[];

    if (used != null) {
      facts.add(Text('Used ingredients: $used'));
    }
    if (missed != null) {
      facts.add(Text('Missing ingredients: $missed'));
    }
    if (ready != null && ready > 0) {
      facts.add(Text('Ready in $ready min'));
    }
    if (servings != null && servings > 0) {
      facts.add(Text('Serves $servings'));
    }

    if (facts.isEmpty) {
      facts.add(const Text('Tap to view recipe details'));
    }

    return facts;
  }

  String? _resolveSmartQueryDisplay(
    String original,
    SmartSearchResult? result,
  ) {
    if (result == null) return null;
    final cleaned = result.cleanedQuery.trim();
    if (cleaned.isEmpty) return null;
    final base = original.trim();
    if (base.isEmpty) return cleaned;
    return cleaned.toLowerCase() == base.toLowerCase() ? null : cleaned;
  }

  List<String> _deriveSmartHighlights({
    required RecipeSearchOptions baseOptions,
    required RecipeSearchOptions appliedOptions,
  }) {
    final highlights = <String>[];

    void addLabel(String? label) {
      if (label == null) return;
      if (label.trim().isEmpty) return;
      highlights.add(label);
    }

    for (final diet in _diffList(baseOptions.diets, appliedOptions.diets)) {
      addLabel('Diet: ${_formatSmartTitle(diet)}');
    }

    for (final intolerance in _diffList(
      baseOptions.intolerances,
      appliedOptions.intolerances,
    )) {
      addLabel('No ${_formatSmartTitle(intolerance)}');
    }

    for (final type in _diffList(
      baseOptions.mealTypes,
      appliedOptions.mealTypes,
    )) {
      addLabel('Type: ${_formatSmartTitle(type)}');
    }

    for (final cuisine in _diffList(
      baseOptions.cuisines,
      appliedOptions.cuisines,
    )) {
      addLabel('Cuisine: ${_formatSmartTitle(cuisine)}');
    }

    for (final equipment in _diffList(
      baseOptions.equipment,
      appliedOptions.equipment,
    )) {
      addLabel('Equipment: ${_formatSmartTitle(equipment)}');
    }

    if (appliedOptions.maxReadyTime != null &&
        appliedOptions.maxReadyTime != baseOptions.maxReadyTime) {
      addLabel('<= ${appliedOptions.maxReadyTime} min');
    }

    appliedOptions.numericFilters.forEach((key, value) {
      final baseValue = baseOptions.numericFilters[key];
      final shouldHighlight =
          baseValue == null ||
          (_isMaxKey(key) && value < baseValue) ||
          (_isMinKey(key) && value > baseValue);
      if (shouldHighlight) {
        addLabel(_formatNumericHighlight(key, value));
      }
    });

    final baseSort = baseOptions.sort;
    final appliedSort = appliedOptions.sort;
    if (appliedSort != null &&
        appliedSort.isNotEmpty &&
        appliedSort != baseSort) {
      final sortLabel =
          kRecipeSortOptions[appliedSort] ?? _formatSmartTitle(appliedSort);
      addLabel('Sort: $sortLabel');
    }

    return highlights;
  }

  Iterable<String> _diffList(List<String> base, List<String> applied) {
    if (applied.isEmpty) return const <String>[];
    final Set<String> baseSet = base
        .map((value) => value.toLowerCase().trim())
        .toSet();
    return applied.where(
      (value) => !baseSet.contains(value.toLowerCase().trim()),
    );
  }

  String _formatSmartTitle(String value) {
    return value
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String? _formatNumericHighlight(String key, num value) {
    final rounded = value.round();
    switch (key.toLowerCase()) {
      case 'maxcalories':
        return '<= $rounded kcal';
      case 'minprotein':
        return 'Protein >= $rounded g';
      case 'maxcarbs':
        return 'Carbs <= $rounded g';
      case 'maxsugar':
        return 'Sugar <= $rounded g';
      case 'maxsodium':
        return 'Sodium <= $rounded mg';
      case 'minfiber':
        return 'Fiber >= $rounded g';
      case 'maxfat':
        return 'Fat <= $rounded g';
      default:
        return null;
    }
  }

  bool _isMaxKey(String key) => key.toLowerCase().startsWith('max');

  bool _isMinKey(String key) => key.toLowerCase().startsWith('min');

  Widget _buildSmartSummarySection(BuildContext context) {
    final query = _smartQueryDisplay;
    final highlights = _smartHighlights;
    if ((query == null || query.isEmpty) && highlights.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (query != null && query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Showing results for "$query"',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
          if (highlights.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final label in highlights) Chip(label: Text(label)),
              ],
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ingProvider = context.watch<IngredientsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Recipe Search')),
      body: Column(
        children: [
          if (ingProvider.ingredients.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'No ingredients yet. Add some or try a keyword search below.',
                textAlign: TextAlign.center,
              ),
            )
          else
            SizedBox(
              height: 74,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final ing in ingProvider.ingredients)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InputChip(
                        label: Text(ing),
                        onDeleted: () => _removeIngredient(ing),
                        deleteIcon: const Icon(Icons.close, size: 18),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _keywordController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchRecipes(),
              decoration: const InputDecoration(
                labelText: 'Add a keyword (e.g. pasta, tacos, curry)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    readOnly: true,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Ingredients used',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _openFilters,
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: const Text('Filters'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _searchRecipes,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                ),
              ],
            ),
          ),
          if (_filters.hasNonIngredientFilters ||
              _filters.excludeIngredients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(children: _buildActiveFilters()),
              ),
            ),
          if ((_smartQueryDisplay != null && _smartQueryDisplay!.isNotEmpty) ||
              _smartHighlights.isNotEmpty)
            _buildSmartSummarySection(context),
          if (_lastResponse != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Found ${_lastResponse!.totalResults} recipes',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (_filters.number != _lastResponse!.number &&
                      _lastResponse!.results.length <
                          _lastResponse!.totalResults)
                    Text(
                      'Showing ${_lastResponse!.results.length} of ${_lastResponse!.totalResults}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    )
                  else
                    Text(
                      'Showing ${_lastResponse!.results.length}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_recipes.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _recipes.length,
                itemBuilder: (context, index) {
                  final recipe = _recipes[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: recipe['image'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                recipe['image'],
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.restaurant),
                                  );
                                },
                              ),
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[300],
                              child: const Icon(Icons.restaurant),
                            ),
                      title: Text(
                        recipe['title'] ?? 'Unknown Recipe',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildRecipeFacts(recipe),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecipeDetailsScreen(
                              recipeId: recipe['id'],
                              recipeName: recipe['title'] ?? 'Unknown Recipe',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            )
          else
            const Expanded(
              child: Center(
                child: Text(
                  'No recipes found. Try adjusting ingredients or filters.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
