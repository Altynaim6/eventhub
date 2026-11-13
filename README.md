# EventHub

A mobile app for creating, discovering and joining events. Built with **Flutter**, **Firebase** (Authentication + Cloud Firestore) and **BLoC** state management, following the SRS *EventHub v2.0*.

> Course project, Hochschule Hof. Author: [Your name]

<!-- Add screenshots here, e.g.:
![Home](docs/screenshots/home.png) ![My Events](docs/screenshots/my_events.png) -->

## Features

- **Accounts:** register, log in and log out with email and password; the session survives app restarts.
- **Events:** create, edit and delete your own events (title, description, category, date, location, capacity).
- **Discovery:** search by title or location, filter by category and date (all, upcoming, today, next 7 days, custom range), sort by date, title or free places.
- **Registration:** join and leave an event with capacity control. Free places are updated live.
- **My Events:** events you created and events you are registered for.
- **Participants:** the organizer sees who registered for an event.
- **Profile:** change your display name, see your statistics, reset your password, sign out.
- **Navigation:** bottom bar with Home, My Events, Create Event and Profile.

## Tech stack

| Part | Technology |
|---|---|
| App | Flutter (Dart `^3.13.5`), Material |
| Auth | Firebase Authentication (Email/Password) |
| Database | Cloud Firestore |
| State management | `flutter_bloc` (Bloc and Cubit), `equatable` |
| Tests | `flutter_test`; Node + Firebase Emulator for security rules |

## Project structure

```
lib/
  main.dart                  app entry, providers, auth-based navigation
  firebase_options.dart      Firebase configuration
  ui/                        theme and shared widgets
  features/
    auth/                    AuthBloc, auth repository, login/register/home screens
    events/                  blocs and cubits, models, event repository, screens, widgets
    profile/                 ProfileCubit, profile repository and screen
test/                        unit, bloc/cubit and widget tests
tools/firestore-tests/       Firestore security rules tests (Node)
firestore.rules              security rules
firestore.indexes.json       Firestore indexes
docs/                        phase reports
```

Each feature has three layers: UI (screens, widgets) → state (Bloc/Cubit) → repository (the only code that calls Firebase). Repositories sit behind interfaces, so the logic is tested without Firebase.

## Getting started

### Prerequisites

- Flutter SDK (stable channel with Dart `^3.13.5`) — check with `flutter --version`
- Android Studio with an emulator, or a physical Android device
- Node.js and Java (only for the security rules tests)
- Firebase CLI: `npm install -g firebase-tools`

### Run the app

```bash
git clone https://github.com/Altynaim6/eventhub.git
cd eventhub
flutter pub get
flutter doctor
flutter devices
flutter run            # or: flutter run -d <device-id>
```

### Firebase setup

The repository is configured for the Firebase project `eventhub-fae97` (`lib/firebase_options.dart` and `android/app/google-services.json`). You need access to that project, or you can use your own:

**Using your own Firebase project**

1. Create a project in the [Firebase console](https://console.firebase.google.com).
2. Run `dart pub global activate flutterfire_cli`, then `flutterfire configure` and select your project. This regenerates `firebase_options.dart` and `google-services.json`.
3. Continue with the steps below.

**Required console settings**

1. **Authentication → Sign-in method:** enable **Email/Password**.
2. **Firestore Database:** create a database (production mode).
3. **Deploy rules and indexes:**

   ```bash
   firebase login
   firebase deploy --only firestore:rules,firestore:indexes --project <your-project-id>
   ```

4. **Firestore → Indexes:** wait until the index shows **Enabled**. Without it the *Registered* tab in My Events returns an error.

## Tests

```bash
flutter analyze
flutter test
```

Security rules tests (run against the Firestore emulator):

```bash
cd tools/firestore-tests && npm ci && cd ../..
firebase emulators:exec --only firestore --project demo-eventhub "npm --prefix tools/firestore-tests test"
```

On Windows use `npm.cmd` instead of `npm` in the last command.

## Data model

```
users/{uid}                              name, email, createdAt
events/{eventId}                         title, description, category, date, location,
                                         capacity, organizerId, createdAt, registeredCount
events/{eventId}/registrations/{uid}     userId, registeredAt, displayName
```

- The registration document ID is the user's `uid`, so a user cannot register twice for the same event.
- Joining and leaving run in a Firestore **transaction**: capacity is checked and `registeredCount` changes by exactly ±1 together with the registration document.
- "My registrations" uses a collection group query on `registrations.userId` (hence the index).

## Security

`firestore.rules` enforces access on the server, independent of the app:

- Only signed-in users can read events.
- Only the organizer can edit or delete an event, and only an event without participants can be deleted.
- `registeredCount` may change only by ±1 and only together with the user's own registration being created or deleted; registration is allowed only for future events.
- A registration can be created or deleted only by its owner; the organizer can read the participant list.
- A user document is readable and writable only by its owner.

The API key in `google-services.json` is a client identifier, not a secret; data is protected by the rules above.

## Known limitations

- An event that has participants cannot be deleted (cascade deletion would need a Cloud Function).
- Email format is validated by Firebase, not on the client.
- The organizer is not shown on the event details screen.
- No guest browsing: the app requires login.
- The password reset is available in the profile, not on the login screen.
- Filtering runs on the client over the full event list (no pagination).
- English-only interface; no event images, notifications, favorites, comments or map.

## License

[Add a license or "For educational use"]
