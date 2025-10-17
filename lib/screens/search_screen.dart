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
  final TextEditingController _keywordController = TextEditingController();
  String _lastIngredientSignature = '';
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
    _keywordController.addListener(_onKeywordChanged);
    if (widget.initialKeyword != null && widget.initialKeyword!.isNotEmpty) {
      _keywordController.text = widget.initialKeyword!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
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
    final signature = ingProvider.ingredients.join(', ');
    if (_lastIngredientSignature != signature) {
      _lastIngredientSignature = signature;
      if (ingProvider.ingredients.isNotEmpty) {
        _searchRecipes();
      }
    }
  }

  String? _resolveSmartQueryDisplay(
    String original,
    SmartSearchResult? result,
  ) {
    if (result == null) {
      return null;
    }
    final cleaned = result.cleanedQuery.trim();
    if (cleaned.isEmpty) {
      return null;
    }
    final base = original.trim();
    if (base.isEmpty) {
      return cleaned;
    }
    return cleaned.toLowerCase() == base.toLowerCase() ? null : cleaned;
  }

  List<String> _deriveSmartHighlights({
    required RecipeSearchOptions baseOptions,
    required RecipeSearchOptions appliedOptions,
  }) {
    final highlights = <String>[];

    void addLabel(String? label) {
      if (label == null) {
        return;
      }
      if (label.trim().isEmpty) {
        return;
      }
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
    if (applied.isEmpty) {
      return const <String>[];
    }
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
      if (!mounted) {
        return;
      }
      setState(() {
        _recipes = recipes;
        _isLoading = false;
        _lastResponse = response;
        _smartHighlights = highlights;
        _smartQueryDisplay = queryDisplay;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
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
    if (!mounted) {
      return;
    }
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
      },
    );
  }

  List<Widget> _buildRecipeFacts(Map<String, dynamic> recipe) {
    final facts = <Widget>[];
    TextStyle style = const TextStyle(fontSize: 12, color: Colors.grey);
    void addFact(String label, dynamic value, {String? suffix}) {
      if (value == null || (value is String && value.trim().isEmpty)) {
        return;
      }
      facts.add(Text('$label: $value${suffix ?? ''}', style: style));
    }

    addFact('Ready in', recipe['readyInMinutes'], suffix: ' min');
    addFact('Servings', recipe['servings']);
    addFact('Health score', recipe['healthScore']);
    if (recipe['vegan'] == true) {
      facts.add(Text('Vegan', style: style));
    }
    if (recipe['vegetarian'] == true) {
      facts.add(Text('Vegetarian', style: style));
    }
    if (recipe['glutenFree'] == true) {
      facts.add(Text('Gluten free', style: style));
    }
    return facts;
  }

  @override
  void dispose() {
    _keywordController.removeListener(_onKeywordChanged);
    _keywordController.dispose();
    super.dispose();
  }

  void _onKeywordChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Widget _buildKeywordField(BuildContext context) {
    return TextField(
      controller: _keywordController,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _searchRecipes(),
      decoration: InputDecoration(
        hintText: 'Search by dish, ingredient, or mood',
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        suffixIcon: _keywordController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear keyword',
                icon: const Icon(Icons.clear),
                onPressed: _isLoading
                    ? null
                    : () {
                        _keywordController.clear();
                      },
              ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: _isLoading ? null : _searchRecipes,
          icon: const Icon(Icons.search),
          label: const Text('Search recipes'),
        ),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _openFilters,
          icon: const Icon(Icons.tune),
          label: const Text('Filters'),
        ),
      ],
    );
  }

  Widget _buildIngredientSection(
    BuildContext context,
    IngredientsProvider ingProvider,
  ) {
    final theme = Theme.of(context);
    if (ingProvider.ingredients.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Add pantry items from the home tab or just try a keyword search above.',
              textAlign: TextAlign.left,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pantry ingredients',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final ing in ingProvider.ingredients)
                    InputChip(
                      label: Text(ing),
                      onDeleted: () => _removeIngredient(ing),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ingProvider = context.watch<IngredientsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Recipe Search')),
      body: Column(
        children: [
          // Scrollable header area so keyboard never causes overflow
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Find the perfect recipe',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        _buildKeywordField(context),
                        const SizedBox(height: 12),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                  _buildIngredientSection(context, ingProvider),
                  if (_filters.hasNonIngredientFilters ||
                      _filters.excludeIngredients.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _buildActiveFilters(),
                        ),
                      ),
                    ),
                  if ((_smartQueryDisplay != null &&
                          _smartQueryDisplay!.isNotEmpty) ||
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          if (_filters.number != _lastResponse!.number &&
                              _lastResponse!.results.length <
                                  _lastResponse!.totalResults)
                            Text(
                              'Showing ${_lastResponse!.results.length} of '
                              '${_lastResponse!.totalResults}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            )
                          else
                            Text(
                              'Showing ${_lastResponse!.results.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Results area
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
      resizeToAvoidBottomInset: true,
    );
  }
}
