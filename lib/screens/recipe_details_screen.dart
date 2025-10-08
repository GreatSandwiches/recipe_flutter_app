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

class _MacroData {
  const _MacroData({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final double value;
  final String unit;
  final Color color;
}

class _DailyNeedItem {
  const _DailyNeedItem({
    required this.title,
    required this.amount,
    required this.percent,
  });

  final String title;
  final String amount;
  final double percent;
}

class _CostIngredient {
  const _CostIngredient({required this.name, required this.price, this.amount});

  final String name;
  final double price;
  final String? amount;
}

class _AmountParts {
  const _AmountParts(this.value, this.unit);

  final double value;
  final String unit;
}

class _MacroGauge extends StatelessWidget {
  const _MacroGauge({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.maxValue,
  });

  final String label;
  final double value;
  final String unit;
  final Color color;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final clamped = maxValue <= 0
        ? 0.0
        : (value / maxValue).clamp(0.0, 1.0).toDouble();
    final valueLabel = value % 1 == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 110,
          width: 110,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: clamped),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) {
              final scheme = Theme.of(context).colorScheme;
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 104,
                    width: 104,
                    child: CircularProgressIndicator(
                      strokeWidth: 10,
                      value: progress,
                      backgroundColor: color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          valueLabel,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ) ??
                              TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                        ),
                        Text(
                          unit,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ) ??
                              TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _DailyNeedsList extends StatelessWidget {
  const _DailyNeedsList({
    required this.label,
    required this.color,
    required this.items,
  });

  final String label;
  final Color color;
  final List<_DailyNeedItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(color: color),
          ),
          const SizedBox(height: 8),
          Text(
            'No highlights yet',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall?.copyWith(color: color)),
        const SizedBox(height: 8),
        ...items.map((item) {
          final percent = (item.percent / 100).clamp(0.0, 1.0).toDouble();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${item.percent.toStringAsFixed(0)}%',
                      style: theme.textTheme.bodySmall?.copyWith(color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: percent,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                if (item.amount.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.amount,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _CostBigNumber extends StatelessWidget {
  const _CostBigNumber({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style:
                theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ) ??
                TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientCostBar extends StatelessWidget {
  const _IngredientCostBar({
    required this.name,
    required this.price,
    required this.share,
    this.amount,
  });

  final String name;
  final double price;
  final double share;
  final String? amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayPrice = '\$${(price / 100).toStringAsFixed(2)}';
    final percentLabel = share > 0 ? '${(share * 100).round()}%' : 'N/A';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(displayPrice, style: theme.textTheme.bodyMedium),
              const SizedBox(width: 8),
              Text(
                percentLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0,
              end: share.clamp(0.0, 1.0).toDouble(),
            ),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: value,
                  backgroundColor: scheme.primary.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              );
            },
          ),
          if (amount != null) ...[
            const SizedBox(height: 4),
            Text(
              amount!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecipeDetailsScreenState extends State<RecipeDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _recipeData;
  Map<String, dynamic>? _nutritionData;
  Map<String, dynamic>? _costData;
  String _errorMessage = '';
  String? _nutritionError;
  String? _costError;
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
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _nutritionError = null;
      _costError = null;
    });

    final nutritionFuture = SpoonacularService.getRecipeNutritionWidget(
      widget.recipeId,
    );
    final costFuture = SpoonacularService.getRecipeCostBreakdown(
      widget.recipeId,
    );

    try {
      final recipeData = await SpoonacularService.getRecipeDetails(
        widget.recipeId,
      );
      final normalized = Map<String, dynamic>.from(recipeData);
      final refined = deriveReadyInMinutes(normalized);
      if (refined != null) {
        normalized['readyInMinutes'] = refined;
      }

      Map<String, dynamic>? nutrition;
      Map<String, dynamic>? cost;
      String? nutritionError;
      String? costError;

      try {
        nutrition = await nutritionFuture;
      } catch (e) {
        nutrition = null;
        nutritionError = 'Unable to load nutrition info: $e';
      }

      try {
        cost = await costFuture;
      } catch (e) {
        cost = null;
        costError = 'Unable to load cost breakdown: $e';
      }

      if (mounted) {
        setState(() {
          _recipeData = normalized;
          _nutritionData = nutrition;
          _costData = cost;
          _nutritionError = nutritionError;
          _costError = costError;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load recipe details: $e';
          _nutritionData = null;
          _costData = null;
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
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.red : null,
            ),
            onPressed: _recipeData == null && !isFav
                ? null
                : () {
                    final data = _recipeData;
                    favourites.toggle(
                      FavouriteRecipe(
                        id: widget.recipeId,
                        title: widget.recipeName,
                        image: data != null ? data['image'] : null,
                        readyInMinutes: data != null
                            ? data['readyInMinutes']
                            : null,
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

        ..._buildNutritionSection(),
        ..._buildCostSection(),

        if (_nutritionData != null || _costData != null)
          const SizedBox(height: 16),

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

  List<Widget> _buildNutritionSection() {
    final data = _nutritionData;
    if (data == null) {
      if (_nutritionError == null) {
        return const [];
      }
      return [
        _buildSectionTitle(Icons.local_fire_department, 'Nutrition Highlights'),
        const SizedBox(height: 8),
        Text(
          _nutritionError!,
          style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 24),
      ];
    }

    final macros = _extractMacros(data);
    if (macros.isEmpty) {
      return const [];
    }

    final maxMacro = macros
        .map((m) => m.value)
        .fold<double>(0, (prev, element) => element > prev ? element : prev);
    final good = _topDailyNeeds(data['good']);
    final bad = _topDailyNeeds(data['bad']);

    return [
      _buildSectionTitle(Icons.local_fire_department, 'Nutrition Highlights'),
      const SizedBox(height: 12),
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 420;
              final itemsPerRow = isWide ? macros.length : 2;
              final rawWidth =
                  constraints.maxWidth / itemsPerRow -
                  (itemsPerRow > 1 ? 12 : 0);
              final tileWidth = rawWidth.clamp(120.0, 160.0).toDouble();
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.spaceEvenly,
                children: macros
                    .map(
                      (macro) => SizedBox(
                        width: tileWidth,
                        child: _MacroGauge(
                          label: macro.label,
                          value: macro.value,
                          unit: macro.unit,
                          color: macro.color,
                          maxValue: maxMacro == 0 ? 1 : maxMacro,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
      ),
      if (good.isNotEmpty || bad.isNotEmpty) ...[
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Impact',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _DailyNeedsList(
                        label: 'Boosts',
                        color: Colors.teal,
                        items: good,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DailyNeedsList(
                        label: 'Watch out',
                        color: Colors.deepOrange,
                        items: bad,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildCostSection() {
    final data = _costData;
    if (data == null) {
      if (_costError == null) {
        return const [];
      }
      return [
        _buildSectionTitle(Icons.attach_money, 'Estimated Cost'),
        const SizedBox(height: 8),
        Text(
          _costError!,
          style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 24),
      ];
    }

    final totalCost = _asDouble(data['totalCost']);
    final costPerServing = _asDouble(data['totalCostPerServing']);
    final servings = _recipeData != null
        ? _asInt(_recipeData!['servings'])
        : null;
    final ingredients = _extractCostIngredients(data);

    return [
      _buildSectionTitle(Icons.attach_money, 'Estimated Cost'),
      const SizedBox(height: 12),
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  _CostBigNumber(
                    label: 'Per serving',
                    value: _formatCost(costPerServing),
                  ),
                  _CostBigNumber(
                    label:
                        'Total${servings != null ? ' ($servings servings)' : ''}',
                    value: _formatCost(totalCost),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (ingredients.isNotEmpty)
                Text(
                  'Cost breakdown',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ...ingredients.map(
                (item) => _IngredientCostBar(
                  name: item.name,
                  amount: item.amount,
                  price: item.price,
                  share: totalCost != null && totalCost > 0
                      ? ((item.price / totalCost).clamp(0.0, 1.0)).toDouble()
                      : 0.0,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  List<_MacroData> _extractMacros(Map<String, dynamic> data) {
    final pairs = <String, dynamic>{
      'Calories': data['calories'],
      'Protein': data['protein'],
      'Carbs': data['carbs'],
      'Fat': data['fat'],
    };
    final colors = {
      'Calories': Colors.deepOrange,
      'Protein': Colors.lightBlue,
      'Carbs': Colors.lightGreen,
      'Fat': Colors.pinkAccent,
    };

    final macros = <_MacroData>[];
    pairs.forEach((label, raw) {
      final parts = _amountParts(raw);
      if (parts == null || parts.value <= 0) return;
      macros.add(
        _MacroData(
          label: label,
          value: parts.value,
          unit: parts.unit.isEmpty && label == 'Calories' ? 'kcal' : parts.unit,
          color: colors[label] ?? Theme.of(context).colorScheme.primary,
        ),
      );
    });

    return macros;
  }

  List<_DailyNeedItem> _topDailyNeeds(dynamic source) {
    if (source is! List) return <_DailyNeedItem>[];
    final items = <_DailyNeedItem>[];
    for (final entry in source) {
      if (entry is! Map<String, dynamic>) continue;
      final percent = _asDouble(entry['percentOfDailyNeeds']);
      if (percent == null || percent <= 0) continue;
      final title = entry['title']?.toString();
      if (title == null || title.isEmpty) continue;
      final amount = entry['amount']?.toString() ?? '';
      items.add(_DailyNeedItem(title: title, amount: amount, percent: percent));
    }
    items.sort((a, b) => b.percent.compareTo(a.percent));
    return items.take(3).toList();
  }

  List<_CostIngredient> _extractCostIngredients(Map<String, dynamic> data) {
    final rawIngredients = data['ingredients'];
    if (rawIngredients is! List) return <_CostIngredient>[];
    final results = <_CostIngredient>[];
    for (final entry in rawIngredients) {
      if (entry is! Map<String, dynamic>) continue;
      final name = entry['name']?.toString();
      if (name == null || name.isEmpty) continue;
      final price = _asDouble(entry['price']);
      if (price == null || price <= 0) continue;
      final amount = _formatIngredientAmount(entry['amount']);
      results.add(_CostIngredient(name: name, price: price, amount: amount));
    }
    results.sort((a, b) => b.price.compareTo(a.price));
    return results.take(5).toList();
  }

  _AmountParts? _amountParts(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) {
      return _AmountParts(raw.toDouble(), '');
    }
    if (raw is String) {
      final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(raw);
      if (match != null) {
        final value = double.tryParse(match.group(1)!);
        if (value == null) return null;
        final unit = raw.replaceFirst(match.group(0)!, '').trim();
        return _AmountParts(value, unit);
      }
    }
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _formatCost(double? cents) {
    if (cents == null) return 'N/A';
    final dollars = cents / 100;
    return '\$${dollars.toStringAsFixed(2)}';
  }

  String? _formatIngredientAmount(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final metric = raw['metric'];
      if (metric is Map<String, dynamic>) {
        final value = _asDouble(metric['value']);
        final unit = metric['unit']?.toString() ?? '';
        if (value != null) {
          final valueStr = value % 1 == 0
              ? value.toStringAsFixed(0)
              : value.toStringAsFixed(1);
          return unit.isEmpty ? valueStr : '$valueStr $unit';
        }
      }
    }
    return null;
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
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
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
                          const Text(
                            'AI Insights',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                                _buildAiTabChip(
                                  sheetSetState,
                                  index: 0,
                                  label: 'Summary',
                                ),
                                _buildAiTabChip(
                                  sheetSetState,
                                  index: 1,
                                  label: 'Substitutions',
                                ),
                                _buildAiTabChip(
                                  sheetSetState,
                                  index: 2,
                                  label: 'Q&A',
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_aiTabIndex == 0)
                              ..._buildSummaryTabContent(sheetSetState, recipe)
                            else if (_aiTabIndex == 1)
                              ..._buildSubsTabContent(sheetSetState, recipe)
                            else
                              ..._buildQATabContent(sheetSetState, recipe),
                            const SizedBox(height: 24),
                            Text(
                              'AI suggestions may be imperfect. Always follow food safety best practices.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
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

  Widget _buildAiTabChip(
    StateSetter sheetSetState, {
    required int index,
    required String label,
  }) {
    final selected = _aiTabIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => sheetSetState(() {
        _aiTabIndex = index;
      }),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: selected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  List<Widget> _buildSummaryTabContent(
    StateSetter sheetSetState,
    Map<String, dynamic> recipe,
  ) {
    return [
      Row(
        children: [
          ElevatedButton.icon(
            onPressed: _loadingSummary
                ? null
                : () async {
                    sheetSetState(() {
                      _loadingSummary = true;
                      if (_aiSummary == null) _aiTabIndex = 0;
                    });
                    try {
                      _aiSummary = await AiService.recipeSummary(recipe);
                    } catch (e) {
                      _aiSummary = 'Error: $e';
                    }
                    if (mounted) {
                      sheetSetState(() {
                        _loadingSummary = false;
                      });
                    }
                  },
            icon: const Icon(Icons.summarize),
            label: Text(
              _loadingSummary
                  ? 'Loading...'
                  : (_aiSummary == null
                        ? 'Generate Summary'
                        : 'Refresh Summary'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (_aiSummary == null && !_loadingSummary)
        Text(
          'Tap "Generate Summary" to create a concise overview.',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        )
      else if (_aiSummary != null)
        ..._buildSummaryParagraphs(_aiSummary!),
    ];
  }

  List<Widget> _buildSubsTabContent(
    StateSetter sheetSetState,
    Map<String, dynamic> recipe,
  ) {
    return [
      Row(
        children: [
          ElevatedButton.icon(
            onPressed: _loadingSubs
                ? null
                : () async {
                    sheetSetState(() {
                      _loadingSubs = true;
                      if (_aiSubs == null) _aiTabIndex = 1;
                    });
                    try {
                      _aiSubs = await AiService.ingredientSubstitutions(recipe);
                    } catch (e) {
                      _aiSubs = 'Error: $e';
                    }
                    if (mounted) {
                      sheetSetState(() {
                        _loadingSubs = false;
                      });
                    }
                  },
            icon: const Icon(Icons.sync_alt),
            label: Text(
              _loadingSubs
                  ? 'Loading...'
                  : (_aiSubs == null
                        ? 'Generate Substitutions'
                        : 'Refresh Substitutions'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (_aiSubs == null && !_loadingSubs)
        Text(
          'Tap "Generate Substitutions" for dietary & cost-saving ideas.',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        )
      else if (_aiSubs != null)
        ..._buildSubstitutionChips(_aiSubs!),
    ];
  }

  List<Widget> _buildQATabContent(
    StateSetter sheetSetState,
    Map<String, dynamic> recipe,
  ) {
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
          onPressed: _asking
              ? null
              : () async {
                  final q = _questionCtrl.text.trim();
                  if (q.isEmpty) return;
                  sheetSetState(() {
                    _asking = true;
                    _answer = null;
                  });
                  try {
                    _answer = await AiService.askCookingAssistant(
                      q,
                      recipe: recipe,
                    );
                  } catch (e) {
                    _answer = 'Error: $e';
                  }
                  if (mounted) {
                    sheetSetState(() {
                      _asking = false;
                    });
                  }
                },
          icon: const Icon(Icons.send),
          label: Text(_asking ? 'Asking...' : 'Send'),
        ),
      ),
      const SizedBox(height: 12),
      if (_answer == null && !_asking)
        Text(
          'Type a question and press Send to get help.',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        )
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
    final fg = isMade
        ? scheme.onPrimaryContainer
        : (isDark ? scheme.onSurface : scheme.onSurfaceVariant);

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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from Dishes Made')),
          );
        } else {
          await dishes.markMade(
            recipeId: widget.recipeId,
            title: widget.recipeName,
            image: data['image'],
          );
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Marked as made!')));
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
                  child: ScaleTransition(
                    scale: Tween(begin: 0.9, end: 1.0).animate(anim),
                    child: child,
                  ),
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
                ingredient['original'] ??
                    ingredient['name'] ??
                    'Unknown ingredient',
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
    final paras = cleaned
        .split(RegExp(r'\n{2,}'))
        .expand((p) {
          if (p.length > 260) {
            // further split long paragraphs on sentences
            return p.split(RegExp(r'(?<=[.!?])\s+'));
          }
          return [p];
        })
        .where((p) => p.trim().isNotEmpty)
        .toList();
    return paras
        .map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              p.trim(),
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
          ),
        )
        .toList();
  }

  List<Widget> _buildSubstitutionChips(String raw) {
    final lines = raw
        .split('\n')
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
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: const TextStyle(fontSize: 13, height: 1.3),
                    ),
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
