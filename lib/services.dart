import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  late final changes = _auth.authStateChanges();
  User? get current => _auth.currentUser;
  Future<void> register(
    String email,
    String password,
    String first,
    String last,
    BoardService board,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await board.saveProfile(credential.user!.uid, first, last);
  }

  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> logout() => _auth.signOut();
}

class Post {
  final String id, uid, name, text;
  final bool edited;
  Post.from(QueryDocumentSnapshot<Map<String, dynamic>> doc)
    : id = doc.id,
      uid = doc['authorUid'],
      name = doc['authorName'],
      text = doc['text'],
      edited = doc.data()['editedAt'] != null;
}

class BoardService {
  final db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get posts =>
      db.collection('messages');
  Stream<String?> profile(String uid) => db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((d) => d.data()?['firstName'] as String?);
  Future<void> saveProfile(String uid, String first, String last) async {
    final ref = db.collection('users').doc(uid);
    await db.runTransaction((t) async {
      if (!(await t.get(ref)).exists) {
        t.set(ref, {
          'uid': uid,
          'firstName': first,
          'lastName': last,
          'role': 'student',
          'registrationDateTime': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Stream<List<Post>> watch() => posts
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(Post.from).toList());
  String newId() => posts.doc().id;
  Future<void> create(String id, String uid, String name, String text) async {
    final ref = posts.doc(id);
    await db.runTransaction((t) async {
      if (!(await t.get(ref)).exists) {
        t.set(ref, {
          'authorUid': uid,
          'authorName': name,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
          'editedAt': null,
          'schemaVersion': 2,
        });
      }
    });
  }

  Future<void> edit(String id, String text) => posts.doc(id).update({
    'text': text,
    'editedAt': FieldValue.serverTimestamp(),
  });
  Future<void> remove(String id) => posts.doc(id).delete();
}
