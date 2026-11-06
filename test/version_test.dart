import 'dart:io';

import 'package:bopmigo/src/client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports the version in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)!.group(1);
    expect(Client.version, version);
  });
}
