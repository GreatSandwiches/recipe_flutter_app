import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../widgets/custom_button.dart';
import 'settings_screen.dart';
import 'search_screen.dart';
import '../providers/ingredients_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _inputWrapperFocus = FocusNode();
  List<String> _suggestions = [];
  int _highlightIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
  }

  void _handleTextChanged() {
    final provider = context.read<IngredientsProvider>();
    _updateSuggestions(provider);
    setState(() {}); // for suffix + suggestions
  }

  void _updateSuggestions(IngredientsProvider provider) {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      _suggestions = provider.suggestions('');
    } else {
      _suggestions = provider
          .suggestions(raw)
          .where((s) => !provider.ingredients.contains(s))
          .toList();
    }
    if (_suggestions.isEmpty) {
      _highlightIndex = -1;
    } else if (_highlightIndex >= _suggestions.length) {
      _highlightIndex = -1;
    }
  }

  void _commitCurrent(IngredientsProvider provider) {
    _submitInput(provider);
  }

  void _selectSuggestion(IngredientsProvider provider, String s) {
    _controller.text = s;
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: s.length));
    _commitCurrent(provider);
  }

  bool _handleKey(KeyEvent e, IngredientsProvider provider) {
    if (e is! KeyDownEvent) return false;
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_suggestions.isNotEmpty) {
        setState(() { _highlightIndex = (_highlightIndex + 1) % _suggestions.length; });
        return true;
      }
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (_suggestions.isNotEmpty) {
        setState(() { _highlightIndex = (_highlightIndex - 1); if (_highlightIndex < 0) _highlightIndex = _suggestions.length - 1; });
        return true;
      }
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (_highlightIndex >= 0 && _highlightIndex < _suggestions.length) {
        _selectSuggestion(provider, _suggestions[_highlightIndex]);
        return true;
      }
      _commitCurrent(provider);
      return true;
    } else if (key == LogicalKeyboardKey.comma || key.keyLabel == ',' || key == LogicalKeyboardKey.semicolon) {
      _commitCurrent(provider);
      return true;
    } else if (key == LogicalKeyboardKey.escape) {
      if (_controller.text.isNotEmpty) {
        _controller.clear();
        return true;
      }
    } else if (key == LogicalKeyboardKey.tab && _highlightIndex >= 0 && _highlightIndex < _suggestions.length) {
      _selectSuggestion(provider, _suggestions[_highlightIndex]);
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _inputWrapperFocus.dispose();
    super.dispose();
  }

  void _submitInput(IngredientsProvider provider) async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;
    final parts = raw.split(RegExp(r'[\n,;]')).map((e) => e.trim()).where((e) => e.isNotEmpty);
    _controller.clear();
    final count = await provider.addMany(parts);
    if (!mounted) return;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No new ingredients added')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $count ingredient${count==1?'':'s'}')));
    }
    _updateSuggestions(provider);
    _focusNode.requestFocus();
    setState(() {});
  }

  void _removeIngredient(IngredientsProvider provider, String ingredient) async {
    await provider.remove(ingredient);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed $ingredient'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            await provider.add(ingredient);
          },
        ),
      ),
    );
  }

  void _clearAll(IngredientsProvider provider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear all ingredients?'),
        content: const Text('This will remove every ingredient you\'ve added.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) {
      await provider.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingredients cleared')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<IngredientsProvider>();
    final isDark = theme.brightness == Brightness.dark;
    _updateSuggestions(provider);
    final rawInput = _controller.text.trim();
    final preview = rawInput.isEmpty ? null : provider.parsePreview(rawInput);
    final showPreview = preview != null && preview.name.isNotEmpty && preview.name != rawInput.toLowerCase();
    final surfaceFill = isDark 
      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
      : theme.colorScheme.surfaceContainerHighest;
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(left: 20.0),
          child: Builder(builder: (context) {
            final hour = DateTime.now().hour;
            late final IconData timeIcon;
            late final String greeting;
            if (hour < 12) {
              timeIcon = Icons.wb_sunny;
              greeting = 'Good morning';
            } else if (hour < 17) {
              timeIcon = Icons.wb_cloudy;
              greeting = 'Good afternoon';
            } else {
              timeIcon = Icons.nights_stay;
              greeting = 'Good evening';
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(timeIcon, size: 16),
                    const SizedBox(width: 6),
                    Text(greeting, style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const Text('Calum Taylor'),
              ],
            );
          }),
        ),
        centerTitle: false,
        actions: [
          if (provider.ingredients.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              onPressed: () => _clearAll(provider),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: KeyboardListener(
              focusNode: _inputWrapperFocus,
              onKeyEvent: (evt) { _handleKey(evt, provider); },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submitInput(provider),
                    decoration: InputDecoration(
                      hintText: 'Add ingredient (comma / enter to add, #tag supported)',
                      prefixIcon: Icon(Icons.kitchen_outlined, color: theme.colorScheme.primary),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_controller.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: 'Clear',
                              onPressed: () { _controller.clear(); _updateSuggestions(provider); setState(() {}); },
                            ),
                          if (_controller.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.send),
                              tooltip: 'Add',
                              onPressed: () => _submitInput(provider),
                            ),
                        ],
                      ),
                      filled: true,
                      fillColor: surfaceFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    onChanged: (_) {},
                  ),
                  if (showPreview) ...[
                    const SizedBox(height: 6),
                    Builder(builder: (_) {
                      final p = preview; // ensured non-null by showPreview
                      if (p == null) return const SizedBox.shrink();
                      String? qPart;
                      final min = p.quantityMin;
                      final max = p.quantityMax;
                      if (min != null && max != null) {
                        if (min == max) {
                          final isInt = min % 1 == 0;
                          qPart = isInt ? min.toStringAsFixed(0) : min.toStringAsFixed(2);
                        } else {
                          qPart = '${min}-${max}';
                        }
                      }
                      final unitPart = p.unit != null ? ' ${p.unit}' : '';
                      final qty = qPart != null ? '$qPart$unitPart ' : '';
                      final tagsPart = p.tags.isNotEmpty ? '  tags: ${p.tags.join(', ')}' : '';
                      return Text(
                        'Parsed as: $qty${p.name}$tagsPart',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.secondary),
                      );
                    }),
                  ],
                  if (_suggestions.isNotEmpty && _controller.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Material(
                      elevation: 3,
                      borderRadius: BorderRadius.circular(8),
                      color: theme.colorScheme.surface,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          itemBuilder: (c,i){
                            final s = _suggestions[i];
                            final highlighted = i == _highlightIndex;
                            return InkWell(
                              borderRadius: i==0? const BorderRadius.vertical(top: Radius.circular(8)) : (i==_suggestions.length-1? const BorderRadius.vertical(bottom: Radius.circular(8)) : BorderRadius.zero),
                              onTap: ()=> _selectSuggestion(provider, s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: highlighted ? BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.08)) : null,
                                child: Row(
                                  children: [
                                    const Icon(Icons.add, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(s, style: TextStyle(fontWeight: highlighted? FontWeight.w600: null))),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (provider.ingredients.isNotEmpty)
            SizedBox(
              height: 90,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                children: [
                  const SizedBox(width: 4),
                  for (final ing in provider.ingredients)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InputChip(
                        label: Text(ing),
                        onDeleted: () => _removeIngredient(provider, ing),
                        deleteIcon: const Icon(Icons.close, size: 18),
                      ),
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          Expanded(
            child: provider.ingredients.isEmpty
                ? const Center(child: Text('No ingredients added yet.'))
                : ListView.builder(
                    itemCount: provider.ingredients.length,
                    itemBuilder: (context, index) {
                      final ing = provider.ingredients[index];
                      return Dismissible(
                        key: ValueKey(ing),
                        background: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 24),
                          child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
                        ),
                        secondaryBackground: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
                        ),
                        onDismissed: (_) => _removeIngredient(provider, ing),
                        child: ListTile(
                          title: Text(ing),
                          leading: const Icon(Icons.circle, size: 10),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _removeIngredient(provider, ing),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: CustomButton(
              label: 'Search Recipes',
              icon: Icons.search,
              onPressed: provider.ingredients.isEmpty
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      );
                    },
            ),
          ),
        ],
      ),
    );
  }
}