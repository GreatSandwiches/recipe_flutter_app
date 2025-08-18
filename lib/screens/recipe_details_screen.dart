import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/spoonacular_service.dart';
import '../providers/favourites_provider.dart';
import '../services/ai_service.dart';

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
  // AI additions
  String? _aiSummary;
  String? _aiSubs;
  bool _loadingSummary = false;
  bool _loadingSubs = false;
  bool _asking = false;
  final TextEditingController _questionCtrl = TextEditingController();
  String? _answer;

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
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
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
        
        const SizedBox(height: 24),
        _buildAiSection(),
      ],
    );
  }

  Widget _buildAiSection() {
    final recipe = _recipeData!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AI Insights', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
            runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: _loadingSummary ? null : () async {
                setState(() { _loadingSummary = true; _aiSummary = null; });
                try { _aiSummary = await AiService.recipeSummary(recipe); } catch (e) { _aiSummary = 'Error: $e'; }
                if (mounted) setState(() { _loadingSummary = false; });
              },
              icon: const Icon(Icons.summarize),
              label: Text(_loadingSummary ? 'Loading...' : (_aiSummary==null ? 'Get Summary' : 'Refresh Summary')),
            ),
            ElevatedButton.icon(
              onPressed: _loadingSubs ? null : () async {
                setState(() { _loadingSubs = true; _aiSubs = null; });
                try { _aiSubs = await AiService.ingredientSubstitutions(recipe); } catch (e) { _aiSubs = 'Error: $e'; }
                if (mounted) setState(() { _loadingSubs = false; });
              },
              icon: const Icon(Icons.sync_alt),
              label: Text(_loadingSubs ? 'Loading...' : (_aiSubs==null ? 'Substitutions' : 'Refresh Substitutions')),
            ),
            ElevatedButton.icon(
              onPressed: () { _openAskDialog(recipe); },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Ask'),
            ),
          ],
        ),
        if (_aiSummary != null) ...[
          const SizedBox(height: 16),
          Text('Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700])),
          const SizedBox(height: 4),
          Text(_aiSummary!, style: const TextStyle(fontSize: 15, height: 1.4)),
        ],
        if (_aiSubs != null) ...[
          const SizedBox(height: 16),
          Text('Substitutions & Dietary Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700])),
          const SizedBox(height: 4),
          Text(_aiSubs!, style: const TextStyle(fontSize: 15, height: 1.4)),
        ],
        if (_answer != null) ...[
          const SizedBox(height: 16),
          Text('Answer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700])),
          const SizedBox(height: 4),
          Text(_answer!, style: const TextStyle(fontSize: 15, height: 1.4)),
        ],
      ],
    );
  }

  void _openAskDialog(Map<String, dynamic> recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Ask the AI Cooking Assistant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _questionCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'e.g. How can I make this spicier? Can I replace chicken with tofu?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _asking ? null : () async {
                      final q = _questionCtrl.text.trim();
                      if (q.isEmpty) return;
                      setState(() { _asking = true; _answer = null; });
                      try { _answer = await AiService.askCookingAssistant(q, recipe: recipe); } catch (e) { _answer = 'Error: $e'; }
                      if (mounted) setState(() { _asking = false; });
                      if (mounted) Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.send),
                    label: Text(_asking ? 'Asking...' : 'Ask'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
