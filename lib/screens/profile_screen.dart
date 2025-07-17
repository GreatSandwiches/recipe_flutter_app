import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';

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

          // Profile
          Container(
            padding: const EdgeInsets.all(25.0),
            margin: const EdgeInsets.symmetric(horizontal: 20.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(25.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 5,
                  blurRadius: 7,
                  offset: const Offset(0, 3), // changes position of shadow
                ),
              ],

            ),
            
            child: const Text(
              'Calum Taylor',
              style: TextStyle(fontSize: 18),
            ),
          ),

          // Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: CustomButton(
              label: 'Logout',
              backgroundColor: Colors.red,
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
