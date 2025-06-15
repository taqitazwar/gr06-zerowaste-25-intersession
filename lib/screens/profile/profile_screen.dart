import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../services/auth_service.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../auth/sign_in_screen.dart';
import '../posts/my_posts_screen.dart';
import '../posts/my_claims_screen.dart';
import '../posts/claim_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _nameController = TextEditingController();
  final _imagePicker = ImagePicker();

  UserModel? _userModel;
  bool _isLoading = true;
  bool _isEditingName = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userModel = await _authService.getUserDocument(user.uid);
      setState(() {
        _userModel = userModel;
        _nameController.text = userModel?.name ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateName() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter a valid name', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(_nameController.text.trim());

        // Update in Firestore
        await _authService.updateUserProfile(user.uid, {
          'name': _nameController.text.trim(),
        });

        await _loadUserData();
        setState(() => _isEditingName = false);
        _showSnackBar('Name updated successfully!');
      }
    } catch (e) {
      _showSnackBar('Failed to update name', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 70,
      );

      if (image == null) return;

      setState(() => _isUploadingImage = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user.uid}.jpg');

      final uploadBytes = await image.readAsBytes();
      await storageRef.putData(uploadBytes);
      final downloadUrl = await storageRef.getDownloadURL();

      // Update in Firestore
      await _authService.updateUserProfile(user.uid, {
        'profileImageUrl': downloadUrl,
      });

      await _loadUserData();
      _showSnackBar('Profile image updated successfully!');
    } catch (e) {
      _showSnackBar('Failed to upload image', isError: true);
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _removeProfileImage() async {
    setState(() => _isUploadingImage = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Remove from Firebase Storage
      if (_userModel?.profileImageUrl != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${user.uid}.jpg');
        await storageRef.delete();
      }

      // Update in Firestore
      await _authService.updateUserProfile(user.uid, {'profileImageUrl': null});

      await _loadUserData();
      _showSnackBar('Profile image removed successfully!');
    } catch (e) {
      _showSnackBar('Failed to remove image', isError: true);
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SignInScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showSnackBar('Error signing out. Please try again.', isError: true);
    }
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Profile Image Section
            _buildProfileImageSection(),

            const SizedBox(height: 32),

            // User Info Section
            _buildUserInfoSection(),

            const SizedBox(height: 32),

            // Stats Section
            _buildStatsSection(),

            const SizedBox(height: 32),

            // Manage Posts Section
            _buildManagePostsSection(),

            const SizedBox(height: 32),

            // Settings Section
            _buildSettingsSection(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: AppColors.primary,
              backgroundImage: _userModel?.profileImageUrl != null
                  ? NetworkImage(_userModel!.profileImageUrl!)
                  : null,
              child: _userModel?.profileImageUrl == null
                  ? Text(
                      _userModel?.name.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : null,
            ),
            if (_isUploadingImage)
              const Positioned.fill(
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.black54,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.onPrimary,
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                child: IconButton(
                  onPressed: _isUploadingImage ? null : _showImageOptions,
                  icon: const Icon(
                    Icons.camera_alt,
                    color: AppColors.onPrimary,
                    size: 20,
                  ),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _userModel?.name ?? 'User',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _userModel?.email ?? '',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildUserInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Personal Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _isEditingName = !_isEditingName),
                  icon: Icon(
                    _isEditingName ? Icons.close : Icons.edit,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isEditingName) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _updateName(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      _nameController.text = _userModel?.name ?? '';
                      setState(() => _isEditingName = false);
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _updateName,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ] else ...[
              ListTile(
                leading: const Icon(
                  Icons.person_outline,
                  color: AppColors.primary,
                ),
                title: const Text('Full Name'),
                subtitle: Text(_userModel?.name ?? 'Not set'),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: const Icon(
                  Icons.email_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Email'),
                subtitle: Text(_userModel?.email ?? 'Not set'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Stats',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.restaurant,
                    label: 'Posts Shared',
                    value: '0', // TODO: Get actual count from Firestore
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.check_circle,
                    label: 'Food Claimed',
                    value: '0', // TODO: Get actual count from Firestore
                    color: AppColors.secondary,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.star,
                    label: 'Rating',
                    value: _userModel?.rating.toStringAsFixed(1) ?? '0.0',
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildManagePostsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage Posts',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.restaurant, color: AppColors.primary),
              ),
              title: const Text('My Food Posts'),
              subtitle: const Text('View, edit, and delete your shared food'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyPostsScreen(),
                  ),
                );
              },
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.handshake, color: AppColors.warning),
              ),
              title: const Text('My Claims'),
              subtitle: const Text('Manage your active food claims'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyClaimsScreen(),
                  ),
                );
              },
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.history, color: AppColors.secondary),
              ),
              title: const Text('Claim History'),
              subtitle: const Text('View food you\'ve claimed from others'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ClaimHistoryScreen(),
                  ),
                );
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.notifications_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Notifications'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to notification settings
              },
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(
                Icons.privacy_tip_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Privacy'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to privacy settings
              },
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: AppColors.primary),
              title: const Text('Help & Support'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Navigate to help
              },
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: _signOut,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Profile Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: AppColors.primary,
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
              if (_userModel?.profileImageUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: AppColors.error),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfileImage();
                  },
                ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
