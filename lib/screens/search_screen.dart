import 'package:flutter/material.dart';
import '../services/spoonacular_service.dart';
import '../widgets/custom_button.dart';
import 'recipe_details_screen.dart';

class SearchScreen extends StatefulWidget {
  final List<String> ingredients;
  const SearchScreen({super.key, required this.ingredients});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _recipes = [];

  @override
  void initState() {
    super.initState();
    if (widget.ingredients.isNotEmpty) {
      _searchController.text = widget.ingredients.join(', ');
      _searchRecipes();
    }
  }

  Future<void> _searchRecipes() async {
    if (_searchController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some ingredients.')),
      );
      return;
    }
  
    setState(() {
      _isLoading = true;
      _recipes = [];
    });

    try {
      final recipes = await SpoonacularService.searchRecipesByIngredients(_searchController.text);
      if (!mounted) return;
      setState(() {
        _recipes = recipes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to search recipes: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Enter ingredients (e.g., chicken, tomatoes, pasta)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                CustomButton(
                  label: 'Search Recipes',
                  onPressed: _searchRecipes,
                  icon: const Icon(Icons.search),
                  backgroundColor: Theme.of(context).primaryColor,
                  textColor: Colors.white,
                  width: double.infinity,
                  height: 48,
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
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
                  'No recipes found. Try searching with different ingredients.',
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
