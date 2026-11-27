# PlayPlace admin, drivers, and route tracking setup

## Firebase setup

1. Enable Email/Password in Firebase Authentication.
2. Create a Firestore database.
3. Publish `firestore.rules`.
4. Create the first administrator in Firebase Authentication. Copy the UID and manually create `admins/{uid}` in Firestore with `email` and `active: true`.
5. Existing admins can invite more administrators. Invitations expire after seven days; the admin must share the admin page URL manually.

Firebase Storage is not used by this version of PlayPlace. Do not deploy or enable Storage rules for the app.

## Driver accounts and buses

Admins register buses in the dashboard. Drivers register with the exact bus number, their name, unique email, and password. New accounts stay pending until an admin approves them. Each driver has a separate Firebase Authentication UID and private performance records.

## Shared routes and announcement audio

Route names, start/end points, stop coordinates, and repeat counts are stored in Firestore under `buses/{busId}/routes`. The app uses one-time Firestore reads and writes; it does not subscribe to Firestore snapshots.

Recorded announcement audio remains on the device that recorded it. It is deliberately not uploaded or shared. Each driver must record their own arriving/arrived audio on their device. If another driver loads the shared route, its route data and repeat counts are available but its audio recordings are not.

## Background route tracking and admin dashboard

When the driver starts a route, Android location tracking runs with a persistent foreground-service notification. GPS continues while the app is in the background, subject to Android location permissions and battery restrictions. At each detected stop arrival, the app writes a small event to `buses/{busId}/locationEvents` and updates `buses/{busId}/locationStatus/latest`. These are ordinary Firestore writes; the Firestore SDK queues writes when offline and syncs them after connectivity returns.

The admin dashboard polls for the latest bus arrival status every 15 seconds. It does not use Firestore real-time streams. The driver must start route tracking while the app is visible; force-stopping the app or disabling location can stop tracking.

## Private performance data

Driver performance is stored under `driverPerformance/{uid}/records/{recordId}`. Drivers can read their own records; administrators can read records for support and reporting.
