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
        body: const Center(
          child: Text('Recipe App Home Page'),
        ),
      ),
    );
  }
}
