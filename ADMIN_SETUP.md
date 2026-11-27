NaN`lib/firebase_options.dart`.
2. In Authentication → Sign-in method, enable **Email/Password**.
3. Create a **Cloud Firestore** database.
4. Publish the repository's `firestore.rules` rules.

## 2. Bootstrap the first administrator

Admin access is intentionally not open self-registration.

1. In Firebase Authentication → Users, add the first administrator with an email and a temporary password.
2. Copy that user's Firebase Authentication UID.
3. In Firestore, create a document in the `admins` collection whose document ID is exactly that UID.
4. Add these fields:
   - `email` (string): same email address
   - `active` (boolean): `true`
5. Sign in at the web app's root URL with that account.

## 3. Invite more administrators

From the admin dashboard, choose **Invite admin** and enter the invitee's email. The invitation remains valid for seven days. Share the web admin URL with that person; they choose **Have an invitation? Create account** and register using the exact invited email address.

The current implementation stores the invitation in Firestore but does not send email automatically. The inviting admin must share the admin URL separately.

## 4. Bus registry

Use **Register bus** to add a bus number and registration number. Route, driver, phone, and active status are optional. Records are stored in the Firestore `buses` collection.

## Security notes

- Firestore rules restrict bus data and invitation creation to active admins.
- Additional admin accounts can only be created by accepting a pending, unexpired invitation matching the authenticated email.
- Keep the first admin's Firebase credentials secure. Disable an administrator by setting `admins/{uid}.active` to `false` in Firestore.
