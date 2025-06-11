import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controllers/user_controller.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Form keys
  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  // Controllers
  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();
  final _signUpNameController = TextEditingController();
  final _signUpEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // State
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    
    _tabController.addListener(() {
      setState(() {
        _errorMessage = null;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _signUpNameController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_signInFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _signInEmailController.text.trim(),
        password: _signInPasswordController.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signUp() async {
    if (!_signUpFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _signUpEmailController.text.trim(),
        password: _signUpPasswordController.text,
      );

      // Update display name
      await credential.user?.updateDisplayName(_signUpNameController.text.trim());
      
      // Create user profile in Firestore
      await UserController.createUserProfile(
        userId: credential.user!.uid,
        email: _signUpEmailController.text.trim(),
        displayName: _signUpNameController.text.trim(),
      );

    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password should be at least 6 characters';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'Authentication failed. Please try again';
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _signUpPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green[400]!,
              Colors.green[600]!,
              Colors.green[700]!,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: keyboardVisible ? 20 : 40,
                ),
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                    minHeight: 500,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      _buildTabBar(),
                      _buildTabContent(),
                      if (_errorMessage != null) _buildErrorMessage(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green[400]!,
                  Colors.green[600]!,
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.recycling,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'ZeroWaste',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share food, reduce waste, build community',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(
            height: 50,
            child: Text('Sign In', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          Tab(
            height: 50,
            child: Text('Sign Up', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[500]!, Colors.green[600]!],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor: MaterialStateProperty.all(Colors.transparent),
      ),
    );
  }

  Widget _buildTabContent() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _tabController.index == 0 ? 320 : 450,
      padding: const EdgeInsets.all(24),
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildSignInForm(),
          _buildSignUpForm(),
        ],
      ),
    );
  }

  Widget _buildSignInForm() {
    return Form(
      key: _signInFormKey,
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildTextField(
            controller: _signInEmailController,
            validator: _validateEmail,
            keyboardType: TextInputType.emailAddress,
            labelText: 'Email Address',
            prefixIcon: Icons.email_outlined,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _signInPasswordController,
            validator: _validatePassword,
            obscureText: _obscurePassword,
            labelText: 'Password',
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: Colors.grey[600],
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 32),
          _buildActionButton(
            text: 'Sign In',
            onPressed: _isLoading ? null : _signIn,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              // Add forgot password functionality later
            },
            child: Text(
              'Forgot Password?',
              style: TextStyle(
                color: Colors.green[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    return Form(
      key: _signUpFormKey,
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildTextField(
            controller: _signUpNameController,
            validator: _validateName,
            labelText: 'Full Name',
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 18),
          _buildTextField(
            controller: _signUpEmailController,
            validator: _validateEmail,
            keyboardType: TextInputType.emailAddress,
            labelText: 'Email Address',
            prefixIcon: Icons.email_outlined,
          ),
          const SizedBox(height: 18),
          _buildTextField(
            controller: _signUpPasswordController,
            validator: _validatePassword,
            obscureText: _obscurePassword,
            labelText: 'Password',
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: Colors.grey[600],
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 18),
          _buildTextField(
            controller: _confirmPasswordController,
            validator: _validateConfirmPassword,
            obscureText: _obscureConfirmPassword,
            labelText: 'Confirm Password',
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: Colors.grey[600],
              ),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          const SizedBox(height: 32),
          _buildActionButton(
            text: 'Create Account',
            onPressed: _isLoading ? null : _signUp,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String? Function(String?) validator,
    required String labelText,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(
          color: Colors.grey[600],
          fontSize: 16,
        ),
        prefixIcon: Icon(
          prefixIcon,
          color: Colors.grey[600],
          size: 22,
        ),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.green[500]!, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback? onPressed,
    required bool isLoading,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: onPressed != null
              ? [Colors.green[500]!, Colors.green[600]!]
              : [Colors.grey[300]!, Colors.grey[400]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    text,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[600], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[700], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
} 