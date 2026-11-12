import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../ui/screen_components.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../events/bloc/event_bloc.dart';
import '../bloc/profile_cubit.dart';
import '../models/user_profile.dart';
import '../repositories/profile_repository.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocListener<AuthBloc, AuthState>(
    listener: (context, state) {
      if (state is AuthUnauthenticated) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    },
    child: Builder(
      builder: (context) {
        final auth = context.watch<AuthBloc>().state;
        if (auth is! AuthAuthenticated) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: const Center(
              child: Text('Please log in to view your profile'),
            ),
          );
        }
        return BlocProvider(
          key: ValueKey(auth.userId),
          create: (_) => ProfileCubit(
            context.read<ProfileStore>(),
            context.read<EventBloc>().repository,
            auth.userId,
          ),
          child: const _ProfileView(),
        );
      },
    ),
  );
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();
  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _dirty = false;
  String? _submitted;
  int _lastNoticeId = 0;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<bool> _confirm(String title, String content, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
  String _date(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ProfileCubit, ProfileState>(
    listener: (context, state) {
      final newNotice = state.noticeId != _lastNoticeId;
      _lastNoticeId = state.noticeId;
      if (newNotice && state.success == ProfileAction.save) {
        _dirty = false;
        _name.text = _submitted ?? state.data.profile?.name ?? _name.text;
        _submitted = null;
      } else if (!_dirty &&
          state.data.profile != null &&
          _name.text != state.data.profile!.name) {
        _name.text = state.data.profile!.name;
      }
    },
    listenWhen: (previous, current) =>
        previous.data.profile != current.data.profile ||
        previous.noticeId != current.noticeId,
    builder: (context, state) {
      final cubit = context.read<ProfileCubit>();
      final profile = state.data.profile;
      final busy = state.busy != null;
      return BlocListener<ProfileCubit, ProfileState>(
        listenWhen: (previous, current) =>
            previous.noticeId != current.noticeId,
        listener: (context, state) {
          if (state.success == ProfileAction.logout) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else if (state.success == null) {
            showErrorSnackBar(context, state.notice!);
          } else {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.notice!)));
          }
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: ContentWidth(
            maxWidth: 640,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (profile == null && state.data.error == null)
                  const StatusPanel.loading(title: 'Loading profile'),
                if (state.data.error != null)
                  StatusPanel(
                    title: 'Unable to load profile',
                    icon: Icons.error_outline,
                    detail: state.data.error,
                    onRetry: busy ? null : cubit.reload,
                  ),
                if (profile != null) ...[
                  Icon(
                    Icons.account_circle,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    profile.email ?? 'Email unavailable',
                    textAlign: TextAlign.center,
                  ),
                  if (profile.createdAt != null)
                    Text(
                      'Member since ${_date(profile.createdAt!)}',
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 24),
                  Form(
                    key: _form,
                    child: TextFormField(
                      controller: _name,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.words,
                      enabled: !busy,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: UserProfile.nameError,
                      onChanged: (_) => _dirty = true,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () {
                            if (!_form.currentState!.validate()) return;
                            _submitted = _name.text.trim();
                            cubit.saveName(_submitted!);
                          },
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      state.busy == ProfileAction.save
                          ? 'Saving...'
                          : 'Save Profile',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Your activity',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  _metric(
                    'Created events',
                    state.created.count,
                    state.created.error,
                  ),
                  _metric(
                    'Event registrations',
                    state.registered.count,
                    state.registered.error,
                  ),
                  _metric(
                    'Participants in your events',
                    state.created.participants,
                    state.created.error,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed:
                        busy ||
                            !profile.canResetPassword ||
                            profile.email == null
                        ? null
                        : () async {
                            final confirmed = await _confirm(
                              'Reset Password?',
                              'Send a password reset link to ${profile.email}?',
                              'Send Email',
                            );
                            if (confirmed && !cubit.isClosed) {
                              await cubit.resetPassword();
                            }
                          },
                    icon: const Icon(Icons.lock_reset),
                    label: Text(
                      state.busy == ProfileAction.resetPassword
                          ? 'Sending...'
                          : 'Reset Password',
                    ),
                  ),
                  if (!profile.canResetPassword)
                    const Text(
                      'Password reset is unavailable for this sign-in method',
                    ),
                ],
                TextButton(
                  onPressed: busy ? null : cubit.reload,
                  child: const Text('Reload Profile and Statistics'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          final confirmed = await _confirm(
                            'Sign Out?',
                            'Sign out of your account on this device?',
                            'Sign Out',
                          );
                          if (confirmed && !cubit.isClosed) {
                            await cubit.logout();
                          }
                        },
                  icon: const Icon(Icons.logout),
                  label: Text(
                    state.busy == ProfileAction.logout
                        ? 'Signing out...'
                        : 'Sign Out',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  Widget _metric(String label, int? value, String? error) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: error == null ? null : Text(error),
    trailing: Text(
      error != null ? 'Unavailable' : value?.toString() ?? 'Loading...',
    ),
  );
}
