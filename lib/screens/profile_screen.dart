import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import '../widgets/profile_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: Column(
        children: [

          // Profile Card
          ProfileCard(name: 'Calum Taylor'),

          

          // User Statistics
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text(
                      '25',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    const Text('Recipes'),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '10',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    const Text('Followers'),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '5',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    const Text('Following'),
                  ],
                ),
              ],
            ),
          ),

          // Favourite Recipes

          // Settings


          // Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: CustomButton(
                label: 'Logout',
                icon: Icon(Icons.logout),
                backgroundColor: Colors.grey[300],
                textColor: Colors.black,
                width: double.infinity,
                height: 48,
                onPressed: () {
                  // TODO: implement logout functionality
                },
              ),
          ),

      ],)
    );
  }
}
