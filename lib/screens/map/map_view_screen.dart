import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/post_model.dart';
import '../../core/theme.dart';
import '../post/post_details_screen.dart';
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
  bool _isMapView = true;
  List<PostModel> _allPosts = [];

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
        _showLocationError();
        _currentPosition = Position(
          latitude: 43.6532, // Toronto City Hall as fallback
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
      _showLocationError();
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

  void _showLocationError() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location services are disabled. Using default location.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _loadAvailablePosts() async {
    try {
      if (_foodMarker == null) return;
      setState(() => _isLoading = true);

      final query = await FirebaseFirestore.instance
          .collection('posts')
          .where('status', isEqualTo: PostStatus.available.name)
          .get();

      final now = DateTime.now();
      _allPosts = [];
      _markers.clear();

      for (DocumentSnapshot doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['postId'] = doc.id;
        final post = PostModel.fromMap(data);

        if (post.expiry.isBefore(now)) continue;

        _allPosts.add(post);
        _addMarker(post);
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addMarker(PostModel post) {
    final markerId = MarkerId(post.postId);
    final marker = Marker(
      markerId: markerId,
      position: LatLng(post.location.latitude, post.location.longitude),
      infoWindow: InfoWindow(
        title: post.title,
        snippet: post.address,
      ),
      icon: _foodMarker!,
      onTap: () => _navigateToPostDetails(post),
    );
    _markers[markerId] = marker;
  }

  void _navigateToPostDetails(PostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailsScreen(post: post),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }

  Future<void> _createCustomMarker() async {
    final Uint8List markerIcon = await _getBytesFromIcon(Icons.fastfood, 96, AppColors.primary);
    _foodMarker = BitmapDescriptor.fromBytes(markerIcon);
  }

  Future<Uint8List> _getBytesFromIcon(IconData icon, double size, Color color) async {
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
    final ui.Image img = await recorder.endRecording().toImage(tp.width.toInt(), tp.height.toInt());
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
      appBar: AppBar(
        title: const Text('Food Map'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isMapView ? Icons.list : Icons.map),
            onPressed: () {
              setState(() => _isMapView = !_isMapView);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAvailablePosts,
          ),
        ],
      ),
      body: _isMapView
          ? GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialLatLng,
                zoom: 12,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: Set<Marker>.of(_markers.values),
              onMapCreated: (controller) => _mapController = controller,
            )
          : ListView.builder(
              itemCount: _allPosts.length,
              itemBuilder: (context, index) {
                final post = _allPosts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: InkWell(
                    onTap: () => _navigateToPostDetails(post),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (post.imageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                post.imageUrl!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          const SizedBox(height: 16),
                          Text(
                            post.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            post.address,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            post.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.access_time, color: AppColors.primary, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Expires: ${_formatDate(post.expiry)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
} 