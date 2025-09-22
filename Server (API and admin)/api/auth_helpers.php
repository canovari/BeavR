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
    $columns = getUserSelectColumns($pdo);
    $stmt = $pdo->prepare(sprintf('SELECT %s FROM users WHERE login_token = :token LIMIT 1', $columns));
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

function getUserSelectColumns(PDO $pdo): string
{
    return usersTableHasStatusColumn($pdo) ? 'id, email, status' : 'id, email';
}

function usersTableHasStatusColumn(PDO $pdo): bool
{
    static $hasStatusColumn;

    if ($hasStatusColumn !== null) {
        return $hasStatusColumn;
    }

    try {
        $stmt = $pdo->prepare(
            "SELECT 1
             FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE()
               AND TABLE_NAME = 'users'
               AND COLUMN_NAME = :column
             LIMIT 1"
        );
        $stmt->execute([':column' => 'status']);
        $hasStatusColumn = (bool) $stmt->fetchColumn();
    } catch (Throwable $e) {
        $hasStatusColumn = false;
    }

    return $hasStatusColumn;
}

function userIsBanned(array $user): bool
{
    return ($user['status'] ?? USER_STATUS_REGULAR) === USER_STATUS_BANNED;
}

function userIsMuted(array $user): bool
{
    return ($user['status'] ?? USER_STATUS_REGULAR) === USER_STATUS_MUTED;
}
