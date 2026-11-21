# Common Room
A Flutter message board for CSC 4360 Homework -02, undergraduate track. Any signed-in student can read the board. Owners can edit and delete individual messages.

## Android setup
Install Flutter, the Android SDK, the Firebase CLI and FlutterFire CLI. Run `flutter doctor` and connect a device. This project includes the generated Android client configuration for the dedicated homework project `hw02-vault-bc-261120`. Its default Cloud Firestore database is in us-east1. Email/Password sign-in is enabled. To use your own project, enable those products, then run the following from the repository root.

```sh
flutter pub get
flutterfire configure --platforms=android --project YOUR_PROJECT_ID
firebase deploy --only firestore:rules --project YOUR_PROJECT_ID
flutter run
```

## Identity and data
Initialization starts before the first Flutter frame. The splash stays on screen until initialization finishes. AuthService wraps registration, sign-in, sign-out and the auth-state stream. Authenticated students reach the board after their private profile exists. An interrupted registration offers profile completion on the next sign-in. The service uses a create-if-absent transaction so concurrent recovery preserves the original record.

| Path | Fields and writers | Access |
|---|---|---|
| users/{uid} | Auth supplies uid. The registrant supplies firstName and lastName. The app sets role to student. Firestore resolves registrationDateTime on commit. | Only the owner can create or fetch the document. Profiles cannot be listed or changed through the app. |
| messages/{id} | The author supplies text. BoardService supplies authorUid from the session, authorName from the profile and schemaVersion 2. Firestore resolves createdAt. editedAt starts null and receives server time on each edit. | Signed-in users read the collection. The owner creates, edits text, or deletes one document. Rules protect metadata and check the public name against the private profile. |
| Device | The composer holds a draft and its submission ID in memory. Firebase Auth manages native session persistence. | Sign-out closes board access. Clearing app data removes local session state. Published messages persist in Firestore. |

BoardService owns all database operations. One ordered snapshots listener drives loading, empty, populated and error states. StreamBuilder releases its listener when the board leaves the widget tree. The app checks ownership before showing actions, and the database independently enforces it. First names are shared on messages. Last names and registration details stay in the private profile.

## Build and verify
```sh
flutter analyze
flutter test
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

The coursework APK uses the Flutter template's local debug signing key in release mode. Do not commit signing material. Test two fictional accounts. Register, verify the five profile fields, sign out and sign back in. Double-tap Post, check the collection count, then post from a second client and watch the first board. Edit and delete one owned message while a neighbor remains. Force-stop, reboot and clear only the test app's data to compare session and cloud lifetimes.

## Undergraduate choice features
1. **Rules Unit Tester (#2).** With Node 22+, Java 21+ and the Firebase CLI installed, run the following. The demo project ID and loopback connection keep the suite isolated.
2. **Idempotent Alchemist (#4).** Each draft retains its document ID on failure. A transaction reads the document before creating it. A repeated call for that ID leaves both the document and original server timestamp intact. The app disables the send button while busy. Transactions require connectivity. A fresh draft after process death is a new intent.
3. **Schema Shape-shifter (#5).** The suite seeds two legacy documents with body, uid and sentAt, including one missing name. The trusted migration transforms those fields, preserves document IDs, timestamps and an unrelated topic field, and fills missing names with Member. Reruns skip v2. A v3 nested author would require dual-read support until old clients retire.

```sh
npm --prefix qa ci
firebase emulators:exec --only firestore --project demo-common-room "npm --prefix qa test"
```

The rules suite includes signed-out reads, cross-user edits and deletes, forged authorship, ownership transfer, private profile access, owner CRUD, concurrent replay and migration assertions. The deployed project uses the same rules file. Passwords and test session tokens stay out of the repository.
