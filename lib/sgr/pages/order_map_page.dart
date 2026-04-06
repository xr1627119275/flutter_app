import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/order.dart';
import '../services/api_service.dart';
import '../utils/storage.dart';
import '../widgets/order_card_sheet.dart';
import '../services/stomp_service.dart';
import 'order_list_page.dart';
import 'order_operation_page.dart';

class OrderMapPage extends StatefulWidget {
  const OrderMapPage({super.key});

  @override
  State<OrderMapPage> createState() => _OrderMapPageState();
}

class _OrderMapPageState extends State<OrderMapPage> {
  GoogleMapController? _mapController;
  String? _roleName;
  bool _disposed = false;
  static const String _mapStyle = '''
[
  {
    "featureType": "poi",
    "stylers": [
      { "visibility": "off" }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "labels.icon",
    "stylers": [
      { "visibility": "off" }
    ]
  }
]
''';

  bool get _isAdmin =>
      _roleName == '管理员' || _roleName == 'Admin' || _roleName == 'Administrator';

  List<Order> _orders = [];
  List<OrderStatus> _statusList = [];
  List<DeliveryPerson> _deliveryList = [];
  List<FloristPerson> _floristList = [];
  Set<Marker> _markers = {};
  bool _isLoading = true;
  String _selectedDay = 'today';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String _searchTags = '';

  // 筛选
  bool _excludeDelivered = false;
  final Set<String> _selectedStatuses = {};
  static const List<String> _allStatuses = [
    'New Order',
    'Ready for Delivery',
    'Out for Delivery',
    'Delivered',
    'Canceled',
  ];

  @override
  void initState() {
    super.initState();
    _initLoad();
    _initStomp();
  }

  void _initStomp() {
    StompService().connect(
      () {
        if (!mounted || _disposed) return;
        print('[OrderMapPage] STOMP connected successfully.');
        // Subscribe to order changes
        StompService.subscribe('/topic/orderChange', (data) {
          print('[OrderMapPage] Received /topic/orderChange: $data');
          if (!mounted || _disposed) return;
          _loadOrders();
        });

        // Subscribe to new orders
        StompService.subscribe('/topic/orderAdd', (data) {
          print('[OrderMapPage] Received /topic/orderAdd: $data');
          if (!mounted || _disposed) return;
          _loadOrders();
        });
      },
      (error) {
        if (!mounted || _disposed) return;
        print('[OrderMapPage] STOMP connection error: $error');
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _mapController = null;
    StompService.disconnect();
    super.dispose();
  }

  Future<void> _initLoad() async {
    await _loadInitialData();
    _loadOrders();
  }
  
  Future<void> _loadInitialData() async {
    try {
      final roleName = await Storage.getRoleName();
      final results = await Future.wait([
        ApiService.getStatusList(),
        ApiService.getDeliveryList(),
        ApiService.getFloristList(),
      ]);
      if (!mounted || _disposed) return;
      setState(() {
        _roleName = roleName;
        _statusList = results[0] as List<OrderStatus>;
        _deliveryList = results[1] as List<DeliveryPerson>;
        _floristList = results[2] as List<FloristPerson>;
      });
    } catch (e) {
      print('Error loading initial data: $e');
    }
  }

  Future<void> _loadOrders() async {
    if (!mounted || _disposed) return;
    setState(() {
      _isLoading = true;
    });

    try {
      String? startDate;
      String? endDate;

      final now = DateTime.now();
      switch (_selectedDay) {
        case 'today':
          startDate = _formatDate(now);
          endDate = startDate;
          break;
        case 'yesterday':
          final yesterday = now.subtract(const Duration(days: 1));
          startDate = _formatDate(yesterday);
          endDate = startDate;
          break;
        case 'tomorrow':
          final tomorrow = now.add(const Duration(days: 1));
          startDate = _formatDate(tomorrow);
          endDate = startDate;
          break;
        case 'custom':
          if (_customStartDate != null) {
            startDate = _formatDate(_customStartDate!);
            endDate = _customEndDate != null
                ? _formatDate(_customEndDate!)
                : startDate;
          }
          break;
        default:
          startDate = null;
          endDate = null;
          break;
      }

      final response = await ApiService.getOrderList(
        page: 1,
        limit: 300,
        startDate: startDate,
        endDate: endDate,
        tags: _searchTags.isNotEmpty ? _searchTags : null,
        fulfillment: '0',
        orderZip: false,
      );
      if (!mounted || _disposed) return;

      if (response.code == 0) {
        setState(() {
          _orders = response.page.list;
        });
        await _updateMarkers();
      } else {
        _showError(response.msg);
      }
    } catch (e) {
      if (!mounted || _disposed) return;
      _showError('Failed to load orders: $e');
    } finally {
      if (!mounted || _disposed) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _updateMarkers() async {
    final markers = <Marker>{};
    final filtered = _filteredOrders;

    for (int index = 0; index < filtered.length; index++) {
      if (!mounted || _disposed) return;
      final order = filtered[index];
      if (order.latitude != null && 
          order.longitude != null &&
          order.latitude! != 0 && 
          order.longitude! != 0) {
        try {
          final icon = await _createMarkerIcon(order, index + 1);
          
          markers.add(
            Marker(
              markerId: MarkerId(order.orderNumber),
              position: LatLng(order.latitude!, order.longitude!),
              icon: icon,
              onTap: () {
                _showOrderCard(order);
              },
            ),
          );
        } catch (e) {
          print('Error creating marker for order ${order.orderNumber}: $e');
        }
      }
    }

    setState(() {
      _markers = markers;
    });

    // Keep camera fixed to the configured center/zoom; do not auto-fit all markers.
  }

  // 判断订单日期类型
  // 1 = 今天, 2 = 明天(next day), 3 = 其他跨天, 0 = 默认
  int _getNowDate(Order order) {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final tomorrowDate = todayDate.add(const Duration(days: 1));
    
    // 根据 selectedDay 确定订单日期
    DateTime orderDate;
    switch (_selectedDay) {
      case 'today':
        orderDate = todayDate;
        break;
      case 'yesterday':
        orderDate = todayDate.subtract(const Duration(days: 1));
        break;
      case 'tomorrow':
        orderDate = tomorrowDate;
        break;
      default:
        orderDate = todayDate;
    }
    
    if (orderDate == todayDate) {
      return 1; // 今天
    } else if (orderDate == tomorrowDate) {
      return 2; // 明天 (next day) - 显示 N
    } else {
      return 3; // 其他跨天
    }
  }
  
  // 判断是否是 next day 订单
  bool _isNextDay(Order order) {
    return _getNowDate(order) == 2;
  }

  // 获取 marker 颜色
  Color _getMarkerColor(Order order) {
    final status = order.orderStatus?.toLowerCase() ?? '';
    
    // Delivered - 红色
    if (status == 'delivered') {
      return Colors.red;
    }
    
    // Cancelled/Canceled - 黑色
    if (status == 'cancelled' || status == 'canceled') {
      return Colors.black;
    }
    
    // 根据日期类型返回颜色
    final nowDate = _getNowDate(order);
    if (nowDate == 2) {
      return Colors.orange; // Next day - 橙色
    } else if (nowDate == 3) {
      return Colors.orange; // 其他跨天 - 橙色
    } else if (nowDate == 1) {
      return Colors.green; // 今天 - 绿色
    }
    
    return Colors.blue; // 默认 - 蓝色
  }

  // 查找订单对应的 driver
  DeliveryPerson? _findDeliveryPerson(Order order) {
    if (order.delivery == null || order.delivery == 0) return null;
    try {
      return _deliveryList.firstWhere((d) => d.id == order.delivery);
    } catch (e) {
      return null;
    }
  }

  bool _shouldShowDriverImage(Order order) {
    final status = order.orderStatus?.toLowerCase() ?? '';
    final isDeliveredOrCancelled = status == 'delivered' || 
                                    status == 'cancelled' || 
                                    status == 'canceled';
    
    if (isDeliveredOrCancelled) return false;
    
    final driver = _findDeliveryPerson(order);
    return driver != null && driver.img != null && driver.img!.isNotEmpty;
  }

  // 创建 marker icon
  Future<BitmapDescriptor> _createMarkerIcon(Order order, int number) async {
    final isMail = order.tags?.toLowerCase().contains('mail') ?? false;
    final isOutForDelivery = order.orderStatus?.toLowerCase() == 'out for delivery';
    final isNextDay = _isNextDay(order);
    final color = _getMarkerColor(order);

    // 构建标签：orderNumber + driverName
    final driver = _findDeliveryPerson(order);
    final driverName = driver?.name ?? '';
    final tag = order.tags ?? '';
    final labelParts = [
      '#${order.orderNumber}',
      if (tag.isNotEmpty) tag,
      if (driverName.isNotEmpty) driverName,
    ];
    final label = labelParts.join(' ');

    // 检查是否应该显示 driver 图片
    if (_shouldShowDriverImage(order)) {
      if (driver != null && driver.img != null && driver.img!.isNotEmpty) {
        try {
          return await _createDriverMarkerIcon(driver.img!, isOutForDelivery, number, label);
        } catch (e) {
          print('Error loading driver image: $e');
        }
      }
    }

    const double scale = 3.0;
    const double pinW = 24.0;
    const double pinH = 32.0;
    const double labelFontSize = 6.0;
    const double labelPadH = 3.0;
    const double labelPadV = 2.0;
    const double gap = 2.0;

    // 测量标签
    final labelTp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.black87,
          fontSize: labelFontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );
    labelTp.layout(maxWidth: 100);

    final labelBgW = labelTp.width + labelPadH * 2;
    final labelBgH = labelTp.height + labelPadV * 2;
    final double logicalW = math.max(pinW, labelBgW);
    final double logicalH = pinH + gap + labelBgH;
    final double w = logicalW * scale;
    final double h = logicalH * scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);

    final centerX = logicalW / 2;
    final circleRadius = pinW / 2 - 2;
    final circleY = circleRadius + 2;

    // 绘制 pin 形状
    final pinPath = Path();
    pinPath.addOval(Rect.fromCircle(
      center: Offset(centerX, circleY),
      radius: circleRadius,
    ));
    pinPath.moveTo(centerX - circleRadius * 0.55, circleY + circleRadius * 0.75);
    pinPath.lineTo(centerX, pinH - 1);
    pinPath.lineTo(centerX + circleRadius * 0.55, circleY + circleRadius * 0.75);
    pinPath.close();

    canvas.drawPath(pinPath, Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true);

    canvas.drawPath(pinPath, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..isAntiAlias = true);

    if (isOutForDelivery) {
      canvas.drawCircle(
        Offset(centerX, circleY),
        circleRadius + 2,
        Paint()
          ..color = Colors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..isAntiAlias = true,
      );
    }

    if (_isAdmin) {
      canvas.drawCircle(
        Offset(centerX, circleY),
        3,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    } else {
      final numberText = number.toString();
      final tp = TextPainter(
        text: TextSpan(
          text: numberText,
          style: TextStyle(
            color: Colors.white,
            fontSize: numberText.length > 2 ? 7 : 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(centerX - tp.width / 2, circleY - tp.height / 2));
    }

    // 标签背景
    final labelY = pinH + gap;
    final labelBgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, labelY + labelBgH / 2),
        width: labelBgW,
        height: labelBgH,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(labelBgRect, Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill);
    canvas.drawRRect(labelBgRect, Paint()
      ..color = Colors.grey.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5);
    labelTp.paint(canvas, Offset(centerX - labelTp.width / 2, labelY + labelPadV));

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.bytes(bytes, imagePixelRatio: scale);
  }

  // 创建 driver 图片 marker
  Future<BitmapDescriptor> _createDriverMarkerIcon(String imageUrl, bool isOutForDelivery, int number, String label) async {
    const double scale = 3.0;
    const double avatarSize = 28.0;
    final double pxAvatarSize = avatarSize * scale; // 84
    final double imgSize = isOutForDelivery ? pxAvatarSize - 18 : pxAvatarSize - 6;
    const double labelFontSize = 18.0; // 实际像素（不经过 scale）
    const double labelPadH = 8.0;
    const double labelPadV = 4.0;
    const double gap = 4.0;

    // 测量标签（实际像素坐标）
    final labelTp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.black87,
          fontSize: labelFontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );
    labelTp.layout(maxWidth: 300);

    final labelBgW = labelTp.width + labelPadH * 2;
    final labelBgH = labelTp.height + labelPadV * 2;
    final double totalW = math.max(pxAvatarSize, labelBgW);
    final double totalH = pxAvatarSize + gap + labelBgH;

    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to load image');
    }
    
    final codec = await ui.instantiateImageCodec(
      response.bodyBytes,
      targetWidth: imgSize.toInt(),
      targetHeight: imgSize.toInt(),
    );
    final frame = await codec.getNextFrame();
    final driverImage = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final centerX = totalW / 2;
    final avatarCenterY = pxAvatarSize / 2;
    final center = Offset(centerX, avatarCenterY);
    final radius = imgSize / 2;

    if (isOutForDelivery) {
      canvas.drawCircle(
        center,
        pxAvatarSize / 2 - 3,
        Paint()
          ..color = Colors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0
          ..isAntiAlias = true,
      );
    }

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    final srcRect = Rect.fromLTWH(0, 0, driverImage.width.toDouble(), driverImage.height.toDouble());
    final dstRect = Rect.fromCenter(center: center, width: imgSize, height: imgSize);
    canvas.drawImageRect(driverImage, srcRect, dstRect, Paint()..isAntiAlias = true);
    canvas.restore();

    canvas.drawCircle(center, radius, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..isAntiAlias = true);

    if (!_isAdmin) {
      final badgeRadius = 10.0;
      final badgeCenter = Offset(centerX + pxAvatarSize / 2 - badgeRadius - 2, avatarCenterY + pxAvatarSize / 2 - badgeRadius - 2);
      canvas.drawCircle(badgeCenter, badgeRadius, Paint()
        ..color = Colors.deepPurple
        ..style = PaintingStyle.fill
        ..isAntiAlias = true);
      canvas.drawCircle(badgeCenter, badgeRadius, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..isAntiAlias = true);

      final numberText = number.toString();
      final tp = TextPainter(
        text: TextSpan(
          text: numberText,
          style: TextStyle(
            color: Colors.white,
            fontSize: numberText.length > 2 ? 9 : 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(badgeCenter.dx - tp.width / 2, badgeCenter.dy - tp.height / 2));
    }

    // 标签背景
    final labelY = pxAvatarSize + gap;
    final labelBgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, labelY + labelBgH / 2),
        width: labelBgW,
        height: labelBgH,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(labelBgRect, Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill);
    canvas.drawRRect(labelBgRect, Paint()
      ..color = Colors.grey.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5);
    labelTp.paint(canvas, Offset(centerX - labelTp.width / 2, labelY + labelPadV));

    final picture = recorder.endRecording();
    final image = await picture.toImage(totalW.toInt(), totalH.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.bytes(bytes, imagePixelRatio: scale);
  }

  void _fitBounds() {
    if (!mounted || _disposed || _orders.isEmpty || _mapController == null) return;

    final validOrders = _orders
        .where((o) => o.latitude != null && 
                     o.longitude != null &&
                     o.latitude! != 0 && 
                     o.longitude! != 0)
        .toList();

    if (validOrders.isEmpty) return;

    try {
      double minLat = validOrders.first.latitude!;
      double maxLat = validOrders.first.latitude!;
      double minLng = validOrders.first.longitude!;
      double maxLng = validOrders.first.longitude!;

      for (var order in validOrders) {
        if (order.latitude! < minLat) minLat = order.latitude!;
        if (order.latitude! > maxLat) maxLat = order.latitude!;
        if (order.longitude! < minLng) minLng = order.longitude!;
        if (order.longitude! > maxLng) maxLng = order.longitude!;
      }

      // Ensure bounds are valid
      if (minLat == maxLat) {
        minLat -= 0.01;
        maxLat += 0.01;
      }
      if (minLng == maxLng) {
        minLng -= 0.01;
        maxLng += 0.01;
      }

      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          100,
        ),
      );
    } catch (e) {
      print('Error fitting bounds: $e');
      // If error, at least move to first order position
      if (validOrders.isNotEmpty) {
        try {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(validOrders.first.latitude!, validOrders.first.longitude!),
              12,
            ),
          );
        } catch (_) {
          // Ignore map controller lifecycle race during page transitions.
        }
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showOrderCard(Order order) {
    if (_isAdmin) {
      showOrderCardSheet(
        context: context,
        order: order,
        statusList: _statusList,
        deliveryList: _deliveryList,
        floristList: _floristList,
        onDataChanged: _loadOrders,
        showDetailButton: false,
        roleName: _roleName,
      );
    } else if (order.id != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderOperationPage(orderId: order.id!),
        ),
      ).then((_) => _loadOrders());
    }
  }

  // 过滤后的订单
  List<Order> get _filteredOrders {
    return _orders.where((order) {
      final status = order.orderStatus ?? '';
      if (_excludeDelivered && status.toLowerCase() == 'delivered') {
        return false;
      }
      if (_selectedStatuses.isNotEmpty && !_selectedStatuses.contains(status)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _selectDay(String day) {
    setState(() {
      _selectedDay = day;
      if (day != 'custom') {
        _customStartDate = null;
        _customEndDate = null;
      }
    });
    _loadOrders();
  }

  Future<void> _showAdvancedFilter() async {
    DateTime? tempStart = _customStartDate;
    DateTime? tempEnd = _customEndDate;
    String tempTags = _searchTags;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (_, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 12,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.tune, size: 20),
                      const SizedBox(width: 8),
                      const Text('Advanced Filter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(sheetContext),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: tempTags,
                    onChanged: (v) => tempTags = v,
                    decoration: const InputDecoration(
                      labelText: 'Tags',
                      hintText: 'e.g. rush, mail',
                      prefixIcon: Icon(Icons.label_outline, size: 20),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start Date', style: TextStyle(fontSize: 13)),
                    subtitle: Text(
                      tempStart != null ? _formatDate(tempStart!) : 'Not selected',
                      style: TextStyle(
                        fontSize: 14,
                        color: tempStart != null ? Colors.black : Colors.grey,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tempStart != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setSheetState(() { tempStart = null; tempEnd = null; }),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        const SizedBox(width: 4),
                        const Icon(Icons.calendar_today, size: 20),
                      ],
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate: tempStart ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setSheetState(() {
                          tempStart = picked;
                          if (tempEnd != null && tempEnd!.isBefore(picked)) {
                            tempEnd = picked;
                          }
                        });
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End Date (optional)', style: TextStyle(fontSize: 13)),
                    subtitle: Text(
                      tempEnd != null ? _formatDate(tempEnd!) : 'Same as start',
                      style: TextStyle(
                        fontSize: 14,
                        color: tempEnd != null ? Colors.black : Colors.grey,
                      ),
                    ),
                    trailing: const Icon(Icons.calendar_today, size: 20),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate: tempEnd ?? tempStart ?? DateTime.now(),
                        firstDate: tempStart ?? DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setSheetState(() {
                          tempEnd = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext, 'reset'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(sheetContext, 'apply'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                          child: const Text('Apply', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (result == 'apply') {
      setState(() {
        _searchTags = tempTags.trim();
        if (tempStart != null) {
          _customStartDate = tempStart;
          _customEndDate = tempEnd;
          _selectedDay = 'custom';
        }
      });
      _loadOrders();
    } else if (result == 'reset') {
      setState(() {
        _searchTags = '';
        _customStartDate = null;
        _customEndDate = null;
        _selectedDay = 'today';
      });
      _loadOrders();
    }
  }

  String get _moreLabel {
    final parts = <String>[];
    if (_searchTags.isNotEmpty) parts.add(_searchTags);
    if (_customStartDate != null) {
      final start = _formatDate(_customStartDate!);
      if (_customEndDate == null || _formatDate(_customEndDate!) == start) {
        parts.add(start.substring(5));
      } else {
        parts.add('${start.substring(5)}~${_formatDate(_customEndDate!).substring(5)}');
      }
    }
    return parts.isEmpty ? 'More' : parts.join(' ');
  }

  bool get _hasAdvancedFilter => _searchTags.isNotEmpty || _customStartDate != null;

  void _toggleStatus(String status) {
    setState(() {
      if (_selectedStatuses.contains(status)) {
        _selectedStatuses.remove(status);
      } else {
        _selectedStatuses.add(status);
      }
    });
    _updateMarkers();
  }

  void _toggleExcludeDelivered() {
    setState(() {
      _excludeDelivered = !_excludeDelivered;
    });
    _updateMarkers();
  }

  Color _getStatusChipColor(String status) {
    switch (status.toLowerCase()) {
      case 'new order':
        return Colors.green;
      case 'ready for delivery':
        return Colors.teal;
      case 'out for delivery':
        return Colors.orange;
      case 'delivered':
        return Colors.red;
      case 'canceled':
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Map (${filtered.length}/${_orders.length})'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OrderListPage(),
                ),
              );
            },
            child: const Text(
              'List',
              style: TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // 日期筛选
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(child: _buildFilterButton('today', 'Today')),
                const SizedBox(width: 4),
                Expanded(child: _buildFilterButton('yesterday', 'Yest.')),
                const SizedBox(width: 4),
                Expanded(child: _buildFilterButton('tomorrow', 'Tmrw.')),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildFilterButton(
                    'custom',
                    _moreLabel,
                    icon: Icons.tune,
                    onTap: _showAdvancedFilter,
                    highlight: _hasAdvancedFilter,
                  ),
                ),
              ],
            ),
          ),
          // 状态筛选
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.grey[50],
            child: Row(
              children: [
                GestureDetector(
                  onTap: _toggleExcludeDelivered,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _excludeDelivered ? Colors.red[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _excludeDelivered ? Colors.red : Colors.grey[400]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _excludeDelivered ? Icons.check_box : Icons.check_box_outline_blank,
                          size: 16,
                          color: _excludeDelivered ? Colors.red : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Excl. Delivered',
                          style: TextStyle(
                            fontSize: 11,
                            color: _excludeDelivered ? Colors.red[800] : Colors.grey[700],
                            fontWeight: _excludeDelivered ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _allStatuses.map((status) {
                        final isSelected = _selectedStatuses.contains(status);
                        final chipColor = _getStatusChipColor(status);
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => _toggleStatus(status),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? chipColor.withOpacity(0.15) : Colors.grey[200],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? chipColor : Colors.grey[400]!,
                                ),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected ? chipColor : Colors.grey[700],
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Map
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    onMapCreated: (controller) {
                      _mapController = controller;
                      controller.setMapStyle(_mapStyle);
                      // Keep camera fixed to the configured center/zoom.
                    },
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(40.72277654561845, -73.99637219055177),
                      zoom: 12,
                    ),
                    markers: _markers,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    mapType: MapType.normal,
                    onTap: (LatLng position) {},
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String day, String label, {IconData? icon, VoidCallback? onTap, bool highlight = false}) {
    final isSelected = _selectedDay == day || highlight;
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: onTap ?? () => _selectDay(day),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.deepPurple : Colors.grey[300],
          foregroundColor: isSelected ? Colors.white : Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          minimumSize: const Size(0, 32),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13),
                const SizedBox(width: 2),
              ],
              Text(label, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
