import 'package:flutter/material.dart';
import '../models/recipe_search_options.dart';
import '../services/spoonacular_service.dart';
import '../utils/recipe_time_utils.dart';
import 'recipe_details_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<Map<String, dynamic>> _featuredRecipes = [];
  String _errorMessage = '';
  bool _refiningTimes = false;
  int _selectedCategory = 0;
  final Map<int, List<Map<String, dynamic>>> _categoryResults = {};
  final Map<int, RecipeSearchResponse> _categoryMeta = {};
  final Map<int, int> _categoryNextOffset = {};

  static const List<_ExploreCategory> _categories = [
    _ExploreCategory(
      title: 'Discover',
      subtitle: 'Surprise me with seasonal picks.',
      icon: Icons.explore,
      options: null,
      pageSize: 12,
    ),
    _ExploreCategory(
      title: '30 Min Meals',
      subtitle: 'Dinner on the table in under half an hour.',
      icon: Icons.timer,
      options: const RecipeSearchOptions(
        maxReadyTime: 30,
        sort: 'time',
        sortDirection: 'asc',
        addRecipeInformation: true,
        instructionsRequired: true,
        ignorePantry: true,
        fillIngredients: true,
        number: 12,
      ),
      pageSize: 12,
    ),
    _ExploreCategory(
      title: 'High Protein',
      subtitle: 'Fuel up with 25g+ of protein per serving.',
      icon: Icons.fitness_center,
      options: const RecipeSearchOptions(
        numericFilters: {'minProtein': 25},
        sort: 'protein',
        sortDirection: 'desc',
        addRecipeInformation: true,
        addRecipeNutrition: true,
        instructionsRequired: true,
        ignorePantry: true,
        fillIngredients: true,
        number: 12,
      ),
      pageSize: 12,
    ),
    _ExploreCategory(
      title: 'Veggie Comfort',
      subtitle: 'Hearty vegetarian mains everyone will love.',
      icon: Icons.spa,
      options: const RecipeSearchOptions(
        diets: ['vegetarian'],
        mealTypes: ['main course'],
        sort: 'popularity',
        sortDirection: 'desc',
        addRecipeInformation: true,
        instructionsRequired: true,
        ignorePantry: true,
        fillIngredients: true,
        number: 12,
      ),
      pageSize: 12,
    ),
    _ExploreCategory(
      title: 'Low Carb',
      subtitle: 'Smart picks with under 25g carbs.',
      icon: Icons.local_fire_department,
      options: const RecipeSearchOptions(
        numericFilters: {'maxCarbs': 25, 'maxCalories': 600},
        sort: 'healthiness',
        sortDirection: 'desc',
        addRecipeInformation: true,
        addRecipeNutrition: true,
        instructionsRequired: true,
        ignorePantry: true,
        fillIngredients: true,
        number: 12,
      ),
      pageSize: 12,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    await _loadCategory(_selectedCategory, forceRefresh: true);
  }

  Future<void> _loadCategory(int index, {bool forceRefresh = false}) async {
    if (!mounted) return;

    // Update selection immediately for visual feedback.
    if (_selectedCategory != index) {
      setState(() {
        _selectedCategory = index;
      });
    }

    if (!forceRefresh && _categoryResults.containsKey(index)) {
      setState(() {
        _featuredRecipes = _categoryResults[index]!;
        _isLoading = false;
        _errorMessage = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _selectedCategory = index;
    });

    final category = _categories[index];

    try {
      if (category.options == null) {
        final recipes = await SpoonacularService.getRandomRecipes(
          category.pageSize,
        );
        if (!mounted) return;
        _featuredRecipes = List<Map<String, dynamic>>.from(recipes);
        _categoryResults[index] = _featuredRecipes;
        _categoryMeta.remove(index);
        _categoryNextOffset.remove(index);
      } else {
        final request = category.options!.copyWith(
          offset: 0,
          number: category.pageSize,
        );
        final response = await SpoonacularService.complexSearch(request);
        if (!mounted) return;
        _featuredRecipes = List<Map<String, dynamic>>.from(response.results);
        _categoryResults[index] = _featuredRecipes;
        _categoryMeta[index] = response;
        _categoryNextOffset[index] = response.offset + response.number;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = '';
      });

      _refineRecipeTimesFor(_featuredRecipes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _refresh() async {
    await _loadCategory(_selectedCategory, forceRefresh: true);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _maybeLoadMore();
    }
  }

  Future<void> _maybeLoadMore() async {
    if (_isLoading || _isLoadingMore) return;

    final category = _categories[_selectedCategory];

    if (category.options == null) {
      await _loadMoreRandom(category.pageSize);
      return;
    }

    final existing = _categoryResults[_selectedCategory] ?? [];
    final meta = _categoryMeta[_selectedCategory];
    final total = meta?.totalResults ?? 0;
    if (meta != null && total == 0) {
      return;
    }
    if (total > 0 && existing.length >= total) {
      return;
    }

    final nextOffset =
        _categoryNextOffset[_selectedCategory] ?? meta?.offset ?? 0;
    await _loadMoreForCategory(category, nextOffset);
  }

  Future<void> _loadMoreRandom(int count) async {
    setState(() {
      _isLoadingMore = true;
    });
    try {
      final newRecipes = await SpoonacularService.getRandomRecipes(count);
      if (!mounted) return;
      final existingIds = _featuredRecipes.map((e) => e['id']).toSet();
      final filtered = newRecipes
          .where((recipe) => !existingIds.contains(recipe['id']))
          .toList();
      if (filtered.isNotEmpty) {
        _featuredRecipes.addAll(filtered);
        _categoryResults[_selectedCategory] = _featuredRecipes;
        setState(() {});
        _refineRecipeTimesFor(filtered);
      } else {
        setState(() {});
      }
    } catch (_) {
      if (mounted) setState(() {});
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreForCategory(
    _ExploreCategory category,
    int offset,
  ) async {
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await SpoonacularService.complexSearch(
        category.options!.copyWith(offset: offset, number: category.pageSize),
      );
      if (!mounted) return;

      final existing = List<Map<String, dynamic>>.from(
        _categoryResults[_selectedCategory] ?? [],
      );
      final seenIds = existing.map((e) => e['id']).toSet();

      final filtered = response.results.where((recipe) {
        final id = recipe['id'];
        if (seenIds.contains(id)) {
          return false;
        }
        seenIds.add(id);
        return true;
      }).toList();

      if (filtered.isNotEmpty) {
        existing.addAll(filtered);
        _categoryResults[_selectedCategory] = existing;
        _featuredRecipes = existing;
        setState(() {});
        _refineRecipeTimesFor(filtered);
      } else {
        setState(() {});
      }

      _categoryMeta[_selectedCategory] = response;
      _categoryNextOffset[_selectedCategory] =
          response.offset + response.number;
    } catch (_) {
      if (mounted) setState(() {});
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _refineRecipeTimesFor(List<Map<String, dynamic>> subset) async {
    if (_refiningTimes || subset.isEmpty) return;
    _refiningTimes = true;
    try {
      final candidates = subset
          .where(
            (r) => r['readyInMinutes'] == null || r['readyInMinutes'] == 45,
          )
          .toList();
      for (final recipe in candidates) {
        try {
          final details = await SpoonacularService.getRecipeDetails(
            recipe['id'],
          );
          final better = deriveReadyInMinutes(details);
          if (better != null && better != recipe['readyInMinutes']) {
            if (!mounted) return;
            setState(() {
              recipe['readyInMinutes'] = better;
            });
          }
        } catch (_) {
          // ignore individual failures
        }
        if (!mounted) return;
      }
    } finally {
      _refiningTimes = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildCategorySelector() {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected = index == _selectedCategory;
          return ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(category.icon, size: 18),
                const SizedBox(width: 6),
                Text(category.title),
              ],
            ),
            selected: selected,
            onSelected: (_) => _loadCategory(index),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: _categories.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Explore')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final category = _categories[_selectedCategory];

    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: _errorMessage.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_errorMessage, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          _loadCategory(_selectedCategory, forceRefresh: true),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                _buildCategorySelector(),
                if (category.subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        category.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: _featuredRecipes.isEmpty
                        ? ListView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 48,
                            ),
                            children: const [
                              Icon(
                                Icons.restaurant_outlined,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No recipes matched these filters yet. Try adjusting the category or refresh for new ideas.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : GridView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            physics: const AlwaysScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.75,
                                ),
                            itemCount:
                                _featuredRecipes.length +
                                (_isLoadingMore ? 2 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _featuredRecipes.length) {
                                return _buildLoadingCard();
                              }
                              final recipe = _featuredRecipes[index];
                              return _buildRecipeCard(recipe);
                            },
                          ),
                  ),
                ),
              ],
            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildLoadingCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              child: Container(color: Colors.grey.shade300),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.timer, size: 14, color: Colors.grey.shade300),
                      const SizedBox(width: 4),
                      Container(
                        height: 12,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
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
    );
  }
}

class _ExploreCategory {
  const _ExploreCategory({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.options,
    required this.pageSize,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final RecipeSearchOptions? options;
  final int pageSize;
}
