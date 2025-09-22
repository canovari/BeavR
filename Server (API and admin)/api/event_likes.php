<?php
declare(strict_types=1);

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/auth_helpers.php';

header('Content-Type: application/json');

try {
    $pdo = getPDO();
} catch (Throwable $e) {
    respondWithError(500, 'Database connection failed.');
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

switch ($method) {
    case 'POST':
        handlePost($pdo);
        break;
    case 'DELETE':
        handleDelete($pdo);
        break;
    case 'OPTIONS':
        http_response_code(204);
        exit;
    default:
        respondWithError(405, 'Method not allowed.');
}

function handlePost(PDO $pdo): void
{
    $user = requireAuth($pdo);
    $payload = decodeJsonBody();

    $eventId = isset($payload['eventId']) ? (int)$payload['eventId'] : 0;
    if ($eventId <= 0) {
        respondWithError(400, 'Invalid eventId.');
    }

    ensureEventIsLikeable($pdo, $eventId);

    $stmt = $pdo->prepare(
        "INSERT IGNORE INTO event_likes (event_id, user_id, created_at)
         VALUES (:event_id, :user_id, UTC_TIMESTAMP())"
    );
    $stmt->execute([
        ':event_id' => $eventId,
        ':user_id' => $user['id'],
    ]);

    logDebug(sprintf('User %d liked event %d', $user['id'], $eventId));
    respondWithJson(['success' => true]);
}

function handleDelete(PDO $pdo): void
{
    $user = requireAuth($pdo);
    $payload = decodeJsonBody();

    $eventId = isset($payload['eventId']) ? (int)$payload['eventId'] : 0;
    if ($eventId <= 0) {
        respondWithError(400, 'Invalid eventId.');
    }

    $stmt = $pdo->prepare(
        "DELETE FROM event_likes
         WHERE event_id = :event_id AND user_id = :user_id"
    );
    $stmt->execute([
        ':event_id' => $eventId,
        ':user_id' => $user['id'],
    ]);

    logDebug(sprintf('User %d unliked event %d', $user['id'], $eventId));
    respondWithJson(['success' => true]);
}

function ensureEventIsLikeable(PDO $pdo, int $eventId): void
{
    $stmt = $pdo->prepare(
        "SELECT id FROM events
         WHERE id = :id
           AND status = 'approved'
           AND (end_time IS NULL OR end_time >= UTC_TIMESTAMP())
         LIMIT 1"
    );
    $stmt->execute([':id' => $eventId]);
    $event = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$event) {
        respondWithError(404, 'Event not found or unavailable.');
    }
}

function requireAuth(PDO $pdo): array
{
    $token = extractBearerToken();
    if ($token === null) {
        respondWithError(401, 'Missing bearer token.');
    }

    $user = findUserByToken($pdo, $token);
    if ($user === null) {
        respondWithError(401, 'Invalid or expired token.');
    }

    if (userIsBanned($user)) {
        respondWithError(403, ACCOUNT_SUSPENDED_MESSAGE);
    }

    return $user;
}

function findUserByToken(PDO $pdo, string $token): ?array
{
    $stmt = $pdo->prepare('SELECT id, email, status FROM users WHERE login_token = :token LIMIT 1');
    $stmt->execute([':token' => $token]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        return null;
    }

    return [
        'id' => (int)$user['id'],
        'email' => strtolower((string)$user['email']),
        'status' => normalizeUserStatus($user['status'] ?? null),
    ];
}

function extractBearerToken(): ?string
{
    $headers = function_exists('getallheaders') ? getallheaders() : [];
    $authorization = $headers['Authorization'] ?? $headers['authorization'] ?? $_SERVER['HTTP_AUTHORIZATION'] ?? null;
    if (!$authorization || stripos($authorization, 'Bearer ') !== 0) {
        return null;
    }
    $token = trim(substr($authorization, 7));
    return $token === '' ? null : $token;
}

function decodeJsonBody(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false) {
        respondWithError(400, 'Unable to read request body.');
    }
    $trimmed = trim($raw);
    if ($trimmed === '') {
        return [];
    }
    $data = json_decode($trimmed, true);
    if (json_last_error() !== JSON_ERROR_NONE || !is_array($data)) {
        respondWithError(400, 'Invalid JSON payload.');
    }
    return $data;
}

function respondWithJson(array $payload, int $statusCode = 200): void
{
    http_response_code($statusCode);
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

function respondWithError(int $statusCode, string $message): void
{
    respondWithJson(['error' => $message], $statusCode);
}

function logDebug(string $message): void
{
    error_log('[event_likes.php] ' . $message);
}
