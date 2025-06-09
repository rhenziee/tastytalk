import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'main.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  String? _selectedGender;
  bool agreeTerms = false;

  Future<void> _selectBirthday(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthdayController.text = DateFormat('yyyy-MM-dd').format(picked);
        _ageController.text = _calculateAge(picked).toString();
      });
    }
  }

  int _calculateAge(DateTime birthDate) {
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  bool isEmailValid(String email) {
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
    );
    return emailRegex.hasMatch(email);
  }

  Future<void> _signUpUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must agree to the terms and conditions'),
        ),
      );
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      String uid = userCredential.user!.uid;

      DatabaseReference userRef = FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(uid);

      await userRef.set({
        'fullName': fullNameController.text.trim(),
        'username': usernameController.text.trim(),
        'email': emailController.text.trim(),
        'birthday': _birthdayController.text.trim(),
        'age': int.parse(_ageController.text),
        'gender': _selectedGender ?? '',
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign-up successful!')));

      // Navigate to login page after success
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String errorMsg =
          e.code == 'email-already-in-use'
              ? 'This email is already registered.'
              : (e.message ?? 'Registration failed');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMsg)));
    }
  }

  @override
  void dispose() {
    _birthdayController.dispose();
    _ageController.dispose();
    fullNameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3642B),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Image.asset(
              'lib/assets/logo.png',
              height: 150,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Full Name
                    TextFormField(
                      controller: fullNameController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.person_outline),
                        hintText: 'Full Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Full name is required';
                        }
                        final nameRegex = RegExp(r'^[a-zA-Z\s]+$');
                        if (!nameRegex.hasMatch(value.trim())) {
                          return 'Full name must contain letters and spaces only';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Birthday
                    TextFormField(
                      controller: _birthdayController,
                      readOnly: true,
                      onTap: () => _selectBirthday(context),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.calendar_today),
                        hintText: 'Birthday',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Birthday is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Age
                    TextFormField(
                      controller: _ageController,
                      readOnly: true,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.numbers),
                        hintText: 'Age',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Age is required';
                        }
                        int age = int.tryParse(value) ?? 0;
                        if (age <= 17) {
                          return 'You must be at least 18 years old';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Gender
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      items:
                          ['Male', 'Female', 'Prefer not to say', 'Other']
                              .map(
                                (gender) => DropdownMenuItem(
                                  value: gender,
                                  child: Text(gender),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value;
                        });
                      },
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.wc),
                        hintText: 'Gender',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      validator: (value) {
                        if (value == null) {
                          return 'Please select gender';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Username
                    TextFormField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.person),
                        hintText: 'Username',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Username is required';
                        }
                        if (value.length < 4) {
                          return 'Username must be at least 4 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Email
                    TextFormField(
                      controller: emailController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.email),
                        hintText: 'Email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!isEmailValid(value.trim())) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Password
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock),
                        hintText: 'Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Confirm Password
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock_outline),
                        hintText: 'Confirm Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      validator: (value) {
                        if (value != passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Terms Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: agreeTerms,
                          onChanged: (value) {
                            setState(() {
                              agreeTerms = value ?? false;
                            });
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'I agree to the terms and conditions',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Sign Up Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _signUpUser,
                        child: const Text(
                          'SIGN UP',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Already have an account? "),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Login',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
