import 'package:flutter/material.dart';

import '../order_query_models.dart';

class OtherOrdersPage extends StatelessWidget {
  const OtherOrdersPage({
    super.key,
    required this.orders,
    required this.onOpenOrder,
  });

  final List<OtherOrderItem> orders;
  final ValueChanged<OtherOrderItem> onOpenOrder;

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
                return InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => onOpenOrder(order),
                  child: Card(
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
                          const SizedBox(height: 10),
                          const Row(
                            children: [
                              Icon(Icons.open_in_new, size: 16, color: Color(0xFF2E7D5A)),
                              SizedBox(width: 6),
                              Text(
                                'Open details',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2E7D5A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
