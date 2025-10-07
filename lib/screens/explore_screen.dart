import 'package:flutter/material.dart';
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
  bool _isLoading = true; // initial load
  bool _isLoadingMore = false; // pagination state
  List<Map<String, dynamic>> _featuredRecipes = [];
  String _errorMessage = '';
  bool _refiningTimes = false; // track background refinement

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final recipes = await SpoonacularService.getRandomRecipes(12);
      if (!mounted) return;
      _featuredRecipes = recipes;
      _isLoading = false;
      setState(() {});
      _refineRecipeTimesFor(recipes); // refine just fetched
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _refresh() async {
    await _initialLoad();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _maybeLoadMore();
    }
  }

  Future<void> _maybeLoadMore() async {
    if (_isLoading || _isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
    });
    try {
      final newRecipes = await SpoonacularService.getRandomRecipes(12);
      if (!mounted) return;
      // de-duplicate by id
      final existingIds = _featuredRecipes.map((e) => e['id']).toSet();
      final filtered = newRecipes
          .where((r) => !existingIds.contains(r['id']))
          .toList();
      if (filtered.isNotEmpty) {
        _featuredRecipes.addAll(filtered);
        setState(() {});
        _refineRecipeTimesFor(filtered);
      } else {
        setState(() {}); // still update to hide loader
      }
    } catch (_) {
      if (mounted) setState(() {}); // ignore load-more errors silently for now
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _refineRecipeTimesFor(List<Map<String, dynamic>> subset) async {
    if (_refiningTimes) return; // simple guard; could queue but unnecessary
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
          /* ignore */
        }
        if (!mounted) return;
      }
    } finally {
      _refiningTimes = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Explore')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
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
                      onPressed: _initialLoad,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: _featuredRecipes.length + (_isLoadingMore ? 2 : 0),
                itemBuilder: (context, index) {
                  if (index >= _featuredRecipes.length) {
                    return _buildLoadingCard();
                  }
                  final recipe = _featuredRecipes[index];
                  return _buildRecipeCard(recipe);
                },
              ),
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
