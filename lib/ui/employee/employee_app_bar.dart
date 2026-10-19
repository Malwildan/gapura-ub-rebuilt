import 'package:flutter/material.dart';
import '../../common/colors.dart';

class EmployeeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EmployeeAppBar({
    super.key,
    required this.title,
    this.bottom,
    this.actions,
  });
  final Widget title;
  final PreferredSizeWidget? bottom;
  final List<Widget>? actions;
  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: navigationSelected,
      ),
    ),
    child: AppBar(
      title: title,
      bottom: bottom,
      actions: actions,
      backgroundColor: navigationBackground,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
