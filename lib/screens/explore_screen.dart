import 'package:flutter/material.dart';
import '../services/spoonacular_service.dart';
import 'recipe_details_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _featuredRecipes = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadFeaturedRecipes();
  }

  Future<void> _loadFeaturedRecipes() async {
    try {
      // Search for popular recipes
      final recipes = await SpoonacularService.searchRecipes('popular');
      if (mounted) {
        setState(() {
          _featuredRecipes = recipes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load featured recipes: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadFeaturedRecipes,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFeaturedRecipes,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Featured Recipes',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Discover delicious recipes from around the world',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildRecipeGrid(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildRecipeGrid() {
    if (_featuredRecipes.isEmpty) {
      return const Center(
        child: Text(
          'No recipes available at the moment.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: _featuredRecipes.length,
      itemBuilder: (context, index) {
        final recipe = _featuredRecipes[index];
        return _buildRecipeCard(recipe);
      },
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    return GestureDetector(
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
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: recipe['image'] != null
                    ? Image.network(
                        recipe['image'],
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.restaurant,
                              size: 48,
                              color: Colors.grey,
                            ),
                          );
                        },
                      )
                    : Container(
                        width: double.infinity,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.restaurant,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe['title'] ?? 'Unknown Recipe',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    if (recipe['readyInMinutes'] != null)
                      Row(
                        children: [
                          const Icon(Icons.timer, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe['readyInMinutes']} min',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
