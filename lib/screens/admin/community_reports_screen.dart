import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/services/community_management_service.dart';
import 'package:sincerelysea/theme/app_colors.dart';

class CommunityReportsScreen extends StatefulWidget {
  const CommunityReportsScreen({super.key});

  @override
  State<CommunityReportsScreen> createState() => _CommunityReportsScreenState();
}

class _CommunityReportsScreenState extends State<CommunityReportsScreen> {
  String _selectedStatus = 'open';

  @override
  Widget build(BuildContext context) {
    final CommunityManagementService service = context
        .read<CommunityManagementService>();
    return FutureBuilder<bool>(
      future: service.canCurrentUserManageCommunity(),
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
                  'Only community admins can manage community reports.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Community Reports')),
          body: Column(
            children: <Widget>[
              SizedBox(
                height: 56,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  scrollDirection: Axis.horizontal,
                  children: const <String>[
                    'open',
                    'reviewing',
                    'resolved',
                    'all',
                  ].map(_buildStatusChip).toList(growable: false),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: service.reportsStream(status: _selectedStatus),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                  ) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Failed to load reports: ${snapshot.error}'),
                      );
                    }
                    final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                        snapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('No community reports in this status.'),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: docs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (BuildContext context, int index) {
                        final Map<String, dynamic> data = docs[index].data();
                        return _ReportCard(
                          reportId: docs[index].id,
                          data: data,
                          onStatusChanged: (String status) async {
                            try {
                              await service.updateReportStatus(
                                reportId: docs[index].id,
                                status: status,
                              );
                            } catch (e) {
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to update report status: $e',
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
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

  Widget _buildStatusChip(String value) {
    final bool selected = _selectedStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        label: Text(value == 'all' ? 'All' : _titleCase(value)),
        labelStyle: TextStyle(
          color: selected ? AppColors.white : AppColors.gray700,
          fontWeight: FontWeight.w600,
        ),
        selectedColor: AppColors.black,
        backgroundColor: AppColors.gray100,
        onSelected: (bool selectedValue) {
          if (!selectedValue) {
            return;
          }
          setState(() => _selectedStatus = value);
        },
      ),
    );
  }

  String _titleCase(String value) {
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.reportId,
    required this.data,
    required this.onStatusChanged,
  });

  final String reportId;
  final Map<String, dynamic> data;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final String type = data['type']?.toString() ?? 'report';
    final String reason = data['reason']?.toString() ?? '-';
    final String status = data['status']?.toString() ?? 'open';
    final String targetId = data['targetId']?.toString() ?? '-';
    final String reporterUid = data['reporterUid']?.toString() ?? '-';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${type.toUpperCase()} REPORT',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Reason: $reason'),
          const SizedBox(height: 4),
          Text('Target ID: $targetId'),
          const SizedBox(height: 4),
          Text('Reporter: $reporterUid'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Update Status'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(value: 'open', child: Text('Open')),
              DropdownMenuItem(value: 'reviewing', child: Text('Reviewing')),
              DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
            ],
            onChanged: (String? value) {
              if (value == null || value == status) {
                return;
              }
              onStatusChanged(value);
            },
          ),
        ],
      ),
    );
  }
}
