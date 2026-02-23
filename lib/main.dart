import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'sgr/sgr_entry.dart';
import 'sgr/utils/storage.dart';
import 'sgr/services/api_service.dart';
import 'sgr/pages/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Order Tracking',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const OrderQueryPage(),
    );
  }
}

class OrderQueryPage extends StatefulWidget {
  const OrderQueryPage({super.key});

  @override
  State<OrderQueryPage> createState() => _OrderQueryPageState();
}

class _OrderQueryPageState extends State<OrderQueryPage> {
  final _emailController = TextEditingController(text: '');
  final _orderNoController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _flowerPictureUrl;
  bool _imageLoaded = false;

  // SGR 5次点击计数器
  int _sgrTapCount = 0;
  DateTime? _sgrLastTapTime;

  @override
  void initState() {
    super.initState();
    _checkSgrLogin();
  }

  /// 启动时检查是否已登录 SGR，已登录则自动跳转
  Future<void> _checkSgrLogin() async {
    final token = await Storage.getToken();
    final roleName = await Storage.getRoleName();
    if (token != null && roleName != null && mounted) {
      ApiService.setToken(token);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => HomePage(roleName: roleName),
        ),
      );
    }
  }

  Future<void> _submitQuery() async {
    // SGR 5次点击检测
    final now = DateTime.now();
    if (_sgrLastTapTime != null &&
        now.difference(_sgrLastTapTime!).inSeconds > 2) {
      _sgrTapCount = 0;
    }
    _sgrLastTapTime = now;
    _sgrTapCount++;

    if (_sgrTapCount >= 5) {
      _sgrTapCount = 0;
      // 检查是否已登录，已登录直接进入 HomePage
      final token = await Storage.getToken();
      final roleName = await Storage.getRoleName();
      if (token != null && roleName != null) {
        ApiService.setToken(token);
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => HomePage(roleName: roleName),
            ),
          );
        }
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const SgrSplashPage(),
          ),
        );
      }
      return;
    }

    final email = _emailController.text.trim();
    final orderNo = _orderNoController.text.trim();

    if (email.isEmpty || orderNo.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter email and order number';
        _flowerPictureUrl = null;
        _imageLoaded = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _flowerPictureUrl = null;
      _imageLoaded = false;
    });

    try {
      final url = Uri.parse(
        'https://preprod.hellosecretgarden.com/south-fast/mall/mallorder/infoByEmailAndOrderNo?email=${Uri.encodeComponent(email)}&orderNo=$orderNo',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 0 && data['msg'] == 'success') {
          final mallOrder = data['mallOrder'] as Map<String, dynamic>?;
          if (mallOrder != null && mallOrder['flowerPicture'] != null) {
            final imageUrl = mallOrder['flowerPicture'] as String;
            setState(() {
              _flowerPictureUrl = imageUrl;
              _errorMessage = null;
              _imageLoaded = false;
            });
            // Preload image
            _preloadImage(imageUrl);
          } else {
            setState(() {
              _errorMessage = 'Order information or image not found';
              _flowerPictureUrl = null;
              _imageLoaded = false;
            });
          }
        } else {
          setState(() {
            _errorMessage = data['msg']?.toString() ?? 'Query failed';
            _flowerPictureUrl = null;
            _imageLoaded = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Query failed: ${response.statusCode}';
          _flowerPictureUrl = null;
          _imageLoaded = false;
        });
      }
    } catch (e) {
      String errorMsg = 'Query error';
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('No address associated with hostname')) {
        errorMsg = 'Network connection failed, please check your network connection or domain name';
      } else if (e.toString().contains('SocketException')) {
        errorMsg = 'Unable to connect to server, please check your network connection';
      } else if (e.toString().contains('TimeoutException')) {
        errorMsg = 'Request timeout, please try again later';
      } else {
        errorMsg = 'Query error: ${e.toString()}';
      }
      setState(() {
        _errorMessage = errorMsg;
        _flowerPictureUrl = null;
        _imageLoaded = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _preloadImage(String imageUrl) async {
    try {
      final imageProvider = NetworkImage(imageUrl);
      final imageStream = imageProvider.resolve(const ImageConfiguration());
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          if (mounted) {
            setState(() {
              _imageLoaded = true;
            });
          }
          imageStream.removeListener(listener);
        },
        onError: (exception, stackTrace) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Image loading failed';
              _imageLoaded = false;
            });
          }
          imageStream.removeListener(listener);
        },
      );
      imageStream.addListener(listener);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Image loading error: $e';
          _imageLoaded = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _orderNoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Order Query'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Order query form card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Email:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Order Number:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _orderNoController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.green),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.green, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitQuery,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Submit',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Result display area
            if (_errorMessage != null)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ),
            // Show loading indicator (when image URL exists but not loaded)
            if (_flowerPictureUrl != null && !_imageLoaded)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            // Display after image is loaded
            if (_flowerPictureUrl != null && _imageLoaded)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Display flower image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _flowerPictureUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Icon(Icons.error, size: 48, color: Colors.red),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Display text
                      const Text(
                        'This is the arrangement that we have prepared for your recipient!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
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
