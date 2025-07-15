import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Recipe App'),
          backgroundColor: Colors.green,
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                // Future action for search button
              },
            ),
          ],
        ),
        body: const Center(
          child: Text('Recipe App Home Page'),
        ),
      ),
    );
  }
}
