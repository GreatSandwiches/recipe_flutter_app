import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/spoonacular_service.dart';
import '../providers/favourites_provider.dart';
import '../services/ai_service.dart';
import '../providers/dishes_provider.dart';
import '../utils/recipe_time_utils.dart';

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
  int _aiTabIndex = 0; // track selected AI result tab

  @override
  void initState() {
    super.initState();
    _loadRecipeDetails();
  }

  Future<void> _loadRecipeDetails() async {
    try {
      final recipeData = await SpoonacularService.getRecipeDetails(
        widget.recipeId,
      );
      final normalized = Map<String, dynamic>.from(recipeData);
      final refined = deriveReadyInMinutes(normalized);
      if (refined != null) {
        normalized['readyInMinutes'] = refined;
      }
      if (mounted) {
        setState(() {
          _recipeData = normalized;
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
      floatingActionButton: _recipeData == null
          ? null
          : FloatingActionButton(
              heroTag: 'ai_btn',
              onPressed: _openAiOverlay,
              tooltip: 'AI Insights',
              child: const Icon(Icons.smart_toy),
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_recipeData!['readyInMinutes'] != null)
              _buildInfoChip(
                Icons.timer,
                '${_recipeData!['readyInMinutes']} min',
              ),
            if (_recipeData!['servings'] != null)
              _buildInfoChip(
                Icons.people,
                '${_recipeData!['servings']} servings',
              ),
            _buildMarkMadeChip(),
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

  void _openAiOverlay() {
    final recipe = _recipeData;
    if (recipe == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, sheetSetState) {
            final bottom = MediaQuery.of(ctx).viewInsets.bottom;
            return AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.only(bottom: bottom),
              child: Container(
                height: MediaQuery.of(ctx).size.height * 0.65,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(Icons.smart_toy, size: 22),
                          const SizedBox(width: 8),
                          const Text('AI Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tabs (always 3)
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                _buildAiTabChip(sheetSetState, index: 0, label: 'Summary'),
                                _buildAiTabChip(sheetSetState, index: 1, label: 'Substitutions'),
                                _buildAiTabChip(sheetSetState, index: 2, label: 'Q&A'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_aiTabIndex == 0) ..._buildSummaryTabContent(sheetSetState, recipe) else if (_aiTabIndex == 1) ..._buildSubsTabContent(sheetSetState, recipe) else ..._buildQATabContent(sheetSetState, recipe),
                            const SizedBox(height: 24),
                            Text(
                              'AI suggestions may be imperfect. Always follow food safety best practices.',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAiTabChip(StateSetter sheetSetState, {required int index, required String label}) {
    final selected = _aiTabIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => sheetSetState(() { _aiTabIndex = index; }),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: selected ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  List<Widget> _buildSummaryTabContent(StateSetter sheetSetState, Map<String, dynamic> recipe) {
    return [
      Row(
        children: [
          ElevatedButton.icon(
            onPressed: _loadingSummary ? null : () async {
              sheetSetState(() { _loadingSummary = true; if (_aiSummary == null) _aiTabIndex = 0; });
              try { _aiSummary = await AiService.recipeSummary(recipe); } catch (e) { _aiSummary = 'Error: $e'; }
              if (mounted) sheetSetState(() { _loadingSummary = false; });
            },
            icon: const Icon(Icons.summarize),
            label: Text(_loadingSummary ? 'Loading...' : (_aiSummary==null ? 'Generate Summary' : 'Refresh Summary')),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (_aiSummary == null && !_loadingSummary)
        Text('Tap "Generate Summary" to create a concise overview.', style: TextStyle(color: Colors.grey[600], fontSize: 14))
      else if (_aiSummary != null)
        ..._buildSummaryParagraphs(_aiSummary!),
    ];
  }

  List<Widget> _buildSubsTabContent(StateSetter sheetSetState, Map<String, dynamic> recipe) {
    return [
      Row(
        children: [
          ElevatedButton.icon(
            onPressed: _loadingSubs ? null : () async {
              sheetSetState(() { _loadingSubs = true; if (_aiSubs == null) _aiTabIndex = 1; });
              try { _aiSubs = await AiService.ingredientSubstitutions(recipe); } catch (e) { _aiSubs = 'Error: $e'; }
              if (mounted) sheetSetState(() { _loadingSubs = false; });
            },
            icon: const Icon(Icons.sync_alt),
            label: Text(_loadingSubs ? 'Loading...' : (_aiSubs==null ? 'Generate Substitutions' : 'Refresh Substitutions')),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (_aiSubs == null && !_loadingSubs)
        Text('Tap "Generate Substitutions" for dietary & cost-saving ideas.', style: TextStyle(color: Colors.grey[600], fontSize: 14))
      else if (_aiSubs != null)
        ..._buildSubstitutionChips(_aiSubs!),
    ];
  }

  List<Widget> _buildQATabContent(StateSetter sheetSetState, Map<String, dynamic> recipe) {
    return [
      TextField(
        controller: _questionCtrl,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Ask a cooking question about this recipe...',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: ElevatedButton.icon(
          onPressed: _asking ? null : () async {
            final q = _questionCtrl.text.trim();
            if (q.isEmpty) return;
            sheetSetState(() { _asking = true; _answer = null; });
            try { _answer = await AiService.askCookingAssistant(q, recipe: recipe); } catch (e) { _answer = 'Error: $e'; }
            if (mounted) sheetSetState(() { _asking = false; });
          },
          icon: const Icon(Icons.send),
          label: Text(_asking ? 'Asking...' : 'Send'),
        ),
      ),
      const SizedBox(height: 12),
      if (_answer == null && !_asking)
        Text('Type a question and press Send to get help.', style: TextStyle(color: Colors.grey[600], fontSize: 14))
      else if (_answer != null)
        ..._buildSummaryParagraphs(_answer!),
    ];
  }

  Widget _buildInfoChip(IconData icon, String text) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
        : scheme.surfaceContainerHighest; // lighter in light mode
    final border = scheme.outlineVariant.withValues(alpha: isDark ? 0.6 : 0.4);
    final foreground = isDark ? scheme.onSurface : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: foreground,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkMadeChip() {
    final dishes = context.watch<DishesProvider>();
    final isMade = dishes.isMade(widget.recipeId);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = scheme.primaryContainer;
    final inactiveColor = isDark
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
        : scheme.surfaceContainerHighest;
    final border = scheme.outlineVariant.withValues(alpha: isDark ? 0.6 : 0.4);
    final fg = isMade ? scheme.onPrimaryContainer : (isDark ? scheme.onSurface : scheme.onSurfaceVariant);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      splashColor: scheme.primary.withValues(alpha: 0.10),
      highlightColor: Colors.transparent,
      onTap: () async {
        final data = _recipeData;
        if (data == null) return;
        if (isMade) {
          await dishes.remove(widget.recipeId);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from Dishes Made')));
        } else {
          await dishes.markMade(
            recipeId: widget.recipeId,
            title: widget.recipeName,
            image: data['image'],
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Marked as made!')),
          );
        }
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: isMade ? 1.02 : 1.0),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        builder: (context, scale, child) => Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isMade ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 140),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(anim), child: child),
                ),
                child: Icon(
                  isMade ? Icons.check_box : Icons.check_box_outline_blank,
                  key: ValueKey<bool>(isMade),
                  size: 18,
                  color: fg,
                ),
              ),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 140),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isMade ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                  letterSpacing: 0.2,
                ),
                child: const Text('Mark as Made'),
              ),
            ],
          ),
        ),
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

  List<Widget> _buildSummaryParagraphs(String text) {
    final cleaned = text.replaceAll(RegExp(r'[\*_`#]'), '').trim();
    final paras = cleaned.split(RegExp(r'\n{2,}')).expand((p) {
      if (p.length > 260) {
        // further split long paragraphs on sentences
        return p.split(RegExp(r'(?<=[.!?])\s+'));
      }
      return [p];
    }).where((p) => p.trim().isNotEmpty).toList();
    return paras.map((p) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(p.trim(), style: const TextStyle(fontSize: 15, height: 1.4)),
    )).toList();
  }

  List<Widget> _buildSubstitutionChips(String raw) {
    final lines = raw.split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('- '))
        .map((l) => l.substring(2))
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return [Text(raw, style: const TextStyle(fontSize: 15, height: 1.4))];
    }
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: lines.map((line) {
          String label = line;
          String detail = '';
            final idx = line.indexOf(':');
            if (idx != -1) {
              label = line.substring(0, idx).trim();
              detail = line.substring(idx + 1).trim();
            }
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(detail, style: const TextStyle(fontSize: 13, height: 1.3)),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    ];
  }
}
