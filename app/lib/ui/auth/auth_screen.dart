import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/supa.dart';
import '../../state/session.dart';
import '../../theme.dart';
import 'auth_data.dart';

/// Phone number + the user's own 6-digit confirmation code (no SMS).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool register = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
          children: [
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(colors: [AppColors.teal, AppColors.navy], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: const Icon(Icons.public, color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 14),
            Text('Migrant Hub', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text('Rossiyadagi yurtdoshlar uchun yordamchi', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 26),
            SegmentedButton<bool>(
              segments: const [ButtonSegment(value: false, label: Text('Kirish')), ButtonSegment(value: true, label: Text('Ro‘yxatdan o‘tish'))],
              selected: {register},
              onSelectionChanged: (s) => setState(() => register = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 22),
            AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: register ? const _RegisterForm(key: ValueKey('r')) : const _LoginForm(key: ValueKey('l'))),
          ],
        ),
      ),
    );
  }
}

InputDecoration _dec(String label, {String? hint, Widget? prefix}) => InputDecoration(labelText: label, hintText: hint, prefixIcon: prefix);

final _phoneFormatters = [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]')), LengthLimitingTextInputFormatter(20)];
final _codeFormatters = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)];

class _LoginForm extends StatefulWidget {
  const _LoginForm({super.key});

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final phone = TextEditingController(text: '+7 ');
  final code = TextEditingController();
  bool busy = false;
  bool hide = true;
  String? error;

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final notice = await AppSession.instance.authCall({'action': 'login', 'phone': phone.text, 'code': code.text});
      if (notice != null && mounted) await showDialog(context: context, builder: (c) => AlertDialog(content: Text(notice), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tushunarli'))]));
    } catch (e) {
      setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> forgot() async {
    final digits = phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      setState(() => error = 'Avval telefon raqamingizni kiriting');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kodni unutdingizmi?'),
        content: const Text('Kodni tiklab bo‘lmaydi. So‘rov yuborilgach, 48 soatdan keyin bu raqamdagi hisob va barcha ma’lumotlar o‘chiriladi, keyin shu raqam bilan qaytadan ro‘yxatdan o‘tasiz.\n\nKodni eslab qolsangiz, shu vaqt ichida to‘g‘ri kod bilan kirib so‘rovni bekor qilishingiz mumkin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Bekor qilish')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('So‘rov yuborish', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await supa.functions.invoke('auth', body: {'action': 'forgot', 'phone': phone.text});
      final until = DateTime.tryParse((res.data as Map)['pendingUntil'] as String? ?? '');
      if (mounted) toast(context, until == null ? 'So‘rov yuborildi' : 'So‘rov qabul qilindi. ${until.toLocal().toString().substring(0, 16)} dan keyin qayta ro‘yxatdan o‘tishingiz mumkin.');
    } catch (e) {
      setState(() => error = errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(controller: phone, keyboardType: TextInputType.phone, inputFormatters: _phoneFormatters, decoration: _dec('Telefon raqami', prefix: const Icon(Icons.phone_outlined))),
      const SizedBox(height: 12),
      TextField(
        controller: code,
        keyboardType: TextInputType.number,
        obscureText: hide,
        inputFormatters: _codeFormatters,
        onSubmitted: (_) => submit(),
        decoration: _dec('Tasdiqlash kodi (6 raqam)', prefix: const Icon(Icons.lock_outline)).copyWith(
          suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => hide = !hide)),
        ),
      ),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: AppColors.danger, height: 1.4))),
      const SizedBox(height: 18),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Text('Kirish')),
      const SizedBox(height: 6),
      TextButton(onPressed: busy ? null : forgot, child: const Text('Kodni unutdim')),
    ]);
  }
}

class _RegisterForm extends StatefulWidget {
  const _RegisterForm({super.key});

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final first = TextEditingController();
  final last = TextEditingController();
  final phone = TextEditingController(text: '+7 ');
  final code = TextEditingController();
  final code2 = TextEditingController();
  final email = TextEditingController();
  DateTime? birth;
  String citizenship = 'uz';
  String region = ruRegions.first;
  bool terms = false;
  bool busy = false;
  String? error;

  String? validate() {
    if (first.text.trim().length < 2) return 'Ismingizni kiriting';
    if (phone.text.replaceAll(RegExp(r'\D'), '').length < 10) return 'Telefon raqamini to‘liq kiriting';
    if (birth == null) return 'Tug‘ilgan sanangizni tanlang';
    if (!RegExp(r'^\d{6}$').hasMatch(code.text)) return 'Tasdiqlash kodi 6 ta raqamdan iborat bo‘lsin';
    if (code.text != code2.text) return 'Kodlar bir xil emas';
    if (email.text.trim().isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim())) return 'Email noto‘g‘ri';
    if (!terms) return 'Foydalanish shartlariga rozilik bering';
    return null;
  }

  Future<void> submit() async {
    final v = validate();
    if (v != null) {
      setState(() => error = v);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AppSession.instance.authCall({
        'action': 'register',
        'phone': phone.text,
        'code': code.text,
        'firstName': first.text.trim(),
        'lastName': last.text.trim(),
        'birthDate': '${birth!.year.toString().padLeft(4, '0')}-${birth!.month.toString().padLeft(2, '0')}-${birth!.day.toString().padLeft(2, '0')}',
        'citizenship': citizenship,
        'region': region,
        'email': email.text.trim(),
        'terms': true,
      });
    } catch (e) {
      setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: TextField(controller: first, textCapitalization: TextCapitalization.words, decoration: _dec('Ism'))),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: last, textCapitalization: TextCapitalization.words, decoration: _dec('Familiya'))),
      ]),
      const SizedBox(height: 12),
      TextField(controller: phone, keyboardType: TextInputType.phone, inputFormatters: _phoneFormatters, decoration: _dec('Telefon raqami', prefix: const Icon(Icons.phone_outlined))),
      const SizedBox(height: 12),
      InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final now = DateTime.now();
          final d = await showDatePicker(context: context, initialDate: birth ?? DateTime(now.year - 25), firstDate: DateTime(1940), lastDate: DateTime(now.year - 14, now.month, now.day));
          if (d != null) setState(() => birth = d);
        },
        child: InputDecorator(
          decoration: _dec('Tug‘ilgan sana', prefix: const Icon(Icons.cake_outlined)),
          child: Text(birth == null ? 'Tanlang' : '${birth!.day.toString().padLeft(2, '0')}.${birth!.month.toString().padLeft(2, '0')}.${birth!.year}', style: TextStyle(color: birth == null ? AppColors.muted : AppColors.ink)),
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: citizenship,
        decoration: _dec('Fuqaroligingiz'),
        items: [for (final (id, name, flag) in citizenships) DropdownMenuItem(value: id, child: Text('$flag  $name'))],
        onChanged: (v) => setState(() => citizenship = v ?? 'uz'),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: region,
        isExpanded: true,
        menuMaxHeight: 420,
        decoration: _dec('Hozir qayerda yashaysiz'),
        items: [for (final r in ruRegions) DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis))],
        onChanged: (v) => setState(() => region = v ?? ruRegions.first),
      ),
      const SizedBox(height: 18),
      const Text('O‘zingiz 6 xonali tasdiqlash kodini o‘ylab toping. U bilan hisobga kirasiz — hech kimga aytmang.', style: TextStyle(color: AppColors.muted, height: 1.4)),
      const SizedBox(height: 10),
      TextField(controller: code, keyboardType: TextInputType.number, obscureText: true, inputFormatters: _codeFormatters, decoration: _dec('Tasdiqlash kodi', prefix: const Icon(Icons.lock_outline))),
      const SizedBox(height: 12),
      TextField(controller: code2, keyboardType: TextInputType.number, obscureText: true, inputFormatters: _codeFormatters, decoration: _dec('Kodni takrorlang', prefix: const Icon(Icons.lock_outline))),
      const SizedBox(height: 12),
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: _dec('Email (ixtiyoriy)', hint: 'Hisobni tiklash uchun', prefix: const Icon(Icons.alternate_email))),
      const SizedBox(height: 8),
      CheckboxListTile(
        value: terms,
        onChanged: (v) => setState(() => terms = v ?? false),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Foydalanish shartlari va maxfiylik siyosatiga roziman', style: TextStyle(fontSize: 14)),
      ),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 4, bottom: 4), child: Text(error!, style: const TextStyle(color: AppColors.danger, height: 1.4))),
      const SizedBox(height: 10),
      FilledButton(onPressed: busy ? null : submit, child: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Text('Ro‘yxatdan o‘tish')),
    ]);
  }
}
