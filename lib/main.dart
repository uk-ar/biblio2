import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Stream userStream;
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
  void initState() {
    // TODO: implement initState
    super.initState();
    userStream = _handleSignIn().asStream();
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

  Widget _handleScreen() {
    //https://flutterdoc.com/mobileauthenticating-users-with-firebase-and-flutter-240c5557ac7f
    return new StreamBuilder<FirebaseUser>(
        stream: userStream,
        builder: (BuildContext context, user) {
          if (user.hasData) {
            return StreamBuilder<QuerySnapshot>(
              stream: Firestore.instance
                  .collection('posts')
                  .where("author",
                      isEqualTo: Firestore.instance
                          .collection("users")
                          .document(user.data.uid))
                  .snapshots(),
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
      children: snapshot.map((data) => _buildListItem(context, data)).toList(),
    );
  }

  Widget _buildListItem(BuildContext context, DocumentSnapshot data) {
    final record = Record.fromSnapshot(data);
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
