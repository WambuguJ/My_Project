import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'appointments_page.dart';
import 'business.dart';

class BookingPage extends StatefulWidget {
  final Business business;

  const BookingPage({
    super.key,
    required this.business,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime? _selectedDate;
  String? _selectedTime;
  Map<String, dynamic>? _selectedService;
  List<String> _availableTimes = [];
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchAvailableTimeSlots() async {
    if (_selectedDate == null) {
      print('No date selected');
      return;
    }

    // Get the day of week with first letter capitalized to match Firebase format
    String dayOfWeek = DateFormat('EEEE').format(_selectedDate!);
    print('Fetching slots for $dayOfWeek');

    // Verify business hours exist
    if (widget.business.businessHours == null) {
      print('No business hours defined');
      setState(() {
        _availableTimes = [];
      });
      return;
    }

    // Find business hours for selected day with debug logging
    var businessHours = widget.business.businessHours!.firstWhere(
          (hours) => hours['day'] == dayOfWeek,
      orElse: () {
        print('No hours found for $dayOfWeek');
        return {'day': '', 'isOpen': false};
      },
    );

    if (!businessHours['isOpen']) {
      print('Business is closed on $dayOfWeek');
      setState(() {
        _availableTimes = [];
      });
      return;
    }

    try {
      // Parse business hours - Convert 12-hour format to 24-hour format
      String openTime = DateFormat('HH:mm')
          .format(DateFormat('h:mm a').parse(businessHours['openTime']));
      String closeTime = DateFormat('HH:mm')
          .format(DateFormat('h:mm a').parse(businessHours['closeTime']));

      print('Business hours: $openTime - $closeTime');

      // Generate all possible time slots
      List<String> allTimeSlots = [];
      DateTime start = DateFormat('HH:mm').parse(openTime);
      DateTime end = DateFormat('HH:mm').parse(closeTime);

      while (start.isBefore(end)) {
        // Format time slots in 12-hour format to match your UI requirements
        allTimeSlots.add(DateFormat('h:mm a').format(start));
        start = start.add(const Duration(minutes: 30));
      }

      setState(() {
        _availableTimes = allTimeSlots;
      });
    } catch (e) {
      print('Error fetching time slots: $e');
      setState(() {
        _availableTimes = [];
      });
    }
  }




  Widget _buildServiceSelection() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Service',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...widget.business.services?.map((service) {
              return ListTile(
                title: Text(service['name']),
                subtitle: Text('\$${service['price']}'),
                trailing: _selectedService == service
                    ? const Icon(Icons.check_circle, color: Colors.purple)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedService = service;
                  });
                },
              );
            }) ?? [],
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeSelection() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Date & Time',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            CalendarDatePicker(
              initialDate: _selectedDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 30)),
              onDateChanged: (date) {
                setState(() {
                  _selectedDate = date;
                  _fetchAvailableTimeSlots();
                });
              },
            ),
            const SizedBox(height: 16),
            if (_availableTimes.isEmpty)
              const Text(
                'No available time slots for selected date',
                style: TextStyle(color: Colors.red),
              )
            else
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _availableTimes.map((time) {
                  bool isSelected = time == _selectedTime;
                  return ChoiceChip(
                    label: Text(time),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedTime = selected ? time : null;
                      });
                    },
                    selectedColor: Colors.purple[200],
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Additional Notes',
            hintText: 'Add any special requests or notes for your appointment...',
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmBooking() async {
    if (_selectedService == null || _selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a service, date, and time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Get the current client ID
      String? clientId = FirebaseAuth.instance.currentUser?.uid;

      if (clientId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You need to be logged in to book an appointment'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create the appointment in Firestore
      await _firestore.collection('appointments').add({
        'businessId': widget.business.id,
        'businessName': widget.business.name,
        'clientId': clientId, // Use dynamic client ID
        'service': _selectedService,
        'date': Timestamp.fromDate(_selectedDate!),
        'time': _selectedTime,
        'notes': _notesController.text,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Show success message and navigate to appointments page
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment booked successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to appointments page (optional)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AppointmentsPage(
              clientId: clientId, // Pass dynamic client ID
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error booking appointment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Book with ${widget.business.name}'),
        backgroundColor: Colors.purple[200],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildServiceSelection(),
            _buildDateTimeSelection(),
            _buildNotesField(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[200],
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _confirmBooking,
                child: const Text(
                  'Confirm Booking',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }}
