import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/login_response.dart';
import '../models/order.dart';
import '../utils/storage.dart';
import '../pages/login_page.dart';

export '../models/order.dart' show OrderStatus, DeliveryPerson, FloristPerson, OrderStatusHistory;

class ApiService {
  static const String baseUrl = 'https://preprod.hellosecretgarden.com/south-fast';
  // static const String baseUrl = 'https://www.hellosecretgarden.com/south-fast';
  // static const String baseUrl = 'https://fast.xrdev.top/south-fast';
  static String? _token;
  static const Duration _timeout = Duration(seconds: 30);

  /// 全局 navigatorKey，由 main.dart 设置
  static GlobalKey<NavigatorState>? navigatorKey;

  static void setToken(String? token) {
    _token = token;
  }

  static Map<String, String> get _headers => {
        'accept': '*/*',
        'content-type': 'application/json; charset=UTF-8',
        if (_token != null) 'token': _token!,
      };

  /// 处理 401 未授权：清除凭证，跳转登录页
  static Future<void> _handle401() async {
    _token = null;
    await Storage.clearAll();
    final context = navigatorKey?.currentContext;
    if (context != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  /// 检查响应状态码，401 时自动跳转登录页
  static Future<void> _checkUnauthorized(http.Response response) async {
    if (response.statusCode == 401) {
      await _handle401();
      throw Exception('登录已过期，请重新登录');
    }
  }

  /// 检查 StreamedResponse 状态码
  static Future<void> _checkUnauthorizedStreamed(http.StreamedResponse response) async {
    if (response.statusCode == 401) {
      await _handle401();
      throw Exception('登录已过期，请重新登录');
    }
  }

  // Login
  static Future<LoginResponse> login({
    required String username,
    required String password,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/sys/appLogin');
      print('🔗 尝试连接: $url');
      print('📤 请求头: $_headers');
      
      final body = jsonEncode({
        'username': username,
        'password': password,
        'type': 'app',
      });
      print('📦 请求体: ${body.replaceAll(password, '***')}');

      final response = await http
          .post(url, headers: _headers, body: body)
          .timeout(_timeout);
      
      print('📥 响应状态码: ${response.statusCode}');
      print('📥 响应体: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final loginResponse = LoginResponse.fromJson(jsonData);
        if (loginResponse.code == 0) {
          _token = loginResponse.token;
        }
        return loginResponse;
      } else {
        throw Exception('登录失败: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      print('❌ SocketException: $e');
      print('❌ 错误类型: ${e.runtimeType}');
      print('❌ 错误消息: ${e.message}');
      print('❌ 地址: ${e.address}');
      print('❌ 端口: ${e.port}');
      throw Exception('网络连接失败: 无法连接到服务器。请检查网络连接。\n错误详情: $e');
    } on HttpException catch (e) {
      print('❌ HttpException: $e');
      print('❌ 错误消息: ${e.message}');
      throw Exception('HTTP 错误: $e');
    } on FormatException catch (e) {
      print('❌ FormatException: $e');
      print('❌ 错误消息: ${e.message}');
      throw Exception('数据格式错误: $e');
    } catch (e, stackTrace) {
      print('❌ 未知错误: $e');
      print('❌ 错误类型: ${e.runtimeType}');
      print('❌ 堆栈跟踪: $stackTrace');
      if (e.toString().contains('TimeoutException') || 
          e.toString().contains('timeout')) {
        throw Exception('连接超时: 服务器响应时间过长，请稍后重试');
      }
      throw Exception('登录失败: $e');
    }
  }

  // Get order list
  static Future<OrderListResponse> getOrderList({
    int page = 1,
    int limit = 300,
    String? startDate,
    String? endDate,
    String? tags,
    String? fulfillment,
    int? delivery,
    bool? orderZip,
  }) async {
    final url = Uri.parse('$baseUrl/mall/mallorder/listForSelectByAdmin');
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      'tags': tags ?? '',
      if (fulfillment != null) 'fulfillment': fulfillment,
      'delivery': delivery?.toString() ?? '',
      if (orderZip != null) 'orderZip': orderZip.toString(),
      't': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    try {
      final uri = url.replace(queryParameters: queryParams);
      final response = await http
          .get(uri, headers: _headers)
          .timeout(_timeout);

      await _checkUnauthorized(response);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return OrderListResponse.fromJson(jsonData);
      } else {
        throw Exception('获取订单列表失败: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败: 无法连接到服务器。请检查网络连接。\n错误详情: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException') || 
          e.toString().contains('timeout')) {
        throw Exception('连接超时: 服务器响应时间过长，请稍后重试');
      }
      throw Exception('获取订单列表失败: $e');
    }
  }

  // Get order details
  static Future<Order> getOrderDetail(int orderId) async {
    try {
      final url = Uri.parse('$baseUrl/mall/mallorder/info/$orderId');
      final response = await http
          .get(url, headers: _headers)
          .timeout(_timeout);

      await _checkUnauthorized(response);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['code'] == 0) {
          return Order.fromJson(jsonData['mallOrder'] ?? {});
        } else {
          throw Exception(jsonData['msg'] ?? '获取订单详情失败');
        }
      } else {
        throw Exception('获取订单详情失败: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败: 无法连接到服务器。请检查网络连接。\n错误详情: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException') || 
          e.toString().contains('timeout')) {
        throw Exception('连接超时: 服务器响应时间过长，请稍后重试');
      }
      throw Exception('获取订单详情失败: $e');
    }
  }

  // Upload order image
  static Future<String> uploadOrderImage({
    required int orderId,
    required String filePath,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/mall/mallorder/updateOrderImages');
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(_headers);
      request.fields['id'] = orderId.toString();
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send().timeout(_timeout);
      await _checkUnauthorizedStreamed(streamedResponse);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['code'] == 0) {
          return jsonData['msg'] ?? '';
        } else {
          throw Exception(jsonData['msg'] ?? '上传失败');
        }
      } else {
        throw Exception('上传失败: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败: 无法连接到服务器。请检查网络连接。\n错误详情: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException') || 
          e.toString().contains('timeout')) {
        throw Exception('连接超时: 服务器响应时间过长，请稍后重试');
      }
      throw Exception('上传订单图片失败: $e');
    }
  }

  // Upload delivery image
  static Future<String> uploadDeliveryImage({
    required int orderId,
    required String filePath,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/mall/mallorder/updateDeliveryImage');
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(_headers);
      request.fields['id'] = orderId.toString();
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send().timeout(_timeout);
      await _checkUnauthorizedStreamed(streamedResponse);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['code'] == 0) {
          return jsonData['msg'] ?? '';
        } else {
          throw Exception(jsonData['msg'] ?? '上传失败');
        }
      } else {
        throw Exception('上传失败: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败: 无法连接到服务器。请检查网络连接。\n错误详情: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException') || 
          e.toString().contains('timeout')) {
        throw Exception('连接超时: 服务器响应时间过长，请稍后重试');
      }
      throw Exception('上传配送图片失败: $e');
    }
  }

  // 获取状态列表
  static Future<List<OrderStatus>> getStatusList() async {
    try {
      final url = Uri.parse('$baseUrl/mall/mallorder/statusList');
      final response = await http
          .get(url, headers: _headers)
          .timeout(_timeout);

      await _checkUnauthorized(response);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['code'] == 0) {
          final List<dynamic> data = jsonData['data'] ?? [];
          return data.map((e) => OrderStatus.fromJson(e)).toList();
        } else {
          throw Exception(jsonData['msg'] ?? '获取状态列表失败');
        }
      } else {
        throw Exception('获取状态列表失败: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败: 无法连接到服务器。请检查网络连接。\n错误详情: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException') || 
          e.toString().contains('timeout')) {
        throw Exception('连接超时: 服务器响应时间过长，请稍后重试');
      }
      throw Exception('获取状态列表失败: $e');
    }
  }

  // 获取配送员列表
  static Future<List<DeliveryPerson>> getDeliveryList() async {
    try {
      final url = Uri.parse('$baseUrl/mall/mallorder/deliveryList');
      final response = await http
          .get(url, headers: _headers)
          .timeout(_timeout);

      await _checkUnauthorized(response);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['code'] == 0) {
          final List<dynamic> data = jsonData['data'] ?? [];
          return data.map((e) => DeliveryPerson.fromJson(e)).toList();
        } else {
          throw Exception(jsonData['msg'] ?? '获取配送员列表失败');
        }
      } else {
        throw Exception('获取配送员列表失败: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败: 无法连接到服务器。请检查网络连接。\n错误详情: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException') || 
          e.toString().contains('timeout')) {
        throw Exception('连接超时: 服务器响应时间过长，请稍后重试');
      }
      throw Exception('获取配送员列表失败: $e');
    }
  }

  // 获取花艺师列表
  static Future<List<FloristPerson>> getFloristList() async {
    try {
      final url = Uri.parse('$baseUrl/mall/mallorder/floristList');
      final response = await http
          .get(url, headers: _headers)
          .timeout(_timeout);

      await _checkUnauthorized(response);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['code'] == 0) {
          final List<dynamic> data = jsonData['data'] ?? [];
          return data.map((e) => FloristPerson.fromJson(e)).toList();
        } else {
          throw Exception(jsonData['msg'] ?? '获取花艺师列表失败');
        }
      } else {
        throw Exception('获取花艺师列表失败: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败: 无法连接到服务器。请检查网络连接。\n错误详情: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException') || 
          e.toString().contains('timeout')) {
        throw Exception('连接超时: 服务器响应时间过长，请稍后重试');
      }
      throw Exception('获取花艺师列表失败: $e');
    }
  }

  // 更新订单状态
  static Future<bool> updateOrderStatus({
    required int orderId,
    required String orderStatus,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/mall/mallorder/updateOrderStatus');
      final body = jsonEncode({
        'id': orderId,
        'orderStatus': orderStatus,
      });

      final response = await http
          .post(url, headers: _headers, body: body)
          .timeout(_timeout);

      await _checkUnauthorized(response);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['code'] == 0) {
          return true;
        } else {
          throw Exception(jsonData['msg'] ?? '更新状态失败');
        }
      } else {
        throw Exception('更新状态失败: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败: 无法连接到服务器。请检查网络连接。\n错误详情: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException') || 
          e.toString().contains('timeout')) {
        throw Exception('连接超时: 服务器响应时间过长，请稍后重试');
      }
      throw Exception('更新状态失败: $e');
    }
  }

  // 修改订单标签
  static Future<bool> updateOrderTags({
    required int orderId,
    required String tags,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/mall/mallorder/updateByTags');
      final body = jsonEncode({
        'id': orderId,
        'tags': tags,
      });

      final response = await http
          .post(url, headers: _headers, body: body)
          .timeout(_timeout);

      await _checkUnauthorized(response);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['code'] == 0) {
          return true;
        } else {
          throw Exception(jsonData['msg'] ?? '更新标签失败');
        }
      } else {
        throw Exception('更新标签失败: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败: 无法连接到服务器。请检查网络连接。\n错误详情: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException') || 
          e.toString().contains('timeout')) {
        throw Exception('连接超时: 服务器响应时间过长，请稍后重试');
      }
      throw Exception('更新标签失败: $e');
    }
  }

  // 更新订单配送员
  static Future<bool> updateOrderDelivery({
    required int orderId,
    required int deliveryId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/mall/mallorder/updateOrderDelivery');
      final body = jsonEncode({
        'id': orderId,
        'delivery': deliveryId,
      });

      final response = await http
          .post(url, headers: _headers, body: body)
          .timeout(_timeout);

      await _checkUnauthorized(response);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['code'] == 0) {
          return true;
        } else {
          throw Exception(jsonData['msg'] ?? '更新配送员失败');
        }
      } else {
        throw Exception('更新配送员失败: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败: 无法连接到服务器。请检查网络连接。\n错误详情: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException') || 
          e.toString().contains('timeout')) {
        throw Exception('连接超时: 服务器响应时间过长，请稍后重试');
      }
      throw Exception('更新配送员失败: $e');
    }
  }

  // 更新订单花艺师
  static Future<bool> updateOrderFlorist({
    required int orderId,
    required int floristId,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/mall/mallorder/updateOrderFlorist');
      final body = jsonEncode({
        'id': orderId,
        'florist': floristId,
      });

      final response = await http
          .post(url, headers: _headers, body: body)
          .timeout(_timeout);

      await _checkUnauthorized(response);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['code'] == 0) {
          return true;
        } else {
          throw Exception(jsonData['msg'] ?? '更新花艺师失败');
        }
      } else {
        throw Exception('更新花艺师失败: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败: 无法连接到服务器。请检查网络连接。\n错误详情: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException') || 
          e.toString().contains('timeout')) {
        throw Exception('连接超时: 服务器响应时间过长，请稍后重试');
      }
      throw Exception('更新花艺师失败: $e');
    }
  }

  // 上传地址图片
  static Future<String> uploadAddressImage({
    required int orderId,
    required String filePath,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/mall/mallorder/updateAddressPicture?id=$orderId');
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(_headers);
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send().timeout(_timeout);
      await _checkUnauthorizedStreamed(streamedResponse);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['code'] == 0) {
          return jsonData['msg'] ?? '';
        } else {
          throw Exception(jsonData['msg'] ?? '上传失败');
        }
      } else {
        throw Exception('上传失败: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败: 无法连接到服务器。请检查网络连接。\n错误详情: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException') || 
          e.toString().contains('timeout')) {
        throw Exception('连接超时: 服务器响应时间过长，请稍后重试');
      }
      throw Exception('上传地址图片失败: $e');
    }
  }

  // 上传预配送图片
  static Future<String> uploadPreDeliveryImage({
    required int orderId,
    required String filePath,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/mall/mallorder/updatePreDeliveryImage');
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(_headers);
      request.fields['id'] = orderId.toString();
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send().timeout(_timeout);
      await _checkUnauthorizedStreamed(streamedResponse);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['code'] == 0) {
          return jsonData['msg'] ?? '';
        } else {
          throw Exception(jsonData['msg'] ?? '上传失败');
        }
      } else {
        throw Exception('上传失败: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败: 无法连接到服务器。请检查网络连接。\n错误详情: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException') || 
          e.toString().contains('timeout')) {
        throw Exception('连接超时: 服务器响应时间过长，请稍后重试');
      }
      throw Exception('上传预配送图片失败: $e');
    }
  }

  // 添加订单状态历史记录
  static Future<bool> addOrderStatusHistory({
    required int orderId,
    required String orderNumber,
    required String status,
    required String operatorRole,
    String? remark,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/mall/orderstatushistory/add');
      final body = jsonEncode({
        'orderId': orderId,
        'orderNumber': orderNumber,
        'status': status,
        'operatorRole': operatorRole,
        if (remark != null) 'remark': remark,
      });

      final response = await http
          .post(url, headers: _headers, body: body)
          .timeout(_timeout);

      await _checkUnauthorized(response);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['code'] == 0) {
          return true;
        } else {
          throw Exception(jsonData['msg'] ?? '添加状态历史失败');
        }
      } else {
        throw Exception('添加状态历史失败: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败: 无法连接到服务器。\n错误详情: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('timeout')) {
        throw Exception('连接超时: 服务器响应时间过长，请稍后重试');
      }
      throw Exception('添加状态历史失败: $e');
    }
  }

  // 获取订单状态历史
  static Future<List<OrderStatusHistory>> getOrderStatusHistory(int orderId) async {
    try {
      final url = Uri.parse('$baseUrl/mall/orderstatushistory/listByOrderId/$orderId');
      final response = await http
          .get(url, headers: _headers)
          .timeout(_timeout);

      await _checkUnauthorized(response);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['code'] == 0) {
          final List<dynamic> data = jsonData['list'] ?? [];
          return data.map((e) => OrderStatusHistory.fromJson(e)).toList();
        } else {
          throw Exception(jsonData['msg'] ?? '获取状态历史失败');
        }
      } else {
        throw Exception('获取状态历史失败: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败: 无法连接到服务器。\n错误详情: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('timeout')) {
        throw Exception('连接超时: 服务器响应时间过长，请稍后重试');
      }
      throw Exception('获取状态历史失败: $e');
    }
  }

  // 删除订单图片
  static Future<bool> removeOrderImage({
    required int orderId,
    required String imageType,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/mall/mallorder/removeImage');
      final body = jsonEncode({
        'id': orderId,
        'imageType': imageType,
      });

      final response = await http
          .post(url, headers: _headers, body: body)
          .timeout(_timeout);

      await _checkUnauthorized(response);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['code'] == 0) {
          return true;
        } else {
          throw Exception(jsonData['msg'] ?? '删除图片失败');
        }
      } else {
        throw Exception('删除图片失败: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败: 无法连接到服务器。请检查网络连接。\n错误详情: $e');
    } catch (e) {
      if (e.toString().contains('TimeoutException') || 
          e.toString().contains('timeout')) {
        throw Exception('连接超时: 服务器响应时间过长，请稍后重试');
      }
      throw Exception('删除图片失败: $e');
    }
  }
}
