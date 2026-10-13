import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/auth_store.dart';
import '../../data/models.dart';
import '../../state/app_controller.dart';

class LoginScreen extends StatefulWidget {
  final AppController controller;
  const LoginScreen({super.key, required this.controller});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _pw = TextEditingController();
  final _base = TextEditingController();
  bool _busy = false;
  bool _showAdv = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    AuthStore.apiBase().then((v) => _base.text = v);
    _err = widget.controller.banner;
  }

  Future<void> _go() async {
    if (_name.text.trim().isEmpty || _pw.text.isEmpty) {
      setState(() => _err = 'Enter your username and password');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      widget.controller.banner = null;
      await widget.controller.login(_name.text, _pw.text, apiBase: _showAdv ? _base.text : null);
    } on ApiException catch (e) {
      if (mounted) setState(() => _err = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Icon(Icons.my_location, size: 56, color: kBrand),
                const SizedBox(height: 12),
                const Text('Geo Attendance', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Check-in and check-out happen automatically at your work site.', textAlign: TextAlign.center, style: TextStyle(color: kSlate)),
                const SizedBox(height: 28),
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline)), textInputAction: TextInputAction.next, autocorrect: false),
                const SizedBox(height: 12),
                TextField(controller: _pw, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)), onSubmitted: (_) => _go()),
                if (_showAdv) ...[
                  const SizedBox(height: 12),
                  TextField(controller: _base, decoration: const InputDecoration(labelText: 'Server address', prefixIcon: Icon(Icons.dns_outlined)), keyboardType: TextInputType.url, autocorrect: false),
                ],
                if (_err != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_err!, style: const TextStyle(color: kRed))),
                const SizedBox(height: 20),
                FilledButton(onPressed: _busy ? null : _go, child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Sign in')),
                TextButton(onPressed: () => setState(() => _showAdv = !_showAdv), child: Text(_showAdv ? 'Hide server settings' : 'Server settings')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
