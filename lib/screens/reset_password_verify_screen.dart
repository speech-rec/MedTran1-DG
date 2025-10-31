import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ResetPasswordVerifyScreen extends StatefulWidget {
  const ResetPasswordVerifyScreen({super.key});

  @override
  State<ResetPasswordVerifyScreen> createState() => _ResetPasswordVerifyScreenState();
}

class _ResetPasswordVerifyScreenState extends State<ResetPasswordVerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.verifyResetCode(_codeController.text.trim());

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code verified successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushNamed('/create-new-password');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid verification code. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Verify Code'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.verified_user,
                    size: 40,
                    color: Color(0xFF4A90E2),
                  ),
                ),
                const SizedBox(height: 30),
                // Title
                const Text(
                  'Verify Code',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please enter the verification code sent to your email address.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 40),
                // Code Field
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Verification Code',
                    prefixIcon: Icon(Icons.pin),
                    hintText: 'Enter 6-digit code',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the verification code';
                    }
                    if (value.length < 4) {
                      return 'Please enter a valid code';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                // Verify Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleVerifyCode,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Verify', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 20),
                // Resend Code
                Center(
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code resent to your email')),
                      );
                    },
                    child: const Text(
                      'Resend Code',
                      style: TextStyle(color: Color(0xFF4A90E2)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
