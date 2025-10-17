import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../providers/favourites_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/dishes_provider.dart';
import '../widgets/profile_card.dart';
import 'recipe_details_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showEditProfile(BuildContext context, ProfileProvider profile) {
    final nameCtrl = TextEditingController(text: profile.name);
    final bioCtrl = TextEditingController(text: profile.bio);
    Color selectedColor = profile.avatarColor;
    final palette = <Color>[
      Colors.tealAccent,
      Colors.teal,
      Colors.orange,
      Colors.deepOrangeAccent,
      Colors.pinkAccent,
      Colors.purple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlueAccent,
      Colors.green,
      Colors.lime,
      Colors.amber,
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: StatefulBuilder(
            builder: (ctx, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit),
                    const SizedBox(width: 8),
                    Text(
                      'Edit Profile',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Display name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Bio'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Avatar colour',
                  style: Theme.of(ctx).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in palette)
                      GestureDetector(
                        onTap: () => setState(() => selectedColor = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedColor == c
                                  ? Colors.black87
                                  : Colors.white,
                              width: selectedColor == c ? 2 : 1,
                            ),
                            boxShadow: [
                              if (selectedColor == c)
                                const BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                            ],
                          ),
                          child: selectedColor == c
                              ? const Icon(Icons.check, color: Colors.black87)
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          await profile.update(
                            name: nameCtrl.text,
                            bio: bioCtrl.text,
                            avatarColor: selectedColor,
                          );
                          // ignore: use_build_context_synchronously
                          Navigator.pop(ctx);
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _stat(String label, String value, BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final favs = context.watch<FavouritesProvider>();
    final auth = context.watch<AuthProvider>();
    final dishes = context.watch<DishesProvider>();
    final recentFavs = favs.favourites.take(8).toList();
    final recentDishes = dishes.dishes.take(8).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: !profile.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: ProfileCard(
                    name: profile.name,
                    bio: profile.bio,
                    avatarColor: profile.avatarColor,
                    onEdit: () => _showEditProfile(context, profile),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _stat(
                          'Favourites',
                          favs.favourites.length.toString(),
                          context,
                        ),
                        _stat(
                          'Dishes Made',
                          dishes.totalCount.toString(),
                          context,
                        ),
                        _stat('Followers', '5', context), // placeholder
                      ],
                    ),
                  ),
                ),
                if (recentFavs.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.favorite,
                            size: 20,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Recent Favourites',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (recentFavs.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 170,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (ctx, i) {
                          final r = recentFavs[i];
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RecipeDetailsScreen(
                                  recipeId: r.id,
                                  recipeName: r.title,
                                ),
                              ),
                            ),
                            child: SizedBox(
                              width: 130,
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: r.image != null
                                          ? Image.network(
                                              r.image!,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                    color: Colors.grey[300],
                                                    child: const Icon(
                                                      Icons.restaurant,
                                                    ),
                                                  ),
                                            )
                                          : Container(
                                              color: Colors.grey[300],
                                              child: const Center(
                                                child: Icon(Icons.restaurant),
                                              ),
                                            ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Text(
                                        r.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemCount: recentFavs.length,
                      ),
                    ),
                  ),
                if (recentDishes.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 20,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Recently Cooked',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (recentDishes.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 170,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (ctx, i) {
                          final dish = recentDishes[i];
                          final lastMade = '${dish.madeAt.day}/'
                              '${dish.madeAt.month}/'
                              '${dish.madeAt.year}';
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RecipeDetailsScreen(
                                  recipeId: dish.recipeId,
                                  recipeName: dish.title,
                                ),
                              ),
                            ),
                            child: SizedBox(
                              width: 140,
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: dish.image != null
                                          ? Image.network(
                                              dish.image!,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                    color: Colors.grey[300],
                                                    child: const Icon(
                                                      Icons.restaurant,
                                                    ),
                                                  ),
                                            )
                                          : Container(
                                              color: Colors.grey[300],
                                              child: const Center(
                                                child: Icon(
                                                  Icons.restaurant_menu,
                                                ),
                                              ),
                                            ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dish.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Last: $lastMade',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemCount: recentDishes.length,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.settings),
                            label: const Text('Settings'),
                            onPressed: () {
                              Navigator.pushNamed(context, '/settings');
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.palette_outlined),
                            label: const Text('Theme (coming soon)'),
                            onPressed: () {},
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: Icon(
                              auth.isLoggedIn ? Icons.logout : Icons.login,
                            ),
                            label: Text(auth.isLoggedIn ? 'Logout' : 'Login'),
                            onPressed: () {
                              if (auth.isLoggedIn) {
                                auth.logout();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Logged out')),
                                );
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/login',
                                  (route) => false,
                                );
                              } else {
                                Navigator.pushNamed(context, '/login');
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
    );
  }
}
