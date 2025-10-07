import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe_search_options.dart';
import '../providers/ingredients_provider.dart';
import '../services/spoonacular_service.dart';
import '../utils/recipe_filter_utils.dart';
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

  @override
  void initState() {
    super.initState();
    _filters = normaliseRecipeSearchOptions(
      widget.initialFilters ?? kDefaultRecipeFilters,
    );
    if (widget.initialKeyword != null && widget.initialKeyword!.isNotEmpty) {
      _keywordController.text = widget.initialKeyword!;
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
    });
    try {
      final options = _filters.copyWith(
        includeIngredients: ingredients,
        query: keyword.isEmpty ? null : keyword,
        offset: 0,
      );

      late RecipeSearchResponse response;

      if (ingredients.isNotEmpty) {
        response = await SpoonacularService.searchRecipesByIngredients(
          ingredients,
          options: options,
        );
      } else {
        response = await SpoonacularService.complexSearch(options);
      }
      final recipes = response.results;
      if (!mounted) return;
      setState(() {
        _recipes = recipes;
        _isLoading = false;
        _lastResponse = response;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
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
