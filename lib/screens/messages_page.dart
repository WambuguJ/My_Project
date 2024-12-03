import 'package:flutter/material.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.purple[200],
      ),
      body: ListView.builder(
        itemCount: 10, // Number of messages
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple[200],
              child: Text('U${index + 1}'), // Placeholder for user initials
            ),
            title: Text('User  ${index + 1}'),
            subtitle: Text('This is a message from User ${index + 1}'),
            trailing: Text('10:0${index + 1} AM'), // Placeholder for time
            onTap: () {
              // You can add functionality for tapping on a message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tapped on User ${index + 1}')),
              );
            },
          );
        },
      ),
    );
  }
}