import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../utils/storage.dart';

class OrderOperationPage extends StatefulWidget {
  final int orderId;

  const OrderOperationPage({super.key, required this.orderId});

  @override
  State<OrderOperationPage> createState() => _OrderOperationPageState();
}

class _OrderOperationPageState extends State<OrderOperationPage> {
  Order? _order;
  bool _isLoading = true;
  String? _roleName;
  bool _isMaking = false;
  bool _isReady = false;
  bool _isDelivering = false;
  bool _isDelivered = false;
  List<OrderStatusHistory> _statusHistory = [];

  @override
  void initState() {
    super.initState();
    _loadRoleName();
    _loadOrder();
    _loadStatusHistory();
  }

  Future<void> _loadRoleName() async {
    final roleName = await Storage.getRoleName();
    setState(() {
      _roleName = roleName;
    });
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final order = await ApiService.getOrderDetail(widget.orderId);
      setState(() {
        _order = order;
        _updateButtonStates(order);
      });
    } catch (e) {
      _showError('Failed to load order: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStatusHistory() async {
    try {
      final history = await ApiService.getOrderStatusHistory(widget.orderId);
      setState(() {
        _statusHistory = history;
      });
      _updateStatusFromHistory();
    } catch (e) {
      print('Error loading status history: $e');
    }
  }

  void _updateButtonStates(Order order) {}

  void _updateStatusFromHistory() {
    _isMaking = false;
    _isReady = false;
    _isDelivering = false;
    _isDelivered = false;

    if (_statusHistory.isNotEmpty) {
      const mainStatuses = ['Making', 'Ready', 'Delivering', 'Delivered'];
      final latestMainStatus = _statusHistory
          .cast<OrderStatusHistory?>()
          .firstWhere(
            (item) => mainStatuses.contains(item?.status),
            orElse: () => null,
          );

      if (latestMainStatus != null) {
        final status = latestMainStatus.status;
        _isMaking = status == 'Making';
        _isReady = status == 'Ready' || status == 'Delivering' || status == 'Delivered';
        _isDelivering = status == 'Delivering';
        _isDelivered = status == 'Delivered';
      }
    }

    setState(() {});
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _addStatusHistoryRecord(String status, String remark) async {
    if (_order == null) return;
    try {
      _showLoading('Processing...');
      await ApiService.addOrderStatusHistory(
        orderId: _order!.id!,
        orderNumber: _order!.orderNumber,
        status: status,
        operatorRole: _roleName ?? '',
        remark: remark,
      );
      _hideLoading();
      _showSuccess('$remark successfully');
      await _loadStatusHistory();
    } catch (e) {
      _hideLoading();
      _showError('Operation failed: $e');
    }
  }

  Future<void> _startMaking() async {
    await _addStatusHistoryRecord('Making', 'Start making');
  }

  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    try {
      _showLoading('Uploading...');
      final imageUrl = await ApiService.uploadOrderImage(
        orderId: widget.orderId,
        filePath: image.path,
      );

      setState(() {
        _order = _order?.copyWith(flowerPicture: imageUrl);
      });

      if (_order != null) {
        final fileName = imageUrl.contains('/')
            ? imageUrl.substring(imageUrl.lastIndexOf('/') + 1)
            : imageUrl;
        try {
          await ApiService.addOrderStatusHistory(
            orderId: _order!.id!,
            orderNumber: _order!.orderNumber,
            status: 'ImageUploaded',
            operatorRole: _roleName ?? '',
            remark: 'Uploaded order image: $fileName',
          );
        } catch (_) {}
      }

      _hideLoading();
      _showSuccess('Image uploaded successfully');

      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Florist'),
          content: const Text('Image uploaded. Confirm completed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _addStatusHistoryRecord('Ready', 'Making completed');
      } else {
        await _loadStatusHistory();
      }
    } catch (e) {
      _hideLoading();
      _showError('Upload failed: $e');
    }
  }

  Future<void> _finishMaking() async {
    await _addStatusHistoryRecord('Ready', 'Making completed');
  }

  Future<void> _startDelivery() async {
    await _addStatusHistoryRecord('Delivering', 'Start delivery');
  }

  Future<void> _uploadDeliveryImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    try {
      _showLoading('Uploading...');
      final imageUrl = await ApiService.uploadDeliveryImage(
        orderId: widget.orderId,
        filePath: image.path,
      );

      setState(() {
        _order = _order?.copyWith(deliveryPicture: imageUrl);
      });

      _hideLoading();
      _showSuccess('Delivery image uploaded');

      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Delivery'),
          content: const Text('Image uploaded. Confirm delivery completed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        if (_order != null) {
          final fileName = imageUrl.contains('/')
              ? imageUrl.substring(imageUrl.lastIndexOf('/') + 1)
              : imageUrl;
          try {
            await ApiService.addOrderStatusHistory(
              orderId: _order!.id!,
              orderNumber: _order!.orderNumber,
              status: 'DeliveryImageUploaded',
              operatorRole: _roleName ?? '',
              remark: 'Uploaded delivery image: $fileName',
            );
          } catch (_) {}
        }
        await _addStatusHistoryRecord('Delivered', 'Delivered');
      }
    } catch (e) {
      _hideLoading();
      _showError('Upload failed: $e');
    }
  }

  OverlayEntry? _loadingOverlay;

  void _showLoading(String message) {
    _loadingOverlay = OverlayEntry(
      builder: (context) => Container(
        color: Colors.black54,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(message),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_loadingOverlay!);
  }

  void _hideLoading() {
    _loadingOverlay?.remove();
    _loadingOverlay = null;
  }

  @override
  void dispose() {
    _hideLoading();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Order Operation'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Order Operation'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Order not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Operation'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_order!.flowerPicture != null ||
                _order!.deliveryPicture != null)
              Row(
                children: [
                  if (_order!.flowerPicture != null)
                    Expanded(
                      child: _buildImageCard(
                        'Order Image',
                        _order!.flowerPicture!,
                      ),
                    ),
                  if (_order!.flowerPicture != null &&
                      _order!.deliveryPicture != null)
                    const SizedBox(width: 8),
                  if (_order!.deliveryPicture != null)
                    Expanded(
                      child: _buildImageCard(
                        'Delivery Image',
                        _order!.deliveryPicture!,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            _buildInfoRow('Order Number', '#${_order!.orderNumber}'),
            _buildInfoRow('Product Name', _order!.productName ?? 'N/A'),
            _buildInfoRow(
                'Customer Name', _order!.customerName.isNotEmpty ? _order!.customerName : 'N/A'),
            _buildInfoRow('Delivery Address', _order!.fullAddress),
            _buildInfoRow('Order Status', _order!.orderStatus ?? 'N/A'),
            if (_order!.tags != null && _order!.tags!.isNotEmpty)
              _buildInfoRow('Tags', _order!.tags!),
            if (_order!.note != null && _order!.note!.isNotEmpty)
              _buildInfoRow('Note', _order!.note!),
            if (_order!.sgrInstValue != null &&
                _order!.sgrInstValue!.isNotEmpty)
              _buildInfoRow('Instructions', _order!.sgrInstValue!),
            const SizedBox(height: 16),
            _buildTimeline(),
            const SizedBox(height: 24),
            if (_roleName == 'Florist') ...[
              ElevatedButton.icon(
                onPressed: _isMaking || _isReady ? null : _startMaking,
                icon: const Icon(Icons.check_circle),
                label: Text(_isMaking ? 'Making...' : 'Start Making'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _uploadImage,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Upload Image & Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: !_isMaking || _isReady ? null : _finishMaking,
                icon: const Icon(Icons.close),
                label: const Text('Finish Making'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
            if (_roleName == 'Driver') ...[
              ElevatedButton.icon(
                onPressed: _isDelivering || _isDelivered ? null : _startDelivery,
                icon: const Icon(Icons.check_circle),
                label: Text(_isDelivering ? 'Delivering...' : 'Start Delivery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: !_isDelivering ? null : _uploadDeliveryImage,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Upload Delivery Image & Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard(String label, String imageUrl) {
    return Card(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image, size: 60),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            width: double.infinity,
            color: Colors.grey[200],
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    if (_statusHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            ..._statusHistory.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == _statusHistory.length - 1;
              return _buildTimelineItem(item, isLast);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(OrderStatusHistory item, bool isLast) {
    final time = item.createTime ?? '';
    final timeOnly = time.length >= 16 ? time.substring(11, 16) : time;
    final dateOnly = time.length >= 10 ? time.substring(5, 10) : '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getTimelineColor(item.status),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _getTimelineColor(item.status).withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey[300],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.status ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: _getTimelineColor(item.status),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$dateOnly $timeOnly',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(_getRoleIcon(item.operatorRole), size: 13, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${item.operatorName ?? ""}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      if (item.operatorRole != null) ...[
                        Text(
                          ' (${item.operatorRole})',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ],
                  ),
                  if (item.remark != null && item.remark!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.remark!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTimelineColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'making':
        return Colors.indigo;
      case 'ready':
      case 'ready for delivery':
        return Colors.teal;
      case 'delivering':
      case 'out for delivery':
        return Colors.orange;
      case 'delivered':
        return Colors.green;
      case 'canceled':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _getRoleIcon(String? role) {
    switch (role?.toLowerCase()) {
      case 'florist':
        return Icons.local_florist;
      case 'driver':
        return Icons.local_shipping;
      case 'admin':
      case 'administrator':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
