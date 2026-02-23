class LoginResponse {
  final String msg;
  final List<RoleInfo> roleInfos;
  final UserInfo userInfo;
  final int code;
  final int expire;
  final List<int> roleList;
  final String token;

  LoginResponse({
    required this.msg,
    required this.roleInfos,
    required this.userInfo,
    required this.code,
    required this.expire,
    required this.roleList,
    required this.token,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    // 处理 code，可能是 int 或 String
    int parseCode(dynamic value) {
      if (value == null) return -1;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? -1;
      return -1;
    }

    // 处理 expire，可能是 int 或 String
    int parseExpire(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    // 处理 roleList，元素可能是 int 或 String
    List<int> parseRoleList(dynamic value) {
      if (value == null) return [];
      if (value is! List) return [];
      return value.map((e) {
        if (e is int) return e;
        if (e is String) return int.tryParse(e) ?? 0;
        return 0;
      }).toList();
    }

    return LoginResponse(
      msg: json['msg']?.toString() ?? '',
      roleInfos: (json['roleInfos'] as List<dynamic>?)
              ?.map((e) => RoleInfo.fromJson(e))
              .toList() ??
          [],
      userInfo: UserInfo.fromJson(json['userInfo'] ?? {}),
      code: parseCode(json['code']),
      expire: parseExpire(json['expire']),
      roleList: parseRoleList(json['roleList']),
      token: json['token']?.toString() ?? '',
    );
  }

  String? get roleName {
    if (roleInfos.isNotEmpty) {
      return roleInfos.first.roleName;
    }
    return null;
  }
}

class RoleInfo {
  final int roleId;
  final String roleName;
  final String remark;
  final int? createUserId;
  final List<int>? menuIdList;
  final String? createTime;

  RoleInfo({
    required this.roleId,
    required this.roleName,
    required this.remark,
    this.createUserId,
    this.menuIdList,
    this.createTime,
  });

  factory RoleInfo.fromJson(Map<String, dynamic> json) {
    // 处理 roleId，可能是 int 或 String
    int parseRoleId(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    // 处理 createUserId，可能是 int 或 String
    int? parseCreateUserId(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    // 处理 menuIdList，元素可能是 int 或 String
    List<int>? parseMenuIdList(dynamic value) {
      if (value == null) return null;
      if (value is! List) return null;
      return value.map((e) {
        if (e is int) return e;
        if (e is String) return int.tryParse(e) ?? 0;
        return 0;
      }).toList();
    }

    return RoleInfo(
      roleId: parseRoleId(json['roleId']),
      roleName: json['roleName']?.toString() ?? '',
      remark: json['remark']?.toString() ?? '',
      createUserId: parseCreateUserId(json['createUserId']),
      menuIdList: parseMenuIdList(json['menuIdList']),
      createTime: json['createTime']?.toString(),
    );
  }
}

class UserInfo {
  final int userId;
  final String username;
  final String? password;
  final String? salt;
  final String? imageUrl;
  final String? email;
  final String? mobile;
  final int? status;
  final List<int>? roleIdList;
  final int? createUserId;
  final String? createTime;
  final bool? isOnline;
  final double? lat;
  final double? lnt;

  UserInfo({
    required this.userId,
    required this.username,
    this.password,
    this.salt,
    this.imageUrl,
    this.email,
    this.mobile,
    this.status,
    this.roleIdList,
    this.createUserId,
    this.createTime,
    this.isOnline,
    this.lat,
    this.lnt,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    // 处理 userId，可能是 int 或 String
    int parseUserId(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    // 处理 status，可能是 int 或 String
    int? parseStatus(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    // 处理 roleIdList，元素可能是 int 或 String
    List<int>? parseRoleIdList(dynamic value) {
      if (value == null) return null;
      if (value is! List) return null;
      return value.map((e) {
        if (e is int) return e;
        if (e is String) return int.tryParse(e) ?? 0;
        return 0;
      }).toList();
    }

    // 处理 createUserId，可能是 int 或 String
    int? parseCreateUserId(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    // 处理 lat 和 lnt，可能是 num、String 或 null
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return UserInfo(
      userId: parseUserId(json['userId']),
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString(),
      salt: json['salt']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      email: json['email']?.toString(),
      mobile: json['mobile']?.toString(),
      status: parseStatus(json['status']),
      roleIdList: parseRoleIdList(json['roleIdList']),
      createUserId: parseCreateUserId(json['createUserId']),
      createTime: json['createTime']?.toString(),
      isOnline: json['isOnline'] as bool?,
      lat: parseDouble(json['lat']),
      lnt: parseDouble(json['lnt']),
    );
  }
}
