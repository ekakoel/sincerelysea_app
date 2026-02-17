import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sincerelysea/services/support_service.dart';
import 'package:sincerelysea/theme/app_semantic_colors.dart';
import 'package:sincerelysea/utils/auth_exception_handler.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _faqSearchController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  Timer? _draftDebounce;
  String _category = 'account';
  bool _submitting = false;
  XFile? _attachment;
  bool _restoringDraft = true;

  static const String _kDraftCategory = 'support_draft_category';
  static const String _kDraftSubject = 'support_draft_subject';
  static const String _kDraftDescription = 'support_draft_description';
  static const String _kDraftEmail = 'support_draft_email';
  static const String _kDraftAttachmentPath = 'support_draft_attachment_path';

  static const List<Map<String, String>> _faqItems = <Map<String, String>>[
    <String, String>{
      'q': 'How long does support response usually take?',
      'a':
          'Most tickets receive the first response within 24 to 48 hours depending on volume.',
    },
    <String, String>{
      'q': 'How do I reset my password?',
      'a':
          'Use the Forgot Password flow from the login screen, then check your email for reset instructions.',
    },
    <String, String>{
      'q': 'Why is my post not visible?',
      'a':
          'Check your post visibility settings and ensure image upload plus Firestore write completed successfully.',
    },
    <String, String>{
      'q': 'How can I report abusive content?',
      'a':
          'Open the post menu and choose Report. Our moderation flow will process the submitted report.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _faqSearchController.addListener(_onFaqSearchChanged);
    _subjectController.addListener(_scheduleDraftSave);
    _descriptionController.addListener(_scheduleDraftSave);
    _emailController.addListener(_scheduleDraftSave);
    final User? user = FirebaseAuth.instance.currentUser;
    _emailController.text = user?.email ?? '';
    _loadDraft();
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _faqSearchController.removeListener(_onFaqSearchChanged);
    _subjectController.removeListener(_scheduleDraftSave);
    _descriptionController.removeListener(_scheduleDraftSave);
    _emailController.removeListener(_scheduleDraftSave);
    _faqSearchController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onFaqSearchChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors semantic = context.semanticColors;
    final List<Map<String, String>> filteredFaq = _faqItems
        .where((Map<String, String> item) {
          final String query = _faqSearchController.text.trim().toLowerCase();
          if (query.isEmpty) {
            return true;
          }
          return item['q']!.toLowerCase().contains(query) ||
              item['a']!.toLowerCase().contains(query);
        })
        .toList(growable: false);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        final bool canLeave = await _confirmDiscardIfNeeded();
        if (canLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Contact Support'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SupportTicketsScreen(),
                  ),
                );
              },
              child: const Text('My Tickets'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            TextField(
              controller: _faqSearchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'How can we help?',
              ),
            ),
            const SizedBox(height: 14),
            _SectionLabel('Quick Actions', semantic: semantic),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _QuickActionChip(
                  label: 'Report a bug',
                  onTap: () => _applyQuickAction(
                    category: 'bug',
                    subject: 'Bug report: ',
                  ),
                ),
                _QuickActionChip(
                  label: 'Account issue',
                  onTap: () => _applyQuickAction(
                    category: 'account',
                    subject: 'Account issue: ',
                  ),
                ),
                _QuickActionChip(
                  label: 'Payment/Billing',
                  onTap: () => _applyQuickAction(
                    category: 'billing',
                    subject: 'Billing question: ',
                  ),
                ),
                _QuickActionChip(
                  label: 'Privacy & Safety',
                  onTap: () => _applyQuickAction(
                    category: 'privacy',
                    subject: 'Privacy/Safety issue: ',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SectionLabel('FAQ', semantic: semantic),
            const SizedBox(height: 8),
            if (filteredFaq.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('No FAQ matches your search.'),
                ),
              )
            else
              ...filteredFaq.map(
                (Map<String, String> item) => ExpansionTile(
                  title: Text(item['q']!),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(item['a']!),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 10),
            _SectionLabel('Submit Ticket', semantic: semantic),
            const SizedBox(height: 8),
            Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: 'account',
                        child: Text('Account'),
                      ),
                      DropdownMenuItem(value: 'bug', child: Text('Bug')),
                      DropdownMenuItem(
                        value: 'billing',
                        child: Text('Billing'),
                      ),
                      DropdownMenuItem(
                        value: 'privacy',
                        child: Text('Privacy'),
                      ),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: _submitting
                        ? null
                        : (String? value) {
                            if (value != null) {
                              setState(() => _category = value);
                              _scheduleDraftSave();
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subjectController,
                    enabled: !_submitting,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      hintText: 'Short summary of your issue',
                    ),
                    validator: (String? value) {
                      final String text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'Subject is required.';
                      }
                      if (text.length < 6) {
                        return 'Subject is too short.';
                      }
                      if (text.length > 100) {
                        return 'Subject must be 100 characters max.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    enabled: !_submitting,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText:
                          'Explain what happened, expected behavior, and steps to reproduce.',
                    ),
                    validator: (String? value) {
                      final String text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'Description is required.';
                      }
                      if (text.length < 20) {
                        return 'Please provide more detail (min 20 chars).';
                      }
                      if (text.length > 1000) {
                        return 'Description must be 1000 characters max.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    enabled: !_submitting,
                    decoration: const InputDecoration(
                      labelText: 'Contact email',
                      hintText: 'you@example.com',
                    ),
                    validator: (String? value) {
                      final String email = value?.trim() ?? '';
                      if (email.isEmpty) {
                        return 'Contact email is required.';
                      }
                      if (!RegExp(
                        r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$',
                      ).hasMatch(email)) {
                        return 'Please enter a valid email.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: _submitting
                              ? null
                              : () => _pickAttachment(ImageSource.gallery),
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Attach Screenshot'),
                        ),
                        if (_attachment != null)
                          OutlinedButton.icon(
                            onPressed: _submitting
                                ? null
                                : () {
                                    setState(() => _attachment = null);
                                    _scheduleDraftSave();
                                  },
                            icon: const Icon(Icons.close),
                            label: const Text('Remove Attachment'),
                          ),
                      ],
                    ),
                  ),
                  if (_attachment != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.attachment_outlined),
                      title: Text(_attachment!.name),
                      subtitle: const Text(
                        'Attachment will be uploaded with your ticket.',
                      ),
                    ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submitTicket,
                      icon: _submitting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined),
                      label: Text(_submitting ? 'Sending...' : 'Send Ticket'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    if (_subjectController.text.trim().isEmpty &&
        _descriptionController.text.trim().isEmpty &&
        _attachment == null) {
      return true;
    }
    final bool discard =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Discard draft?'),
            content: const Text(
              'You have an unfinished support draft. Leave without sending?',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
    if (discard) {
      _clearDraft();
    }
    return discard;
  }

  Future<void> _pickAttachment(ImageSource source) async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (file != null && mounted) {
        setState(() => _attachment = file);
        _scheduleDraftSave();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick attachment.')),
      );
    }
  }

  void _applyQuickAction({required String category, required String subject}) {
    setState(() => _category = category);
    if (_subjectController.text.trim().isEmpty) {
      _subjectController.text = subject;
      _subjectController.selection = TextSelection.collapsed(
        offset: _subjectController.text.length,
      );
    }
  }

  Future<void> _submitTicket() async {
    if (_submitting) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final SupportService support = context.read<SupportService>();
      final ({String ticketId, String ticketNumber}) result = await support
          .createTicket(
            category: _category,
            subject: _subjectController.text.trim(),
            description: _descriptionController.text.trim(),
            contactEmail: _emailController.text.trim(),
            deviceInfo: _collectDeviceInfo(),
            attachmentPath: _attachment?.path,
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SupportTicketSubmittedScreen(
            ticketId: result.ticketId,
            ticketNumber: result.ticketNumber,
          ),
        ),
      );
      await _clearDraft();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_mapSupportSubmitError(e))));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Map<String, dynamic> _collectDeviceInfo() {
    return <String, dynamic>{
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'locale': WidgetsBinding.instance.platformDispatcher.locale
          .toLanguageTag(),
      'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
    };
  }

  String _mapSupportSubmitError(Object e) {
    if (e is FirebaseException &&
        (e.code == 'unavailable' || e.code == 'network-request-failed')) {
      return 'No internet connection. Your draft is saved, please retry later.';
    }
    return AuthExceptionHandler.handleException(e);
  }

  Future<void> _loadDraft() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? subject = prefs.getString(_kDraftSubject);
      final String? description = prefs.getString(_kDraftDescription);
      final String? email = prefs.getString(_kDraftEmail);
      final String? category = prefs.getString(_kDraftCategory);
      final String? attachmentPath = prefs.getString(_kDraftAttachmentPath);
      if (!mounted) {
        return;
      }
      setState(() {
        if ((subject ?? '').trim().isNotEmpty) {
          _subjectController.text = subject!.trim();
        }
        if ((description ?? '').trim().isNotEmpty) {
          _descriptionController.text = description!.trim();
        }
        if ((email ?? '').trim().isNotEmpty) {
          _emailController.text = email!.trim();
        }
        if ((category ?? '').trim().isNotEmpty) {
          _category = category!;
        }
        if ((attachmentPath ?? '').trim().isNotEmpty) {
          _attachment = XFile(attachmentPath!);
        }
      });
    } finally {
      if (mounted) {
        setState(() => _restoringDraft = false);
      }
    }
  }

  void _scheduleDraftSave() {
    if (_restoringDraft) {
      return;
    }
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 350), _persistDraft);
  }

  Future<void> _persistDraft() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDraftCategory, _category);
    await prefs.setString(_kDraftSubject, _subjectController.text.trim());
    await prefs.setString(
      _kDraftDescription,
      _descriptionController.text.trim(),
    );
    await prefs.setString(_kDraftEmail, _emailController.text.trim());
    await prefs.setString(_kDraftAttachmentPath, _attachment?.path ?? '');
  }

  Future<void> _clearDraft() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDraftCategory);
    await prefs.remove(_kDraftSubject);
    await prefs.remove(_kDraftDescription);
    await prefs.remove(_kDraftEmail);
    await prefs.remove(_kDraftAttachmentPath);
  }
}

class SupportTicketSubmittedScreen extends StatelessWidget {
  const SupportTicketSubmittedScreen({
    super.key,
    required this.ticketId,
    required this.ticketNumber,
  });

  final String ticketId;
  final String ticketNumber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ticket Sent')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.check_circle_outline, size: 64),
              const SizedBox(height: 12),
              const Text(
                'Ticket sent successfully',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text('Ticket ID: $ticketNumber', textAlign: TextAlign.center),
              const SizedBox(height: 4),
              const Text(
                'Estimated first response: 24-48 hours',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SupportTicketDetailScreen(ticketId: ticketId),
                      ),
                    );
                  },
                  child: const Text('View ticket'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                        builder: (_) => const SupportTicketsScreen(),
                      ),
                      (Route<dynamic> route) => route.isFirst,
                    );
                  },
                  child: const Text('View my tickets'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final SupportService support = context.read<SupportService>();
    final AppSemanticColors semantic = context.semanticColors;
    return Scaffold(
      appBar: AppBar(title: const Text('My Tickets')),
      body: Column(
        children: <Widget>[
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _buildFilterChip('All', 'all'),
                _buildFilterChip('Open', 'open'),
                _buildFilterChip('In Progress', 'in_progress'),
                _buildFilterChip('Resolved', 'resolved'),
                _buildFilterChip('Closed', 'closed'),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: support.myTicketsStream(),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                  ) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'Failed to load tickets: ${snapshot.error}',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              FilledButton.tonal(
                                onPressed: () => setState(() {}),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    docs =
                        snapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    filtered = docs
                        .where((
                          QueryDocumentSnapshot<Map<String, dynamic>> doc,
                        ) {
                          if (_statusFilter == 'all') return true;
                          return (doc.data()['status']?.toString() ?? '') ==
                              _statusFilter;
                        })
                        .toList(growable: false);

                    if (filtered.isEmpty) {
                      return const Center(child: Text('No tickets yet.'));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: semantic.divider),
                      itemBuilder: (BuildContext context, int index) {
                        final Map<String, dynamic> data = filtered[index]
                            .data();
                        final String ticketId = filtered[index].id;
                        final String status =
                            data['status']?.toString() ?? 'open';
                        final String subject =
                            data['subject']?.toString() ?? 'Untitled ticket';
                        final String category =
                            data['category']?.toString() ?? 'other';
                        final Timestamp? updatedAt =
                            data['updatedAt'] as Timestamp?;
                        final String updatedText = updatedAt == null
                            ? '-'
                            : DateFormat(
                                'dd MMM yyyy, HH:mm',
                              ).format(updatedAt.toDate());

                        return ListTile(
                          leading: Icon(
                            Icons.support_agent_outlined,
                            color: semantic.notificationIcon,
                          ),
                          title: Text(
                            subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${data['ticketNumber'] ?? ticketId} • ${category.toUpperCase()} • Updated $updatedText',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: _StatusChip(status: status),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SupportTicketDetailScreen(
                                  ticketId: ticketId,
                                ),
                              ),
                            );
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
  }

  Widget _buildFilterChip(String label, String value) {
    final bool selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) => setState(() => _statusFilter = value),
      ),
    );
  }
}

class SupportTicketDetailScreen extends StatefulWidget {
  const SupportTicketDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<SupportTicketDetailScreen> createState() =>
      _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState extends State<SupportTicketDetailScreen> {
  final TextEditingController _replyController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SupportService support = context.read<SupportService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Ticket Detail')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: support.ticketStream(widget.ticketId),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>>
              ticketSnapshot,
            ) {
              if (ticketSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (ticketSnapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Failed to load ticket: ${ticketSnapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        FilledButton.tonal(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!ticketSnapshot.hasData || !ticketSnapshot.data!.exists) {
                return const Center(child: Text('Ticket not found.'));
              }

              final Map<String, dynamic> ticket =
                  ticketSnapshot.data!.data() ?? <String, dynamic>{};
              final String status = ticket['status']?.toString() ?? 'open';
              final bool closed = status == 'closed';

              return Column(
                children: <Widget>[
                  _TicketHeader(ticket: ticket),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: support.ticketMessagesStream(widget.ticketId),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                            msgSnapshot,
                          ) {
                            if (msgSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (msgSnapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Failed to load timeline: ${msgSnapshot.error}',
                                  ),
                                ),
                              );
                            }
                            final List<
                              QueryDocumentSnapshot<Map<String, dynamic>>
                            >
                            msgs =
                                msgSnapshot.data?.docs ??
                                <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                              itemCount: msgs.length,
                              itemBuilder: (BuildContext context, int index) {
                                final Map<String, dynamic> data = msgs[index]
                                    .data();
                                final String sender =
                                    data['senderType']?.toString() ?? 'user';
                                final String message =
                                    data['message']?.toString() ?? '';
                                final Timestamp? ts =
                                    data['createdAt'] as Timestamp?;
                                return _MessageBubble(
                                  message: message,
                                  sender: sender,
                                  createdAt: ts?.toDate(),
                                );
                              },
                            );
                          },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _replyController,
                              enabled: !_sending && !closed,
                              minLines: 1,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: closed
                                    ? 'Ticket is closed'
                                    : 'Add a follow-up message',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: (_sending || closed) ? null : _sendReply,
                            icon: _sending
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
      ),
    );
  }

  Future<void> _sendReply() async {
    final String message = _replyController.text.trim();
    if (message.isEmpty) {
      return;
    }
    setState(() => _sending = true);
    try {
      await context.read<SupportService>().addReply(
        ticketId: widget.ticketId,
        message: message,
      );
      _replyController.clear();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthExceptionHandler.handleException(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.semantic});

  final String text;
  final AppSemanticColors semantic;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: semantic.notificationIcon,
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    String text = status;
    if (status == 'in_progress') {
      text = 'in progress';
    }
    return Chip(visualDensity: VisualDensity.compact, label: Text(text));
  }
}

class _TicketHeader extends StatelessWidget {
  const _TicketHeader({required this.ticket});

  final Map<String, dynamic> ticket;

  @override
  Widget build(BuildContext context) {
    final String subject = ticket['subject']?.toString() ?? 'Support ticket';
    final String status = ticket['status']?.toString() ?? 'open';
    final String ticketNo = ticket['ticketNumber']?.toString() ?? '-';
    final String category = ticket['category']?.toString() ?? 'other';
    final String attachmentUrl = ticket['attachmentUrl']?.toString() ?? '';
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              subject,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text('Ticket: $ticketNo'),
            Text('Category: ${category.toUpperCase()}'),
            Text('Status: ${status.toUpperCase()}'),
            if (attachmentUrl.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              SelectableText('Attachment: $attachmentUrl'),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.sender,
    required this.createdAt,
  });

  final String message;
  final String sender;
  final DateTime? createdAt;

  @override
  Widget build(BuildContext context) {
    final bool fromUser = sender == 'user';
    final Alignment align = fromUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              crossAxisAlignment: fromUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: <Widget>[
                Text(message),
                const SizedBox(height: 4),
                Text(
                  createdAt == null
                      ? '-'
                      : DateFormat('dd MMM HH:mm').format(createdAt!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
