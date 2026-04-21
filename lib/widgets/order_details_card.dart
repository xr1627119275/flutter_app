import 'package:flutter/material.dart';

import '../order_query_models.dart';
import '../pages/other_orders_page.dart';

class OrderDetailsCard extends StatelessWidget {
  const OrderDetailsCard({
    super.key,
    required this.result,
    required this.imageLoaded,
    required this.onPreviewImage,
    this.showMoreOrdersButton = true,
  });

  final OrderQueryResult result;
  final bool imageLoaded;
  final ValueChanged<String> onPreviewImage;
  final bool showMoreOrdersButton;

  @override
  Widget build(BuildContext context) {
    final primaryItems = [
      _InfoItemData(
        label: 'Product',
        value: result.product,
        icon: Icons.local_florist_outlined,
        trailing: _buildStatusChip(result.status),
        emphasized: true,
      ),
      _InfoItemData(
        label: 'Create Time',
        value: result.createTime,
        icon: Icons.schedule_outlined,
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
            _buildImageSection(),
            if (showMoreOrdersButton && result.otherOrders.isNotEmpty) ...[
              const SizedBox(height: 14),
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
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
          else if (!imageLoaded)
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
              onTap: () => onPreviewImage(result.imageUrl),
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
}

class OrderDetailsPage extends StatelessWidget {
  const OrderDetailsPage({
    super.key,
    required this.order,
  });

  final OtherOrderItem order;

  @override
  Widget build(BuildContext context) {
    final result = OrderQueryResult(
      product: order.productName,
      recipient: order.recipient,
      address: '-',
      message: '-',
      status: order.status,
      imageUrl: '',
      otherOrders: const [],
      createTime: order.createDate,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: OrderDetailsCard(
          result: result,
          imageLoaded: true,
          onPreviewImage: (_) {},
          showMoreOrdersButton: false,
        ),
      ),
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
