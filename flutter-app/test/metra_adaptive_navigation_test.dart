import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/widgets/metra_adaptive_navigation.dart';

void main() {
  testWidgets('shared navigation switches between rail and bar at breakpoint',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    const destinations = <NavigationDestination>[
      NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
      NavigationDestination(icon: Icon(Icons.map_outlined), label: 'المحطات'),
    ];

    tester.view.physicalSize = const Size(1000, 800);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MetraAdaptiveNavigation(
          selectedIndex: 0,
          destinations: destinations,
          onDestinationSelected: (_) {},
          child: const Center(child: Text('محتوى الصفحة')),
        ),
      ),
    ));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('محتوى الصفحة'), findsOneWidget);

    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });
}
