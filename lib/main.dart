import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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

class OrderQueryResult {
  const OrderQueryResult({
    required this.product,
    required this.recipient,
    required this.address,
    required this.message,
    required this.status,
    required this.imageUrl,
    required this.otherOrders,
  });

  final String product;
  final String recipient;
  final String address;
  final String message;
  final String status;
  final String imageUrl;
  final List<OtherOrderItem> otherOrders;

  factory OrderQueryResult.fromResponse(Map<String, dynamic> response) {
    final mallOrder = (response['mallOrder'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final otherOrdersJson = response['otherOrders'] as List<dynamic>? ?? const [];

    final recipientParts = [
      mallOrder['fristName']?.toString().trim() ?? '',
      mallOrder['lastName']?.toString().trim() ?? '',
      mallOrder['recipientFirstName']?.toString().trim() ?? '',
      mallOrder['recipientLastName']?.toString().trim() ?? '',
    ].where((part) => part.isNotEmpty).toList();

    final state = _readFirstAvailable(mallOrder, const ['state', 'province']) ?? '';
    final zip = _readFirstAvailable(mallOrder, const ['userZip', 'zipCode']) ?? '';
    final stateZip = [state, zip].where((part) => part.isNotEmpty).join(' ');

    final addressParts = [
      _readFirstAvailable(mallOrder, const ['address', 'address1']),
      mallOrder['address2']?.toString().trim(),
      mallOrder['city']?.toString().trim(),
      stateZip,
    ].where((part) => part != null && part.toString().trim().isNotEmpty).toList();

    return OrderQueryResult(
      product: _readFirstAvailable(mallOrder, const ['productName', 'product']) ?? '-',
      recipient: recipientParts.isNotEmpty
          ? recipientParts.join(' ')
          : (_readFirstAvailable(mallOrder, const ['recipient', 'recipientName']) ?? '-'),
      address: _readFirstAvailable(mallOrder, const ['fullAddress']) ??
          (addressParts.isNotEmpty ? addressParts.join(', ') : '-'),
      message: _normalizeMessage(
            _readFirstAvailable(mallOrder, const ['note', 'message']) ?? '-',
          ),
      status: _readFirstAvailable(mallOrder, const ['orderStatus', 'status']) ?? '-',
      imageUrl: _readFirstAvailable(mallOrder, const ['flowerPicture', 'imageUrl']) ?? '',
      otherOrders: otherOrdersJson
          .whereType<Map<String, dynamic>>()
          .map(OtherOrderItem.fromJson)
          .toList(),
    );
  }

  static String _normalizeMessage(String value) {
    return value
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  static String? _readFirstAvailable(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return null;
  }
}

class OtherOrderItem {
  const OtherOrderItem({
    required this.orderNumber,
    required this.productName,
    required this.status,
    required this.recipient,
    required this.createDate,
  });

  final String orderNumber;
  final String productName;
  final String status;
  final String recipient;
  final String createDate;

  factory OtherOrderItem.fromJson(Map<String, dynamic> json) {
    final recipientParts = [
      json['fristName']?.toString().trim() ?? '',
      json['lastName']?.toString().trim() ?? '',
      json['recipientFirstName']?.toString().trim() ?? '',
      json['recipientLastName']?.toString().trim() ?? '',
    ].where((part) => part.isNotEmpty).toList();

    return OtherOrderItem(
      orderNumber: OrderQueryResult._readFirstAvailable(
            json,
            const ['orderNumber', 'externalId'],
          ) ??
          '-',
      productName: OrderQueryResult._readFirstAvailable(
            json,
            const ['productName', 'product'],
          ) ??
          '-',
      status: OrderQueryResult._readFirstAvailable(
            json,
            const ['orderStatus', 'status'],
          ) ??
          '-',
      recipient: recipientParts.isNotEmpty
          ? recipientParts.join(' ')
          : (OrderQueryResult._readFirstAvailable(
                json,
                const ['recipient', 'recipientName'],
              ) ??
              '-'),
      createDate: json['createDate']?.toString().trim().isNotEmpty == true
          ? json['createDate'].toString().trim()
          : '-',
    );
  }
}

class _InfoItemData {
  const _InfoItemData({
    required this.label,
    required this.value,
    required this.icon,
    this.multiline = false,
    this.trailing,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool multiline;
  final Widget? trailing;
  final bool emphasized;
}

class OtherOrdersPage extends StatelessWidget {
  const OtherOrdersPage({
    super.key,
    required this.orders,
  });

  final List<OtherOrderItem> orders;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More Orders'),
      ),
      body: orders.isEmpty
          ? const Center(
              child: Text(
                'No other orders found',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                order.productName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF18212F),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _OtherOrderStatusChip(status: order.status),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Order No: ${order.orderNumber}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Recipient: ${order.recipient}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Create Time: ${order.createDate}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _OtherOrderStatusChip extends StatelessWidget {
  const _OtherOrderStatusChip({required this.status});

  final String status;

  Color _statusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('delivered')) {
      return const Color(0xFF1F9D61);
    }
    if (normalized.contains('cancel')) {
      return const Color(0xFFE05252);
    }
    if (normalized.contains('out for delivery') || normalized.contains('ready')) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
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
              final result = OrderQueryResult.fromResponse(data as Map<String, dynamic>);
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

  Widget _buildInfoTile(_InfoItemData item) {
    final isCompact = item.label == 'Recipient' || item.label == 'Address';
    final isEmphasized = item.emphasized;

    return Container(
      padding: EdgeInsets.all(isEmphasized ? 14 : (isCompact ? 10 : 12)),
      decoration: BoxDecoration(
        color: isEmphasized ? const Color(0xFFF3FAF6) : const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(isEmphasized ? 18 : (isCompact ? 14 : 16)),
        border: Border.all(
          color: isEmphasized ? const Color(0xFFDCEFE3) : const Color(0xFFE8EDF5),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            item.multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: isEmphasized ? 38 : (isCompact ? 30 : 34),
            height: isEmphasized ? 38 : (isCompact ? 30 : 34),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D5A).withValues(alpha: isEmphasized ? 0.14 : 0.10),
              borderRadius: BorderRadius.circular(isEmphasized ? 12 : 10),
            ),
            child: Icon(
              item.icon,
              color: const Color(0xFF2E7D5A),
              size: isEmphasized ? 20 : 18,
            ),
          ),
          SizedBox(width: isEmphasized ? 12 : (isCompact ? 8 : 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: isEmphasized ? 12 : 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    if (item.trailing != null) ...[
                      const SizedBox(width: 8),
                      item.trailing!,
                    ],
                  ],
                ),
                SizedBox(height: isCompact ? 2 : 4),
                Text(
                  item.value.isEmpty ? '-' : item.value,
                  style: TextStyle(
                    fontSize: isEmphasized ? 15 : (isCompact ? 13 : 14),
                    height: isCompact ? 1.25 : 1.35,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF18212F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('delivered')) {
      return const Color(0xFF1F9D61);
    }
    if (normalized.contains('cancel')) {
      return const Color(0xFFE05252);
    }
    if (normalized.contains('out for delivery') || normalized.contains('ready')) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF64748B);
  }

  Widget _buildStatusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showImagePreview(String imageUrl) {
    showDialog<void>(
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

  Widget _buildImageSection(OrderQueryResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.image_outlined, size: 18, color: Color(0xFF2E7D5A)),
              SizedBox(width: 8),
              Text(
                'Preview Image',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C2533),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (result.imageUrl.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8EDF5)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    size: 40,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No image available',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            )
          else if (!_imageLoaded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 42),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8EDF5)),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            )
          else
            GestureDetector(
              onTap: () => _showImagePreview(result.imageUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.network(
                        result.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.white,
                            child: const Center(
                              child: Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.zoom_out_map,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Preview',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _queryResult;
    if (result == null) {
      return const SizedBox.shrink();
    }

    final primaryItems = [
      _InfoItemData(
        label: 'Product',
        value: result.product,
        icon: Icons.local_florist_outlined,
        trailing: _buildStatusChip(result.status),
        emphasized: true,
      ),
      _InfoItemData(
        label: 'Recipient',
        value: result.recipient,
        icon: Icons.person_outline,
      ),
    ];

    final secondaryItems = [
      _InfoItemData(
        label: 'Address',
        value: result.address,
        icon: Icons.location_on_outlined,
        multiline: true,
      ),
      _InfoItemData(
        label: 'Message',
        value: result.message,
        icon: Icons.chat_bubble_outline,
        multiline: true,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final useTwoColumns = constraints.maxWidth >= 560;

                if (!useTwoColumns) {
                  return Column(
                    children: [
                      ...primaryItems.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildInfoTile(item),
                        ),
                      ),
                      ...secondaryItems.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildInfoTile(item),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildInfoTile(primaryItems[0])),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInfoTile(primaryItems[1])),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...secondaryItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildInfoTile(item),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            _buildImageSection(result),
            if (result.otherOrders.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OtherOrdersPage(orders: result.otherOrders),
                      ),
                    );
                  },
                  icon: const Icon(Icons.list_alt_outlined),
                  label: Text('More Order (${result.otherOrders.length})'),
                ),
              ),
            ],
          ],
        ),
      ),
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
              keyboardType: TextInputType.number,
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
