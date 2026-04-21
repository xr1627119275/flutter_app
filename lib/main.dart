import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'order_query_models.dart';
import 'pages/other_orders_page.dart';
import 'widgets/order_details_card.dart';
import 'sgr/sgr_entry.dart';
import 'sgr/utils/storage.dart';
import 'sgr/services/api_service.dart';
import 'sgr/pages/home_page.dart';

/// 全局 navigatorKey，用于在无 BuildContext 的地方（如 ApiService）执行导航
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  ApiService.navigatorKey = navigatorKey;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D5A),
      brightness: Brightness.light,
    );

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Order Tracking',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: colorScheme.onSurface,
          titleTextStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF18212F),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.04)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFD),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          hintStyle: TextStyle(color: Colors.grey.shade500),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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
  OrderQueryResult? _queryResult;
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomePage(roleName: roleName),
        ),
      );
    }
  }

  Future<void> _submitQuery() async {
    final now = DateTime.now();
    if (_sgrLastTapTime != null &&
        now.difference(_sgrLastTapTime!).inSeconds > 2) {
      _sgrTapCount = 0;
    }
    _sgrLastTapTime = now;
    _sgrTapCount++;

    if (_sgrTapCount >= 5) {
      _sgrTapCount = 0;
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
        _queryResult = null;
        _imageLoaded = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _queryResult = null;
      _imageLoaded = false;
    });

    try {
      final url = Uri.parse(
        ApiService.baseUrl + '/mall/mallorder/infoByEmailAndOrderNo?email=${Uri.encodeComponent(email)}&orderNo=$orderNo',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 0 && data['msg'] == 'success') {
          final mallOrder = data['mallOrder'] as Map<String, dynamic>?;
          if (mallOrder != null) {
            final result = OrderQueryResult.fromResponse(
              data as Map<String, dynamic>,
            );
            setState(() {
              _queryResult = result;
              _errorMessage = null;
              _imageLoaded = result.imageUrl.isEmpty;
            });
            if (result.imageUrl.isNotEmpty) {
              _preloadImage(result.imageUrl);
            }
          } else {
            setState(() {
              _errorMessage = 'Order information not found';
              _queryResult = null;
              _imageLoaded = false;
            });
          }
        } else {
          setState(() {
            _errorMessage = data['msg']?.toString() ?? 'Query failed';
            _queryResult = null;
            _imageLoaded = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Query failed: ${response.statusCode}';
          _queryResult = null;
          _imageLoaded = false;
        });
      }
    } catch (e) {
      String errorMsg = 'Query error';
      if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('No address associated with hostname')) {
        errorMsg =
            'Network connection failed, please check your network connection or domain name';
      } else if (e.toString().contains('SocketException')) {
        errorMsg = 'Unable to connect to server, please check your network connection';
      } else if (e.toString().contains('TimeoutException')) {
        errorMsg = 'Request timeout, please try again later';
      } else {
        errorMsg = 'Query error: ${e.toString()}';
      }
      setState(() {
        _errorMessage = errorMsg;
        _queryResult = null;
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

  Future<void> _showImagePreview(String imageUrl) async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 48,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: SafeArea(
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required TextInputType keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C2533),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard() {
    final result = _queryResult;
    if (result == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.otherOrders.isNotEmpty) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OtherOrdersPage(
                      orders: result.otherOrders,
                      onOpenOrder: (order) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OrderDetailsPage(order: order),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.list_alt_outlined),
              label: Text('More Orders (${result.otherOrders.length})'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        OrderDetailsCard(
          result: result,
          imageLoaded: _imageLoaded,
          onPreviewImage: _showImagePreview,
          showMoreOrdersButton: false,
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDFF7EA), Color(0xFFC9EEDC)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF2E7D5A),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Track your order',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF18212F),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Enter your email and order number to view the latest delivery details.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildFormField(
              label: 'Email',
              hint: 'name@example.com',
              icon: Icons.email_outlined,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              label: 'Order Number',
              hint: 'Enter your order number',
              icon: Icons.confirmation_number_outlined,
              controller: _orderNoController,
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitQuery,
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 20),
                        SizedBox(width: 8),
                        Text('Search Order'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    if (_errorMessage == null) {
      return const SizedBox.shrink();
    }

    return Card(
      color: const Color(0xFFFFF4F4),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE05252).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Color(0xFFE05252),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFF9F2D2D),
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
        title: const Text('Secret Garden Rose'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF2F7F3), Color(0xFFF5F7FB), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFormCard(),
                    const SizedBox(height: 16),
                    if (_errorMessage != null) ...[
                      _buildErrorCard(),
                      const SizedBox(height: 16),
                    ],
                    if (_queryResult != null) _buildResultCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
