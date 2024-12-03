import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BusinessAppointmentsManagement extends StatefulWidget {
  final String businessId;

  const BusinessAppointmentsManagement({
    Key? key,
    required this.businessId,
  }) : super(key: key);

  @override
  State<BusinessAppointmentsManagement> createState() =>
      _BusinessAppointmentsManagementState();
}

class _BusinessAppointmentsManagementState
    extends State<BusinessAppointmentsManagement> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime _selectedDate = DateTime.now();

  // Stream to fetch appointments for the selected date
  Stream<List<QueryDocumentSnapshot>> _getAppointmentsForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection('appointments')
        .where('businessId', isEqualTo: widget.businessId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  // Function to update appointment status
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

  // Function to build the appointment card UI
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
                Text(
                  data['time'],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
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

  // Function to build the status badge for the appointment
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Appointments'),
        backgroundColor: Colors.purple[200],
      ),
      body: Column(
        children: [
          // Date picker to select the date for viewing appointments
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
            child: StreamBuilder<List<QueryDocumentSnapshot>>(
              stream: _getAppointmentsForDate(_selectedDate),
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

                if (appointments == null || appointments.isEmpty) {
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
      ),
    );
  }
}
