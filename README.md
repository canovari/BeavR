# BeavR Email Login Flow

This repository now includes a lightweight PHP backend that powers the email + one-time code login flow described in the specification.

## Backend setup

1. Create the tables using the schema in [`database/schema.sql`](database/schema.sql). This now provisions both the `users` table for authentication and an `events` table that stores every submitted event together with its creator email and publication status.
2. Provide the database connection credentials through the following environment variables before serving the PHP scripts (the shared `config.php` will refuse to bootstrap without them and will return HTTP 500 instead of leaking stack traces). You can set them in your shell, configure them in your web server, or create a `.env` file (either at the repository root or inside `Server (API and admin)/`) with the same key/value pairs:
   - `DB_HOST`
   - `DB_NAME`
   - `DB_USER`
   - `DB_PASS`
   For local development you can copy [`Server (API and admin)/.env.example`](Server%20(API%20and%20admin)/.env.example) to `.env` and customise the values.
3. Deploy the contents of the [`api/`](api) directory to your PHP-capable web server. Both scripts expect `config.php` one level above them so they can share the PDO connection.

### Available endpoints

#### `POST api/request_code.php`

Request a new verification code. Parameters:

| Field | Description |
| --- | --- |
| `email` | LSE email address (`@lse.ac.uk`). |

Successful response:

```json
{ "success": true }
```

Example error response (`400 Bad Request`):

```json
{ "error": "Invalid email domain." }
```

The endpoint generates a 6-digit code, stores it along with a 5-minute expiry window, and sends the email from `noreply@beavr.net`.

#### `POST api/verify_code.php`

Verify a previously issued code. Parameters:

| Field | Description |
| --- | --- |
| `email` | Same email used to request the code. |
| `code` | 6-digit code received by email. |

Successful response:

```json
{ "success": true, "token": "..." }
```

This call ensures the code has not expired, marks the user as verified, clears the temporary code, generates a new login token, and returns the token to the client.

#### `api/events.php`

This endpoint manages event submissions and retrieval:

* `POST api/events.php`
  * Requires an `Authorization: Bearer <token>` header with a valid login token.
  * Accepts a JSON payload with the event details plus a `creator` field (the LSE email of the submitter). The server always persists the authenticated email in the `creator` column so the event can be tied back to the user.
  * Stores the event as `pending` and returns the new event id.
* `GET api/events.php`
  * Returns all live events for the public feed.
* `GET api/events.php?mine=1`
  * Requires the bearer token header and returns every event that belongs to the authenticated user, regardless of status (`pending`, `live`, or `expired`).
* `DELETE api/events.php`
  * Requires the bearer token header and a JSON payload with the event `id`.
  * Allows the creator to cancel and delete a pending submission.

Each response uses ISO-8601 date strings and includes the persisted `creator` value so the mobile app can display ownership metadata in the "My Events" tab.

### Database schema

The schema creates a `users` table with the fields required for the flow plus a persistent `login_token` column that can be reused to authenticate subsequent API requests.

## iOS app integration

The SwiftUI app now checks for a stored login token on launch. If a token exists, the user is taken directly to the main experience. Otherwise a two-step login flow is presented:

1. Enter an `@lse.ac.uk` email address to trigger `request_code.php`.
2. Enter the six-digit code from the email to call `verify_code.php`.

After successful verification the login token is saved locally in the iOS Keychain (with an automatic migration for users that still had credentials in `UserDefaults`), so future launches bypass the login flow until the app is reinstalled or the token is cleared.
