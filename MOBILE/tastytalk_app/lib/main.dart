import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup.dart';
import 'menu.dart';
import 'splash_screen.dart';
import 'forgot_password.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const TastyTalkApp());
}

class TastyTalkApp extends StatelessWidget {
  const TastyTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tasty Talk',
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      navigatorObservers: [routeObserver],
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _agreedToTerms = false;
  String _selectedLanguage = 'en-US'; // Default: English

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3642B),
      body: Column(
        children: [
          const SizedBox(height: 80),
          Image.asset('lib/assets/logo.png', height: 200, fit: BoxFit.contain),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 30),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(50),
                  topRight: Radius.circular(50),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      _selectedLanguage == 'en-US' ? "LOGIN" : "MAG-LOGIN",
                      style: const TextStyle(
                        fontSize: 35,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Language Selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _selectedLanguage == 'en-US'
                              ? "Language: "
                              : "Wika: ",
                        ),
                        Row(
                          children: [
                            Radio<String>(
                              value: 'en-US',
                              groupValue: _selectedLanguage,
                              onChanged: (value) {
                                setState(() {
                                  _selectedLanguage = value!;
                                });
                              },
                            ),
                            const Text("English"),
                          ],
                        ),
                        Row(
                          children: [
                            Radio<String>(
                              value: 'fil-PH',
                              groupValue: _selectedLanguage,
                              onChanged: (value) {
                                setState(() {
                                  _selectedLanguage = value!;
                                });
                              },
                            ),
                            const Text("Tagalog"),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),
                    _buildTextField(
                      hint: _selectedLanguage == 'en-US' ? "Email" : "Email",
                      icon: Icons.email,
                      controller: _emailController,
                    ),
                    const SizedBox(height: 25),
                    _buildPasswordField(),

                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _agreedToTerms,
                          onChanged: (value) {
                            setState(() {
                              _agreedToTerms = value ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black,
                              ),
                              children: [
                                TextSpan(
                                  text: _selectedLanguage == 'en-US'
                                      ? "I agree to the "
                                      : "Sumasang-ayon ako sa ",
                                ),
                                TextSpan(
                                  text: _selectedLanguage == 'en-US'
                                      ? "terms and conditions"
                                      : "mga tuntunin at kondisyon",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    // login button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 60,
                          vertical: 15,
                        ),
                      ),
                      onPressed: _login,
                      child: Text(
                        _selectedLanguage == 'en-US' ? "LOGIN" : "MAG-LOGIN",
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    // Forgot Password
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordPage(),
                              ),
                            );
                          },
                          child: Text(
                            _selectedLanguage == 'en-US'
                                ? "Forgot Password?"
                                : "Nakalimutan ang Password?",
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),

                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpPage(),
                          ),
                        );
                      },
                      child: Text.rich(
                        TextSpan(
                          text:
                              _selectedLanguage == 'en-US'
                                  ? "No Account? "
                                  : "Walang Account? ",
                          children: [
                            TextSpan(
                              text:
                                  _selectedLanguage == 'en-US'
                                      ? "Sign Up"
                                      : "Mag-sign Up",
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscureText,
      decoration: InputDecoration(
        hintText: _selectedLanguage == 'en-US' ? "Password" : "Password",
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
          onPressed: () {
            setState(() {
              _obscureText = !_obscureText;
            });
          },
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (!_agreedToTerms) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedLanguage == 'en-US'
                ? "Please agree to the terms and conditions."
                : "Mangyaring sumang-ayon sa mga tuntunin at kondisyon.",
          ),
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedLanguage == 'en-US'
                ? "Login Successful!"
                : "Matagumpay na nag-login!",
          ),
        ),
      );

      // Pass selected language to HomePage or store it globally
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(language: _selectedLanguage),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMessage = '';
      if (e.code == 'user-not-found') {
        errorMessage =
            _selectedLanguage == 'en-US'
                ? 'No user found for that email.'
                : 'Walang user na nahanap para sa email na iyon.';
      } else if (e.code == 'wrong-password') {
        errorMessage =
            _selectedLanguage == 'en-US'
                ? 'Wrong password provided.'
                : 'Maling password ang ibinigay.';
      } else {
        errorMessage =
            _selectedLanguage == 'en-US'
                ? 'An error occurred: ${e.message}'
                : 'May error na nangyari: ${e.message}';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }
}
