import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'utils/storage.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';

/// SGR 应用入口 - SplashPage
/// 检查登录状态，已登录跳转 HomePage，未登录跳转 LoginPage
class SgrSplashPage extends StatefulWidget {
  const SgrSplashPage({super.key});

  @override
  State<SgrSplashPage> createState() => _SgrSplashPageState();
}

class _SgrSplashPageState extends State<SgrSplashPage> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Initialize token
    final token = await Storage.getToken();
    if (token != null) {
      ApiService.setToken(token);
    }

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    final roleName = await Storage.getRoleName();

    if (token != null && roleName != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomePage(roleName: roleName),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.local_florist,
              size: 80,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 16),
            const Text(
              'Secret Garden Rose',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
