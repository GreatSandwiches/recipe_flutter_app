import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _ingredients = [];

  void _addIngredient() {
    final ingredient = _controller.text.trim();
    if (ingredient.isNotEmpty) {
      setState(() {
        _ingredients.add(ingredient);
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
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
            title: Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                children: const [
                  Icon(Icons.wb_sunny, size: 16),
                  SizedBox(width: 6),
                  Text('Good morning', style: TextStyle(fontSize: 12)),
                ],
                ),
                const Text('Calum Taylor'),
              ],
              ),
            ),
            centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                // Future action for settings button
              },
            ),
          ],
        ), 
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Add ingredients',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                onSubmitted: (value) => _addIngredient(),
              ),
            ),
            Expanded(
              child: _ingredients.isEmpty
                ? const Center(
                    child: Text('No ingredients added yet.'),
                  )
                : ListView.builder(
                    itemCount: _ingredients.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(_ingredients[index]),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            setState(() {
                              _ingredients.removeAt(index);
                            });
                          },
                        ),
                      );
                    },
              )
            ),
          ],
        ),
      ),
    );
  }
}
