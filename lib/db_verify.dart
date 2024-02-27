import 'package:cbl/cbl.dart';

Future<void> verify() async {
  // Open the database (creating it if it doesn’t exist).
  final database = await Database.openAsync('my-database');

  // Create a new document.
  final mutableDocument = MutableDocument({'type': 'SDK', 'majorVersion': 2});
  await database.saveDocument(mutableDocument);

  print(
    'Created document with id ${mutableDocument.id} and '
    'type ${mutableDocument.string('type')}.',
  );

  // Update the document.
  mutableDocument.setString('Dart', key: 'language');
  await database.saveDocument(mutableDocument);

  print(
    'Updated document with id ${mutableDocument.id}, '
    'adding language ${mutableDocument.string("language")!}.',
  );

  // Read the document.
  final document = (await database.document(mutableDocument.id))!;

  print(
    'Read document with id ${document.id}, '
    'type ${document.string('type')} and '
    'language ${document.string('language')}.',
  );

  // Create a query to fetch documents of type SDK.
  print('Querying Documents of type=SDK.');
  final query = await Query.fromN1ql(database, '''
    SELECT * FROM _
    WHERE type = 'SDK'
  ''');

  // Run the query.
  final result = await query.execute();
  final results = await result.allResults();
  print('Number of results: ${results.length}');

  // Close the database.
  await database.close();
}
