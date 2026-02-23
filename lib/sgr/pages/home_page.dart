import 'package:flutter/material.dart';
import 'order_list_page.dart';
import 'order_map_page.dart';
import 'login_page.dart';
import '../utils/storage.dart';
import '../services/api_service.dart';

class HomePage extends StatelessWidget {
  final String roleName;

  const HomePage({super.key, required this.roleName});

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Storage.clearAll();
      ApiService.setToken(null);
      
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = roleName == 'Driver';
    final isFlorist = roleName == 'Florist';
    final isAdmin = roleName == '管理员' || roleName == 'Admin' || roleName == 'Administrator';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secret Garden Rose'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 管理员、花艺师、司机都可以看到订单列表
              if (isFlorist || isDriver || isAdmin) ...[
                _buildMenuCard(
                  context,
                  title: 'Order List',
                  icon: Icons.list,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrderListPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              // 管理员和司机都可以看到地图
              if (isDriver || isAdmin) ...[
                _buildMenuCard(
                  context,
                  title: 'Order Map',
                  icon: Icons.map,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrderMapPage(),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(
                icon,
                size: 48,
                color: Colors.deepPurple,
              ),
              const SizedBox(width: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
