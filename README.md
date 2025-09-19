# BeavR Email Login Flow

This repository now includes a lightweight PHP backend that powers the email + one-time code login flow described in the specification.

## Backend setup

1. Create the `users` table using the schema in [`database/schema.sql`](database/schema.sql).
2. Provide the database connection credentials through the following environment variables before serving the PHP scripts:
   - `DB_HOST`
   - `DB_NAME`
   - `DB_USER`
   - `DB_PASS`
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

The endpoint generates a 6-digit code, stores it along with a 5-minute expiry window, and sends the email from `noreply@canovari.com`.

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

### Database schema

The schema creates a `users` table with the fields required for the flow plus a persistent `login_token` column that can be reused to authenticate subsequent API requests.

## iOS app integration

The SwiftUI app now checks for a stored login token on launch. If a token exists, the user is taken directly to the main experience. Otherwise a two-step login flow is presented:

1. Enter an `@lse.ac.uk` email address to trigger `request_code.php`.
2. Enter the six-digit code from the email to call `verify_code.php`.

After successful verification the login token is saved locally (via `UserDefaults`), so future launches bypass the login flow until the app is reinstalled.
