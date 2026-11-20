import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final boot = initialize();
  runApp(
    MaterialApp(
      title: 'Common Room',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff28594c)),
        scaffoldBackgroundColor: const Color(0xfff8f7f1),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: Launch(boot),
    ),
  );
}

Future<void> initialize() async {
  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    Future<void>.delayed(const Duration(milliseconds: 950)),
  ]);
}

String feedback(Object e) {
  final code = e is FirebaseException ? e.code : '';
  return switch (code) {
    'email-already-in-use' => 'This email has an account. Sign in to continue.',
    'weak-password' => 'Use a stronger password.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Check your email and password.',
    'permission-denied' =>
      'Permission denied. This account cannot perform that action.',
    'too-many-requests' => 'Too many attempts. Try again later.',
    _ => 'Could not finish. Check your connection and try again.',
  };
}

class Launch extends StatefulWidget {
  final Future<void> boot;
  const Launch(this.boot, {super.key});
  @override
  State<Launch> createState() => _Launch();
}

class _Launch extends State<Launch> {
  late Future<void> boot = widget.boot;
  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: boot,
    builder: (c, s) {
      if (s.hasError) {
        return Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => setState(() => boot = initialize()),
              child: const Text('Retry connection'),
            ),
          ),
        );
      }
      if (s.connectionState != ConnectionState.done) {
        return const Scaffold(
          backgroundColor: Color(0xff163f35),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forum_outlined, color: Colors.white, size: 56),
                Text(
                  'Common Room',
                  style: TextStyle(color: Colors.white, fontSize: 34),
                ),
                SizedBox(height: 22),
                CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),
        );
      }
      return const Gate();
    },
  );
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _Gate();
}

class _Gate extends State<Gate> {
  final auth = AuthService(), board = BoardService();
  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: auth.changes,
    builder: (c, s) {
      if (s.hasError) {
        return const Scaffold(
          body: Center(child: Text('Session unavailable. Reopen the app.')),
        );
      }
      if (s.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final user = s.data;
      if (user == null) return Access(auth, board);
      return ProfileGate(auth, board, user.uid, key: ValueKey(user.uid));
    },
  );
}

class ProfileGate extends StatefulWidget {
  final AuthService auth;
  final BoardService board;
  final String uid;
  const ProfileGate(this.auth, this.board, this.uid, {super.key});
  @override
  State<ProfileGate> createState() => _ProfileGate();
}

class _ProfileGate extends State<ProfileGate> {
  late final profile = widget.board.profile(widget.uid);
  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: profile,
    builder: (c, s) {
      if (s.hasError) {
        return Scaffold(
          body: Center(
            child: TextButton(
              onPressed: widget.auth.logout,
              child: Text('${feedback(s.error!)} Sign out'),
            ),
          ),
        );
      }
      if (s.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (s.data == null) {
        return Access(widget.auth, widget.board, uid: widget.uid);
      }
      return Board(widget.auth, widget.board, widget.uid, s.data!);
    },
  );
}

class Access extends StatefulWidget {
  final AuthService auth;
  final BoardService board;
  final String? uid;
  const Access(this.auth, this.board, {super.key, this.uid});
  @override
  State<Access> createState() => _Access();
}

class _Access extends State<Access> {
  final form = GlobalKey<FormState>();
  final values = <String, String>{};
  bool registering = false, busy = false;
  String error = '';
  bool get profile => widget.uid != null;
  Widget field(String name, {bool password = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: ValueKey(name),
      decoration: InputDecoration(labelText: name),
      obscureText: password,
      autocorrect: false,
      keyboardType: name == 'Email' ? TextInputType.emailAddress : null,
      onSaved: (v) => values[name] = password ? v! : v!.trim(),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return 'Enter your ${name.toLowerCase()}.';
        }
        if (name == 'Email' &&
            !RegExp(r'^[^ @]+@[^ @]+\.[^ @]+$').hasMatch(v.trim())) {
          return 'Enter a valid email address.';
        }
        if (password && registering && v.length < 6) {
          return 'Use at least six characters.';
        }
        if (name.endsWith('name') && v.trim().length > 60) {
          return 'Use 60 characters or fewer.';
        }
        return null;
      },
    ),
  );
  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    form.currentState!.save();
    setState(() {
      busy = true;
      error = '';
    });
    try {
      if (profile) {
        await widget.board.saveProfile(
          widget.uid!,
          values['First name']!,
          values['Last name']!,
        );
      } else if (registering) {
        await widget.auth.register(
          values['Email']!,
          values['Password']!,
          values['First name']!,
          values['Last name']!,
          widget.board,
        );
      } else {
        await widget.auth.login(values['Email']!, values['Password']!);
      }
    } catch (e) {
      if (mounted) setState(() => error = feedback(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.forum_outlined,
                    size: 44,
                    color: Color(0xff28594c),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Common Room',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    profile
                        ? 'Complete your profile'
                        : registering
                        ? 'Create account'
                        : 'Sign in',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (registering || profile) ...[
                    field('First name'),
                    field('Last name'),
                  ],
                  if (!profile) ...[
                    field('Email'),
                    field('Password', password: true),
                  ],
                  if (error.isNotEmpty) Text(error),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(
                      busy
                          ? 'Please wait…'
                          : profile
                          ? 'Save profile'
                          : registering
                          ? 'Register'
                          : 'Sign in',
                    ),
                  ),
                  if (!profile)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              registering = !registering;
                              error = '';
                            }),
                      child: Text(
                        registering
                            ? 'Already registered? Sign in'
                            : 'New here? Create account',
                      ),
                    ),
                  if (profile)
                    TextButton(
                      onPressed: widget.auth.logout,
                      child: const Text('Sign out'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class Board extends StatefulWidget {
  final AuthService auth;
  final BoardService board;
  final String uid, name;
  const Board(this.auth, this.board, this.uid, this.name, {super.key});
  @override
  State<Board> createState() => _Board();
}

class _Board extends State<Board> {
  final draft = TextEditingController();
  late final posts = widget.board.watch();
  String? intent;
  bool busy = false;
  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  Future<void> act(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(feedback(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> post() async {
    final text = draft.text.trim();
    if (text.isEmpty) return;
    intent ??= widget.board.newId();
    await widget.board.create(intent!, widget.uid, widget.name, text);
    intent = null;
    draft.clear();
  }

  Future<void> edit(Post p) async {
    String value = p.text;
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit message'),
        content: TextFormField(
          initialValue: value,
          maxLength: 1000,
          onChanged: (s) => value = s,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (value.trim().isNotEmpty) Navigator.pop(c, value.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) await widget.board.edit(p.id, result);
  }

  Future<void> remove(Post p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this message?'),
        content: Text(p.text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await widget.board.remove(p.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Common Room'),
      actions: [
        IconButton(
          tooltip: 'Sign out',
          onPressed: busy ? null : () => act(widget.auth.logout),
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Message board',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text('Signed in as ${widget.name}'),
            const Divider(),
            Expanded(
              child: StreamBuilder(
                stream: posts,
                builder: (c, s) {
                  if (s.hasError) {
                    return Center(child: Text(feedback(s.error!)));
                  }
                  if (!s.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (s.data!.isEmpty) {
                    return const Center(
                      child: Text('No messages yet. Start the conversation.'),
                    );
                  }
                  return ListView(
                    children: [
                      for (final p in s.data!)
                        Card(
                          child: ListTile(
                            title: Text(p.text),
                            subtitle: Text(
                              '${p.name}${p.edited ? " · edited" : ""}',
                            ),
                            trailing: p.uid == widget.uid
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit message',
                                        onPressed: busy
                                            ? null
                                            : () => act(() => edit(p)),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete message',
                                        onPressed: busy
                                            ? null
                                            : () => act(() => remove(p)),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            TextField(
              controller: draft,
              enabled: !busy,
              maxLength: 1000,
              onChanged: (_) {
                intent = null;
              },
              decoration: const InputDecoration(labelText: 'Message'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: busy ? null : () => act(post),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Post'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
