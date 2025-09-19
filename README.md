# BeavR Email Login Flow

This repository includes a lightweight PHP backend that powers the email + one-time code login flow described in the specification, plus endpoints to submit and manage events tied to the authenticated user.

## Backend setup

1. Create the tables using the schema in [`database/schema.sql`](database/schema.sql). This provisions both the `users` table for authentication and an `events` table that stores every submitted event together with its `creator` email and publication `status`.
2. Provide the database connection credentials through the following environment variables **before** serving the PHP scripts:
   - `DB_HOST`
   - `DB_NAME`
   - `DB_USER`
   - `DB_PASS`
3. Deploy the contents of the [`api/`](api) directory to your PHP-capable web server. Both scripts expect `config.php` **one level above them** so they can share the PDO connection.

---

## Available endpoints

### `POST api/request_code.php`

Request a new verification code.

**Parameters**

| Field   | Description                   |
|--------|-------------------------------|
| `email` | LSE email address (`@lse.ac.uk`). |

**Successful response**
```json
{ "success": true }
