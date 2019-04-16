import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<FirebaseUser> _handleSignIn() async {
    //https://android.jlelse.eu/authenticate-with-firebase-anonymously-android-34fdf3c7336b
    var user = await _auth.currentUser();
    if (user == null) {
      user = await _auth.signInAnonymously();
      await Firestore.instance.collection("users").document(user.uid).setData({
        "isAnonymous": user.isAnonymous,
      });
    }
    print("signed in " + user.uid);
    return user;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baby isbns',
      //home: new LoginSignUpPage(auth: new Auth()),
      home: _handleScreen(),
    );
  }

  Widget SplashScreen() {
    return new Scaffold(
      body: new Center(
        child: new Image.asset('assets/flutter-icon.png'),
      ),
    );
  }

  Future<Iterable<Map<dynamic, dynamic>>> fetchPost(
      Iterable<Record> records) async {
    print(records);
    final isbns = records.map((record) => record.isbn).join(",");
    print('https://api.openbd.jp/v1/get?isbn=$isbns');
    final response = await http.get('https://api.openbd.jp/v1/get?isbn=$isbns');
    //TODO:handle no result
    if (response.statusCode == 200) {
      // If server returns an OK response, parse the JSON
      var books = json.decode(response.body);
      print(books.map((book) => Book.fromJson(book)));
      books.map((book) => Book.fromJson(book));
    } else {
      // If that response was not OK, throw an error.
      throw Exception('Failed to load post');
    }
  }

  Stream<List<Record>> _handleBookList(user) {
    print("handlebooklist");
    var recordsStream = Firestore.instance
        .collection('posts')
        .where("author",
            isEqualTo:
                Firestore.instance.collection("users").document(user.data.uid))
        .snapshots()
        .map((data) => data.documents) //records
        .map((snapshot) => snapshot.map((data) => Record.fromSnapshot(data)))
        .asyncExpand((records) => fetchPost(records).asStream())
        .listen((data) => print(data));
    //.map((data) =>
    //    data.documents.map((snapshot) => Record.fromSnapshot(snapshot)));
    //.map((records)=>fetchPost(records));
    /*await for (var records in recordsStream) {
      //sum += recor;
      var books;
      books = await fetchPost(records);
      yield books;
    }*/
  }

  Stream<QuerySnapshot> _handleSnapshot(user) {
    _handleBookList(user);
    return Firestore.instance
        .collection('posts')
        .where("author",
            isEqualTo:
                Firestore.instance.collection("users").document(user.data.uid))
        .snapshots(); //.data.documents
  }

  Widget _handleScreen() {
    //https://flutterdoc.com/mobileauthenticating-users-with-firebase-and-flutter-240c5557ac7f
    return new FutureBuilder<FirebaseUser>(
        future: _handleSignIn(),
        builder: (BuildContext context, user) {
          if (user.hasData) {
            return StreamBuilder<QuerySnapshot>(
              stream: _handleSnapshot(user),
              //stream: Firestore.instance.collection(name).snapshots(),
              builder: (BuildContext context,
                  AsyncSnapshot<QuerySnapshot> snapshot) {
                return new MyHomePage(firestore: snapshot);
                //return new ListView(children: createChildren(snapshot));
              },
            );
            //return new MyHomePage(firestore: firestore);
          }
          return SplashScreen();
          //LinearProgressIndicator
          //return new LoginScreen();
        });
  }
}

class MyHomePage extends StatelessWidget {
  MyHomePage({
    Key key,
    this.firestore,
  }) : super(key: key);
  final AsyncSnapshot firestore;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Baby isbn isbn')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    // TODO: get actual snapshot from Cloud Firestore
    if (firestore.hasData) {
      return _buildList(context, firestore.data.documents);
    }
    return _buildList(context, []);
  }

  Widget _buildList(BuildContext context, List<DocumentSnapshot> snapshot) {
    return ListView(
      padding: const EdgeInsets.only(top: 20.0),
      children: snapshot
          .map((data) => Record.fromSnapshot(data))
          .map((record) => _buildListItem(context, record))
          .toList(),
    );
  }

  Widget _buildListItem(BuildContext context, Record record) {
    //final record = Record.fromSnapshot(data);
    //fetchPost();
    return Padding(
        key: ValueKey(record.isbn),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(5.0),
          ),
          child: ListTile(
              title: Text(record.isbn),
              //trailing: Text(record.votes.toString()),
              onTap: () =>
                  Firestore.instance.runTransaction((transaction) async {
                    final freshSnapshot =
                        await transaction.get(record.reference);
                    final fresh = Record.fromSnapshot(freshSnapshot);

                    //await transaction
                    //    .update(record.reference, {'votes': fresh.votes + 1});
                  })),
        ));
  }
}

class Book {
  final String title;

  Book({this.title});

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      title: json["onix"]["DescriptiveDetail"]["TitleDetail"]["TitleElement"]
          ["TitleText"]["content"],
      //author: json["onix"]["DescriptiveDetail"]["Contributor"].map()
      //books.map((book) => Book.fromJson(book));
    );
  }
  @override
  String toString() => "Book<$title:>";
}

class Record {
  final String isbn;
  final DocumentReference reference;

  Record.fromMap(Map<String, dynamic> map, {this.reference})
      : assert(map['isbn'] != null),
        isbn = map['isbn'];

  Record.fromSnapshot(DocumentSnapshot snapshot)
      : this.fromMap(snapshot.data, reference: snapshot.reference);

  @override
  String toString() => "Record<$isbn:>";
}
