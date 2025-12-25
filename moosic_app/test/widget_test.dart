import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:moosic_app/main.dart';
import 'package:moosic_app/services/api_service.dart';

// Mock ApiService to avoid network calls during tests
class MockApiService extends ApiService {
  @override
  Future<List<dynamic>> search(String query) async {
    return []; // Return empty list
  }

  @override
  Future<List<dynamic>> getRecommendations() async {
    return [];
  }
}

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>(create: (_) => MockApiService()),
          ChangeNotifierProvider(create: (_) => AudioProvider()),
        ],
        child: const MoosicApp(),
      ),
    );

    // Verify that Discover screen shows up
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
  });
}
