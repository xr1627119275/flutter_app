import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flower',
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
  final _emailController = TextEditingController(text: 'pollock123@aol.com');
  final _orderNoController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _flowerPictureUrl;
  bool _imageLoaded = false;

  Future<void> _submitQuery() async {
    final email = _emailController.text.trim();
    final orderNo = _orderNoController.text.trim();

    if (email.isEmpty || orderNo.isEmpty) {
      setState(() {
        _errorMessage = '请输入邮箱和订单号';
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
            // 预加载图片
            _preloadImage(imageUrl);
          } else {
            setState(() {
              _errorMessage = '未找到订单信息或图片';
              _flowerPictureUrl = null;
              _imageLoaded = false;
            });
          }
        } else {
          setState(() {
            _errorMessage = data['msg']?.toString() ?? '查询失败';
            _flowerPictureUrl = null;
            _imageLoaded = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = '查询失败: ${response.statusCode}';
          _flowerPictureUrl = null;
          _imageLoaded = false;
        });
      }
    } catch (e) {
      String errorMsg = '查询出错';
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('No address associated with hostname')) {
        errorMsg = '网络连接失败，请检查网络连接或域名是否正确';
      } else if (e.toString().contains('SocketException')) {
        errorMsg = '无法连接到服务器，请检查网络连接';
      } else if (e.toString().contains('TimeoutException')) {
        errorMsg = '请求超时，请稍后重试';
      } else {
        errorMsg = '查询出错: ${e.toString()}';
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
              _errorMessage = '图片加载失败';
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
          _errorMessage = '图片加载出错: $e';
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
            // 订单查询表单卡片
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
            // 结果显示区域
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
            // 显示加载指示器（当图片URL存在但未加载完成时）
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
            // 图片加载完成后显示
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
                      // 显示花束图片
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
                      // 显示文字
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
