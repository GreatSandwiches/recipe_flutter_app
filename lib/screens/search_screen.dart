import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/spoonacular_service.dart';
import 'recipe_details_screen.dart';
import '../providers/ingredients_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _recipes = [];

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
    if (ingProvider.ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some ingredients first.')),
      );
      return;
    }
    final query = ingProvider.ingredients.join(',');
    setState(() { _isLoading = true; _recipes = []; });
    try {
      final recipes = await SpoonacularService.searchRecipesByIngredients(query);
      if (!mounted) return;
      setState(() { _recipes = recipes; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to search recipes: $e')),
      );
    }
  }

  void _removeIngredient(String ing) async {
    final provider = context.read<IngredientsProvider>();
    await provider.remove(ing);
    if (!mounted) return;
    if (provider.ingredients.isNotEmpty) {
      _searchRecipes();
    } else {
      setState(() { _recipes = []; });
    }
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
              child: Text('No ingredients. Go back and add some to search.'),
            )
          else
            SizedBox(
              height: 74,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                FilledButton.icon(
                  onPressed: ingProvider.ingredients.isEmpty || _isLoading ? null : _searchRecipes,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
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
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        children: [
                          Text('Used ingredients: ${recipe['usedIngredientCount'] ?? 0}'),
                          Text('Missing ingredients: ${recipe['missedIngredientCount'] ?? 0}'),
                        ],
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
                  'No recipes found. Try adjusting ingredients.',
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
