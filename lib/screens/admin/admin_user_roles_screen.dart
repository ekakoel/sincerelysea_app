import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/services/admin_service.dart';
import 'package:sincerelysea/theme/app_colors.dart';

class AdminUserRolesScreen extends StatefulWidget {
  const AdminUserRolesScreen({super.key});

  @override
  State<AdminUserRolesScreen> createState() => _AdminUserRolesScreenState();
}

class _AdminUserRolesScreenState extends State<AdminUserRolesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _updatingUserId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AdminService adminService = context.read<AdminService>();
    return FutureBuilder<bool>(
      future: adminService.isCurrentUserAdmin(),
      builder: (BuildContext context, AsyncSnapshot<bool> roleSnapshot) {
        if (roleSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (roleSnapshot.data != true) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Only admin accounts can manage roles.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Admin Roles')),
          body: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search username, name, or email',
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onChanged: (String value) {
                    setState(() => _searchQuery = value.trim().toLowerCase());
                  },
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: adminService.usersStream(),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                  ) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                        snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    final List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs =
                        docs.where(_matchesSearch).toList();
                    final int adminCount = docs.where((doc) {
                      return doc.data()['role']?.toString().toLowerCase() == 'admin';
                    }).length;

                    if (filteredDocs.isEmpty) {
                      return ListView(
                        padding: const EdgeInsets.all(24),
                        children: const <Widget>[
                          SizedBox(height: 40),
                          Text(
                            'No users match this search.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: <Widget>[
                        _AdminSummaryCard(
                          totalUsers: docs.length,
                          adminUsers: adminCount,
                          filteredUsers: filteredDocs.length,
                        ),
                        const SizedBox(height: 12),
                        ...filteredDocs.map((doc) => _UserRoleTile(
                              document: doc,
                              isUpdating: _updatingUserId == doc.id,
                              onRoleChanged: (String role) =>
                                  _updateRole(doc.id, role),
                            )),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _matchesSearch(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    if (_searchQuery.isEmpty) {
      return true;
    }
    final Map<String, dynamic> data = doc.data();
    final String username = data['username']?.toString().toLowerCase() ?? '';
    final String displayName =
        data['displayName']?.toString().toLowerCase() ?? '';
    final String email = data['email']?.toString().toLowerCase() ?? '';
    final String haystack = '$username $displayName $email';
    return haystack.contains(_searchQuery);
  }

  Future<void> _updateRole(String userId, String role) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _updatingUserId = userId);
    try {
      await context.read<AdminService>().updateUserRole(
        userId: userId,
        role: role,
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Role updated to ${role.toUpperCase()}')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update role: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingUserId = null);
      }
    }
  }
}

class _AdminSummaryCard extends StatelessWidget {
  const _AdminSummaryCard({
    required this.totalUsers,
    required this.adminUsers,
    required this.filteredUsers,
  });

  final int totalUsers;
  final int adminUsers;
  final int filteredUsers;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray300),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: _SummaryMetric(label: 'Users', value: totalUsers)),
          Expanded(child: _SummaryMetric(label: 'Admins', value: adminUsers)),
          Expanded(
            child: _SummaryMetric(label: 'Visible', value: filteredUsers),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          '$value',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.black54),
        ),
      ],
    );
  }
}

class _UserRoleTile extends StatelessWidget {
  const _UserRoleTile({
    required this.document,
    required this.isUpdating,
    required this.onRoleChanged,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final bool isUpdating;
  final ValueChanged<String> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data = document.data();
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final String username = data['username']?.toString().trim().isNotEmpty == true
        ? data['username'].toString().trim()
        : 'user';
    final String displayName =
        data['displayName']?.toString().trim().isNotEmpty == true
        ? data['displayName'].toString().trim()
        : username;
    final String email = data['email']?.toString().trim() ?? '';
    final String role = data['role']?.toString().trim().toLowerCase() == 'admin'
        ? 'admin'
        : 'user';
    final bool isSelf = currentUser?.uid == document.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: role == 'admin' ? AppColors.black : AppColors.gray300,
          child: Text(
            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
            style: TextStyle(
              color: role == 'admin' ? AppColors.white : AppColors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _RoleChip(role: role),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('@$username'),
              if (email.isNotEmpty) Text(email),
              if (isSelf)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Current account',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
        trailing: isUpdating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : PopupMenuButton<String>(
                enabled: !isSelf,
                onSelected: onRoleChanged,
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'user',
                    child: Text('Set as User'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'admin',
                    child: Text('Set as Admin'),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelf ? AppColors.gray200 : AppColors.black,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isSelf ? 'Locked' : 'Change',
                    style: TextStyle(
                      color: isSelf ? AppColors.black54 : AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isAdmin ? AppColors.black : AppColors.gray200,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isAdmin ? 'ADMIN' : 'USER',
        style: TextStyle(
          color: isAdmin ? AppColors.white : AppColors.black87,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
