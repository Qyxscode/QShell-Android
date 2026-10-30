import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qshell/widgets/sparkline.dart';

void main() {
  testWidgets('sparkline 渲染检查', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFF2F2F7),
          body: Center(
            child: SizedBox(
              width: 300,
              child: Container(
                color: const Color(0xFFFFFFFF),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: SizedBox(
                    height: 80,
                    child: Sparkline(
                      values: [10, 12, 11, 20, 30, 28, 40, 45],
                      color: Color(0xFF3B5BDB),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(Sparkline),
      matchesGoldenFile('sparkline_golden.png'),
    );
  });
}
