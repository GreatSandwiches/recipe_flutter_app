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
        body: const Center(
          child: Text('Recipe App Home Page'),
        ),
      ),
    );
  }
}
