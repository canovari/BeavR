<?php
declare(strict_types=1);

require_once __DIR__ . '/../config.php';

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
            "SELECT * FROM events
             WHERE (creator_user_id = :user_id)
                OR (LOWER(creator) = :creator_email)
             ORDER BY start_time DESC"
        );
        $stmt->execute([
            ':user_id' => $user['id'],
            ':creator_email' => strtolower($user['email']),
        ]);
        $events = $stmt->fetchAll(PDO::FETCH_ASSOC);
        respondWithJson(array_map('mapEventRow', $events));
    }

    // Public feed: only approved events that haven't ended yet
    $stmt = $pdo->prepare(
        "SELECT * FROM events
         WHERE status = 'approved'
           AND (end_time IS NULL OR end_time >= UTC_TIMESTAMP())
         ORDER BY start_time ASC"
    );
    $stmt->execute();
    $events = $stmt->fetchAll(PDO::FETCH_ASSOC);
    respondWithJson(array_map('mapEventRow', $events));
}

function handlePost(PDO $pdo): void
{
    $user = requireAuth($pdo);
    $payload = decodeJsonBody();

    $requiredFields = ['title', 'startTime', 'location', 'description', 'organization', 'category', 'latitude', 'longitude'];
    foreach ($requiredFields as $field) {
        if (!isset($payload[$field]) || trim((string)$payload[$field]) === '') {
            respondWithError(400, sprintf('Missing field: %s', $field));
        }
    }

    $title = trim((string)$payload['title']);
    $location = trim((string)$payload['location']);
    $description = trim((string)$payload['description']);
    $organization = trim((string)$payload['organization']);
    $category = trim((string)$payload['category']);
    $latitude = filter_var($payload['latitude'], FILTER_VALIDATE_FLOAT);
    $longitude = filter_var($payload['longitude'], FILTER_VALIDATE_FLOAT);

    if ($latitude === false || $longitude === false) {
        respondWithError(400, 'Invalid latitude or longitude.');
    }

    $startDate = parseIncomingDate(isset($payload['startTime']) ? $payload['startTime'] : null);
    if ($startDate === null) {
        respondWithError(400, 'Invalid or missing startTime.');
    }

    $endDate = parseIncomingDate(isset($payload['endTime']) ? $payload['endTime'] : null);

    $contactType = null;
    $contactValue = null;
    if (isset($payload['contact']) && is_array($payload['contact'])) {
        $contactTypeCandidate = trim((string)($payload['contact']['type'] ?? ''));
        $contactValueCandidate = trim((string)($payload['contact']['value'] ?? ''));
        if ($contactTypeCandidate !== '' && $contactValueCandidate !== '') {
            $contactType = $contactTypeCandidate;
            $contactValue = $contactValueCandidate;
        }
    }

    $imageUrl = isset($payload['imageUrl']) && trim((string)$payload['imageUrl']) !== ''
        ? trim((string)$payload['imageUrl'])
        : null;

    $stmt = $pdo->prepare(
        "INSERT INTO events (
            title, start_time, end_time, location, description, organization,
            category, image_url, contact_type, contact_value, latitude, longitude,
            status, creator, creator_user_id, created_at, updated_at
        ) VALUES (
            :title, :start_time, :end_time, :location, :description, :organization,
            :category, :image_url, :contact_type, :contact_value, :latitude, :longitude,
            'pending', :creator, :creator_user_id, UTC_TIMESTAMP(), UTC_TIMESTAMP()
        )"
    );

    $stmt->execute([
        ':title' => $title,
        ':start_time' => formatForStorage($startDate),
        ':end_time' => $endDate ? formatForStorage($endDate) : null,
        ':location' => $location,
        ':description' => $description,
        ':organization' => $organization,
        ':category' => $category,
        ':image_url' => $imageUrl,
        ':contact_type' => $contactType,
        ':contact_value' => $contactValue,
        ':latitude' => $latitude,
        ':longitude' => $longitude,
        ':creator' => strtolower($user['email']),
        ':creator_user_id' => $user['id'],
    ]);

    $eventId = (int)$pdo->lastInsertId();

    logDebug(sprintf(
        'Created event %d for %s (%s -> %s)',
        $eventId,
        $user['email'],
        $startDate->format(DateTimeInterface::ATOM),
        $endDate ? $endDate->format(DateTimeInterface::ATOM) : 'no end'
    ));

    respondWithJson(['success' => true, 'id' => $eventId], 201);
}

function handleDelete(PDO $pdo): void
{
    $user = requireAuth($pdo);
    $payload = decodeJsonBody();

    $eventId = isset($payload['id']) ? (int)$payload['id'] : 0;
    if ($eventId <= 0) {
        respondWithError(400, 'Invalid event id.');
    }

    $stmt = $pdo->prepare(
        "SELECT id, status FROM events
         WHERE id = :id
           AND (creator_user_id = :user_id OR LOWER(creator) = :creator_email)
         LIMIT 1"
    );
    $stmt->execute([
        ':id' => $eventId,
        ':user_id' => $user['id'],
        ':creator_email' => strtolower($user['email']),
    ]);

    $event = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$event) {
        respondWithError(404, 'Event not found.');
    }

    if (isset($event['status']) && strtolower((string)$event['status']) !== 'pending') {
        respondWithError(409, 'Only pending events can be cancelled.');
    }

    $deleteStmt = $pdo->prepare("DELETE FROM events WHERE id = :id");
    $deleteStmt->execute([':id' => $eventId]);

    logDebug(sprintf('Deleted pending event %d for %s', $eventId, $user['email']));

    respondWithJson(['success' => true]);
}

function requireAuth(PDO $pdo): array
{
    $token = extractBearerToken();
    if ($token === null) {
        respondWithError(401, 'Missing bearer token.');
    }

    $stmt = $pdo->prepare('SELECT id, email FROM users WHERE login_token = :token LIMIT 1');
    $stmt->execute([':token' => $token]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        respondWithError(401, 'Invalid or expired token.');
    }

    return [
        'id' => (int)$user['id'],
        'email' => strtolower((string)$user['email']),
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

// ✅ PHP 7 compatible (no union types)
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

function mapEventRow(array $row): array
{
    return [
        'id' => isset($row['id']) ? (int)$row['id'] : null,
        'title' => $row['title'] ?? null,
        'startTime' => formatDateForJson($row['start_time'] ?? null),
        'endTime' => formatDateForJson($row['end_time'] ?? null),
        'location' => $row['location'] ?? null,
        'description' => $row['description'] ?? null,
        'organization' => $row['organization'] ?? null,
        'category' => $row['category'] ?? null,
        'imageUrl' => $row['image_url'] ?? null,
        'status' => $row['status'] ?? null,
        'latitude' => isset($row['latitude']) ? (float)$row['latitude'] : null,
        'longitude' => isset($row['longitude']) ? (float)$row['longitude'] : null,
        'creator' => $row['creator'] ?? null,
        'contact' => buildContact($row),
        'createdAt' => formatDateForJson($row['created_at'] ?? null),
        'updatedAt' => formatDateForJson($row['updated_at'] ?? null),
    ];
}

function buildContact(array $row): ?array
{
    $type = $row['contact_type'] ?? null;
    $value = $row['contact_value'] ?? null;
    if ($type === null || $value === null) {
        return null;
    }
    $trimmedType = trim((string)$type);
    $trimmedValue = trim((string)$value);
    if ($trimmedType === '' || $trimmedValue === '') {
        return null;
    }
    return ['type' => $trimmedType, 'value' => $trimmedValue];
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
    error_log('[events.php] ' . $message);
}
