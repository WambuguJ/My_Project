import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'b_profile_page.dart';
import 'package:intl/intl.dart';

class BusinessDashboard extends StatefulWidget {
  const BusinessDashboard({super.key});

  @override
  _BusinessDashboardState createState() => _BusinessDashboardState();
}

class _BusinessDashboardState extends State<BusinessDashboard> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime _selectedDate = DateTime.now();

  Stream<QuerySnapshot> _getAppointments() {
    // Simplified query that only filters by businessId
    return _firestore
        .collection('appointments')
        .where('businessId', isEqualTo: 'gBkGPTYmSShJzyijcKsRSpsm7Ow1') // Replace with actual business ID
        .orderBy('date', descending: false)
        .snapshots();
  }

  Future<void> _updateAppointmentStatus(String appointmentId, String newStatus) async {
    try {
      await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .update({'status': newStatus});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appointment $newStatus successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating appointment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case 'pending':
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[900]!;
        break;
      case 'confirmed':
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[900]!;
        break;
      case 'completed':
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[900]!;
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[900]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  bool _isAppointmentForSelectedDate(DateTime appointmentDate) {
    return appointmentDate.year == _selectedDate.year &&
        appointmentDate.month == _selectedDate.month &&
        appointmentDate.day == _selectedDate.day;
  }

  Widget _buildAppointmentCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final date = (data['date'] as Timestamp).toDate();
    final service = data['service'] as Map<String, dynamic>;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMM dd, yyyy').format(date),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['time'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(data['status']),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Service: ${service['name']} - \$${service['price']}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (data['notes']?.isNotEmpty ?? false)
              Text(
                'Notes: ${data['notes']}',
                style: const TextStyle(fontSize: 16),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (data['status'] == 'pending') ...[
                  TextButton.icon(
                    onPressed: () => _updateAppointmentStatus(doc.id, 'confirmed'),
                    icon: const Icon(Icons.check, color: Colors.green),
                    label: const Text('Confirm'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _updateAppointmentStatus(doc.id, 'cancelled'),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Decline'),
                  ),
                ] else if (data['status'] == 'confirmed') ...[
                  TextButton.icon(
                    onPressed: () => _updateAppointmentStatus(doc.id, 'completed'),
                    icon: const Icon(Icons.done_all, color: Colors.blue),
                    label: const Text('Mark Complete'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: CalendarDatePicker(
            initialDate: _selectedDate,
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            onDateChanged: (date) {
              setState(() {
                _selectedDate = date;
              });
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getAppointments(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allAppointments = snapshot.data?.docs ?? [];

              // Filter appointments for selected date
              final appointments = allAppointments.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final date = (data['date'] as Timestamp).toDate();
                return _isAppointmentForSelectedDate(date);
              }).toList();

              if (appointments.isEmpty) {
                return const Center(
                  child: Text(
                    'No appointments for this date',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: appointments.length,
                itemBuilder: (context, index) =>
                    _buildAppointmentCard(appointments[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Dashboard'),
        backgroundColor: Colors.purple[200],
      ),
      body: PageView(
        controller: _pageController,
        children: [
          _buildAppointmentsPage(),
        ],
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
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
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          } else {
            setState(() {
              _currentIndex = index;
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            });
          }
        },
      ),
    );
  }
}