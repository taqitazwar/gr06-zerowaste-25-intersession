import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../models/food_post_model.dart';
import '../models/user_model.dart';
import '../controllers/food_post_controller.dart';

// Google Places API configuration
String get kGoogleApiKey => 'AIzaSyBv6Sg--2_TK2y22950yy6rHMxXlsyOGC4'; // Using Firebase API key temporarily
// String get kGoogleApiKey => dotenv.env['GOOGLE_PLACES_API_KEY'] ?? 'YOUR_GOOGLE_PLACES_API_KEY';

class AddressSuggestion {
  final String description;
  final double latitude;
  final double longitude;
  final String placeId;

  AddressSuggestion({
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.placeId,
  });

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) {
    return AddressSuggestion(
      description: json['description'] ?? '',
      latitude: 0.0, // Will be filled later
      longitude: 0.0, // Will be filled later
      placeId: json['place_id'] ?? '',
    );
  }
}

class PostFoodScreen extends StatefulWidget {
  final UserModel userProfile;

  const PostFoodScreen({super.key, required this.userProfile});

  @override
  State<PostFoodScreen> createState() => _PostFoodScreenState();
}

class _PostFoodScreenState extends State<PostFoodScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pickupInstructionsController = TextEditingController();
  final _locationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<File> _selectedImages = [];
  Set<DietaryTag> _selectedTags = {};
  DateTime? _selectedExpiryTime;
  LocationData? _selectedLocation;
  bool _isLoading = false;
  bool _isLocationLoading = false;
  List<AddressSuggestion> _addressSuggestions = [];
  bool _showSuggestions = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pickupInstructionsController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Add Photos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildImagePickerOption(
                        'Camera',
                        Icons.camera_alt,
                        () => _getImages(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildImagePickerOption(
                        'Gallery',
                        Icons.photo_library,
                        () => _getImages(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      _showError('Error opening image picker: $e');
    }
  }

  Widget _buildImagePickerOption(String title, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.green[50],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 32, color: Colors.green[600]),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _getImages(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> images = await _picker.pickMultiImage(
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );
        
        if (images.isNotEmpty && _selectedImages.length + images.length <= 5) {
          setState(() {
            _selectedImages.addAll(images.map((e) => File(e.path)));
          });
        } else if (_selectedImages.length + images.length > 5) {
          _showError('You can only select up to 5 images');
        }
      } else {
        final XFile? image = await _picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );

        if (image != null && _selectedImages.length < 5) {
          setState(() {
            _selectedImages.add(File(image.path));
          });
        } else if (_selectedImages.length >= 5) {
          _showError('You can only select up to 5 images');
        }
      }
    } catch (e) {
      _showError('Error picking images: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // Google Places API integration with CORS handling
  void _onAddressChanged(String query) async {
    if (query.length < 3) {
      setState(() {
        _addressSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    try {
      // Use Places Autocomplete API
      final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&key=$kGoogleApiKey'
          '&types=establishment|geocode'
          '&language=en';
          
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['predictions'] != null) {
          final suggestions = <AddressSuggestion>[];
          
          for (final prediction in (data['predictions'] as List).take(5)) {
            final placeId = prediction['place_id'];
            final description = prediction['description'];
            
            // Get place details for coordinates
            final detailUrl = 'https://maps.googleapis.com/maps/api/place/details/json'
                '?place_id=$placeId'
                '&key=$kGoogleApiKey'
                '&fields=geometry';
                
            final detailResponse = await http.get(
              Uri.parse(detailUrl),
              headers: {'Content-Type': 'application/json'},
            ).timeout(const Duration(seconds: 5));
            
            if (detailResponse.statusCode == 200) {
              final detailData = json.decode(detailResponse.body);
              
              if (detailData['status'] == 'OK' && detailData['result'] != null) {
                final location = detailData['result']['geometry']['location'];
                
                suggestions.add(AddressSuggestion(
                  description: description,
                  latitude: location['lat'].toDouble(),
                  longitude: location['lng'].toDouble(),
                  placeId: placeId,
                ));
              }
            }
          }
          
          setState(() {
            _addressSuggestions = suggestions;
            _showSuggestions = suggestions.isNotEmpty;
          });
        } else {
          _handleApiError(data['status']);
        }
      } else {
        _handleNetworkError(response.statusCode);
      }
    } on http.ClientException catch (e) {
      _showCorsWarning();
    } catch (e) {
      _showError('Network error: $e');
      _showFallbackSuggestions(query);
    }
  }

  void _handleApiError(String status) {
    setState(() {
      _addressSuggestions = [];
      _showSuggestions = false;
    });
    
    switch (status) {
      case 'REQUEST_DENIED':
        _showError('Google Places API key is invalid or restricted. Please check your API key setup.');
        break;
      case 'OVER_QUERY_LIMIT':
        _showError('Google Places API quota exceeded. Please try again later.');
        break;
      case 'ZERO_RESULTS':
        _showError('No results found for your search.');
        break;
      default:
        _showError('Google Places API error: $status');
    }
  }

  void _showCorsWarning() {
    _showError('⚠️ Direct Google Places API blocked by browser security. Use "Manual Entry" or run on mobile device.');
    _showFallbackSuggestions(_locationController.text);
  }

  void _handleNetworkError(int statusCode) {
    setState(() {
      _addressSuggestions = [];
      _showSuggestions = false;
    });
    
    switch (statusCode) {
      case 403:
        _showError('🔑 Google Places API key is invalid or restricted.');
        break;
      case 429:
        _showError('⏰ Google Places API quota exceeded. Try again later.');
        break;
      default:
        _showError('🌐 Network error: $statusCode');
    }
  }

  void _showFallbackSuggestions(String query) {
    // Provide some common suggestions when API fails
    final fallbackSuggestions = <AddressSuggestion>[
      AddressSuggestion(
        description: '$query (Manual Entry - Tap to set coordinates)',
        latitude: 37.7749, // Default to San Francisco coordinates
        longitude: -122.4194,
        placeId: 'manual_entry',
      ),
    ];
    
    setState(() {
      _addressSuggestions = fallbackSuggestions;
      _showSuggestions = true;
    });
  }

  // Alternative method: Simple Places search with text input
  Future<void> _openPlacesSearch() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Type your address in the location field above to get suggestions, or enter it manually:'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                hintText: 'e.g., 123 Main St, City, State',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  Navigator.pop(context);
                  setState(() {
                    _locationController.text = value;
                    _selectedLocation = LocationData(
                      latitude: 0.0, // User will need to set manually or use GPS
                      longitude: 0.0,
                      address: value,
                    );
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _selectAddress(AddressSuggestion suggestion) {
    setState(() {
      _locationController.text = suggestion.description;
      
      if (suggestion.placeId == 'manual_entry') {
        // For manual entries, allow user to set coordinates later or use GPS
        _selectedLocation = LocationData(
          latitude: suggestion.latitude,
          longitude: suggestion.longitude,
          address: suggestion.description.replaceAll(' (Manual Entry - Tap to set coordinates)', ''),
        );
        _showSuggestions = false;
        
        // Show dialog to get GPS coordinates
        _showManualLocationDialog();
      } else {
        // Normal Google Places result
        _selectedLocation = LocationData(
          latitude: suggestion.latitude,
          longitude: suggestion.longitude,
          address: suggestion.description,
        );
        _showSuggestions = false;
      }
    });
  }

  void _showManualLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Location'),
        content: const Text('Would you like to use your current GPS location for this address, or enter it manually?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _getCurrentLocation();
            },
            child: const Text('Use GPS'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Keep the manual address as-is
            },
            child: const Text('Keep Manual'),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocationLoading = true;
    });

    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Location permissions are permanently denied');
        return;
      }

      // Get location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // In a real app, you'd use reverse geocoding to get the actual address
      final address = 'Current Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';

      setState(() {
        _selectedLocation = LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          address: address,
        );
        _locationController.text = address;
        _showSuggestions = false;
      });
    } catch (e) {
      _showError('Error getting location: $e');
    } finally {
      setState(() {
        _isLocationLoading = false;
      });
    }
  }

  Future<void> _selectExpiryTime() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 7)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green[600]!,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: 18, minute: 0),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Colors.green[600]!,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          _selectedExpiryTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _postFood() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      _showError('Please add at least one photo');
      return;
    }
    if (_selectedLocation == null) {
      _showError('Please set pickup location');
      return;
    }
    if (_selectedExpiryTime == null) {
      _showError('Please set expiry time');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final foodPost = FoodPostModel(
        id: '', // Will be set by Firestore
        donorId: widget.userProfile.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrls: [], // Will be populated after upload
        pickupLocation: _selectedLocation!,
        dietaryTags: _selectedTags.toList(),
        expiryTime: _selectedExpiryTime!,
        status: FoodPostStatus.available,
        pickupInstructions: _pickupInstructionsController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await FoodPostController.createFoodPost(
        foodPost: foodPost,
        imageFiles: _selectedImages,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Food posted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      _showError('Failed to post food: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Food'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _postFood,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'POST',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageSection(),
                const SizedBox(height: 24),
                _buildBasicInfoSection(),
                const SizedBox(height: 24),
                _buildLocationSection(),
                const SizedBox(height: 24),
                _buildDietaryTagsSection(),
                const SizedBox(height: 24),
                _buildExpirySection(),
                const SizedBox(height: 24),
                _buildPickupInstructionsSection(),
                const SizedBox(height: 100), // Extra space for floating button
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Photos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add up to 5 photos of your food (required)',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedImages.isEmpty)
            _buildAddPhotoButton()
          else
            _buildImageGrid(),
        ],
      ),
    );
  }

  Widget _buildAddPhotoButton() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[200]!, width: 2, style: BorderStyle.solid),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate, size: 32, color: Colors.green[600]),
              const SizedBox(height: 8),
              Text(
                'Add Photos',
                style: TextStyle(
                  color: Colors.green[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _selectedImages.length + (_selectedImages.length < 5 ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _selectedImages.length) {
              return GestureDetector(
                onTap: _pickImages,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Icon(Icons.add, color: Colors.green[600]),
                ),
              );
            }
            
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImages[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _removeImage(index),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Food Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Food Title',
              hintText: 'e.g., Fresh Homemade Pizza',
              prefixIcon: const Icon(Icons.restaurant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Description',
              hintText: 'Describe your food, ingredients, etc.',
              prefixIcon: const Icon(Icons.description),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a description';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pickup Location',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              TextFormField(
                controller: _locationController,
                onChanged: _onAddressChanged,
                onTap: () => setState(() => _showSuggestions = true),
                decoration: InputDecoration(
                  labelText: 'Address',
                  hintText: 'Type your address...',
                  prefixIcon: const Icon(Icons.location_on),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _openPlacesSearch,
                        tooltip: 'Search places',
                      ),
                      if (_isLocationLoading)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.my_location),
                          onPressed: _getCurrentLocation,
                          tooltip: 'Use current location',
                        ),
                      if (_locationController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _locationController.clear();
                              _selectedLocation = null;
                              _showSuggestions = false;
                            });
                          },
                        ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (_selectedLocation == null || _locationController.text.trim().isEmpty) {
                    return 'Please select a pickup location';
                  }
                  return null;
                },
              ),
              if (_showSuggestions && _addressSuggestions.isNotEmpty)
                Positioned(
                  top: 65,
                  left: 0,
                  right: 0,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _addressSuggestions.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: Colors.grey[200],
                        ),
                        itemBuilder: (context, index) {
                          final suggestion = _addressSuggestions[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.location_on,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                            title: Text(
                              suggestion.description,
                              style: const TextStyle(fontSize: 14),
                            ),
                            onTap: () => _selectAddress(suggestion),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the address where people can pick up the food',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.info_outline, size: 12, color: Colors.green[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Type an address or tap 🔍 for full search, 📍 for current location',
                  style: TextStyle(
                    color: Colors.green[600],
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryTagsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dietary Tags',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Help people find food that matches their dietary needs',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DietaryTag.values.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return FilterChip(
                label: Text(tag.displayName),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  });
                },
                selectedColor: Colors.green[100],
                checkmarkColor: Colors.green[700],
                backgroundColor: Colors.grey[100],
                side: BorderSide(
                  color: isSelected ? Colors.green[400]! : Colors.grey[300]!,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpirySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expiry Time',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When should this food be picked up by?',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _selectExpiryTime,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedExpiryTime != null
                          ? 'Expires: ${_formatDateTime(_selectedExpiryTime!)}'
                          : 'Select expiry time',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedExpiryTime != null
                            ? Colors.black87
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupInstructionsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pickup Instructions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Optional: Any special instructions for pickup',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _pickupInstructionsController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g., Ring doorbell, meet at front gate, etc.',
              prefixIcon: const Icon(Icons.info_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
} 