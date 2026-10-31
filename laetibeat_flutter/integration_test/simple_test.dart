import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:laetibeat/app/app_form_factor.dart';
import 'package:laetibeat/src/rust/frb_generated.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  testWidgets('app form factor is resolved on device', (tester) async {
    expect(AppFormFactor.values, contains(detectAppFormFactor()));
  });
}
