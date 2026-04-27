class OrderQueryResult {
  const OrderQueryResult({
    required this.product,
    required this.recipient,
    required this.address,
    required this.message,
    required this.status,
    required this.imageUrl,
    required this.otherOrders,
    required this.createTime,
    this.orderNumber = '-',
  });

  final String orderNumber;
  final String product;
  final String recipient;
  final String address;
  final String message;
  final String status;
  final String imageUrl;
  final List<OtherOrderItem> otherOrders;
  final String createTime;

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

    return OrderQueryResult(
      orderNumber: _readFirstAvailable(
            mallOrder,
            const ['orderNumber', 'orderNo', 'externalId'],
          ) ??
          '-',
      product: _readFirstAvailable(mallOrder, const ['productName', 'product']) ?? '-',
      recipient: recipientParts.isNotEmpty
          ? recipientParts.join(' ')
          : (_readFirstAvailable(mallOrder, const ['recipient', 'recipientName']) ?? '-'),
      address: _readAddress(mallOrder),
      message: _normalizeMessage(
            _readFirstAvailable(mallOrder, const ['note', 'message']) ?? '-',
          ),
      status: _readFirstAvailable(mallOrder, const ['orderStatus', 'status']) ?? '-',
      imageUrl: _readFirstAvailable(mallOrder, const ['flowerPicture', 'imageUrl']) ?? '',
      otherOrders: otherOrdersJson
          .whereType<Map<String, dynamic>>()
          .map(OtherOrderItem.fromJson)
          .toList(),
      createTime: _formatUtcToLocal(
        _readFirstAvailable(mallOrder, const ['createTime', 'createDate']),
      ),
    );
  }

  static String _normalizeMessage(String value) {
    return value
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll('&nbsp;', ' ')
      .trim();
  }

  static String _readAddress(Map<String, dynamic> json) {
    final state = _readFirstAvailable(json, const ['state', 'province']) ?? '';
    final zip = _readFirstAvailable(json, const ['userZip', 'zipCode']) ?? '';
    final stateZip = [state, zip].where((part) => part.isNotEmpty).join(' ');

    final addressParts = [
      _readFirstAvailable(json, const ['address', 'address1']),
      json['address2']?.toString().trim(),
      json['city']?.toString().trim(),
      stateZip,
    ].where((part) => part != null && part.toString().trim().isNotEmpty).toList();

    return _readFirstAvailable(json, const ['fullAddress']) ??
        (addressParts.isNotEmpty ? addressParts.join(', ') : '-');
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

  static String _formatUtcToLocal(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return '-';
    }

    final value = rawValue.trim();

    final matched = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})[T\s](\d{2}):(\d{2})(?::(\d{2}))?(?:\.(\d{1,6}))?(?:Z|([+-])(\d{2}):?(\d{2}))?$',
    ).firstMatch(value);

    if (matched == null) {
      return value;
    }

    try {
      final year = int.parse(matched.group(1)!);
      final month = int.parse(matched.group(2)!);
      final day = int.parse(matched.group(3)!);
      final hour = int.parse(matched.group(4)!);
      final minute = int.parse(matched.group(5)!);
      final second = int.parse(matched.group(6) ?? '0');
      final fraction = (matched.group(7) ?? '').padRight(6, '0');
      final millisecond = fraction.isEmpty ? 0 : int.parse(fraction.substring(0, 3));
      final microsecond = fraction.isEmpty ? 0 : int.parse(fraction.substring(3, 6));

      var utc = DateTime.utc(
        year,
        month,
        day,
        hour,
        minute,
        second,
        millisecond,
        microsecond,
      );

      final sign = matched.group(8);
      final offsetHour = int.tryParse(matched.group(9) ?? '0') ?? 0;
      final offsetMinute = int.tryParse(matched.group(10) ?? '0') ?? 0;
      if (sign != null) {
        final offset = Duration(hours: offsetHour, minutes: offsetMinute);
        utc = sign == '+' ? utc.subtract(offset) : utc.add(offset);
      }

      final local = utc.toLocal();
      final monthText = local.month.toString().padLeft(2, '0');
      final dayText = local.day.toString().padLeft(2, '0');
      final hourText = local.hour.toString().padLeft(2, '0');
      final minuteText = local.minute.toString().padLeft(2, '0');
      return '${local.year}-$monthText-$dayText $hourText:$minuteText';
    } catch (_) {
      return value;
    }
  }
}

class OtherOrderItem {
  const OtherOrderItem({
    required this.orderNumber,
    required this.productName,
    required this.status,
    required this.recipient,
    required this.createDate,
    this.address = '-',
    this.message = '-',
    this.imageUrl = '',
  });

  final String orderNumber;
  final String productName;
  final String status;
  final String recipient;
  final String createDate;
  final String address;
  final String message;
  final String imageUrl;

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
            const ['orderNumber', 'orderNo', 'externalId'],
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
      createDate: OrderQueryResult._formatUtcToLocal(
        OrderQueryResult._readFirstAvailable(json, const ['createTime', 'createDate']),
      ),
      address: OrderQueryResult._readAddress(json),
      message: OrderQueryResult._normalizeMessage(
        OrderQueryResult._readFirstAvailable(json, const ['note', 'message']) ?? '-',
      ),
      imageUrl:
          OrderQueryResult._readFirstAvailable(json, const ['flowerPicture', 'imageUrl']) ??
              '',
    );
  }
}
