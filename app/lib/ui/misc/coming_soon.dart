import 'package:flutter/material.dart';

import '../widgets/common.dart';

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, required this.icon, required this.text, this.showBack = false});
  final String title;
  final IconData icon;
  final String text;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), automaticallyImplyLeading: showBack),
      body: Center(child: SingleChildScrollView(child: EmptyState(icon: icon, title: 'Tez orada', text: text))),
    );
  }
}
