import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          
          // Search results title
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: Text(
                'Search Results',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),


          // Search results (cards)
          Expanded(
            child: ListView.builder(
              itemCount: 10, // Placeholder for number of results, in future integrate with api/ai
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: ListTile(
                    title: Text('Recipe ${index + 1}'),
                    subtitle: Text('Description of recipe ${index + 1}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.favorite_border),
                      onPressed: () {
                        // Add to favourites logic here
                        // For now, just show a snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added Recipe ${index + 1} to favourites'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),

          // Load more button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
            child: CustomButton(
              label: 'Load More',
              icon: Icon(Icons.refresh),
              backgroundColor: Colors.grey[300],
              textColor: Colors.black,
              width: double.infinity,
              height: 48,
              onPressed: () {
                // Load more results logic here, just showing a snackbar for now
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Loading more results...'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
