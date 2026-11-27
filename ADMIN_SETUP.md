# PlayPlace admin, Super Admin, drivers, and route tracking setup

## Firebase setup

1. Enable Email/Password in Firebase Authentication and create a Firestore database.
2. Publish the repository's `firestore.rules` before running the first-account setup.
3. Open the web admin portal. If no Super Admin has been registered, choose **First time here? Set up Super Admin**.
4. Register the one Super Admin using their real email address and a Firebase Authentication password.
5. The first successful claim is stored in `appConfig/superAdmin`. The document is immutable to client users, and later users cannot claim or replace it.
6. The Super Admin can invite other administrators. Invitees register with the exact invited email; invitations expire after seven days.

**Important:** The first-claim flow is a one-time bootstrap. The first person to complete it becomes the only Super Admin. For production deployment, restrict initial access to the setup page (for example, deploy it privately or provision the initial claim through a trusted operator) before making the portal public.

## Super Admin dashboard

- Create packages with a name, price in INR, duration in days, maximum buses, and comma-separated features.
- Edit, enable, disable, or delete packages.
- View administrator accounts, enable/disable access, and assign an active package.
- Package assignments are stored in `admins/{uid}.subscription`, including start and expiry timestamps.
- Pending admin invitations are visible and can be cancelled.

## Driver accounts and buses

Admins register buses in the dashboard. Drivers register with the exact bus number, their name, unique email, and password. New accounts stay pending until an admin approves them. Each driver has a separate Firebase Authentication UID and private performance records.

## Shared routes and announcement audio

Route names, start/end points, stop coordinates, and repeat counts are stored in Firestore under `buses/{busId}/routes`. The app uses one-time Firestore reads and writes; it does not subscribe to Firestore snapshots.

Recorded announcement audio remains on the device that recorded it. It is deliberately not uploaded or shared. Each driver must record their own arriving/arrived audio on their device. If another driver loads the shared route, its route data and repeat counts are available but its audio recordings are not.

## Background route tracking and admin dashboard

When the driver starts a route, Android location tracking runs with a persistent foreground-service notification. GPS continues while the app is in the background, subject to Android location permissions and battery restrictions. At each detected stop arrival, the app writes an event to `buses/{busId}/locationEvents` and updates `buses/{busId}/locationStatus/latest`. The admin dashboard polls every 15 seconds.

## Private performance data

Driver performance is stored under `driverPerformance/{uid}/records/{recordId}`. Drivers can read their own records; administrators can read records for support and reporting.
