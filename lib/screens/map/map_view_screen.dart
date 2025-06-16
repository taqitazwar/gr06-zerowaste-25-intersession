import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/post_model.dart';
import '../post/post_details_screen.dart';
import '../../core/theme.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Map<MarkerId, Marker> _markers = {};
  BitmapDescriptor? _foodMarker;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _getCurrentLocation();
    await _createCustomMarker();
    await _loadAvailablePosts();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      } else {
        // Fallback to Toronto City Hall if permission denied
        _currentPosition = Position(
          latitude: 43.6532,
          longitude: -79.3832,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
    } catch (e) {
      // On error, use fallback position (Toronto City Hall)
      _currentPosition = Position(
        latitude: 43.6532,
        longitude: -79.3832,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
  }

  Future<void> _loadAvailablePosts() async {
    try {
      if (_foodMarker == null) return;
      
      // Simplified query to avoid composite index requirement
      final query = await FirebaseFirestore.instance
          .collection('posts')
          .where('status', isEqualTo: PostStatus.available.name)
          .get();

      final now = DateTime.now();
      for (DocumentSnapshot doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['postId'] = doc.id;
        final post = PostModel.fromMap(data);

        // Filter expired posts in memory
        if (post.isExpired || post.expiry.isBefore(now)) continue;

        final markerId = MarkerId(post.postId);
        final marker = Marker(
          markerId: markerId,
          position: LatLng(post.location.latitude, post.location.longitude),
          infoWindow: InfoWindow(
            title: post.title,
            snippet: post.address,
          ),
          icon: _foodMarker!,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PostDetailsScreen(
                  initialPost: post,
                ),
              ),
            );
          },
        );
        _markers[markerId] = marker;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading posts: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _createCustomMarker() async {
    final Uint8List markerIcon = await _getBytesFromIcon(
      Icons.fastfood,
      96,
      AppColors.primary,
    );
    _foodMarker = BitmapDescriptor.fromBytes(markerIcon);
  }

  Future<Uint8List> _getBytesFromIcon(
    IconData icon,
    double size,
    Color color,
  ) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final TextPainter tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        color: color,
      ),
    );
    tp.layout();
    tp.paint(canvas, Offset.zero);
    final ui.Image img = await recorder.endRecording().toImage(
      tp.width.toInt(),
      tp.height.toInt(),
    );
    final ByteData? data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    final initialLatLng = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: initialLatLng,
          zoom: 12,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        markers: Set<Marker>.of(_markers.values),
        onMapCreated: (controller) => _mapController = controller,
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
} 