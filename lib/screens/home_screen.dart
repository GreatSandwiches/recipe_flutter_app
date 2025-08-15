import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import 'settings_screen.dart';
import 'search_screen.dart';


class HomeScreen extends StatefulWidget {
  final List<String> ingredients;
  const HomeScreen({super.key, required this.ingredients});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();

  void _addIngredient() {
    final ingredient = _controller.text.trim();
    if (ingredient.isNotEmpty) {
      setState(() {
        widget.ingredients.add(ingredient);
        _controller.clear();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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

            // Greeting user with time specific message + icon
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
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addIngredient(),
              decoration: InputDecoration(
                hintText: 'Add ingredient',
                prefixIcon: Icon(Icons.add, color: theme.colorScheme.primary),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear',
                        onPressed: () {
                          setState(() => _controller.clear());
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(isDark ? 0.35 : 1),
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
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ingredients',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    '${widget.ingredients.length} item${widget.ingredients.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                ],
              ),
            ),
          ),
          Expanded(
            child: widget.ingredients.isEmpty
                ? const Center(
                    child: Text('No ingredients added yet.'),
                  )
                : ListView.builder(
                    itemCount: widget.ingredients.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(widget.ingredients[index]),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            setState(() {
                              widget.ingredients.removeAt(index);
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),

          // Search Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: CustomButton(
              label: 'Search',
              icon: Icon(Icons.search),
              backgroundColor: Colors.grey[300],
              textColor: Colors.black,
              width: double.infinity,
              height: 48,

              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SearchScreen(ingredients: widget.ingredients)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}