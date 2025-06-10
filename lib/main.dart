import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZeroWaste',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const HomePage();
        }
        return const AuthScreen();
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String error = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> signInWithGoogle() async {
    setState(() => error = '');
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User aborted sign-in
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      setState(() => error = 'Google sign-in failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(32),
            width: 400,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.deepPurple,
                  child: Icon(Icons.map, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 18),
                const Text(
                  "ZeroWaste",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Share surplus food in your community. Discover or post nearby food items on an interactive map.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(child: Text('Log In', style: TextStyle(color: Colors.black))),
                      Tab(child: Text('Sign Up', style: TextStyle(color: Colors.black))),
                    ],
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 320,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLogin(context),
                      _buildSignUp(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogin(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: const Text("Email", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            hintText: "Enter your email",
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            fillColor: Colors.grey[50],
            filled: true,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: const Text("Password", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: "Enter your password",
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            fillColor: Colors.grey[50],
            filled: true,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              // TODO: implement forgot password
            },
            child: const Text(
              "Forgot Password?",
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
        if (error.isNotEmpty)
          Text(error, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              setState(() => error = '');
              try {
                await FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: _emailController.text.trim(),
                  password: _passwordController.text,
                );
              } catch (e) {
                setState(() => error = 'Login failed: $e');
              }
            },
            child: const Text("Log In"),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: const [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.0),
              child: Text("or"),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.g_mobiledata, size: 26),
            label: const Text("Continue with Google"),
            onPressed: signInWithGoogle,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "By continuing, you agree to our Terms of Service and Privacy Policy",
          style: TextStyle(fontSize: 11, color: Colors.black54),
          textAlign: TextAlign.center,
        )
      ],
    );
  }

  Widget _buildSignUp(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: const Text("Email", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            hintText: "Enter your email",
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            fillColor: Colors.grey[50],
            filled: true,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: const Text("Password", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: "Enter your password",
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            fillColor: Colors.grey[50],
            filled: true,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              setState(() => error = '');
              try {
                await FirebaseAuth.instance.createUserWithEmailAndPassword(
                  email: _emailController.text.trim(),
                  password: _passwordController.text,
                );
              } catch (e) {
                setState(() => error = 'Sign up failed: $e');
              }
            },
            child: const Text("Sign Up"),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: const [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.0),
              child: Text("or"),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.g_mobiledata, size: 26),
            label: const Text("Continue with Google"),
            onPressed: signInWithGoogle,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "By continuing, you agree to our Terms of Service and Privacy Policy",
          style: TextStyle(fontSize: 11, color: Colors.black54),
          textAlign: TextAlign.center,
        )
      ],
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZeroWaste Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('Welcome to ZeroWaste!'),
            SizedBox(height: 24),
            PlaceholderButton(text: 'Post Food'),
            PlaceholderButton(text: 'Map View'),
            PlaceholderButton(text: 'Chat'),
            PlaceholderButton(text: 'My Claims'),
          ],
        ),
      ),
    );
  }
}

class PlaceholderButton extends StatelessWidget {
  final String text;
  const PlaceholderButton({required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: OutlinedButton(
        onPressed: () {},
        child: Text(text),
      ),
    );
  }
}
