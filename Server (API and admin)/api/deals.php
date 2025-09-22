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
    case 'GET':
        handleGet($pdo);
        break;
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

function handleGet(PDO $pdo): void
{
    if (isset($_GET['mine']) && (string)$_GET['mine'] === '1') {
        $user = requireAuth($pdo);

        $stmt = $pdo->prepare(
            "SELECT * FROM deals
             WHERE (creator_user_id = :user_id)
                OR (LOWER(creator) = :creator_email)
             ORDER BY start_date DESC"
        );
        $stmt->execute([
            ':user_id' => $user['id'],
            ':creator_email' => strtolower($user['email']),
        ]);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        respondWithJson(array_map('mapDealRow', $rows));
    }

    $stmt = $pdo->prepare(
        "SELECT * FROM deals
         WHERE status = 'approved'
           AND start_date <= UTC_TIMESTAMP()
           AND (end_date IS NULL OR end_date >= UTC_TIMESTAMP())
         ORDER BY start_date ASC"
    );
    $stmt->execute();
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    respondWithJson(array_map('mapDealRow', $rows));
}

function handlePost(PDO $pdo): void
{
    $user = requireAuth($pdo);
    $payload = decodeJsonBody();

    $requiredFields = ['name', 'type', 'discount', 'description', 'startDate'];
    foreach ($requiredFields as $field) {
        if (!isset($payload[$field]) || trim((string)$payload[$field]) === '') {
            respondWithError(400, sprintf('Missing field: %s', $field));
        }
    }

    $name = trim((string)$payload['name']);
    $description = trim((string)$payload['description']);
    $discount = trim((string)$payload['discount']);
    $type = strtolower(trim((string)$payload['type']));

    if (!in_array($type, ['service', 'good'], true)) {
        respondWithError(400, 'Invalid deal type.');
    }

    $startDate = parseIncomingDate($payload['startDate'] ?? null);
    if ($startDate === null) {
        respondWithError(400, 'Invalid or missing startDate.');
    }

    $endDate = parseIncomingDate($payload['endDate'] ?? null);
    if ($endDate !== null && $endDate < $startDate) {
        respondWithError(400, 'endDate cannot be before startDate.');
    }

    $location = isset($payload['location']) ? trim((string)$payload['location']) : '';
    $normalizedLocation = $location === '' ? null : $location;

    $stmt = $pdo->prepare(
        "INSERT INTO deals (
            name, type, discount, description, location,
            start_date, end_date, status, creator, creator_user_id,
            created_at, updated_at
        ) VALUES (
            :name, :type, :discount, :description, :location,
            :start_date, :end_date, 'pending', :creator, :creator_user_id,
            UTC_TIMESTAMP(), UTC_TIMESTAMP()
        )"
    );

    $stmt->execute([
        ':name' => $name,
        ':type' => $type,
        ':discount' => $discount,
        ':description' => $description,
        ':location' => $normalizedLocation,
        ':start_date' => formatForStorage($startDate),
        ':end_date' => $endDate ? formatForStorage($endDate) : null,
        ':creator' => strtolower($user['email']),
        ':creator_user_id' => $user['id'],
    ]);

    $dealId = (int)$pdo->lastInsertId();

    logDebug(sprintf('Created deal %d for %s', $dealId, $user['email']));

    respondWithJson(['success' => true, 'id' => $dealId], 201);
}

function handleDelete(PDO $pdo): void
{
    $user = requireAuth($pdo);
    $payload = decodeJsonBody();

    $dealId = isset($payload['id']) ? (int)$payload['id'] : 0;
    if ($dealId <= 0) {
        respondWithError(400, 'Invalid deal id.');
    }

    $stmt = $pdo->prepare(
        "SELECT id, status FROM deals
         WHERE id = :id
           AND (creator_user_id = :user_id OR LOWER(creator) = :creator_email)
         LIMIT 1"
    );
    $stmt->execute([
        ':id' => $dealId,
        ':user_id' => $user['id'],
        ':creator_email' => strtolower($user['email']),
    ]);

    $deal = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$deal) {
        respondWithError(404, 'Deal not found.');
    }

    if (isset($deal['status']) && strtolower((string)$deal['status']) !== 'pending') {
        respondWithError(409, 'Only pending deals can be cancelled.');
    }

    $deleteStmt = $pdo->prepare('DELETE FROM deals WHERE id = :id');
    $deleteStmt->execute([':id' => $dealId]);

    logDebug(sprintf('Deleted pending deal %d for %s', $dealId, $user['email']));

    respondWithJson(['success' => true]);
}

function mapDealRow(array $row): array
{
    return [
        'id' => isset($row['id']) ? (int)$row['id'] : null,
        'name' => $row['name'] ?? null,
        'type' => $row['type'] ?? null,
        'discount' => $row['discount'] ?? null,
        'description' => $row['description'] ?? null,
        'location' => $row['location'] ?? null,
        'startDate' => formatDateForJson($row['start_date'] ?? null),
        'endDate' => formatDateForJson($row['end_date'] ?? null),
        'status' => $row['status'] ?? null,
        'creator' => $row['creator'] ?? null,
        'createdAt' => formatDateForJson($row['created_at'] ?? null),
        'updatedAt' => formatDateForJson($row['updated_at'] ?? null),
    ];
}

function requireAuth(PDO $pdo): array
{
    $token = extractBearerToken();
    if ($token === null) {
        respondWithError(401, 'Missing bearer token.');
    }

    $user = fetchUserByToken($pdo, $token);

    if ($user === null) {
        respondWithError(401, 'Invalid or expired token.');
    }

    if (userIsBanned($user)) {
        respondWithError(403, ACCOUNT_SUSPENDED_MESSAGE);
    }

    return $user;
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

function parseIncomingDate($value): ?DateTimeImmutable
{
    if ($value === null || trim((string)$value) === '') {
        return null;
    }
    try {
        return new DateTimeImmutable((string)$value);
    } catch (Exception $e) {
        return null;
    }
}

function formatForStorage(DateTimeImmutable $date): string
{
    return $date->setTimezone(new DateTimeZone('UTC'))->format('Y-m-d H:i:s');
}

function formatDateForJson($value): ?string
{
    if ($value === null || trim((string)$value) === '') {
        return null;
    }
    $date = DateTimeImmutable::createFromFormat('Y-m-d H:i:s', (string)$value, new DateTimeZone('UTC'));
    if ($date instanceof DateTimeImmutable) {
        return $date->format(DateTimeInterface::ATOM);
    }
    try {
        $fallback = new DateTimeImmutable((string)$value);
        return $fallback->format(DateTimeInterface::ATOM);
    } catch (Exception $e) {
        return null;
    }
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
    error_log('[deals.php] ' . $message);
}
