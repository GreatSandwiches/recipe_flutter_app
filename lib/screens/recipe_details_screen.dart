import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/spoonacular_service.dart';
import '../providers/favourites_provider.dart';

class RecipeDetailsScreen extends StatefulWidget {
  final int recipeId;
  final String recipeName;

  const RecipeDetailsScreen({
    super.key, 
    required this.recipeId,
    required this.recipeName,
  });

  @override
  State<RecipeDetailsScreen> createState() => _RecipeDetailsScreenState();
}

class _RecipeDetailsScreenState extends State<RecipeDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _recipeData;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadRecipeDetails();
  }

  Future<void> _loadRecipeDetails() async {
    try {
      final recipeData = await SpoonacularService.getRecipeDetails(widget.recipeId);
      if (mounted) {
        setState(() {
          _recipeData = recipeData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load recipe details: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final favourites = context.watch<FavouritesProvider>();
    final isFav = favourites.isFavourite(widget.recipeId);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipeName),
        actions: [
          IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : null),
            onPressed: _recipeData == null && !isFav ? null : () {
              final data = _recipeData;
              favourites.toggle(
                FavouriteRecipe(
                  id: widget.recipeId,
                  title: widget.recipeName,
                  image: data!=null ? data['image'] : null,
                  readyInMinutes: data!=null ? data['readyInMinutes'] : null,
                ),
              );
            },
            tooltip: isFav ? 'Remove favourite' : 'Add to favourites',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildRecipeContent(),
                ),
    );
  }

  Widget _buildRecipeContent() {
    if (_recipeData == null) {
      return const Center(child: Text('No recipe data available'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recipe image
        if (_recipeData!['image'] != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _recipeData!['image'],
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: 200,
                  color: Colors.grey[300],
                  child: const Icon(Icons.restaurant, size: 64),
                );
              },
            ),
          ),
        
        const SizedBox(height: 16),
        
        // Recipe info
        Row(
          children: [
            if (_recipeData!['readyInMinutes'] != null)
              _buildInfoChip(
                Icons.timer,
                '${_recipeData!['readyInMinutes']} min',
              ),
            const SizedBox(width: 8),
            if (_recipeData!['servings'] != null)
              _buildInfoChip(
                Icons.people,
                '${_recipeData!['servings']} servings',
              ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Ingredients section
        const Text(
          'Ingredients',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        if (_recipeData!['extendedIngredients'] != null)
          ..._buildIngredientsList(),
        
        const SizedBox(height: 24),
        
        // Instructions section
        const Text(
          'Instructions',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        if (_recipeData!['analyzedInstructions'] != null && 
            _recipeData!['analyzedInstructions'].isNotEmpty)
          ..._buildInstructionsList()
        else if (_recipeData!['instructions'] != null)
          Text(
            _recipeData!['instructions'],
            style: const TextStyle(fontSize: 16, height: 1.5),
          )
        else
          const Text(
            'No instructions available for this recipe.',
            style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
          ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  List<Widget> _buildIngredientsList() {
    final ingredients = _recipeData!['extendedIngredients'] as List;
    return ingredients.map<Widget>((ingredient) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 8, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ingredient['original'] ?? ingredient['name'] ?? 'Unknown ingredient',
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildInstructionsList() {
    final instructions = _recipeData!['analyzedInstructions'] as List;
    if (instructions.isEmpty) return [];
    
    final steps = instructions[0]['steps'] as List;
    return steps.asMap().entries.map<Widget>((entry) {
      final index = entry.key;
      final step = entry.value;
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                step['step'] ?? '',
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
