import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/screens/admin/admin_dashboard_screen.dart';
import 'package:sincerelysea/screens/admin/admin_user_roles_screen.dart';
import 'package:sincerelysea/screens/admin/community_reports_screen.dart';
import 'package:sincerelysea/screens/admin/sales_reports_screen.dart';
import 'package:sincerelysea/screens/orders/seller_orders_screen.dart';
import 'package:sincerelysea/screens/product/manage_products_screen.dart';
import 'package:sincerelysea/screens/settings/firebase_health_check_screen.dart';
import 'package:sincerelysea/services/admin_service.dart';
import 'package:sincerelysea/theme/app_colors.dart';

class DeveloperConsoleScreen extends StatelessWidget {
  const DeveloperConsoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AdminService adminService = context.read<AdminService>();
    return FutureBuilder<bool>(
      future: adminService.isCurrentUserDeveloper(),
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data != true) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Developer Console hanya bisa diakses oleh role developer.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Developer Console')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gray300),
                ),
                child: const Text(
                  'Akses cepat untuk kontrol sistem, operasional store, role management, dan diagnostic Firebase.',
                ),
              ),
              const SizedBox(height: 14),
              _ActionTile(
                icon: Icons.space_dashboard_outlined,
                title: 'Admin Dashboard',
                subtitle: 'Monitor users, products, orders, dan role logs',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AdminDashboardScreen(),
                  ),
                ),
              ),
              _ActionTile(
                icon: Icons.inventory_2_outlined,
                title: 'Manage Products',
                subtitle: 'Kelola katalog, stok, preorder, dan pricing',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ManageProductsScreen(),
                  ),
                ),
              ),
              _ActionTile(
                icon: Icons.receipt_long_outlined,
                title: 'Store Orders',
                subtitle: 'Kelola order lifecycle dan status fulfillment',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SellerOrdersScreen(),
                  ),
                ),
              ),
              _ActionTile(
                icon: Icons.assessment_outlined,
                title: 'Transaction Reports',
                subtitle: 'Review sales report dan journal entries',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SalesReportsScreen(),
                  ),
                ),
              ),
              _ActionTile(
                icon: Icons.flag_outlined,
                title: 'Community Reports',
                subtitle: 'Moderasi laporan konten dan user',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CommunityReportsScreen(),
                  ),
                ),
              ),
              _ActionTile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Manage Access',
                subtitle: 'Kelola role user/admin/developer dan scopes',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AdminUserRolesScreen(),
                  ),
                ),
              ),
              _ActionTile(
                icon: Icons.health_and_safety_outlined,
                title: 'Firebase Health Check',
                subtitle: 'Verifikasi project ID dan akses Firestore',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FirebaseHealthCheckScreen(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
