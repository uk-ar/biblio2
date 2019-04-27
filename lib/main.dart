import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:bloc_provider/bloc_provider.dart';
import 'package:rxdart/rxdart.dart';

class BooksBloc implements Bloc {
  //final _countController = BehaviorSubject<int>(seedValue: 0);
  final _recordRequestController = PublishSubject<String>(); //Sink
  final _recordController = BehaviorSubject<List<String>>(); //Stream
  final _detailRequestController = PublishSubject<List<String>>(); //Sink
  final _detailController = BehaviorSubject<List<Book>>(); //Stream
  final _statusRequestController = ReplaySubject<List<String>>(); //Sink
  final _statusController = BehaviorSubject<Map>(); //Stream
  final _booksController = BehaviorSubject<List<Book>>(); //Stream

  Sink<void> get recordRequest => _recordRequestController.sink;
  Observable<List<Book>> get books => _booksController.startWith([]);

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
      List<Book> ret = [];
      for (var i = 0; i < isbns.length; i++) {
        ret.add(Book.fromJson(books[i], isbn: isbns[i]));
      }
      return ret;
    } else {
      // If that response was not OK, throw an error.
      throw Exception('Failed to load post');
    }
  }

  Future<Map> fetchLibraryStatus(String url) async {
    if (url.isEmpty) {
      return {};
    }
    // https://calil.jp/doc/api_ref.html
    final response = await http.get(url);
    //TODO:handle no result
    if (response.statusCode == 200) {
      // If server returns an OK response, parse the JSON
      //https://medium.com/flutter-community/parsing-complex-json-in-flutter-747c46655f51
      var body = json.decode(response.body);
      return body;
    } else {
      // If that response was not OK, throw an error.
      throw Exception('Failed to load post');
    }
  }

  Map bodyToStatus(Map body) {
    const LIBRARY_ID = 'Tokyo_Fuchu';
    Map bookStatus = {};
    if (body == null || body.isEmpty) {
      return {};
    }
    body["books"].forEach((isbn, book) {
      if (book[LIBRARY_ID]["status"] == "Running") {
        bookStatus[isbn] = {"status": "Running"};
      } else if (book[LIBRARY_ID]["libkey"] == null) {
        bookStatus[isbn] = {"status": "No Collection"};
      } else if (book[LIBRARY_ID]["libkey"].containsValue("貸出可")) {
        bookStatus[isbn] = {
          "status": "Rentable",
          "reserveurl": book[LIBRARY_ID]["reserveurl"]
        };
      } else {
        bookStatus[isbn] = {
          "status": "On Loan",
          "reserveurl": book[LIBRARY_ID]["reserveurl"]
        };
      }
    });
    return bookStatus;
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
        .map((snapshot) =>
            snapshot.map((data) => Record.fromSnapshot(data)).toList())
        .distinct()
        //.doOnData((data) => print("record request:$data"))
        .map((records) =>
            records.map((record) => record.isbn).toList()..add("4569787789"))
        .pipe(_recordController);
    _recordController
        //.doOnData((data) => print("record cont:$data"))
        .pipe(_detailRequestController);
    _detailRequestController
        .asyncExpand((isbns) => fetchBooks(isbns).asStream())
        //.doOnData((data) => print("detail:$data"))
        .pipe(_detailController);
    var session = "";
    _recordController
        .doOnData((_) => session = "")
        .pipe(_statusRequestController);
    new RetryWhenStream<Map>(
      () => _statusRequestController
          .map((isbns) {
            if (isbns.isEmpty) {
              return "";
            } else if (session.isEmpty) {
              return 'http://api.calil.jp/check?callback=no&appkey=bc3d19b6abbd0af9a59d97fe8b22660f&format=json&systemid=${LIBRARY_ID}&isbn=${isbns.join(",")}';
            } else {
              return "http://api.calil.jp/check?callback=no&session=${session}&format=json";
            }
          })
          //.doOnData((data) => print("status req:$data"))
          .asyncExpand((url) => fetchLibraryStatus(url).asStream())
          .doOnData((data) => print("status req2:$data"))
          .expand((Map body) => body["continue"] == 1
              ? [
                  Map.from(body)..addAll(<String, dynamic>{"continue": 0}),
                  body
                ]
              : [body])
          //.doOnData((data) => print("status response:$data"))
          .map((body) => body["continue"] == 1 ? throw body["session"] : body)
          //.doOnData((data) => print("status response2:$data"))
          .map(bodyToStatus),
      (e, s) {
        //errorHappened = true;
        print("error:$e");
        session = e;
        return new Observable<String>.timer(
                "random", const Duration(seconds: 2))
            .doOnData((data) => print("duration:$data"));
      },
    )
        // .listen((data) => print("Retry:$data"),
        //     onError: (data) => print("Error:$data"));
        .pipe(_statusController);
    CombineLatestStream.combine2<List<Book>, Map, List<Book>>(
        _detailController, _statusController, (List<Book> books, Map status) {
      print("status controller,$books,$status");
      if (status == null || status.isEmpty) {
        return books;
      }
      return books
        ..forEach((book) {
          print("b:$book,${status[book.isbn]}");
          book.status = status[book.isbn];
        });
    }).pipe(_booksController); //.listen((data) => print("combine:$data")); //
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

void main() => runApp(
      BlocProvider<BooksBloc>(
        creator: (_context, _bag) => BooksBloc(),
        child: MyApp(),
      ),
    );

class MyApp extends StatelessWidget {
  Future<FirebaseUser> _handleSignIn() async {
    final FirebaseAuth _auth = FirebaseAuth.instance;
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
      home: _handleScreen(context),
    );
  }

  Widget SplashScreen() {
    return new Scaffold(
      body: new Center(
        child: new Image.asset('assets/flutter-icon.png'),
      ),
    );
  }

  Widget _handleScreen(BuildContext context) {
    final bloc = BlocProvider.of<BooksBloc>(context);
    //https://flutterdoc.com/mobileauthenticating-users-with-firebase-and-flutter-240c5557ac7f
    return new FutureBuilder<FirebaseUser>(
        future: _handleSignIn(),
        builder: (BuildContext context, user) {
          if (user.hasData) {
            bloc.recordRequest.add(user.data.uid);
            return StreamBuilder<List<Book>>(
              stream: bloc.books,
              //initialData: bloc.books.value,
              builder: (BuildContext context, AsyncSnapshot<List<Book>> books) {
                print(books);
                print("futurebuilder:$books.data");
                if (books.hasData) {
                  return new MyHomePage(books: books.data);
                } else {
                  return new MyHomePage(books: []);
                }
              },
            );
          }
          return SplashScreen();
        });
  }
}

class MyHomePage extends StatelessWidget {
  MyHomePage({
    Key key,
    this.books,
  }) : super(key: key);
  final List<Book> books;
  @override
  Widget build(BuildContext context) {
    print("build:$books");
    return Scaffold(
      appBar: AppBar(title: Text('Baby title title')),
      body: _buildList(context, books),
    );
  }

  Widget _buildList(BuildContext context, List<Book> snapshot) {
    print("buildList:$snapshot");
    return ListView(
      padding: const EdgeInsets.only(top: 20.0),
      children: snapshot.map((book) => _buildListItem(context, book)).toList(),
    );
  }

  Widget _buildListItem(BuildContext context, Book book) {
    print("book:$book,${book.status}");
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
              trailing: Text(book.status == null ? "" : book.status["status"]),
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
  final String isbn;
  final String cover;
  Map status = {};

  Book.fromJson(Map<String, dynamic> json, {this.status, this.isbn})
      : title = json["onix"]["DescriptiveDetail"]["TitleDetail"]["TitleElement"]
            ["TitleText"]["content"],
        cover = json["summary"]["cover"];
  //isbn = json["summary"]["isbn"];

  //https://api.openbd.jp/v1/get?isbn=4772100318&pretty

  @override
  String toString() => "Book<$title:$isbn:$status>";
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
