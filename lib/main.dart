import 'dart:async';

import 'package:cbl/cbl.dart';
import 'package:flutter/material.dart';
import 'package:cbl_flutter/cbl_flutter.dart';
// import 'db_verify.dart';

late final AsyncDatabase database;

Future<void> main() async {
  await CouchbaseLiteFlutter.init();
  // await verify();
  await openDatabase();
  await createNoteFtsIndex();
  await createNote(
      title: 'First Note for init',
      body: 'Dude this is the first note that I am writing for the note.');
  runApp(const MyApp());
}

Future<void> openDatabase() async {
  database = await Database.openAsync('notes-app');
} // Create a database or open an existing one

Future<MutableDocument> createNote({
  required String title,
  required String body,
}) async {
  final doc = MutableDocument({
    'type': 'note',
    'title': title,
    'body': body,
  });

  await database.saveDocument(doc);

  return doc;
} // Creates a note in the opened db

Future<void> createNoteFtsIndex() async {
  await database.createIndex(
    'note-fts',
    FullTextIndexConfiguration(['title', 'body'],
        language: FullTextLanguage.english),
  );
}

class NoteSearchResult {
  NoteSearchResult({required this.id, required this.title});

  static NoteSearchResult fromResult(Result result) => NoteSearchResult(
        id: result.string('id')!,
        title: result.string('title')!,
      );
  final String id;
  final String title;
}

Future<List<NoteSearchResult>> searchNotes(Query queryString) async {
  final query = await Query.fromN1ql(
    database,
    r'''SELECT META().id AS id, title
  FROM _
  WHERE type = 'note' AND match(note-fts, $query)
  ORDER BY rank(note-fts)
  LIMIT 10
  ''',
  );

  await query.setParameters(Parameters({'query': '$queryString'}));
  final resultSet = await query.execute();

  return resultSet.asStream().map(NoteSearchResult.fromResult).toList();
}

class Note {
  final String id;
  final String title;
  final String body;

  Note({
    required this.id,
    required this.title,
    required this.body,
  });
}

Future<List<Note>> fetchNotes() async {
  final query = await Query.fromN1ql(database, '''
    SELECT META().id AS id, title, body
    FROM _
    WHERE type = 'note'
    ORDER BY title
  ''');

  final resultSet = await query.execute();

  return resultSet
      .asStream()
      .map((result) => Note(
            id: result.string('id')!,
            title: result.string('title')!,
            body: result.string('body')!,
          ))
      .toList();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Note>> notesFuture;

  @override
  void initState() {
    super.initState();
    notesFuture = fetchNotes(); // Initialize the future in initState
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
      ),
      body: FutureBuilder<List<Note>>(
        future: notesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final notes = snapshot.data!;
            return ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return ListTile(
                  title: Text(note.title),
                  subtitle: Text(note.body),
                );
              },
            );
          } else {
            return const Center(child: Text('No notes found'));
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context)
              .push(
            MaterialPageRoute(builder: (context) => const CreateNoteScreen()),
          )
              .then((_) {
            setState(() {
              notesFuture = fetchNotes();
            });
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CreateNoteScreen extends StatefulWidget {
  const CreateNoteScreen({Key? key}) : super(key: key);

  @override
  _CreateNoteScreenState createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  Future<void> _saveNote() async {
    if (_formKey.currentState!.validate()) {
      await createNote(
        title: _titleController.text,
        body: _bodyController.text,
      );

      Navigator.of(context).pop(); // Go back to the previous screen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Note'),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(labelText: 'Body'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
              ElevatedButton(
                onPressed: _saveNote,
                child: const Text('Save Note'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
}
