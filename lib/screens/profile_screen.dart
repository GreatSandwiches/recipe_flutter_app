import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import '../widgets/profile_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

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

          // User Statistics

          // Recipes made

          // Favourite Recipes

          // Settings

          

      ],)
    );
  }
}
