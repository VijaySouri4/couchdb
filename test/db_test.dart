import 'dart:io';

import 'package:cbl/cbl.dart';
import 'package:cbl_dart/cbl_dart.dart';
import 'package:flutter_test/flutter_test.dart';

void setupCouchbaseLiteForUnitTests() {
  setUpAll(() async {
    // If no `filesDir` is specified when initializing CouchbaseLiteDart, the
    // working directory is used as the default database directory.
    // By specifying a `filesDir` here, we can ensure that the tests don't
    // create databases in the project directory.
    final tempFilesDir = await Directory.systemTemp.createTemp();
    await CouchbaseLiteDart.init(
      edition: Edition.enterprise,
      filesDir: tempFilesDir.path,
    );
  });
}

void main() {
  setupCouchbaseLiteForUnitTests();

  test('use a database', () async {
    final db = await Database.openAsync('test');
    // ...
  });
}
