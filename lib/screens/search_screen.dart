import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../widgets/custom_button.dart';
import '../constants.dart';
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
  List<String> _recipes = [];

  @override
  void initState() {
    super.initState();
    if (widget.ingredients.isNotEmpty) {
      _searchController.text = widget.ingredients.join(', ');
      _generateRecipes();
    }
  }

  Future<void> _generateRecipes() async {
    if (_searchController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some ingredients.')),
      );
      return;
    }
  
    setState(() {
      _isLoading = true;
      _recipes = [];
    });

    final apiKey = dotenv.env[AppConstants.geminiApiKeyEnv];
    if (apiKey == null || apiKey.isEmpty || apiKey == AppConstants.apiKeyPlaceholder) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Key not found or not configured.')),
      );
      return;
    }

    final model = GenerativeModel(model: AppConstants.geminiModel, apiKey: apiKey);
    final prompt =
        'Generate 5 recipe names based on the following ingredients: ${_searchController.text}. Just give me the names, separated by newlines, and nothing else.';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text;

      if (text == null || text.trim().isEmpty) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No recipes were generated. Please try again.')),
          );
        }
        return;
      }

      setState(() {
        _recipes = text.split('\n')
            .where((recipe) => recipe.trim().isNotEmpty)
            .map((e) => e.replaceAll(RegExp(r'^\d+\.\s*'), '').trim())
            .where((recipe) => recipe.isNotEmpty)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate recipes: $e')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Recipe Search'),
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
                  label: 'Generate Recipes',
                  onPressed: _generateRecipes,
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
                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 10.0),
                    child: ListTile(
                      title: Text(_recipes[index]),
                      subtitle: const Text('AI generated recipe'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecipeDetailsScreen(
                              recipeName: _recipes[index],
                            ),
                          ),
                        );
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.favorite_border),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Added ${_recipes[index]} to favourites'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            )
          else
            const Expanded(
              child: Center(
                child: Text('Enter ingredients and search for recipes!'),
              ),
            ),
        ],
      ),
    );
  }
}
