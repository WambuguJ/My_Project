import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

abstract class LocationHandler {
  static const int _timeoutSeconds = 15; // Increased timeout duration

  static Future<bool> handleLocationPermission(BuildContext? context) async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Check if location services are enabled
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location services are disabled. Please enable the services'),
            duration: Duration(seconds: 3),
          ));
        }
        return false;
      }

      // Check for permission status
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (context != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permissions are denied'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
              'Location permissions are permanently denied. Please enable them in your device settings.',
            ),
            duration: Duration(seconds: 3),
          ));
        }
        return false;
      }

      return true;
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error checking location permissions: $e'),
          duration: const Duration(seconds: 3),
        ));
      }
      return false;
    }
  }

  static Future<Position?> getCurrentPosition([BuildContext? context]) async {
    try {
      final hasPermission = await handleLocationPermission(context);
      if (!hasPermission) return null;

      // First try with high accuracy
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: _timeoutSeconds),
        ).timeout(
          Duration(seconds: _timeoutSeconds),
          onTimeout: () {
            throw TimeoutException();
          },
        );
      } catch (e) {
        // If high accuracy fails, try with lower accuracy
        debugPrint('High accuracy location failed, trying with lower accuracy: $e');
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: _timeoutSeconds),
        ).timeout(
          Duration(seconds: _timeoutSeconds),
          onTimeout: () {
            throw TimeoutException();
          },
        );
      }
    } on TimeoutException {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location request timed out. Please check your GPS signal and try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return null;
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      debugPrint('Location error: $e');
      return null;
    }
  }

  static Future<String?> getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(
        Duration(seconds: _timeoutSeconds),
        onTimeout: () {
          throw TimeoutException();
        },
      );

      if (placemarks.isEmpty) return null;

      Placemark place = placemarks[0];
      List<String> addressParts = [
        if (place.street?.isNotEmpty == true) place.street!,
        if (place.subLocality?.isNotEmpty == true) place.subLocality!,
        if (place.locality?.isNotEmpty == true) place.locality!,
        if (place.postalCode?.isNotEmpty == true) place.postalCode!,
        if (place.country?.isNotEmpty == true) place.country!,
      ];

      return addressParts.where((part) => part.isNotEmpty).join(', ');
    } on TimeoutException {
      debugPrint('Address lookup timed out');
      return null;
    } catch (e) {
      debugPrint('Error getting address: $e');
      return null;
    }
  }

  static double calculateDistance(
      double startLatitude,
      double startLongitude,
      double endLatitude,
      double endLongitude,
      ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}

class TimeoutException implements Exception {
  @override
  String toString() => 'The location request timed out.';
}