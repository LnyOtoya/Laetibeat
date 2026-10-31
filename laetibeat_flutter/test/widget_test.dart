import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laetibeat/app/app_form_factor.dart';
import 'package:laetibeat/app/app_size.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('android/iOS map to mobile form factor', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(detectAppFormFactor(), AppFormFactor.mobile);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(detectAppFormFactor(), AppFormFactor.mobile);
  });

  test('desktop platforms map to desktop form factor', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(detectAppFormFactor(), AppFormFactor.desktop);

    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(detectAppFormFactor(), AppFormFactor.desktop);

    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(detectAppFormFactor(), AppFormFactor.desktop);
  });

  test('single pane policy depends only on width', () {
    expect(isSinglePaneWidth(400), isTrue);
    expect(isSinglePaneWidth(kSinglePaneBreakpoint), isFalse);
    expect(isSinglePaneWidth(1200), isFalse);
  });
}
