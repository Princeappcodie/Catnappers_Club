import 'package:flutter/material.dart';

class Extra extends StatefulWidget {
  const Extra({super.key});
  @override
  State<Extra> createState() => _ExtraState();
}
class _ExtraState extends State<Extra> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Icon(Icons.menu),
                  Text("Home", style: TextStyle(fontSize: 20)),
                  Icon(Icons.search),
                ],
              ),
            ),
            const Expanded(
              child: Center(child: Text("Content")),
            )
          ],
        ),
      ),
    );
  }
}