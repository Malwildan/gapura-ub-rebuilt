import 'package:flutter/material.dart';

/// Recovered PageHeader (ci23575); inherited text metrics remain theme-owned.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Container(
    height: 200,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0xff003153), Color(0xff0070bd)],
        stops: [0.19, 0.81],
      ),
      image: DecorationImage(
        image: AssetImage('assets/img/fluid-nav.png'),
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
      ),
    ),
    child: Container(
      margin: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width / 100 * 5,
        130,
        0,
        0,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}
