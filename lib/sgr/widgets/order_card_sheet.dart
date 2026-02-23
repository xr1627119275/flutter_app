import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../pages/order_operation_page.dart';

/// 显示订单卡片底部弹窗
void showOrderCardSheet({
  required BuildContext context,
  required Order order,
  required List<OrderStatus> statusList,
  required List<DeliveryPerson> deliveryList,
  required List<FloristPerson> floristList,
  required VoidCallback onDataChanged,
  bool showDetailButton = true,
  String? roleName,
}) {
  Order currentOrder = order;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setModalState) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: _OrderCardContent(
          order: currentOrder,
          statusList: statusList,
          deliveryList: deliveryList,
          floristList: floristList,
          roleName: roleName,
          onOrderUpdated: (updatedOrder) {
            setModalState(() {
              currentOrder = updatedOrder;
            });
          },
          onDataChanged: onDataChanged,
          onClose: () => Navigator.pop(sheetContext),
          parentContext: context,
          showDetailButton: showDetailButton,
        ),
      ),
    ),
  );
}

class _OrderCardContent extends StatelessWidget {
  final Order order;
  final List<OrderStatus> statusList;
  final List<DeliveryPerson> deliveryList;
  final List<FloristPerson> floristList;
  final String? roleName;
  final ValueChanged<Order> onOrderUpdated;
  final VoidCallback onDataChanged;
  final VoidCallback onClose;
  final BuildContext parentContext;
  final bool showDetailButton;

  const _OrderCardContent({
    required this.order,
    required this.statusList,
    required this.deliveryList,
    required this.floristList,
    this.roleName,
    required this.onOrderUpdated,
    required this.onDataChanged,
    required this.onClose,
    required this.parentContext,
    this.showDetailButton = true,
  });

  bool get _isAdmin =>
      roleName == '管理员' || roleName == 'Admin' || roleName == 'Administrator';
  bool get _isFlorist => roleName == 'Florist';
  bool get _isDriver => roleName == 'Driver';

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '#${order.orderNumber}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              if (_isAdmin)
                _StatusSelector(
                  currentStatus: order.orderStatus,
                  statusList: statusList,
                  orderId: order.id,
                  onStatusChanged: (newStatus) async {
                    if (order.id != null) {
                      try {
                        await ApiService.updateOrderStatus(orderId: order.id!, orderStatus: newStatus);
                        onOrderUpdated(order.copyWith(orderStatus: newStatus));
                        onDataChanged();
                        _showSnackBar(context, 'Status updated', Colors.green);
                      } catch (e) {
                        _showSnackBar(context, 'Failed to update status', Colors.red);
                      }
                    }
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.orderStatus ?? ''),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    order.orderStatus ?? 'N/A',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Product', value: order.productName ?? '-'),
                _InfoRowWithCopy(
                  label: 'Recipient',
                  value: order.customerName.isNotEmpty ? order.customerName : '-',
                  onCopy: () => _copyToClipboard(context, order.customerName, 'Recipient'),
                ),
                _AddressRow(
                  order: order,
                  onCopy: () => _copyToClipboard(context, order.fullAddress, 'Address'),
                ),
                if (_isAdmin)
                  _AssignmentSection(
                    order: order,
                    deliveryList: deliveryList,
                    floristList: floristList,
                    onDataChanged: onDataChanged,
                    onShowSuccess: (msg) => _showSnackBar(context, msg, Colors.green),
                    onShowError: (msg) => _showSnackBar(context, msg, Colors.red),
                  ),
                if (order.tags != null && order.tags!.isNotEmpty)
                  _TagsRow(tags: order.tags!),
                _InfoRow(label: 'Message', value: order.note ?? '-'),
                _InfoRow(label: 'Instructions', value: order.sgrInstValue ?? '-'),
                _ContactSection(order: order),
                _ImagesSection(
                  order: order,
                  isAdmin: _isAdmin,
                  isFlorist: _isFlorist,
                  isDriver: _isDriver,
                  onOrderUpdated: onOrderUpdated,
                  onShowSuccess: (msg) => _showSnackBar(context, msg, Colors.green),
                  onShowError: (msg) => _showSnackBar(context, msg, Colors.red),
                ),
                const SizedBox(height: 16),
                if (showDetailButton && order.id != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        onClose();
                        Navigator.push(
                          parentContext,
                          MaterialPageRoute(
                            builder: (_) => OrderOperationPage(orderId: order.id!),
                          ),
                        ).then((_) => onDataChanged());
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('View Details & Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar(context, '$label copied', Colors.green);
  }

  static void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 1)),
    );
  }
}

class _StatusSelector extends StatelessWidget {
  final String? currentStatus;
  final List<OrderStatus> statusList;
  final int? orderId;
  final ValueChanged<String> onStatusChanged;

  const _StatusSelector({
    required this.currentStatus,
    required this.statusList,
    required this.orderId,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final selected = await showDialog<String>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('Select Status'),
            children: statusList.map((status) {
              final isSelected = status.name == currentStatus;
              return SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, status.name),
                child: Text(
                  status.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.deepPurple : null,
                  ),
                ),
              );
            }).toList(),
          ),
        );
        if (selected != null) {
          onStatusChanged(selected);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(currentStatus ?? 'Status', style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700], fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _InfoRowWithCopy extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;

  const _InfoRowWithCopy({required this.label, required this.value, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700], fontSize: 13)),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
                if (value.isNotEmpty && value != '-')
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: onCopy,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final Order order;
  final VoidCallback onCopy;

  const _AddressRow({required this.order, required this.onCopy});

  Future<void> _openGoogleMap() async {
    final address = Uri.encodeComponent(order.fullAddress);
    final url = 'https://www.google.com/maps/search/?api=1&query=$address';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text('Address', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700], fontSize: 13)),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _openGoogleMap,
                    child: Text(
                      order.fullAddress,
                      style: const TextStyle(fontSize: 13, color: Colors.blue, decoration: TextDecoration.underline),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: onCopy,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentSection extends StatelessWidget {
  final Order order;
  final List<DeliveryPerson> deliveryList;
  final List<FloristPerson> floristList;
  final VoidCallback onDataChanged;
  final ValueChanged<String> onShowSuccess;
  final ValueChanged<String> onShowError;

  const _AssignmentSection({
    required this.order,
    required this.deliveryList,
    required this.floristList,
    required this.onDataChanged,
    required this.onShowSuccess,
    required this.onShowError,
  });

  String _getDriverName(int? deliveryId) {
    if (deliveryId == null || deliveryId == 0) return 'Select';
    try {
      return deliveryList.firstWhere((d) => d.id == deliveryId).name;
    } catch (_) {
      return 'Driver #$deliveryId';
    }
  }

  String _getFloristName(int? floristId) {
    if (floristId == null || floristId == 0) return 'Select';
    try {
      return floristList.firstWhere((f) => f.id == floristId).name;
    } catch (_) {
      return 'Florist #$floristId';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = ['Out for Delivery', 'Cancelled', 'Canceled'].contains(order.orderStatus);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Driver', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 4),
                _buildSelector(
                  context: context,
                  title: 'Select Driver',
                  currentValue: _getDriverName(order.delivery),
                  isDisabled: isDisabled,
                  items: deliveryList.map((p) => _SelectItem(id: p.id, name: p.name, isSelected: p.id == order.delivery)).toList(),
                  onSelected: (id) async {
                    if (order.id != null) {
                      try {
                        await ApiService.updateOrderDelivery(orderId: order.id!, deliveryId: id);
                        onDataChanged();
                        onShowSuccess('Driver updated');
                      } catch (e) {
                        onShowError('Failed to update driver');
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Florist', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 4),
                _buildSelector(
                  context: context,
                  title: 'Select Florist',
                  currentValue: _getFloristName(order.florist),
                  isDisabled: isDisabled,
                  items: floristList.map((p) => _SelectItem(id: p.id, name: p.name, isSelected: p.id == order.florist)).toList(),
                  onSelected: (id) async {
                    if (order.id != null) {
                      try {
                        await ApiService.updateOrderFlorist(orderId: order.id!, floristId: id);
                        onDataChanged();
                        onShowSuccess('Florist updated');
                      } catch (e) {
                        onShowError('Failed to update florist');
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelector({
    required BuildContext context,
    required String title,
    required String currentValue,
    required bool isDisabled,
    required List<_SelectItem> items,
    required ValueChanged<int> onSelected,
  }) {
    return InkWell(
      onTap: isDisabled ? null : () async {
        final selected = await showDialog<int>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: Text(title),
            children: items.map((item) {
              return SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, item.id),
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: item.isSelected ? FontWeight.bold : FontWeight.normal,
                    color: item.isSelected ? Colors.deepPurple : null,
                  ),
                ),
              );
            }).toList(),
          ),
        );
        if (selected != null) {
          onSelected(selected);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: isDisabled ? Colors.grey[300]! : Colors.grey[400]!),
          borderRadius: BorderRadius.circular(4),
          color: isDisabled ? Colors.grey[100] : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                currentValue,
                style: TextStyle(fontSize: 12, color: isDisabled ? Colors.grey : null),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: isDisabled ? Colors.grey : null),
          ],
        ),
      ),
    );
  }
}

class _SelectItem {
  final int id;
  final String name;
  final bool isSelected;
  _SelectItem({required this.id, required this.name, required this.isSelected});
}

class _TagsRow extends StatelessWidget {
  final String tags;
  const _TagsRow({required this.tags});

  @override
  Widget build(BuildContext context) {
    final tagList = tags.split(',').where((t) => t.trim().isNotEmpty).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text('Tags', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700], fontSize: 13)),
          ),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: tagList.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(12)),
                child: Text(tag.trim(), style: TextStyle(fontSize: 11, color: Colors.blue[800])),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  final Order order;
  const _ContactSection({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Contact Info', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          _contactRow('Email', order.userEmail),
          _contactRow('Billing Phone', order.billingPhone),
          _contactRow('User Phone', order.userPhone),
          _contactRow('Recipient Phone', order.recipientPhone),
        ],
      ),
    );
  }

  Widget _contactRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
          Expanded(child: Text(value?.isNotEmpty == true ? value! : '-', style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _ImagesSection extends StatefulWidget {
  final Order order;
  final bool isAdmin;
  final bool isFlorist;
  final bool isDriver;
  final ValueChanged<Order> onOrderUpdated;
  final ValueChanged<String> onShowSuccess;
  final ValueChanged<String> onShowError;

  const _ImagesSection({
    required this.order,
    this.isAdmin = false,
    this.isFlorist = false,
    this.isDriver = false,
    required this.onOrderUpdated,
    required this.onShowSuccess,
    required this.onShowError,
  });

  @override
  State<_ImagesSection> createState() => _ImagesSectionState();
}

class _ImagesSectionState extends State<_ImagesSection> {
  Future<void> _uploadImage(String imageType) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final orderId = widget.order.id;
    if (orderId == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading...'), duration: Duration(seconds: 1)),
      );

      String imageUrl;
      Order updatedOrder;

      switch (imageType) {
        case 'flower':
          imageUrl = await ApiService.uploadOrderImage(orderId: orderId, filePath: image.path);
          updatedOrder = widget.order.copyWith(flowerPicture: imageUrl);
          break;
        case 'address':
          imageUrl = await ApiService.uploadAddressImage(orderId: orderId, filePath: image.path);
          updatedOrder = widget.order.copyWith(addressPicture: imageUrl);
          break;
        case 'preDelivery':
          imageUrl = await ApiService.uploadPreDeliveryImage(orderId: orderId, filePath: image.path);
          updatedOrder = widget.order.copyWith(preDeliveryPicture: imageUrl);
          break;
        case 'delivery':
          imageUrl = await ApiService.uploadDeliveryImage(orderId: orderId, filePath: image.path);
          updatedOrder = widget.order.copyWith(deliveryPicture: imageUrl);
          break;
        default:
          return;
      }

      widget.onOrderUpdated(updatedOrder);
      widget.onShowSuccess('Image uploaded');
    } catch (e) {
      widget.onShowError('Upload failed: $e');
    }
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Image'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Icon(Icons.broken_image, size: 60, color: Colors.grey),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageItem(String label, String? imageUrl, String type, bool canUpload) {
    return Column(
      children: [
        GestureDetector(
          onTap: imageUrl != null && imageUrl.isNotEmpty
              ? () => _showFullImage(imageUrl)
              : (canUpload ? () => _uploadImage(type) : null),
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
              color: Colors.grey[100],
            ),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.network(
                          imageUrl,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.broken_image, size: 30, color: Colors.grey);
                          },
                        ),
                      ),
                      if (canUpload)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => _uploadImage(type),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.edit, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  )
                : canUpload
                    ? const Icon(Icons.add_photo_alternate, size: 30, color: Colors.grey)
                    : const Icon(Icons.image_not_supported, size: 30, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isAdmin = widget.isAdmin;
    final isDriver = widget.isDriver;
    final canUploadFlower = isAdmin || widget.isFlorist;
    final canUploadAddress = isAdmin;
    final canUploadPreDelivery = isAdmin &&
        ['Ready for Delivery', 'Out for Delivery', 'Delivered'].contains(order.orderStatus);
    final canUploadDelivery = isAdmin || isDriver;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Images:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildImageItem('Flower', order.flowerPicture, 'flower', canUploadFlower),
                _buildImageItem('Address', order.addressPicture, 'address', canUploadAddress),
                _buildImageItem('PreDelivery', order.preDeliveryPicture, 'preDelivery', canUploadPreDelivery),
                _buildImageItem('Delivery', order.deliveryPicture, 'delivery', canUploadDelivery),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
