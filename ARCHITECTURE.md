# PlayPlace architecture

PlayPlace is migrating to a feature-first Flutter architecture using GetX.

## Application structure

```text
lib/
├── app/
│   ├── bindings/       # Application-wide dependency registration
│   └── routes/         # Named route constants
├── core/               # Shared infrastructure and reusable utilities
├── features/
│   ├── announcements/
│   │   ├── controllers/
│   │   └── models/
│   └── routes/
│       └── controllers/
├── admin/              # Existing admin screens (migration in progress)
├── driver_*.dart       # Existing driver screens (migration in progress)
└── main.dart           # App bootstrap and current home UI
```

## GetX conventions

- State: feature-scoped `GetxController` classes; use Rx values and `Obx` for reactive UI.
- Dependency injection: register app-wide dependencies in `AppBinding`; feature-only dependencies belong in feature bindings.
- Navigation: use named routes declared in `AppRoutes` and registered by `GetMaterialApp`. Existing imperative routes remain temporarily during migration.
- Data access: move Firestore and local persistence into repositories/services rather than embedding database calls in widgets.
- Lifecycle: background GPS tracking must be owned by a long-lived service, not a screen controller disposed during navigation.

## Current migration scope

- Replaced Riverpod voice-trigger and route-progress state with GetX controllers.
- Extracted the voice-trigger model and controllers into feature folders.
- Added GetMaterialApp, named entry routes, and root dependency registration.
- Preserved Firebase initialization, driver/admin gates, existing screens, local audio, and GPS behavior.
- Admin, driver authentication, bus/route screens, calendar, and performance data access remain to be migrated feature by feature. Keep these screens until replacements have been tested.

## Verification

Run after pulling:

```bash
flutter pub get
dart format lib
flutter analyze
flutter test
```

Test background GPS on a physical device after any future tracking-service refactor.
