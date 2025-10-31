import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userEmail;
  String? _userName;
  String? _resetEmail;
  String? _verificationCode;

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  String? get resetEmail => _resetEmail;

  Future<void> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
    _userEmail = prefs.getString('userEmail');
    _userName = prefs.getString('userName');
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));
      
      // Mock validation
      if (email.isNotEmpty && password.isNotEmpty) {
        _isAuthenticated = true;
        _userEmail = email;
        _userName = email.split('@')[0];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isAuthenticated', true);
        await prefs.setString('userEmail', email);
        await prefs.setString('userName', _userName!);
        
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Login error: $e');
      }
      return false;
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));
      
      // Mock validation
      if (name.isNotEmpty && email.isNotEmpty && password.isNotEmpty) {
        _isAuthenticated = true;
        _userEmail = email;
        _userName = name;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isAuthenticated', true);
        await prefs.setString('userEmail', email);
        await prefs.setString('userName', name);
        
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Signup error: $e');
      }
      return false;
    }
  }

  Future<bool> sendResetCode(String email) async {
    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));
      
      // Mock sending verification code
      _resetEmail = email;
      _verificationCode = '123456'; // Mock code
      
      if (kDebugMode) {
        debugPrint('Reset code sent to $email: $_verificationCode');
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Send reset code error: $e');
      }
      return false;
    }
  }

  Future<bool> verifyResetCode(String code) async {
    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));
      
      // Mock verification
      if (code == _verificationCode) {
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Verify code error: $e');
      }
      return false;
    }
  }

  Future<bool> createNewPassword(String password) async {
    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));
      
      // Mock password reset
      if (password.isNotEmpty) {
        _verificationCode = null;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Create password error: $e');
      }
      return false;
    }
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _userEmail = null;
    _userName = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    notifyListeners();
  }

  Future<bool> loginWithGoogle() async {
    // Mock OAuth login
    await Future.delayed(const Duration(seconds: 1));
    return await login('google.user@gmail.com', 'mock_password');
  }

  Future<bool> loginWithApple() async {
    // Mock OAuth login
    await Future.delayed(const Duration(seconds: 1));
    return await login('apple.user@icloud.com', 'mock_password');
  }

  Future<bool> loginWithFacebook() async {
    // Mock OAuth login
    await Future.delayed(const Duration(seconds: 1));
    return await login('facebook.user@facebook.com', 'mock_password');
  }
}
