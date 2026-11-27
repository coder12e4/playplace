# PlayPlace web admin and driver setup

## Firebase setup

1. Enable Email/Password in Firebase Authentication.
2. Create a Firestore database.
3. Publish `firestore.rules` and `storage.rules` from this repository.
4. Enable Firebase Storage and configure Storage rules to access Firestore for driver membership checks.
5. Create the first administrator in Firebase Authentication. Copy the UID and manually create `admins/{uid}` in Firestore with `email` and `active: true`.
6. Admins can invite more administrators from the dashboard. The invitee registers with the exact invited email. Invitations expire after seven days; the admin must share the admin page URL manually.

## Bus registration

Admins register buses in the dashboard. Drivers must enter the exact bus number shown in the registry as their Bus ID.

## Driver registration and approval

Drivers register with their name, Bus ID, unique email, and password. Firebase Authentication creates a separate identity for each driver. A matching `driverProfiles/{uid}` document is created with `status: pending`. An admin approves or rejects the request in the Driver approval requests section. Only approved drivers can enter the app.

## Shared bus routes and announcements

Approved drivers assigned to the same bus read and write the same `buses/{busId}/routes` collection. Route metadata, stops, repeat counts, and recorded announcement audio are shared. Audio files are uploaded to Firebase Storage under `busRoutes/{busId}/{routeId}/...`. Other approved drivers on that bus can play the recordings.

Deleting a shared route removes it for every driver on that bus. Existing routes saved only in SharedPreferences remain local to their original device; recreate them in the shared route list. Locally recorded audio must be uploaded again.

## Private performance data

Store each driver's performance under `driverPerformance/{uid}/records/{recordId}`. Firestore rules allow the driver and administrators to read it; other drivers cannot read it.
