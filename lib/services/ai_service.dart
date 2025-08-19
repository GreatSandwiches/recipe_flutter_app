import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  AiService._();
  static String? get _apiKey => dotenv.env['GEMINI_API_KEY'];

  static bool _isInvalidKey(String? key) => key == null || key.isEmpty || key.startsWith('YOUR_') || key.contains('GEMINI_API_KEY_HERE');

  static GenerativeModel _model() {
    final key = _apiKey;
    if (_isInvalidKey(key)) {
      throw Exception('Gemini API key not configured. Set GEMINI_API_KEY in .env and restart.');
    }
    return GenerativeModel(model: 'gemini-2.5-flash-lite', apiKey: key!);
  }

  static Future<String> recipeSummary(Map<String, dynamic> recipe) async {
    final name = recipe['title'] ?? 'this recipe';
    final ingredients = (recipe['extendedIngredients'] as List?)?.map((e) => e['original']).whereType<String>().take(30).join(', ');
    final steps = _collectSteps(recipe, max: 12);
    final prompt = 'Give a concise, friendly overview (max 90 words) of the recipe "$name". Key ingredients: $ingredients. Steps: $steps. Emphasize what makes it appealing and any dietary notes if obvious. Return plain text.';
    final response = await _model().generateContent([Content.text(prompt)]);
    return response.text?.trim() ?? 'No summary available.';
  }

  static Future<String> ingredientSubstitutions(Map<String, dynamic> recipe) async {
    final ingredients = (recipe['extendedIngredients'] as List?)?.map((e) => e['original']).whereType<String>().take(40).join('\n');
    final prompt = 'Given this ingredient list for a recipe, suggest smart substitutions for common dietary needs (VEGETARIAN, VEGAN, GLUTEN-FREE, DAIRY-FREE, LOW-COST) and cost-saving options. Return ONLY a clean bullet list where each line starts with "- " followed by an UPPERCASE label (single word or short phrase) then a colon and the suggestion(s). No markdown, no asterisks, no numbering, no headings. Keep each bullet under 140 characters. Avoid repeating identical ideas. Ingredients:\n$ingredients';
    final response = await _model().generateContent([Content.text(prompt)]);
    return response.text?.trim() ?? 'No suggestions available.';
  }

  static Future<String> askCookingAssistant(String question, {Map<String, dynamic>? recipe}) async {
    final ctx = recipe == null ? '' : 'Context recipe title: ${recipe['title']}. Key ingredients: ${(recipe['extendedIngredients'] as List?)?.map((e) => e['name']).whereType<String>().take(15).join(', ')}';
    final prompt = 'You are a helpful cooking assistant. $ctx\nUser question: "$question"\nReply in 1-3 short paragraphs (max 80 words each). No markdown lists or headings unless explicitly asked for a list. Plain text only.';
    final response = await _model().generateContent([Content.text(prompt)]);
    return response.text?.trim() ?? 'No answer.';
  }

  static String _collectSteps(Map<String, dynamic> recipe, {int max = 10}) {
    final ai = recipe['analyzedInstructions'];
    if (ai is List && ai.isNotEmpty) {
      final steps = ai.first['steps'];
      if (steps is List) {
        return steps.take(max).map((s) => s['step']).whereType<String>().join(' ');
      }
    }
    final raw = recipe['instructions'];
    if (raw is String) return raw.split(RegExp(r'(?<=[.!?])')).take(max).join(' ');
    return '';
  }
}
