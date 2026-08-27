import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grocery POS',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TestFirestorePage(),
    );
  }
}

class TestFirestorePage extends StatefulWidget {
  const TestFirestorePage({Key? key}) : super(key: key);

  @override
  State<TestFirestorePage> createState() => _TestFirestorePageState();
}

class _TestFirestorePageState extends State<TestFirestorePage> {
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _testFirestore();
  }

  Future<void> _testFirestore() async {
    try {
      // Write a test document
      await FirebaseFirestore.instance.collection('test').doc('hello').set({
        'message': 'Flutter ↔ Firestore connected!',
        'timestamp': DateTime.now(),
      });

      // Read it back
      final doc = await FirebaseFirestore.instance
          .collection('test')
          .doc('hello')
          .get();

      setState(() {
        _status = 'Success!\nData: ${doc.data()}';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Test')),
      body: Center(
        child: Text(_status, textAlign: TextAlign.center),
      ),
    );
  }
}