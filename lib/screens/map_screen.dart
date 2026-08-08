import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/photo_spot.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? controller;

  @override
  Widget build(BuildContext context) {
    final markers = demoSpots.map((spot) {
      return Marker(
        markerId: MarkerId(spot.id),
        position: LatLng(spot.latitude, spot.longitude),
        infoWindow: InfoWindow(
          title: spot.name,
          snippet: '⭐ ${spot.rating} • ${spot.bestTime}',
        ),
      );
    }).toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Çekim Haritası')),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(41.015, 28.975),
          zoom: 11.5,
        ),
        markers: markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: false,
        onMapCreated: (c) => controller = c,
      ),
    );
  }
}
