# Common Room

A live message board built with Flutter and Firebase for CSC 4360 Homework 02 (undergraduate track). Sign in to read the board, post a message, or edit and delete your own posts. Other students see changes without refreshing.

## Run on Android

With Flutter and the Android SDK installed, start an emulator or connect a phone. The included Firebase configuration points to the homework project.

```sh
flutter pub get
flutter run
```

To use your own Firebase project, enable Email/Password sign-in and create a Firestore database. With the Firebase and FlutterFire CLIs installed, run these before launching the app:

```sh
flutterfire configure --platforms=android --project YOUR_PROJECT_ID
firebase deploy --only firestore:rules --project YOUR_PROJECT_ID
```

## How the board works

The splash screen covers startup while Firebase connects. `AuthService` handles registration, sign-in and sign-out. Once a signed-in user has a profile, the app opens the board. `BoardService` reads and writes Firestore data.

- **Profiles** live at `users/{uid}`. Firebase Auth supplies the UID, the student enters their first and last names, the app assigns the student role, and Firestore timestamps registration. Only the owner can read the full profile.
- **Posts** live at `messages/{id}`. The author writes the text. The app adds the signed-in UID, the first name from the profile and schema version 2. Firestore timestamps each post and edit. Rules let signed-in students read posts and restrict edits and deletes to the author.
- **On the phone**, drafts stay in memory. The login survives a restart. Clearing app data signs the user out, and their published posts are still there when they sign back in.

## Tests

```sh
flutter analyze
flutter test
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

For a quick check, open the board on two devices with different accounts. Post from one, watch it appear on the other, then edit and delete it as the author.

The three choice features cover Firestore rules (#2), duplicate posts (#4) and migration (#5). Each draft reuses its document ID on retry. The emulator tests check ownership, send the same draft twice, and upgrade two v1 posts to v2 while preserving their IDs and timestamps. Run them with Node 22+, Java 21+ and the Firebase CLI:

```sh
npm --prefix qa ci
firebase emulators:exec --only firestore --project demo-common-room "npm --prefix qa test"
```
