import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sincerelysea/l10n/app_localizations.dart';
import 'package:sincerelysea/services/account_lifecycle_service.dart';
import 'package:sincerelysea/services/auth_service.dart';
import 'package:sincerelysea/services/user_profile_service.dart';
import 'package:sincerelysea/utils/auth_exception_handler.dart';
import 'package:sincerelysea/utils/username_text_input_formatter.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  bool _initialized = false;
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _deletingAccount = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<UserProfileService>().updateProfile(
        displayName: _displayNameController.text,
        bio: _bioController.text,
        location: _locationController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _changeUsernameDialog({
    required bool changedOnce,
    required String currentUsername,
    required String currentUid,
  }) async {
    if (changedOnce) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).usernameCanOnlyChangeOnce),
        ),
      );
      return;
    }

    final TextEditingController usernameController = TextEditingController(
      text: currentUsername,
    );
    bool isSubmitting = false;
    bool isChecking = false;
    bool? isAvailable;
    String status = '3-20 chars: a-z, 0-9, _';
    Timer? debounceTimer;
    final UserProfileService profileService = context
        .read<UserProfileService>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    Future<void> checkAvailability(StateSetter setModalState) async {
      final String normalized = profileService.normalizeUsername(
        usernameController.text,
      );
      if (!profileService.isUsernameFormatValid(normalized)) {
        setModalState(() {
          isChecking = false;
          isAvailable = false;
          status = 'Use 3-20 chars: a-z, 0-9, _';
        });
        return;
      }
      if (normalized == currentUsername) {
        setModalState(() {
          isChecking = false;
          isAvailable = false;
          status = AppLocalizations.of(context).usernameMustBeDifferent;
        });
        return;
      }
      setModalState(() {
        isChecking = true;
        isAvailable = null;
        status = 'Checking...';
      });
      try {
        final bool available = await profileService.isUsernameAvailable(
          normalized,
          excludeUid: currentUid,
        );
        setModalState(() {
          isChecking = false;
          isAvailable = available;
          status = available ? 'Username available' : 'Username already in use';
        });
      } catch (_) {
        setModalState(() {
          isChecking = false;
          isAvailable = false;
          status = 'Failed to check username';
        });
      }
    }

    void scheduleCheck(StateSetter setModalState) {
      debounceTimer?.cancel();
      debounceTimer = Timer(const Duration(milliseconds: 400), () {
        checkAvailability(setModalState);
      });
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return AlertDialog(
            title: const Text('Change Username'),
            content: TextField(
              controller: usernameController,
              maxLength: 20,
              onChanged: (_) => scheduleCheck(setModalState),
              inputFormatters: <TextInputFormatter>[
                LengthLimitingTextInputFormatter(20),
                UsernameTextInputFormatter(),
              ],
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).usernamePlaceholder,
                helperText: status,
                helperStyle: TextStyle(
                  color: isAvailable == true
                      ? AppColors.black
                      : isAvailable == false
                      ? AppColors.gray500
                      : AppColors.gray600,
                ),
                suffixIcon: isChecking
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : isAvailable == true
                    ? const Icon(Icons.check_circle, color: AppColors.black)
                    : isAvailable == false
                    ? const Icon(Icons.cancel, color: AppColors.gray500)
                    : null,
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        await checkAvailability(setModalState);
                        if (isAvailable != true) {
                          return;
                        }
                        setModalState(() => isSubmitting = true);
                        try {
                          await profileService.changeUsernameOnce(
                            usernameController.text,
                          );
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Username updated')),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed to change username: $e'),
                            ),
                          );
                        } finally {
                          if (context.mounted) {
                            setModalState(() => isSubmitting = false);
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
    debounceTimer?.cancel();
  }

  Future<void> _pickAndUploadAvatar() async {
    final ImagePicker picker = ImagePicker();
    final UserProfileService profileService = context
        .read<UserProfileService>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }
    setState(() => _uploadingAvatar = true);
    try {
      await profileService.uploadProfilePhoto(File(picked.path));
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Profile photo updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to upload profile photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    }
  }

  Future<String?> _askPasswordForReauth() async {
    final TextEditingController passwordController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm password'),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Enter your password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(passwordController.text),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = context.watch<User?>();
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login first.')));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: context.read<UserProfileService>().profileStream(user.uid),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> data =
                snapshot.data?.data() ?? <String, dynamic>{};
            final String displayName =
                data['displayName']?.toString() ??
                user.displayName ??
                user.email?.split('@').first ??
                'User';
            final String bio = data['bio']?.toString() ?? '';
            final String location = data['location']?.toString() ?? '';
            final String username =
                data['username']?.toString() ??
                _emailPrefixLower(user.email) ??
                'user';
            final bool changedOnce = data['usernameChangedOnce'] == true;
            final String? avatarUrl =
                data['photoUrl']?.toString().isNotEmpty == true
                ? data['photoUrl']?.toString()
                : user.photoURL;
            final bool profileReady =
                snapshot.connectionState != ConnectionState.waiting;

            if (!_initialized && profileReady) {
              _displayNameController.text = displayName;
              _bioController.text = bio;
              _locationController.text = location;
              _initialized = true;
            }

            return Scaffold(
              appBar: AppBar(
                title: const Text('Profile Settings'),
                actions: <Widget>[
                  TextButton(
                    onPressed: _saving ? null : _saveProfile,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
              body: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          CircleAvatar(
                            radius: 52,
                            backgroundColor: AppColors.gray300,
                            backgroundImage:
                                avatarUrl != null && avatarUrl.isNotEmpty
                                ? CachedNetworkImageProvider(avatarUrl)
                                : null,
                            child: avatarUrl == null || avatarUrl.isEmpty
                                ? Text(
                                    displayName.isNotEmpty
                                        ? displayName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: IconButton.filled(
                              onPressed: _uploadingAvatar
                                  ? null
                                  : _pickAndUploadAvatar,
                              icon: _uploadingAvatar
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('@$username'),
                      subtitle: Text(
                        changedOnce
                            ? AppLocalizations.of(
                                context,
                              ).usernameAlreadyChanged
                            : AppLocalizations.of(
                                context,
                              ).usernameCanChangeOnce,
                      ),
                      trailing: OutlinedButton(
                        onPressed: () => _changeUsernameDialog(
                          changedOnce: changedOnce,
                          currentUsername: username,
                          currentUid: user.uid,
                        ),
                        child: const Text('Change'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _displayNameController,
                      maxLength: 40,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                      ),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppLocalizations.of(
                            context,
                          ).displayNameRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _bioController,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 160,
                      decoration: const InputDecoration(labelText: 'Bio'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _locationController,
                      maxLength: 80,
                      decoration: const InputDecoration(labelText: 'Location'),
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Export my data'),
                            onPressed: () async {
                              final String json = await context
                                  .read<AccountLifecycleService>()
                                  .exportMyDataAsJson();
                              await SharePlus.instance.share(
                                ShareParams(
                                  text: json,
                                  subject: 'SincerelySea data export',
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.tonalIcon(
                            icon: _deletingAccount
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.delete_forever_outlined),
                            label: const Text('Hard delete account'),
                            onPressed: _deletingAccount
                                ? null
                                : () async {
                                    final AccountLifecycleService
                                    accountService = context
                                        .read<AccountLifecycleService>();
                                    final AuthService authService = context
                                        .read<AuthService>();
                                    final User? currentUser = context
                                        .read<User?>();
                                    if (currentUser == null) {
                                      return;
                                    }
                                    final bool confirmed =
                                        await showDialog<bool>(
                                          context: context,
                                          builder: (BuildContext ctx) =>
                                              AlertDialog(
                                                title: const Text(
                                                  'Hard delete account',
                                                ),
                                                content: const Text(
                                                  'This will permanently delete Auth account, profile, posts, and media. This action cannot be undone.',
                                                ),
                                                actions: <Widget>[
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          ctx,
                                                        ).pop(false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          ctx,
                                                        ).pop(true),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                        ) ??
                                        false;
                                    if (!confirmed) {
                                      return;
                                    }
                                    setState(() => _deletingAccount = true);
                                    try {
                                      String? password;
                                      if (authService.usesPasswordProvider(
                                        currentUser,
                                      )) {
                                        password =
                                            await _askPasswordForReauth();
                                        if (password == null) {
                                          return;
                                        }
                                      }

                                      await authService
                                          .reauthenticateForSensitiveAction(
                                            password: password,
                                          );
                                      await accountService
                                          .hardDeleteMyAccount();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Account deleted successfully',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        final String message =
                                            AuthExceptionHandler.handleException(
                                              e,
                                            );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(message)),
                                        );
                                      }
                                    } finally {
                                      if (context.mounted) {
                                        setState(
                                          () => _deletingAccount = false,
                                        );
                                      }
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
    );
  }
}

String? _emailPrefixLower(String? email) {
  if (email == null || email.isEmpty) {
    return null;
  }
  return email.split('@').first.toLowerCase();
}
