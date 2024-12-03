import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'booking_page.dart';
import 'location_handler.dart';
import 'appointments_page.dart';
import 'screens/profile_page.dart';
import 'business.dart';



class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  String? _currentAddress;
  Position? _currentPosition;
  final MapController _mapController = MapController();
  bool _showMap = true;
  String _searchQuery = '';
  bool _isLoading = true;
  List<Business> _businesses = [];
  List<Business> _filteredBusinesses = [];

  @override
  void initState() {
    super.initState();
    _getCurrentPosition();
    _loadBusinesses();
  }
  Future<void> _getCurrentPosition() async {
    setState(() => _isLoading = true); // Show loading indicator

    try {
      final position = await LocationHandler.getCurrentPosition(context);
      if (position != null) {
        setState(() {
          _currentPosition = position;
          _isLoading = false;
        });

        // Move map to current position
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          15,
        );

        // Get address (optional)
        _getAddressFromLatLng(position);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }
  Future<void> _getAddressFromLatLng(Position position) async {
    final address = await LocationHandler.getAddressFromLatLng(position);
    setState(() {
      _currentAddress = address;
    });
  }


  Future<void> _loadBusinesses() async {
    try {
      final snapshot = await _firestore.collection('users')
          .where('role', isEqualTo: 'business')
          .get();
      print('Found ${snapshot.docs.length} business documents');
      final List<Business> businesses = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (kDebugMode) {
          print('Processing business: ${data['username']}');
        }  // Debug print
        print('Location data: ${data['location']}');
        if (data['location'] != null &&
            data['location']['latitude'] != null &&  // Changed this check
            data['location']['longitude'] != null) {  // Added this check
          businesses.add(Business.fromFirestore(doc));
        }
      }

      setState(() {
        _businesses = businesses;
        _filteredBusinesses = businesses;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading businesses: $e');  // Add this for debugging
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading businesses: $e')),
      );
    }
  }

  void _filterBusinesses(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredBusinesses = _businesses.where((business) {
        return business.name.toLowerCase().contains(_searchQuery) ||
            business.type.toLowerCase().contains(_searchQuery);
      }).toList();
    });
  }

  void _showBusinessDetails(Business business) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (business.profileImage != null)
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: MemoryImage(
                      base64Decode(business.profileImage!),
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        business.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (business.services != null)
                        Text(
                          'Services: ${(business.services! as List).map((s) => s['name']).join(", ")}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      Row(
                        children: [
                          Text('Rating: ${business.rating}'),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber[600],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (business.businessHours != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Business Hours:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...List<Widget>.from(
                    (business.businessHours! as List).map((hours) {
                      final isOpen = hours['isOpen'] ?? false;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${hours['day']}: ${isOpen ? "${hours['openTime']} - ${hours['closeTime']}" : "Closed"}',
                          style: TextStyle(
                            color: isOpen ? Colors.black : Colors.grey,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[200],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Close the bottom sheet
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookingPage(business: business),
                        ),
                      );
                    },
                    child: const Text('Book Appointment'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[200],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      // Navigate to full profile page
                      Navigator.pop(context);
                    },
                    child: const Text('full profile'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        _showMap
            ? FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentPosition != null
                ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                : const LatLng(0, 0),
            initialZoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.my_project',
            ),
            MarkerLayer(
              markers: [
                if (_currentPosition != null)
                  Marker(
                    point: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    width: 80,
                    height: 80,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ..._filteredBusinesses.map(
                      (business) => Marker(
                    point: LatLng(business.latitude, business.longitude),
                    width: 110,
                    height: 110,
                    child: GestureDetector(
                      onTap: () => _showBusinessDetails(business),
                      child: Column(
                        children: [
                          Icon(
                            business.type == 'salon'
                                ? Icons.cut
                                : business.type == 'barber'
                                ? Icons.content_cut
                                : Icons.spa,
                            color: Colors.purple,
                            size: 30,
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            child: Text(
                              business.name,
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        )
            : Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('LAT: ${_currentPosition?.latitude ?? ""}'),
              Text('LNG: ${_currentPosition?.longitude ?? ""}'),
              Text('ADDRESS: ${_currentAddress ?? ""}'),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _getCurrentPosition,
                child: const Text("Get Current Location"),
              ),
            ],
          ),
        ),
        if (_showMap)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: _getCurrentPosition,
              child: const Icon(Icons.my_location),
            ),
          ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildLocationContent(),
      AppointmentsPage(clientId: '',),
      const ProfilePage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('StyleHub'),
        backgroundColor: Colors.purple[200],
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: Icon(_showMap ? Icons.list : Icons.map),
              onPressed: () {
                setState(() {
                  _showMap = !_showMap;
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (_currentIndex == 0)
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: _filterBusinesses,
                  decoration: InputDecoration(
                    hintText: 'Search for salons, barbers, nail services...',
                    border: InputBorder.none,
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search, color: Colors.grey),
                      onPressed: () {},
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: PageView(
              controller: _pageController,
              children: pages,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _currentIndex,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.purple[200],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          });
        },
      ),
    );
  }
}