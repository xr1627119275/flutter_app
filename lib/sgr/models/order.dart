class Order {
  final int? id;
  final String orderNumber;
  final String? productName;
  final String? firstName;
  final String? lastName;
  final String? address;
  final String? address2;
  final String? city;
  final String? userZip;
  final String? orderStatus;
  final String? fulfillmentStatus;
  final String? flowerPicture;
  final String? deliveryPicture;
  final String? addressPicture;
  final String? preDeliveryPicture;
  final String? tags;
  final int? delivery;
  final int? florist;
  final String? note;
  final String? sgrInstValue;
  final double? latitude;
  final double? longitude;
  // 联系信息
  final String? userEmail;
  final String? billingPhone;
  final String? userPhone;
  final String? recipientPhone;
  // 其他信息
  final bool? isBusiness;
  final String? source;
  final bool? isPrintInfo;
  final bool? isPrintOrder;
  final String? deliveryId;

  Order({
    this.id,
    required this.orderNumber,
    this.productName,
    this.firstName,
    this.lastName,
    this.address,
    this.address2,
    this.city,
    this.userZip,
    this.orderStatus,
    this.fulfillmentStatus,
    this.flowerPicture,
    this.deliveryPicture,
    this.addressPicture,
    this.preDeliveryPicture,
    this.tags,
    this.delivery,
    this.florist,
    this.note,
    this.sgrInstValue,
    this.latitude,
    this.longitude,
    this.userEmail,
    this.billingPhone,
    this.userPhone,
    this.recipientPhone,
    this.isBusiness,
    this.source,
    this.isPrintInfo,
    this.isPrintOrder,
    this.deliveryId,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // 处理 id，可能是 int 或 String
    int? parseId(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    // 处理 delivery/florist，可能是 int 或 String
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    // 处理 latitude 和 longitude，可能是 num、String 或 null
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    // 处理布尔值
    bool? parseBool(dynamic value) {
      if (value == null) return null;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) return value.toLowerCase() == 'true' || value == '1';
      return null;
    }

    return Order(
      id: parseId(json['id']),
      orderNumber: json['orderNumber']?.toString() ?? '',
      productName: json['productName']?.toString(),
      firstName: json['firstName']?.toString(),
      lastName: json['lastName']?.toString(),
      address: json['address']?.toString(),
      address2: json['address2']?.toString(),
      city: json['city']?.toString(),
      userZip: json['userZip']?.toString(),
      orderStatus: json['orderStatus']?.toString(),
      fulfillmentStatus: json['fulfillmentStatus']?.toString(),
      flowerPicture: json['flowerPicture']?.toString(),
      deliveryPicture: json['deliveryPicture']?.toString(),
      addressPicture: json['addressPicture']?.toString(),
      preDeliveryPicture: json['preDeliveryPicture']?.toString(),
      tags: json['tags']?.toString(),
      delivery: parseInt(json['delivery']),
      florist: parseInt(json['florist']),
      note: json['note']?.toString(),
      sgrInstValue: json['sgrInstValue']?.toString(),
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      userEmail: json['userEmail']?.toString(),
      billingPhone: json['billingPhone']?.toString(),
      userPhone: json['userPhone']?.toString(),
      recipientPhone: json['recipientPhone']?.toString(),
      isBusiness: parseBool(json['isBusiness']),
      source: json['source']?.toString(),
      isPrintInfo: parseBool(json['isPrintInfo']),
      isPrintOrder: parseBool(json['isPrintOrder']),
      deliveryId: json['deliveryId']?.toString(),
    );
  }

  String get fullAddress {
    final parts = [
      address,
      address2,
      city,
      userZip,
    ].where((part) => part != null && part.isNotEmpty).toList();
    return parts.join(', ');
  }

  String get customerName {
    final parts = [firstName, lastName]
        .where((part) => part != null && part.isNotEmpty)
        .toList();
    return parts.join(' ');
  }

  String get googleMapUrl {
    final place = '${address ?? ''},${city ?? ''},NY ${userZip ?? ''}';
    return 'https://www.google.com/maps/place/${Uri.encodeComponent(place)}';
  }

  Order copyWith({
    int? id,
    String? orderNumber,
    String? productName,
    String? firstName,
    String? lastName,
    String? address,
    String? address2,
    String? city,
    String? userZip,
    String? orderStatus,
    String? fulfillmentStatus,
    String? flowerPicture,
    String? deliveryPicture,
    String? addressPicture,
    String? preDeliveryPicture,
    String? tags,
    int? delivery,
    int? florist,
    String? note,
    String? sgrInstValue,
    double? latitude,
    double? longitude,
    String? userEmail,
    String? billingPhone,
    String? userPhone,
    String? recipientPhone,
    bool? isBusiness,
    String? source,
    bool? isPrintInfo,
    bool? isPrintOrder,
    String? deliveryId,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      productName: productName ?? this.productName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      address: address ?? this.address,
      address2: address2 ?? this.address2,
      city: city ?? this.city,
      userZip: userZip ?? this.userZip,
      orderStatus: orderStatus ?? this.orderStatus,
      fulfillmentStatus: fulfillmentStatus ?? this.fulfillmentStatus,
      flowerPicture: flowerPicture ?? this.flowerPicture,
      deliveryPicture: deliveryPicture ?? this.deliveryPicture,
      addressPicture: addressPicture ?? this.addressPicture,
      preDeliveryPicture: preDeliveryPicture ?? this.preDeliveryPicture,
      tags: tags ?? this.tags,
      delivery: delivery ?? this.delivery,
      florist: florist ?? this.florist,
      note: note ?? this.note,
      sgrInstValue: sgrInstValue ?? this.sgrInstValue,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      userEmail: userEmail ?? this.userEmail,
      billingPhone: billingPhone ?? this.billingPhone,
      userPhone: userPhone ?? this.userPhone,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      isBusiness: isBusiness ?? this.isBusiness,
      source: source ?? this.source,
      isPrintInfo: isPrintInfo ?? this.isPrintInfo,
      isPrintOrder: isPrintOrder ?? this.isPrintOrder,
      deliveryId: deliveryId ?? this.deliveryId,
    );
  }
}

// 订单状态模型
class OrderStatus {
  final int id;
  final String name;

  OrderStatus({required this.id, required this.name});

  factory OrderStatus.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return OrderStatus(
      id: parseId(json['id']),
      name: json['name']?.toString() ?? '',
    );
  }
}

// 配送员模型
class DeliveryPerson {
  final int id;
  final String name;
  final String? img;

  DeliveryPerson({required this.id, required this.name, this.img});

  factory DeliveryPerson.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return DeliveryPerson(
      id: parseId(json['id']),
      name: json['name']?.toString() ?? '',
      img: json['img']?.toString(),
    );
  }
}

// 花艺师模型
class FloristPerson {
  final int id;
  final String name;

  FloristPerson({required this.id, required this.name});

  factory FloristPerson.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return FloristPerson(
      id: parseId(json['id']),
      name: json['name']?.toString() ?? '',
    );
  }
}

class OrderStatusHistory {
  final int? id;
  final int? orderId;
  final String? orderNumber;
  final String? status;
  final int? operatorId;
  final String? operatorName;
  final String? operatorRole;
  final String? remark;
  final String? createTime;

  OrderStatusHistory({
    this.id,
    this.orderId,
    this.orderNumber,
    this.status,
    this.operatorId,
    this.operatorName,
    this.operatorRole,
    this.remark,
    this.createTime,
  });

  factory OrderStatusHistory.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    return OrderStatusHistory(
      id: parseInt(json['id']),
      orderId: parseInt(json['orderId']),
      orderNumber: json['orderNumber']?.toString(),
      status: json['status']?.toString(),
      operatorId: parseInt(json['operatorId']),
      operatorName: json['operatorName']?.toString(),
      operatorRole: json['operatorRole']?.toString(),
      remark: json['remark']?.toString(),
      createTime: json['createTime']?.toString(),
    );
  }
}

class OrderListResponse {
  final int code;
  final String msg;
  final OrderPage page;

  OrderListResponse({
    required this.code,
    required this.msg,
    required this.page,
  });

  factory OrderListResponse.fromJson(Map<String, dynamic> json) {
    // 处理 code，可能是 int 或 String
    int parseCode(dynamic value) {
      if (value == null) return -1;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? -1;
      return -1;
    }

    return OrderListResponse(
      code: parseCode(json['code']),
      msg: json['msg']?.toString() ?? '',
      page: OrderPage.fromJson(json['page'] ?? {}),
    );
  }
}

class OrderPage {
  final int totalCount;
  final List<Order> list;

  OrderPage({
    required this.totalCount,
    required this.list,
  });

  factory OrderPage.fromJson(Map<String, dynamic> json) {
    // 处理 totalCount，可能是 int 或 String
    int parseTotalCount(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return OrderPage(
      totalCount: parseTotalCount(json['totalCount']),
      list: (json['list'] as List<dynamic>?)
              ?.map((e) => Order.fromJson(e))
              .toList() ??
          [],
    );
  }
}
