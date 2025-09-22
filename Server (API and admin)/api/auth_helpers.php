<?php
declare(strict_types=1);

const USER_STATUS_REGULAR = 'regular';
const USER_STATUS_MUTED = 'muted';
const USER_STATUS_BANNED = 'banned';
const ACCOUNT_SUSPENDED_MESSAGE = 'uh-oh.. looks like you have been suspended, if you believe this is an error contact us @ support@beavr.net';

/**
 * Normalize a raw status string coming from the database.
 */
function normalizeUserStatus($status): string
{
    $normalized = strtolower(trim((string) $status));
    if (in_array($normalized, [USER_STATUS_REGULAR, USER_STATUS_MUTED, USER_STATUS_BANNED], true)) {
        return $normalized;
    }

    return USER_STATUS_REGULAR;
}

/**
 * Fetch a user by login token, returning null when not found.
 */
function fetchUserByToken(PDO $pdo, string $token): ?array
{
    $stmt = $pdo->prepare('SELECT id, email, status FROM users WHERE login_token = :token LIMIT 1');
    $stmt->execute([':token' => $token]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        return null;
    }

    return [
        'id' => (int) $row['id'],
        'email' => strtolower((string) $row['email']),
        'status' => normalizeUserStatus($row['status'] ?? null),
    ];
}

function userIsBanned(array $user): bool
{
    return ($user['status'] ?? USER_STATUS_REGULAR) === USER_STATUS_BANNED;
}

function userIsMuted(array $user): bool
{
    return ($user['status'] ?? USER_STATUS_REGULAR) === USER_STATUS_MUTED;
}
