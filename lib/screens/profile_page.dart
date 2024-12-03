import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:convert';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  String? _profileImageBase64;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final docSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .get();

        if (docSnapshot.exists) {
          setState(() {
            _profileImageBase64 = docSnapshot.data()?['profileImage'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile image: $e');
    }
  }

  Future<void> _uploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512, // Limit image size
        maxHeight: 512,
        imageQuality: 50, // Reduce quality to keep file size down
      );

      if (image == null) return;

      setState(() {
        _isLoading = true;
      });

      // Convert image to base64
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Check file size (Firestore document limit is 1MB)
      if (base64Image.length > 900000) { // Leave some room for other fields
        throw Exception('Image too large. Please choose a smaller image.');
      }

      // Store in Firestore
      await _firestore.collection('users').doc(_auth.currentUser?.uid).set({
        'profileImage': base64Image,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _profileImageBase64 = base64Image;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated successfully')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile picture: $e')),
      );
    }
  }

  // Logout function
  Future<void> _logout() async {
    try {
      await _auth.signOut();
      // Navigate to login page after logging out
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Profile Picture
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _profileImageBase64 != null
                            ? MemoryImage(base64Decode(_profileImageBase64!))
                            : const AssetImage('assets/default_profile.png') as ImageProvider,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, color: Colors.white),
                            onPressed: _uploadImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // User Details
                StreamBuilder<DocumentSnapshot>(
                  stream: _firestore.collection('users').doc(user?.uid).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data?.exists == true) {
                      final userData = snapshot.data!.data() as Map<String, dynamic>;
                      return Column(
                        children: [
                          Text(
                            userData['displayName'] ?? user?.displayName ?? "User",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            userData['email'] ?? user?.email ?? "No email",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Text(
                          user?.displayName ?? "User",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user?.email ?? "No email",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Settings Section
                const Text(
                  "Settings",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                // Settings List
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text("Notifications"),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Navigate to notifications settings
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lock),
                  title: const Text("Privacy"),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Navigate to privacy settings
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help),
                  title: const Text("Help"),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Navigate to help section
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text("Logout", style: TextStyle(color: Colors.red)),
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
