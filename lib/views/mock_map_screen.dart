// Create this file: lib/views/mock_map_screen.dart
// This version uses mock data to test your map while Firestore permissions are being fixed

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/food_post_model.dart';
import '../models/user_model.dart';
import '../models/location_data.dart';

class MockMapScreen extends StatefulWidget {
  final UserModel userProfile;

  const MockMapScreen({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<MockMapScreen> createState() => _MockMapScreenState();
}

class _MockMapScreenState extends State<MockMapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  List<FoodPostModel> _mockPosts = [];
  bool _isMapView = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _getCurrentLocation();
    _createMockData();
    _updateMarkers();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          _currentPosition = position;
        });
      } else {
        // Use Toronto as default
        setState(() {
          _currentPosition = Position(
            latitude: 43.7532,
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
        });
      }
    } catch (e) {
      print('Error getting location: $e');
      // Use Toronto as default
      setState(() {
        _currentPosition = Position(
          latitude: 43.7532,
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
      });
    }
  }

  void _createMockData() {
    if (_currentPosition == null) return;

    // Create mock food posts around your location
    _mockPosts = [
      FoodPostModel(
        id: 'mock1',
        donorId: 'user1',
        title: 'Fresh Pizza Slices',
        description:
            '3 slices of pepperoni pizza, still warm! Perfect for lunch.',
        imageUrls: [
          'https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=400'
        ],
        pickupLocation: LocationData(
          latitude: _currentPosition!.latitude + 0.002,
          longitude: _currentPosition!.longitude + 0.002,
          address: '123 College Street, Toronto',
        ),
        dietaryTags: [DietaryTag.vegetarian],
        expiryTime: DateTime.now().add(const Duration(hours: 4)),
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        status: FoodPostStatus.available,
      ),
      FoodPostModel(
        id: 'mock2',
        donorId: 'user2',
        title: 'Vegetarian Sandwich',
        description:
            'Hummus and veggie sandwich with fresh lettuce, tomatoes, and cucumber.',
        imageUrls: [
          'https://images.unsplash.com/photo-1553909489-cd47e0ef937f?w=400'
        ],
        pickupLocation: LocationData(
          latitude: _currentPosition!.latitude - 0.003,
          longitude: _currentPosition!.longitude + 0.001,
          address: '456 Bloor Street, Toronto',
        ),
        dietaryTags: [DietaryTag.vegetarian, DietaryTag.vegan],
        expiryTime: DateTime.now().add(const Duration(hours: 2)),
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        status: FoodPostStatus.available,
      ),
      FoodPostModel(
        id: 'mock3',
        donorId: 'user3',
        title: 'Fresh Fruit Salad',
        description:
            'Mixed fruit salad with strawberries, grapes, and apple. Perfect healthy snack!',
        imageUrls: [
          'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400'
        ],
        pickupLocation: LocationData(
          latitude: _currentPosition!.latitude + 0.001,
          longitude: _currentPosition!.longitude - 0.002,
          address: '789 Queen Street, Toronto',
        ),
        dietaryTags: [
          DietaryTag.vegetarian,
          DietaryTag.vegan,
          DietaryTag.glutenFree
        ],
        expiryTime: DateTime.now().add(const Duration(hours: 6)),
        createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 45)),
        status: FoodPostStatus.available,
      ),
      FoodPostModel(
        id: 'mock4',
        donorId: 'user4',
        title: 'Halal Chicken Wrap',
        description:
            'Delicious halal chicken wrap with fresh vegetables and tahini sauce.',
        imageUrls: [
          'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=400'
        ],
        pickupLocation: LocationData(
          latitude: _currentPosition!.latitude - 0.001,
          longitude: _currentPosition!.longitude - 0.003,
          address: '321 Dundas Street, Toronto',
        ),
        dietaryTags: [DietaryTag.halal],
        expiryTime: DateTime.now().add(const Duration(hours: 8)),
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        status: FoodPostStatus.available,
      ),
    ];
  }

  Future<void> _updateMarkers() async {
    Set<Marker> markers = {};

    for (var post in _mockPosts) {
      Marker marker = await _createFoodMarker(post);
      markers.add(marker);
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<Marker> _createFoodMarker(FoodPostModel post) async {
    return Marker(
      markerId: MarkerId(post.id),
      position: LatLng(
        post.pickupLocation.latitude,
        post.pickupLocation.longitude,
      ),
      infoWindow: InfoWindow(
        title: post.title,
        snippet: post.description.length > 50
            ? '${post.description.substring(0, 50)}...'
            : post.description,
      ),
      icon: await _getFoodMarkerIcon(post),
      onTap: () => _showFoodDetails(post),
    );
  }

  Future<BitmapDescriptor> _getFoodMarkerIcon(FoodPostModel post) async {
    if (post.dietaryTags.contains(DietaryTag.vegetarian) ||
        post.dietaryTags.contains(DietaryTag.vegan)) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    } else if (post.dietaryTags.contains(DietaryTag.halal)) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    } else if (post.dietaryTags.contains(DietaryTag.glutenFree)) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
    } else {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  void _showFoodDetails(FoodPostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MockFoodDetailsBottomSheet(
        post: post,
        currentPosition: _currentPosition,
        onClaim: () => _claimFood(post),
      ),
    );
  }

  void _claimFood(FoodPostModel post) {
    // Mock claiming - just show success message
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Food claimed successfully! (Mock data)'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Food Map (Mock Data)'),
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.green),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Map (Mock Data)'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isMapView = !_isMapView;
              });
            },
            icon: Icon(
              _isMapView ? Icons.list : Icons.map,
              color: Colors.white,
            ),
            label: Text(
              _isMapView ? 'List' : 'Map',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green[600]!,
              Colors.green[50]!,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: Column(
          children: [
            _buildInfoBanner(),
            Expanded(
              child: _isMapView ? _buildMapView() : _buildListView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.blue[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Testing with mock data - ${_mockPosts.length} items',
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    if (_currentPosition == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GoogleMap(
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
          initialCameraPosition: CameraPosition(
            target:
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 14.0,
          ),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
        ),
      ),
    );
  }

  Widget _buildListView() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        itemCount: _mockPosts.length,
        itemBuilder: (context, index) {
          final post = _mockPosts[index];
          return MockFoodListTile(
            post: post,
            currentPosition: _currentPosition,
            onTap: () => _showFoodDetails(post),
          );
        },
      ),
    );
  }
}

// Mock Bottom Sheet
class MockFoodDetailsBottomSheet extends StatelessWidget {
  final FoodPostModel post;
  final Position? currentPosition;
  final VoidCallback onClaim;

  const MockFoodDetailsBottomSheet({
    Key? key,
    required this.post,
    this.currentPosition,
    required this.onClaim,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              post.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              post.description,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (post.dietaryTags.isNotEmpty) ...[
              const Text(
                'Dietary Tags:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: post.dietaryTags.map((tag) {
                  return Chip(
                    label: Text(tag.displayName),
                    backgroundColor: Colors.green[100],
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      post.pickupLocation.address,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onClaim,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Claim This Food (Mock)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 20), // Extra space at bottom
          ],
        ),
      ),
    );
  }
}

// Mock List Tile
class MockFoodListTile extends StatelessWidget {
  final FoodPostModel post;
  final Position? currentPosition;
  final VoidCallback onTap;

  const MockFoodListTile({
    Key? key,
    required this.post,
    this.currentPosition,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green[100],
          child: Icon(Icons.fastfood, color: Colors.green[600]),
        ),
        title: Text(post.title),
        subtitle: Text(post.description,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
