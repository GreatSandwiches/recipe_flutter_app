import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../constants.dart';

class RecipeDetailsScreen extends StatefulWidget {
  final String recipeName;

  const RecipeDetailsScreen({super.key, required this.recipeName});

  @override
  State<RecipeDetailsScreen> createState() => _RecipeDetailsScreenState();
}

class _RecipeDetailsScreenState extends State<RecipeDetailsScreen> {
  bool _isLoading = true;
  String _recipeDetails = '';

  @override
  void initState() {
    super.initState();
    _generateRecipeDetails();
  }

  Future<void> _generateRecipeDetails() async {
    final apiKey = dotenv.env[AppConstants.geminiApiKeyEnv];
    if (apiKey == null || apiKey.isEmpty || apiKey == AppConstants.apiKeyPlaceholder) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _recipeDetails = 'API Key not found or not configured.';
        });
      }
      return;
    }

    final model = GenerativeModel(model: AppConstants.geminiModel, apiKey: apiKey);
    final prompt =
        'Generate a detailed recipe for \'${widget.recipeName}\'. Include a list of ingredients and step-by-step instructions. Format the ingredients with bullet points and the instructions with numbered steps.';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text;
      if (mounted) {
        setState(() {
          _recipeDetails = text ?? 'No recipe details found.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _recipeDetails = 'Failed to generate recipe details: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipeName),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: _buildRecipeContent(),
            ),
    );
  }

  Widget _buildRecipeContent() {
    if (_recipeDetails.isEmpty) {
      return const Center(child: Text('No recipe details found.'));
    }

    // Find the main sections of the recipe
    final ingredientsMatch = RegExp(r'Ingredients:([\s\S]*?)(Instructions:|Method:)', caseSensitive: false).firstMatch(_recipeDetails);
    final instructionsMatch = RegExp(r'(Instructions:|Method:)([\s\S]*)', caseSensitive: false).firstMatch(_recipeDetails);

    String ingredientsText = ingredientsMatch?.group(1)?.trim() ?? '';
    String instructionsText = instructionsMatch?.group(2)?.trim() ?? '';

    // If parsing fails, display the raw text
    if (ingredientsText.isEmpty && instructionsText.isEmpty) {
      return Text(_recipeDetails);
    }

    // Split the sections into individual lines
    List<String> ingredients = ingredientsText.split('\n').where((s) => s.trim().isNotEmpty).toList();
    List<String> instructions = instructionsText.split('\n').where((s) => s.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingredients',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8.0),
        ...ingredients.map((ingredient) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 16)),
                  Expanded(child: Text(ingredient.replaceAll(RegExp(r'^\s*[\*•-]\s*'), ''), style: const TextStyle(fontSize: 16))),
                ],
              ),
            )),
        const SizedBox(height: 24.0),
        Text(
          'Instructions',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8.0),
        ...instructions.asMap().entries.map((entry) {
          int idx = entry.key;
          String instruction = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${idx + 1}. ', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Expanded(child: Text(instruction.replaceAll(RegExp(r'^\s*\d+\.\s*'), ''), style: const TextStyle(fontSize: 16))),
              ],
            ),
          );
        }),
      ],
    );
  }
}
