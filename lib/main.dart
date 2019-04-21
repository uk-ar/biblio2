import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:bloc_provider/bloc_provider.dart';
import 'package:rxdart/rxdart.dart';

void main() => runApp(MyApp());

class BooksBloc implements Bloc {
  //final _countController = BehaviorSubject<int>(seedValue: 0);
  final _recordRequestController = PublishSubject<String>(); //Sink
  final _recordController = BehaviorSubject<List<Record>>.seeded([]); //Stream
  final _detailRequestController = PublishSubject<List<String>>(); //Sink
  final _detailController = BehaviorSubject<List<Book>>.seeded([]); //Stream
  final _statusRequestController = PublishSubject<String>(); //Sink
  final _statusController = BehaviorSubject<Map>.seeded({}); //Stream
  final _booksController = BehaviorSubject<List<Book>>.seeded([]); //Stream

  //Sink<void> get booksRequest => _detailRequestController.sink;
  //ValueObservable<List<Book>> get books => _detailController;
  //Sink<void> get statusRequest => _statusRequestController.sink;
  //ValueObservable<Map> get status => _statusController;
  Sink<void> get recordRequest => _recordRequestController.sink;
  ValueObservable<List<Book>> get books => _booksController;

  Future<List<Book>> fetchBooks(List<String> isbns) async {
    if (isbns.isEmpty) {
      return [];
    }
    final response =
        await http.get('https://api.openbd.jp/v1/get?isbn=${isbns.join(",")}');
    //TODO:handle no result
    if (response.statusCode == 200) {
      // If server returns an OK response, parse the JSON
      //https://medium.com/flutter-community/parsing-complex-json-in-flutter-747c46655f51
      var books = json.decode(response.body) as List;
      return books.map((book) => Book.fromJson(book, status: "a")).toList();
    } else {
      // If that response was not OK, throw an error.
      throw Exception('Failed to load post');
    }
  }

  Future<Map> fetchLibraryStatus(String url) async {
    if (url.isEmpty) {
      return {};
    }
    const LIBRARY_ID = 'Tokyo_Fuchu';
    //var url =
    //    'http://api.calil.jp/check?callback=no&appkey=bc3d19b6abbd0af9a59d97fe8b22660f&systemid=${LIBRARY_ID}&format=json&isbn=${isbns}';
    final response = await http.get(url);
    //TODO:handle no result
    if (response.statusCode == 200) {
      // If server returns an OK response, parse the JSON
      //https://medium.com/flutter-community/parsing-complex-json-in-flutter-747c46655f51
      var body = json.decode(response.body);
      print(body);
      if (body["continue"] == 1) {
        print("retry:" + body);
        _statusRequestController.add(
            "http://api.calil.jp/check?session=${body["session"]}&format=json");
      }
      Map bookStatus;
      body["books"].forEach((isbn, value) {
        print(isbn);
        print(value[LIBRARY_ID]);
        //var {status,reserveurl,libkey}=value[LIBRARY_ID];
        if (value[LIBRARY_ID]["status"] == "running") {
          bookStatus[isbn] = "Running";
        } else if (value[LIBRARY_ID]["libkey"].isEmpty()) {
          bookStatus[isbn] = "No Collection";
        } else if (value[LIBRARY_ID]["libkey"].containsValue("貸出可")) {
          bookStatus[isbn] = "Rentable";
        } else {
          bookStatus[isbn] = "On Loan";
        }
        return bookStatus;
      });
    } else {
      // If that response was not OK, throw an error.
      throw Exception('Failed to load post');
    }
  }

  BooksBloc() {
    const LIBRARY_ID = 'Tokyo_Fuchu';
    _recordRequestController
        .asyncExpand((uid) {
          return Firestore.instance
              .collection('posts')
              .where("author",
                  isEqualTo:
                      Firestore.instance.collection("users").document(uid))
              .snapshots();
        })
        .map((data) => data.documents) //books
        .map((snapshot) => snapshot.map((data) => Record.fromSnapshot(data)))
        .distinct()
        .pipe(_recordController);
    _recordController
        .map((records) => records.map((record) => record.isbn))
        .pipe(_detailRequestController);
    _recordController
        .map((records) => records.map((record) => record.isbn))
        .map((isbns) =>
            'http://api.calil.jp/check?callback=no&appkey=bc3d19b6abbd0af9a59d97fe8b22660f&systemid=${LIBRARY_ID}&isbn=${isbns}')
        .pipe(_statusRequestController);
    _detailRequestController
        .asyncExpand((isbns) => fetchBooks(isbns).asStream())
        .pipe(_detailController);
    _statusRequestController
        //.interval(new Duration(seconds: 2))
        .delay(new Duration(seconds: 2))
        .asyncExpand((url) => fetchLibraryStatus(url).asStream())
        //.marge()//initial request & switchmap
        .pipe(_statusController);
    CombineLatestStream.combine2(
            _detailController,
            _statusController,
            (books, status) =>
                books.forEach((book) => book.status = status[book.isbn]))
        .pipe(_booksController);
    //bloc.booksRequest.add(["4834000826","4772100318","9784834005158"])
  }

  @override
  void dispose() async {
    await _booksController.close();
    await _detailRequestController.close();
    await _detailController.close();
    await _statusRequestController.close();
    await _statusController.close();
    await _recordRequestController.close();
    await _recordController.close();
  }
}

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
      title: 'Baby titles',
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

  Future<List<Book>> fetchPost(Iterable<Record> records) async {
    print("fetchPost");
    //print(records);
    final isbns = records.map((record) => record.isbn).join(",");
    print('https://api.openbd.jp/v1/get?title=$isbns');
    final response = await http.get('https://api.openbd.jp/v1/get?isbn=$isbns');
    //TODO:handle no result
    if (response.statusCode == 200) {
      // If server returns an OK response, parse the JSON
      //https://medium.com/flutter-community/parsing-complex-json-in-flutter-747c46655f51
      var books = json.decode(response.body) as List;
      //print("fetched");
      //print(books);
      return books.map((book) => Book.fromJson(book, status: "a")).toList();
    } else {
      // If that response was not OK, throw an error.
      throw Exception('Failed to load post');
    }
  }

  Future<List<Book>> fetchLibraryStatus(Iterable<Record> records) async {
    print("fetchPost");
    //print(records);
    final isbns = records.map((record) => record.isbn).join(",");
    const LIBRARY_ID = 'Tokyo_Fuchu';
    var url =
        'http://api.calil.jp/check?callback=no&appkey=bc3d19b6abbd0af9a59d97fe8b22660f&systemid=${LIBRARY_ID}&format=json&isbn=${isbns}';
    print(url);
    final response = await http.get(url);
    //TODO:handle no result
    if (response.statusCode == 200) {
      // If server returns an OK response, parse the JSON
      //https://medium.com/flutter-community/parsing-complex-json-in-flutter-747c46655f51
      var body = json.decode(response.body);
      print(body);
      //TODO:retry
      Map bookStatuses;
      body["books"].forEach((isbn, value) {
        print(isbn);
        print(value[LIBRARY_ID]);

        //var libkey = value[LIBRARY_ID]["libkey"];
        //if (libkey.containsValue("貸出可")) {}
        //bookStatuses[isbn] = {};
      });
      print("fetched");
    } else {
      // If that response was not OK, throw an error.
      throw Exception('Failed to load post');
    }
  }

  Stream<List<Book>> _handleBookList(String uid) {
    print("handlebooklist");
    var recordStream = Firestore.instance
        .collection('posts')
        .where("author",
            isEqualTo: Firestore.instance.collection("users").document(uid))
        .snapshots()
        .map((data) => data.documents) //books
        .map((snapshot) {
          print("foo");
          //print(snapshot);
          return snapshot;
        })
        .map((snapshot) => snapshot.map((data) => Record.fromSnapshot(data)))
        .map((snapshot) {
          //print(snapshot);
          return snapshot;
        })
        .distinct();
    var libStatusStream = recordStream
        .asyncExpand((records) => fetchLibraryStatus(records).asStream());
    //.listen((data) => print(data));
    var bookStream =
        recordStream.asyncExpand((records) => fetchPost(records).asStream());
    var bothStreams =
        StreamZip([bookStream, libStatusStream]).listen((streams) {
      print("zip");
      print(streams[0]);
      print(streams[1]);
    });
    //.listen((data) => print(data));
    return bookStream;
  }

  Widget _handleScreen() {
    //https://flutterdoc.com/mobileauthenticating-users-with-firebase-and-flutter-240c5557ac7f
    return new FutureBuilder<FirebaseUser>(
        future: _handleSignIn(),
        builder: (BuildContext context, user) {
          if (user.hasData) {
            return StreamBuilder<List<Book>>(
              stream: _handleBookList(user.data.uid),
              //stream: Firestore.instance.collection(name).snapshots(),
              builder: (BuildContext context, AsyncSnapshot<List<Book>> books) {
                print(books);
                print(books.data);
                if (books.hasData) {
                  return new MyHomePage(firestore: books.data);
                } else {
                  return new MyHomePage(firestore: []);
                }
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
  final List<Book> firestore;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Baby title title')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    // TODO: get actual snapshot from Cloud Firestore
    return _buildList(context, firestore);
  }

  Widget _buildList(BuildContext context, List<Book> snapshot) {
    print(snapshot);
    return ListView(
      padding: const EdgeInsets.only(top: 20.0),
      children: snapshot
          //.map((data) => book.fromSnapshot(data))
          .map((book) => _buildListItem(context, book))
          .toList(),
    );
  }

  Widget _buildListItem(BuildContext context, Book book) {
    return Padding(
        key: ValueKey(book.title),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(5.0),
          ),
          child: ListTile(
              title: Text(book.title),
              trailing: Text(book.status),
              onTap: () =>
                  Firestore.instance.runTransaction((transaction) async {
                    //final freshSnapshot =
                    //    await transaction.get(book.reference);
                    //final fresh = book.fromSnapshot(freshSnapshot);

                    //await transaction
                    //    .update(book.reference, {'votes': fresh.votes + 1});
                  })),
        ));
  }
}

class Book {
  final String title;
  final String status;

  //Book(this.status, {this.title});

  Book.fromJson(Map<String, dynamic> json, {this.status})
      : title = json["onix"]["DescriptiveDetail"]["TitleDetail"]["TitleElement"]
            ["TitleText"]["content"];
  //https://api.openbd.jp/v1/get?isbn=4772100318&pretty
  //author: json["onix"]["DescriptiveDetail"]["Contributor"].map()
  //books.map((book) => Book.fromJson(book))
  // factory Book.fromJson(Map<String, dynamic> json) {
  //   return Book(
  //       title: json["onix"]["DescriptiveDetail"]["TitleDetail"]["TitleElement"]
  //           ["TitleText"]["content"]);
  // }
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
  String toString() => "book<$isbn:>";
}
