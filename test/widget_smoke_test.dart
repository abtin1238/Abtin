import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:abtin_navigator/core/theme/app_theme.dart';
import 'package:abtin_navigator/core/constants/app_strings.dart';

/// تست سبک UI بدون geolocator / bootstrap / SQLCipher.
void main() {
  testWidgets('MaterialApp + theme builds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(child: Text(AppStrings.appName)),
          ),
        ),
      ),
    );
    expect(find.text(AppStrings.appName), findsOneWidget);
  });
}
