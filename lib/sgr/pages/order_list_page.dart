import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../utils/storage.dart';
import '../widgets/order_card_sheet.dart';
import '../services/stomp_service.dart';
import 'order_operation_page.dart';

class OrderListPage extends StatefulWidget {
  const OrderListPage({super.key});

  @override
  State<OrderListPage> createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> {
  List<Order> _orders = [];
  bool _isLoading = true;
  String _selectedDay = 'today';
  String _date = '';
  int _orderCount = 0;
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

  String? _roleName;

  bool get _isAdmin =>
      _roleName == '管理员' || _roleName == 'Admin' || _roleName == 'Administrator';

  List<OrderStatus> _statusList = [];
  List<DeliveryPerson> _deliveryList = [];
  List<FloristPerson> _floristList = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadOrders();
    _initStomp();
  }

  void _initStomp() {
    StompService().connect(
      () {
        print('[OrderListPage] STOMP connected successfully.');
        // Subscribe to order changes
        StompService.subscribe('/topic/orderChange', (data) {
          print('[OrderListPage] Received /topic/orderChange: $data');
          _loadOrders();
        });

        // Subscribe to new orders
        StompService.subscribe('/topic/orderAdd', (data) {
          print('[OrderListPage] Received /topic/orderAdd: $data');
          _loadOrders();
        });
      },
      (error) {
        print('[OrderListPage] STOMP connection error: $error');
      },
    );
  }

  @override
  void dispose() {
    StompService.disconnect();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final roleName = await Storage.getRoleName();
      final results = await Future.wait([
        ApiService.getStatusList(),
        ApiService.getDeliveryList(),
        ApiService.getFloristList(),
      ]);
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
    setState(() {
      _isLoading = true;
    });

    try {
      String? startDate;
      String? endDate;

      final now = DateTime.now();
      switch (_selectedDay) {
        case 'today':
          _date = _formatDate(now);
          startDate = _date;
          endDate = _date;
          break;
        case 'yesterday':
          final yesterday = now.subtract(const Duration(days: 1));
          _date = _formatDate(yesterday);
          startDate = _date;
          endDate = _date;
          break;
        case 'tomorrow':
          final tomorrow = now.add(const Duration(days: 1));
          _date = _formatDate(tomorrow);
          startDate = _date;
          endDate = _date;
          break;
        case 'custom':
          if (_customStartDate != null) {
            startDate = _formatDate(_customStartDate!);
            endDate = _customEndDate != null
                ? _formatDate(_customEndDate!)
                : startDate;
            _date = startDate;
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

      if (response.code == 0) {
        setState(() {
          _orders = response.page.list;
          _orderCount = response.page.totalCount;
        });
      } else {
        _showError(response.msg);
      }
    } catch (e) {
      _showError('Failed to load orders: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // 过滤后的订单
  List<Order> get _filteredOrders {
    return _orders.where((order) {
      final status = order.orderStatus ?? '';
      // exclude delivered
      if (_excludeDelivered && status.toLowerCase() == 'delivered') {
        return false;
      }
      // 状态多选筛选
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
                  // 拖拽指示条
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 标题
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
                  // Tags 搜索
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
                  // 开始日期
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
                  // 结束日期
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
                  // 操作按钮
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
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;
    return Scaffold(
      appBar: AppBar(
        title: Text('Order List (${filtered.length}/$_orderCount)'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
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
            child: Column(
              children: [
                // Exclude Delivered + 状态 chips
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() { _excludeDelivered = !_excludeDelivered; }),
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
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () => _toggleStatus(status),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected ? _getStatusColor(status).withOpacity(0.15) : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected ? _getStatusColor(status) : Colors.grey[400]!,
                                    ),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isSelected ? _getStatusColor(status) : Colors.grey[700],
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
              ],
            ),
          ),
          // 订单列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text('No orders found'))
                    : RefreshIndicator(
                        onRefresh: _loadOrders,
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) => _buildOrderCard(filtered[index]),
                        ),
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

  Widget _buildOrderCard(Order order) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: _getCardBorderColor(order), width: 2),
      ),
      child: InkWell(
        onTap: () {
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
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (order.isBusiness == true)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.business, color: Colors.red, size: 18),
                    ),
                  Text(
                    '#${order.orderNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.deepPurple, fontSize: 15),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.productName ?? 'N/A',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.orderStatus ?? ''),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order.orderStatus ?? 'N/A',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Recipient: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Expanded(
                    child: Text(
                      order.customerName.isNotEmpty ? order.customerName : '-',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Address: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Expanded(
                    child: Text(order.fullAddress, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              if (order.tags != null && order.tags!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: order.tags!.split(',').map((tag) {
                    final t = tag.trim();
                    final isCwc = t.toLowerCase().contains('cwc');
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCwc ? Colors.yellow[300] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 11,
                          color: isCwc ? Colors.orange[900] : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildThumbnail(order.flowerPicture, 'Flower'),
                  const SizedBox(width: 8),
                  _buildThumbnail(order.addressPicture, 'Address'),
                  const SizedBox(width: 8),
                  _buildThumbnail(order.preDeliveryPicture, 'PreDel'),
                  const SizedBox(width: 8),
                  _buildThumbnail(order.deliveryPicture, 'Delivery'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(String? imageUrl, String label) {
    return Column(
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: imageUrl != null && imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.image, size: 24, color: Colors.grey);
                    },
                  ),
                )
              : const Icon(Icons.image_not_supported, size: 24, color: Colors.grey),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }

  Color _getCardBorderColor(Order order) {
    final status = order.orderStatus?.toLowerCase() ?? '';
    if (status == 'canceled' || status == 'cancelled') return Colors.grey;
    if (status == 'delivered') return Colors.red;
    if (status == 'new order') return Colors.green;
    if (order.tags != null && order.tags!.toLowerCase().contains('rush')) return Colors.orange;
    return Colors.grey[300]!;
  }

  Color _getStatusColor(String status) {
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
}
