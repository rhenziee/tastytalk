import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String? _gender;

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _loadingProfile = true;
  bool _savingProfile = false;
  bool _changingPassword = false;

  DatabaseReference? _userRef;
  StreamSubscription<DatabaseEvent>? _userSub;
  String _currentUid = '';
  String _currentAuthEmail = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _bindRealtime();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _birthdayController.dispose();
    _ageController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _bindRealtime() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _currentUid = user.uid;
    _currentAuthEmail = user.email ?? '';

    final root = FirebaseDatabase.instance.ref().child('users');

    // Prefer binding to users/{uid} if it exists
    final byUid = await root.child(user.uid).get();
    DatabaseReference? refToBind;
    if (byUid.exists && byUid.value is Map) {
      refToBind = root.child(user.uid);
    } else {
      // Otherwise, find by email
      final byEmail =
          await root
              .orderByChild('email')
              .equalTo(user.email ?? '')
              .limitToFirst(1)
              .get();
      if (byEmail.exists && byEmail.value is Map) {
        final map = Map<dynamic, dynamic>.from(byEmail.value as Map);
        final firstKey = map.keys.first;
        refToBind = root.child(firstKey.toString());
      }
    }

    if (refToBind == null) {
      setState(() => _loadingProfile = false);
      return;
    }

    _userRef = refToBind;
    _userSub?.cancel();
    _userSub = _userRef!.onValue.listen((event) {
      final snap = event.snapshot;
      if (snap.exists && snap.value is Map) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        setState(() {
          _fullNameController.text = (data['fullName'] ?? '').toString();
          _usernameController.text = (data['username'] ?? '').toString();
          _emailController.text =
              (data['email'] ?? (_currentAuthEmail)).toString();
          _birthdayController.text = (data['birthday'] ?? '').toString();
          _ageController.text = (data['age']?.toString() ?? '');
          _gender = (data['gender'] ?? '') as String?;
          _loadingProfile = false;
        });
      } else {
        if (mounted) setState(() => _loadingProfile = false);
      }
    });
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickBirthday() async {
    DateTime initial =
        DateTime.tryParse(_birthdayController.text) ?? DateTime(2000);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _birthdayController.text = DateFormat('yyyy-MM-dd').format(picked);
      _ageController.text = _calculateAge(picked).toString();
      setState(() {});
    }
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loadingProfile = false);
      return;
    }

    try {
      final db = FirebaseDatabase.instance.ref().child('users');
      // 1) Try by uid
      final byUid = await db.child(user.uid).get();
      if (byUid.exists && byUid.value is Map) {
        final data = Map<String, dynamic>.from(byUid.value as Map);
        _fullNameController.text = (data['fullName'] ?? '').toString();
        _usernameController.text = (data['username'] ?? '').toString();
        _emailController.text =
            (data['email'] ?? (user.email ?? '')).toString();
        _birthdayController.text = (data['birthday'] ?? '').toString();
        _ageController.text = (data['age']?.toString() ?? '');
        _gender = (data['gender'] ?? '') as String?;
      } else {
        // 2) Try query by exact email (normalized)
        final normalizedEmail = (user.email ?? '').trim().toLowerCase();
        final query =
            await db
                .orderByChild('email')
                .equalTo(user.email ?? '')
                .limitToFirst(1)
                .get();
        if (query.exists && query.value is Map) {
          final map = Map<dynamic, dynamic>.from(query.value as Map);
          final firstKey = map.keys.first;
          final data = Map<String, dynamic>.from(
            Map<dynamic, dynamic>.from(map[firstKey] as Map),
          );
          _fullNameController.text = (data['fullName'] ?? '').toString();
          _usernameController.text = (data['username'] ?? '').toString();
          _emailController.text =
              (data['email'] ?? (user.email ?? '')).toString();
          _birthdayController.text = (data['birthday'] ?? '').toString();
          _ageController.text = (data['age']?.toString() ?? '');
          _gender = (data['gender'] ?? '') as String?;
        } else {
          // 3) Full scan: find first by case-insensitive email; else newest createdAt
          final allSnap = await db.get();
          if (allSnap.exists && allSnap.value is Map) {
            final all = Map<dynamic, dynamic>.from(allSnap.value as Map);
            Map<String, dynamic>? picked;
            DateTime? newest;
            for (final entry in all.entries) {
              if (entry.value is Map) {
                final data = Map<String, dynamic>.from(
                  Map<dynamic, dynamic>.from(entry.value as Map),
                );
                final e = (data['email'] ?? '').toString().trim().toLowerCase();
                if (e == normalizedEmail) {
                  picked = data;
                  break;
                }
                final createdStr = (data['createdAt'] ?? '').toString();
                DateTime? created;
                try {
                  if (createdStr.isNotEmpty) {
                    created = DateTime.tryParse(createdStr);
                  }
                } catch (_) {}
                final bool isNewer =
                    newest == null
                        ? true
                        : (created != null && created.isAfter(newest));
                if (created != null && isNewer) {
                  newest = created;
                  picked = data;
                }
              }
            }
            if (picked != null) {
              _fullNameController.text = (picked['fullName'] ?? '').toString();
              _usernameController.text = (picked['username'] ?? '').toString();
              _emailController.text =
                  (picked['email'] ?? (user.email ?? '')).toString();
              _birthdayController.text = (picked['birthday'] ?? '').toString();
              _ageController.text = (picked['age']?.toString() ?? '');
              _gender = (picked['gender'] ?? '') as String?;
            } else {
              // 4) Firestore fallback
              final doc =
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .get();
              if (doc.exists) {
                final data = doc.data() ?? {};
                _fullNameController.text = (data['fullName'] ?? '').toString();
                _usernameController.text = (data['username'] ?? '').toString();
                _emailController.text =
                    (data['email'] ?? (user.email ?? '')).toString();
                _birthdayController.text = (data['birthday'] ?? '').toString();
                _ageController.text = (data['age']?.toString() ?? '');
                _gender = (data['gender'] ?? '') as String?;
              } else {
                _emailController.text = user.email ?? '';
              }
            }
          } else {
            // Nothing under users
            _emailController.text = user.email ?? '';
          }
        }
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final birthday = _birthdayController.text.trim();
    final age = int.tryParse(_ageController.text.trim());
    final gender = _gender ?? '';

    if (fullName.isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        !email.contains('@') ||
        birthday.isEmpty ||
        age == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all fields with valid values.'),
        ),
      );
      return;
    }

    setState(() => _savingProfile = true);
    try {
      // Write to Realtime Database
      await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(user.uid)
          .update({
            'fullName': fullName,
            'username': username,
            'email': email,
            'birthday': birthday,
            'age': age,
            'gender': gender,
            'updatedAt': DateTime.now().toIso8601String(),
          });

      // If email changed, trigger verification email update in Auth
      if (email != (user.email ?? '')) {
        await user.verifyBeforeUpdateEmail(email);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Verification link sent to the new email. Confirm to finish updating.',
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Failed to update profile.';
      if (e.code == 'requires-recent-login') {
        msg = 'Please re-login and try again.';
      } else if (e.message != null && e.message!.isNotEmpty) {
        msg = e.message!;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final current = _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (current.isEmpty || newPass.length < 6 || newPass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check your current and new password (min 6 chars).'),
        ),
      );
      return;
    }

    setState(() => _changingPassword = true);
    try {
      // Reauthenticate
      final cred = EmailAuthProvider.credential(
        email: (user.email ?? ''),
        password: current,
      );
      await user.reauthenticateWithCredential(cred);

      await user.updatePassword(newPass);

      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
    } on FirebaseAuthException catch (e) {
      String msg = 'Failed to change password.';
      if (e.code == 'wrong-password') {
        msg = 'Current password is incorrect.';
      } else if (e.code == 'requires-recent-login') {
        msg = 'Please re-login and try again.';
      } else if (e.message != null && e.message!.isNotEmpty) {
        msg = e.message!;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.orange,
      ),
      body:
          _loadingProfile
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentUid.isNotEmpty) ...[
                      Text(
                        'UID: $_currentUid',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        'Auth email: $_currentAuthEmail',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _birthdayController,
                      readOnly: true,
                      onTap: _pickBirthday,
                      decoration: const InputDecoration(
                        labelText: 'Birthday (yyyy-MM-dd)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ageController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(
                          value: 'Female',
                          child: Text('Female'),
                        ),
                        DropdownMenuItem(
                          value: 'Prefer not to say',
                          child: Text('Prefer not to say'),
                        ),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() => _gender = v),
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _savingProfile ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child:
                            _savingProfile
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text(
                                  'Save Profile',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'Change Password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password (min 6 chars)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _changingPassword ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child:
                            _changingPassword
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text(
                                  'Change Password',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
