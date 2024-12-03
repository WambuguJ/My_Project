import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AppointmentsPage extends StatelessWidget {
  final String clientId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppointmentsPage({
    super.key,
    required this.clientId,
  });

  // Stream to fetch upcoming appointments for the client
  Stream<List<QueryDocumentSnapshot>> _getUpcomingAppointments() {
    return _firestore
        .collection('appointments')
        .where('clientId', isEqualTo: clientId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      return snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final appointmentDate = (data['date'] as Timestamp).toDate();
        return appointmentDate.isAfter(now); // Only show future appointments
      }).toList();
    });
  }

  // Function to handle appointment cancellation
  Future<void> _cancelAppointment(BuildContext context, String appointmentId) async {
    try {
      // Show confirmation dialog before cancelling
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Cancel Appointment'),
            content: const Text('Are you sure you want to cancel this appointment?'),
            actions: <Widget>[
              TextButton(
                child: const Text('No'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: const Text('Yes'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      );

      if (confirm ?? false) {
        // Update appointment status to 'cancelled'
        await _firestore
            .collection('appointments')
            .doc(appointmentId)
            .update({'status': 'cancelled'});

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appointment cancelled successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      // Handle errors
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling appointment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Widget to build the appointment card UI
  Widget _buildAppointmentCard(BuildContext context, QueryDocumentSnapshot doc) {
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
                Expanded(
                  child: Text(
                    data['businessName'] ?? 'Unknown Business',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: data['status'] == 'pending'
                        ? Colors.orange[100]
                        : Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    data['status'].toUpperCase(),
                    style: TextStyle(
                      color: data['status'] == 'pending'
                          ? Colors.orange[900]
                          : Colors.green[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM dd, yyyy').format(date),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 8),
                Text(
                  data['time'],
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.spa, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${service['name']} - \$${service['price']}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            if (data['notes']?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.note, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data['notes'],
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Show cancel button only for pending appointments
                if (data['status'] == 'pending')
                  TextButton.icon(
                    onPressed: () => _cancelAppointment(context, doc.id),
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text(
                      'Cancel Appointment',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
        backgroundColor: Colors.purple[200],
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot>>(
        stream: _getUpcomingAppointments(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final appointments = snapshot.data;

          // No upcoming appointments case
          if (appointments == null || appointments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No upcoming appointments',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Book an Appointment'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 16, bottom: 24),
            itemCount: appointments.length,
            itemBuilder: (context, index) =>
                _buildAppointmentCard(context, appointments[index]),
          );
        },
      ),
    );
  }
}
