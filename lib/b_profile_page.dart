import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'dart:convert';
import 'dart:io';

class BusinessHours {
  final String day;
  final String openTime;
  final String closeTime;
  final bool isOpen;

  BusinessHours({
    required this.day,
    required this.openTime,
    required this.closeTime,
    required this.isOpen,
  });

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'openTime': openTime,
      'closeTime': closeTime,
      'isOpen': isOpen,
    };
  }

  factory BusinessHours.fromMap(Map<String, dynamic> map) {
    return BusinessHours(
      day: map['day'],
      openTime: map['openTime'],
      closeTime: map['closeTime'],
      isOpen: map['isOpen'],
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Location _locationService = Location();

  String? _profileImageBase64;
  String _businessName = '';
  List<Map<String, dynamic>> _services = [];
  Map<String, double>? _locationData;
  String _locationDisplay = 'Location not set';
  List<BusinessHours> _businessHours = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeBusinessHours();
    _loadUserData();
    _getCurrentLocation();
  }

  void _initializeBusinessHours() {
    _businessHours = [
      BusinessHours(day: 'Monday', openTime: '9:00 AM', closeTime: '5:00 PM', isOpen: true),
      BusinessHours(day: 'Tuesday', openTime: '9:00 AM', closeTime: '5:00 PM', isOpen: true),
      BusinessHours(day: 'Wednesday', openTime: '9:00 AM', closeTime: '5:00 PM', isOpen: true),
      BusinessHours(day: 'Thursday', openTime: '9:00 AM', closeTime: '5:00 PM', isOpen: true),
      BusinessHours(day: 'Friday', openTime: '9:00 AM', closeTime: '5:00 PM', isOpen: true),
      BusinessHours(day: 'Saturday', openTime: '10:00 AM', closeTime: '4:00 PM', isOpen: true),
      BusinessHours(day: 'Sunday', openTime: '10:00 AM', closeTime: '4:00 PM', isOpen: false),
    ];
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permissionGranted = await _locationService.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission not granted')),
        );
        return;
      }

      final locationData = await _locationService.getLocation();

      if (locationData.latitude != null && locationData.longitude != null) {
        final user = _auth.currentUser;
        if (user != null) {
          final location = {
            'latitude': locationData.latitude,
            'longitude': locationData.longitude,
            'timestamp': FieldValue.serverTimestamp(),
          };

          await _firestore.collection('users').doc(user.uid).update({
            'location': location,
          });

          setState(() {
            _locationData = {
              'latitude': locationData.latitude!,
              'longitude': locationData.longitude!,
            };
            _locationDisplay = 'Lat: ${locationData.latitude?.toStringAsFixed(4)}, '
                'Long: ${locationData.longitude?.toStringAsFixed(4)}';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location updated successfully')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing location: $e')),
      );
    }
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        setState(() {
          _profileImageBase64 = data?['profileImage'];
          _services = List<Map<String, dynamic>>.from(data?['services'] ?? []);
          _businessName = data?['businessName'] ?? '';

          if (data?['location'] != null) {
            _locationData = {
              'latitude': data?['location']['latitude'],
              'longitude': data?['location']['longitude'],
            };
            _locationDisplay = 'Lat: ${_locationData?['latitude']?.toStringAsFixed(4)}, '
                'Long: ${_locationData?['longitude']?.toStringAsFixed(4)}';
          }

          if (data?['businessHours'] != null) {
            _businessHours = List<BusinessHours>.from(
                data?['businessHours'].map((x) => BusinessHours.fromMap(x))
            );
          }
        });
      }
    }
  }

  Future<void> _uploadProfileImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 50,
      );

      if (pickedFile == null) return;

      setState(() => _isLoading = true);

      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      if (base64Image.length > 900000) {
        throw Exception('Image too large. Please choose a smaller image.');
      }

      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
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
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile picture: $e')),
      );
    }
  }

  void _showAddServiceDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Service Name',
                hintText: 'e.g. manicure',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Price (\ksh)',
                hintText: 'e.g. 30',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _addService(nameController.text, priceController.text);
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addService(String name, String price) async {
    if (name.trim().isEmpty || price.trim().isEmpty) return;

    final newService = {
      'name': name.trim(),
      'price': double.tryParse(price.trim()) ?? 0,
    };

    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'services': FieldValue.arrayUnion([newService]),
      });

      setState(() {
        _services.add(newService);
      });
    }
  }

  Future<void> _updateBusinessHours(int index) async {
    TimeOfDay? openTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (openTime == null) return;

    TimeOfDay? closeTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (closeTime == null) return;

    setState(() {
      _businessHours[index] = BusinessHours(
        day: _businessHours[index].day,
        openTime: '${openTime.format(context)}',
        closeTime: '${closeTime.format(context)}',
        isOpen: _businessHours[index].isOpen,
      );
    });

    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'businessHours': _businessHours.map((h) => h.toMap()).toList(),
      });
    }
  }

  void _toggleDayStatus(int index) async {
    setState(() {
      _businessHours[index] = BusinessHours(
        day: _businessHours[index].day,
        openTime: _businessHours[index].openTime,
        closeTime: _businessHours[index].closeTime,
        isOpen: !_businessHours[index].isOpen,
      );
    });

    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'businessHours': _businessHours.map((h) => h.toMap()).toList(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Profile'),
        backgroundColor: Colors.purple[200],
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: _getCurrentLocation,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _auth.signOut,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _uploadProfileImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _profileImageBase64 != null
                            ? MemoryImage(base64Decode(_profileImageBase64!))
                            : null,
                        child: _profileImageBase64 == null
                            ? const Icon(Icons.person, size: 40)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor: Colors.purple[200],
                          radius: 20,
                          child: const Icon(Icons.camera_alt, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _businessName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _locationDisplay,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 32),

          // Services Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Services',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle),
                color: Colors.purple[200],
                onPressed: _showAddServiceDialog,
              ),
            ],
          ),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _services.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final service = _services[index];
                return ListTile(
                  title: Text(service['name']),
                  trailing: Text(
                    '\$${service['price'].toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Business Hours Section
          Text(
            'Business Hours',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _businessHours.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final hours = _businessHours[index];
                return ListTile(
                  title: Text(hours.day),
                  subtitle: hours.isOpen
                      ? Text('${hours.openTime} - ${hours.closeTime}')
                      : const Text('Closed'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: hours.isOpen,
                        onChanged: (value) => _toggleDayStatus(index),
                      ),
                      if (hours.isOpen)
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _updateBusinessHours(index),
                        ),
                    ],
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