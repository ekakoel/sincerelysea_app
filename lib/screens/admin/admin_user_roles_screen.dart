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
      future: adminService.canCurrentUserManageAdminAccess(),
      builder: (BuildContext context, AsyncSnapshot<bool> accessSnapshot) {
        if (accessSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (accessSnapshot.data != true) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Only authorized admins can manage admin access.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Admin Access')),
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
                        snapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    final List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs =
                        docs.where(_matchesSearch).toList(growable: false);
                    final int adminCount = docs.where((doc) {
                      return adminService.isAdminData(doc.data());
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
                        ...filteredDocs.map(
                          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                              _UserAccessTile(
                                document: doc,
                                isUpdating: _updatingUserId == doc.id,
                                onManageTap: () => _showAccessSheet(doc),
                              ),
                        ),
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
    return '$username $displayName $email'.contains(_searchQuery);
  }

  Future<void> _showAccessSheet(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final AdminService adminService = context.read<AdminService>();
    final Map<String, dynamic> data = document.data();
    String selectedRole =
        adminService.isAdminData(data) ? 'admin' : 'user';
    final Set<String> selectedScopes = adminService
        .adminScopesFromData(data)
        .toSet();
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final bool isSelf = currentUser?.uid == document.id;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Future<void> save() async {
              final NavigatorState navigator = Navigator.of(bottomSheetContext);
              final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
                this.context,
              );
              setModalState(() => saving = true);
              setState(() => _updatingUserId = document.id);
              try {
                await adminService.updateUserAccess(
                  userId: document.id,
                  role: selectedRole,
                  adminScopes: selectedScopes.toList(growable: false),
                );
                if (!mounted) {
                  return;
                }
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Admin access updated.')),
                );
              } catch (e) {
                if (!mounted) {
                  return;
                }
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to update access: $e')),
                );
              } finally {
                if (mounted) {
                  setState(() => _updatingUserId = null);
                }
                setModalState(() => saving = false);
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(bottomSheetContext).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Manage Access',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['displayName']?.toString().trim().isNotEmpty == true
                          ? data['displayName'].toString().trim()
                          : '@${data['username'] ?? 'user'}',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(value: 'user', child: Text('User')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(
                          value: 'developer',
                          child: Text('Developer'),
                        ),
                      ],
                      onChanged: isSelf
                          ? null
                          : (String? value) {
                              if (value == null) {
                                return;
                              }
                              setModalState(() {
                                selectedRole = value;
                                if (selectedRole == 'user') {
                                  selectedScopes.clear();
                                } else if (selectedRole == 'developer') {
                                  selectedScopes
                                    ..clear()
                                    ..addAll(AdminService.supportedScopes);
                                } else if (selectedScopes.isEmpty) {
                                  selectedScopes.addAll(
                                    AdminService.supportedScopes,
                                  );
                                }
                              });
                            },
                    ),
                    if (selectedRole != 'user') ...<Widget>[
                      const SizedBox(height: 16),
                      const Text(
                        'Admin Responsibilities',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AdminService.supportedScopes.map((String scope) {
                          final bool selected = selectedScopes.contains(scope);
                          final bool lockScope = selectedRole == 'developer';
                          return FilterChip(
                            selected: selected,
                            label: Text(_scopeLabel(scope)),
                            onSelected: isSelf || lockScope
                                ? null
                                : (bool value) {
                                    setModalState(() {
                                      if (value) {
                                        selectedScopes.add(scope);
                                      } else {
                                        selectedScopes.remove(scope);
                                      }
                                    });
                                  },
                          );
                        }).toList(growable: false),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use products for catalog managers, orders for operational order admins, finance for transaction reporting, community for moderation, and roles for access management.',
                        style: TextStyle(color: AppColors.black54, height: 1.35),
                      ),
                      if (selectedRole == 'developer')
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Developer role always has all scopes enabled.',
                            style: TextStyle(color: AppColors.black54),
                          ),
                        ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: saving || isSelf ? null : save,
                        child: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save Access'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _scopeLabel(String scope) {
    return switch (scope) {
      'products' => 'Product Manager',
      'orders' => 'Order Manager',
      'finance' => 'Finance Admin',
      'community' => 'Community Manager',
      'roles' => 'Access Manager',
      _ => scope,
    };
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
          Expanded(child: _SummaryMetric(label: 'Visible', value: filteredUsers)),
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
        Text(label, style: const TextStyle(color: AppColors.black54)),
      ],
    );
  }
}

class _UserAccessTile extends StatelessWidget {
  const _UserAccessTile({
    required this.document,
    required this.isUpdating,
    required this.onManageTap,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final bool isUpdating;
  final VoidCallback onManageTap;

  @override
  Widget build(BuildContext context) {
    final AdminService adminService = context.read<AdminService>();
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
    final String role = adminService.roleFromData(data);
    final bool isAdmin = adminService.isAdminData(data);
    final List<String> scopes = isAdmin
        ? adminService.adminScopesFromData(data)
        : const <String>[];
    final bool isSelf = currentUser?.uid == document.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: isAdmin ? AppColors.black : AppColors.gray300,
          child: Text(
            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
            style: TextStyle(
              color: isAdmin ? AppColors.white : AppColors.black,
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 4),
            Text('@$username'),
            if (email.isNotEmpty) Text(email),
            if (scopes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: scopes.map((String scope) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      switch (scope) {
                        'products' => 'Products',
                        'orders' => 'Orders',
                        'finance' => 'Finance',
                        'community' => 'Community',
                        'roles' => 'Roles',
                        _ => scope,
                      },
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
            ],
            if (isSelf)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Current account',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        trailing: isUpdating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : FilledButton.tonal(
                onPressed: isSelf ? null : onManageTap,
                child: Text(isSelf ? 'Locked' : 'Manage'),
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
    final bool isDeveloper = role == 'developer';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDeveloper
            ? Colors.indigo
            : (isAdmin ? AppColors.black : AppColors.gray200),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        switch (role) {
          'developer' => 'DEVELOPER',
          'admin' => 'ADMIN',
          _ => 'USER',
        },
        style: TextStyle(
          color: (isAdmin || isDeveloper) ? AppColors.white : AppColors.black87,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
