import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/food_post_model.dart';
import '../models/user_model.dart';
import '../controllers/food_post_controller.dart';

class InteractiveMapScreen extends StatefulWidget {
  final UserModel userProfile;

  const InteractiveMapScreen({Key? key, required this.userProfile})
      : super(key: key);

  @override
  State<InteractiveMapScreen> createState() => _InteractiveMapScreenState();
}

class _InteractiveMapScreenState extends State<InteractiveMapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  List<FoodPostModel> _allPosts = [];
  List<FoodPostModel> _filteredPosts = [];
  bool _isMapView = true;
  bool _isLoading = true;

  // Filter options
  Set<DietaryTag> _selectedTags = {};
  double _maxDistance = 10.0; // km
  int _maxTimeRemaining = 24; // hours

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _getCurrentLocation();
    await _loadFoodPosts();
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
        // Use default location if permission denied
        setState(() {
          _currentPosition = Position(
            latitude: 43.7532, // Toronto default
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
      // Set Toronto as default
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

  Future<void> _loadFoodPosts() async {
    if (_currentPosition == null) return;

    try {
      // Use your existing FoodPostController
      final posts = await FoodPostController.getNearbyFoodPosts(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        radiusInKm: 50.0, // Get wider range first, then filter
        limit: 100,
      );

      setState(() {
        _allPosts = posts;
        _applyFilters();
      });
    } catch (e) {
      print('Error loading food posts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading food posts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    if (_currentPosition == null) return;

    List<FoodPostModel> filtered = _allPosts.where((post) {
      // Filter by distance
      final distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            post.pickupLocation.latitude,
            post.pickupLocation.longitude,
          ) /
          1000; // Convert to km

      if (distance > _maxDistance) return false;

      // Filter by dietary tags
      if (_selectedTags.isNotEmpty) {
        final hasMatchingTag =
            _selectedTags.any((tag) => post.dietaryTags.contains(tag));
        if (!hasMatchingTag) return false;
      }

      // Filter by time remaining
      final timeRemaining = post.expiryTime.difference(DateTime.now());
      if (timeRemaining.inHours > _maxTimeRemaining ||
          timeRemaining.isNegative) {
        return false;
      }

      return true;
    }).toList();

    // Sort by distance
    filtered.sort((a, b) {
      final distanceA = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        a.pickupLocation.latitude,
        a.pickupLocation.longitude,
      );
      final distanceB = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        b.pickupLocation.latitude,
        b.pickupLocation.longitude,
      );
      return distanceA.compareTo(distanceB);
    });

    setState(() {
      _filteredPosts = filtered;
    });

    _updateMarkers();
  }

  Future<void> _updateMarkers() async {
    Set<Marker> markers = {};

    for (var post in _filteredPosts) {
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
    // Color markers based on dietary tags
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
      builder: (context) => FoodDetailsBottomSheet(
        post: post,
        currentPosition: _currentPosition,
        onClaim: () => _claimFood(post),
      ),
    );
  }

  Future<void> _claimFood(FoodPostModel post) async {
    try {
      // Use your existing controller method
      await FoodPostController.updateFoodPostStatus(
        postId: post.id,
        status: FoodPostStatus.claimed,
        claimedBy: widget.userProfile.uid,
      );

      // Refresh the data
      await _loadFoodPosts();

      Navigator.pop(context); // Close bottom sheet

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Food claimed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error claiming food: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Food Map'),
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.green),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Map'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        elevation: 0,
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
            _buildFilterBar(),
            Expanded(
              child: _isMapView ? _buildMapView() : _buildListView(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshData,
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                '${_filteredPosts.length} items found',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  'Distance: ${_maxDistance.toInt()}km',
                  () => _showDistanceFilter(),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Time: ${_maxTimeRemaining}h',
                  () => _showTimeFilter(),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Dietary: ${_selectedTags.isEmpty ? "All" : "${_selectedTags.length} selected"}',
                  () => _showDietaryFilter(),
                ),
                const SizedBox(width: 8),
                if (_selectedTags.isNotEmpty ||
                    _maxDistance != 10.0 ||
                    _maxTimeRemaining != 24)
                  _buildClearFiltersChip(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.green[700],
          ),
        ),
      ),
    );
  }

  Widget _buildClearFiltersChip() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTags.clear();
          _maxDistance = 10.0;
          _maxTimeRemaining = 24;
        });
        _applyFilters();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.clear, size: 14, color: Colors.red[700]),
            const SizedBox(width: 4),
            Text(
              'Clear',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.red[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    if (_currentPosition == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 16),
            Text('Getting your location...'),
          ],
        ),
      );
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
          mapType: MapType.normal,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }

  Widget _buildListView() {
    if (_filteredPosts.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.no_food,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No food found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your filters or check back later',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        itemCount: _filteredPosts.length,
        itemBuilder: (context, index) {
          final post = _filteredPosts[index];
          return FoodListTile(
            post: post,
            currentPosition: _currentPosition,
            onTap: () => _showFoodDetails(post),
          );
        },
      ),
    );
  }

  void _showDistanceFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Distance'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Maximum distance: ${_maxDistance.toInt()} km'),
              Slider(
                value: _maxDistance,
                min: 1.0,
                max: 50.0,
                divisions: 49,
                activeColor: Colors.green[600],
                label: '${_maxDistance.toInt()} km',
                onChanged: (value) {
                  setDialogState(() {
                    _maxDistance = value;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _applyFilters();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showTimeFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Time Remaining'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Maximum time: $_maxTimeRemaining hours'),
              Slider(
                value: _maxTimeRemaining.toDouble(),
                min: 1.0,
                max: 48.0,
                divisions: 47,
                activeColor: Colors.green[600],
                label: '$_maxTimeRemaining hours',
                onChanged: (value) {
                  setDialogState(() {
                    _maxTimeRemaining = value.toInt();
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _applyFilters();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showDietaryFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Dietary Tags'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: DietaryTag.values.map((tag) {
                  return CheckboxListTile(
                    title: Text(tag.displayName),
                    value: _selectedTags.contains(tag),
                    activeColor: Colors.green[600],
                    onChanged: (bool? value) {
                      setDialogState(() {
                        if (value == true) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _applyFilters();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    await _loadFoodPosts();
    setState(() {
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Map refreshed!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

// Bottom Sheet for Food Details
class FoodDetailsBottomSheet extends StatelessWidget {
  final FoodPostModel post;
  final Position? currentPosition;
  final VoidCallback onClaim;

  const FoodDetailsBottomSheet({
    Key? key,
    required this.post,
    this.currentPosition,
    required this.onClaim,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String distance = '';
    if (currentPosition != null) {
      double distanceInKm = Geolocator.distanceBetween(
            currentPosition!.latitude,
            currentPosition!.longitude,
            post.pickupLocation.latitude,
            post.pickupLocation.longitude,
          ) /
          1000;
      distance = '${distanceInKm.toStringAsFixed(1)} km away';
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
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
                const SizedBox(height: 20),

                // Title and distance
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        post.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (distance.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          distance,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Images
                if (post.imageUrls.isNotEmpty)
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: post.imageUrls.length == 1
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: post.imageUrls.first,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.error),
                              ),
                            ),
                          )
                        : PageView.builder(
                            itemCount: post.imageUrls.length,
                            itemBuilder: (context, index) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: post.imageUrls[index],
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.error),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                const SizedBox(height: 16),

                // Description
                Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  post.description,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),

                // Dietary tags
                if (post.dietaryTags.isNotEmpty) ...[
                  Text(
                    'Dietary Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: post.dietaryTags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green[300]!),
                        ),
                        child: Text(
                          tag.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Pickup info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              post.pickupLocation.address,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.schedule, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Expires: ${_formatDateTime(post.expiryTime)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      if (post.pickupInstructions != null &&
                          post.pickupInstructions!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                post.pickupInstructions!,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Claim button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: post.status == FoodPostStatus.available
                        ? onClaim
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: post.status == FoodPostStatus.available
                          ? Colors.green[600]
                          : Colors.grey[400],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      post.status == FoodPostStatus.available
                          ? 'Claim This Food'
                          : 'Already Claimed',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

// List Tile for Food Items
class FoodListTile extends StatelessWidget {
  final FoodPostModel post;
  final Position? currentPosition;
  final VoidCallback onTap;

  const FoodListTile({
    Key? key,
    required this.post,
    this.currentPosition,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String distance = '';
    if (currentPosition != null) {
      double distanceInKm = Geolocator.distanceBetween(
            currentPosition!.latitude,
            currentPosition!.longitude,
            post.pickupLocation.latitude,
            post.pickupLocation.longitude,
          ) /
          1000;
      distance = '${distanceInKm.toStringAsFixed(1)} km';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: post.imageUrls.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: post.imageUrls.first,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, error, stackTrace) {
                              return Icon(
                                Icons.restaurant,
                                color: Colors.grey[400],
                                size: 32,
                              );
                            },
                          )
                        : Icon(
                            Icons.restaurant,
                            color: Colors.grey[400],
                            size: 32,
                          ),
                  ),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and status
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              post.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (post.status != FoodPostStatus.available)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Claimed',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red[700],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Description
                      Text(
                        post.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Distance and time
                      Row(
                        children: [
                          if (distance.isNotEmpty) ...[
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              distance,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimeRemaining(post.expiryTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),

                      // Dietary tags
                      if (post.dietaryTags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          children: post.dietaryTags.take(3).map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tag.displayName,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),

                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimeRemaining(DateTime expiryTime) {
    final now = DateTime.now();
    final difference = expiryTime.difference(now);

    if (difference.isNegative) {
      return 'Expired';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d left';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h left';
    } else {
      return '${difference.inMinutes}m left';
    }
  }
}
