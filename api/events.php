<?php
declare(strict_types=1);

require_once __DIR__ . '/../config.php';

header('Content-Type: application/json');

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

try {
    switch (strtoupper($method)) {
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
            break;
        default:
            http_response_code(405);
            echo json_encode(['error' => 'Method not allowed.']);
    }
} catch (Throwable $exception) {
    http_response_code(500);
    echo json_encode(['error' => 'Unexpected server error.']);
}

function handleGet(PDO $pdo): void
{
    expireOldEvents($pdo);

    $mine = isset($_GET['mine']) && $_GET['mine'] === '1';

    if ($mine) {
        $token = extractBearerToken();
        if ($token === null) {
            http_response_code(401);
            echo json_encode(['error' => 'Authentication required.']);
            return;
        }

        $user = findUserByToken($pdo, $token);
        if ($user === null) {
            http_response_code(401);
            echo json_encode(['error' => 'Invalid login token.']);
            return;
        }

        $query = $pdo->prepare(
            'SELECT id, title, start_time, end_time, location, description, organization, category,
                    contact_type, contact_value, latitude, longitude, status, creator
             FROM events
             WHERE creator = :creator
             ORDER BY start_time ASC'
        );
        $query->execute([':creator' => $user['email']]);
        $rows = $query->fetchAll();
    } else {
        $query = $pdo->prepare(
            'SELECT id, title, start_time, end_time, location, description, organization, category,
                    contact_type, contact_value, latitude, longitude, status, creator
             FROM events
             WHERE status = :status
             ORDER BY start_time ASC'
        );
        $query->execute([':status' => 'live']);
        $rows = $query->fetchAll();
    }

    echo json_encode(formatEvents($rows));
}

function handlePost(PDO $pdo): void
{
    $token = extractBearerToken();
    if ($token === null) {
        http_response_code(401);
        echo json_encode(['error' => 'Authentication required.']);
        return;
    }

    $user = findUserByToken($pdo, $token);
    if ($user === null) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid login token.']);
        return;
    }

    $payload = decodeJsonPayload();
    if ($payload === null) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid JSON payload.']);
        return;
    }

    $title = trim((string) ($payload['title'] ?? ''));
    $startTimeRaw = $payload['startTime'] ?? null;
    $endTimeRaw = $payload['endTime'] ?? null;
    $location = trim((string) ($payload['location'] ?? ''));
    $description = trim((string) ($payload['description'] ?? ''));
    $organization = trim((string) ($payload['organization'] ?? ''));
    $category = trim((string) ($payload['category'] ?? ''));
    $contact = $payload['contact'] ?? null;
    $latitude = $payload['latitude'] ?? null;
    $longitude = $payload['longitude'] ?? null;
    $creatorField = isset($payload['creator']) ? trim((string) $payload['creator']) : '';

    if ($title === '' || $startTimeRaw === null || $endTimeRaw === null || $location === '' || $description === '' ||
        $organization === '' || $category === '' || $latitude === null || $longitude === null) {
        http_response_code(400);
        echo json_encode(['error' => 'Missing required fields.']);
        return;
    }

    $startTime = parseIsoDate($startTimeRaw);
    $endTime = parseIsoDate($endTimeRaw);

    if ($startTime === null) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid start time.']);
        return;
    }

    if ($endTime === null) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid end time.']);
        return;
    }

    if ($endTime <= $startTime) {
        $endTime = $endTime->add(new DateInterval('P1D'));
    }

    $contactType = null;
    $contactValue = null;

    if (is_array($contact)) {
        $contactType = normalizeOptionalString($contact['type'] ?? null);
        $contactValue = normalizeOptionalString($contact['value'] ?? null);

        if ($contactType === null || $contactValue === null) {
            $contactType = null;
            $contactValue = null;
        }
    }

    if (!is_numeric($latitude) || !is_numeric($longitude)) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid coordinates.']);
        return;
    }

    if ($creatorField === '') {
        http_response_code(400);
        echo json_encode(['error' => 'Creator is required.']);
        return;
    }

    $creatorEmail = strtolower($user['email']);

    $insert = $pdo->prepare(
        'INSERT INTO events
            (title, start_time, end_time, location, description, organization, category,
             contact_type, contact_value, latitude, longitude, status, creator, creator_user_id)
         VALUES
            (:title, :start_time, :end_time, :location, :description, :organization, :category,
             :contact_type, :contact_value, :latitude, :longitude, :status, :creator, :creator_user_id)'
    );

    $insert->execute([
        ':title' => $title,
        ':start_time' => $startTime->format('Y-m-d H:i:s'),
        ':end_time' => $endTime->format('Y-m-d H:i:s'),
        ':location' => $location,
        ':description' => $description,
        ':organization' => $organization,
        ':category' => $category,
        ':contact_type' => $contactType,
        ':contact_value' => $contactValue,
        ':latitude' => (float) $latitude,
        ':longitude' => (float) $longitude,
        ':status' => 'pending',
        ':creator' => $creatorEmail,
        ':creator_user_id' => $user['id'],
    ]);

    http_response_code(201);
    echo json_encode([
        'success' => true,
        'id' => (int) $pdo->lastInsertId(),
        'status' => 'pending',
    ]);
}

function handleDelete(PDO $pdo): void
{
    $token = extractBearerToken();
    if ($token === null) {
        http_response_code(401);
        echo json_encode(['error' => 'Authentication required.']);
        return;
    }

    $user = findUserByToken($pdo, $token);
    if ($user === null) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid login token.']);
        return;
    }

    $payload = decodeJsonPayload();
    if ($payload === null || !isset($payload['id'])) {
        http_response_code(400);
        echo json_encode(['error' => 'Event id is required.']);
        return;
    }

    $eventId = (int) $payload['id'];
    if ($eventId <= 0) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid event id.']);
        return;
    }

    $select = $pdo->prepare('SELECT id, creator, status FROM events WHERE id = :id LIMIT 1');
    $select->execute([':id' => $eventId]);
    $event = $select->fetch();

    if (!$event) {
        http_response_code(404);
        echo json_encode(['error' => 'Event not found.']);
        return;
    }

    if (strcasecmp($event['creator'], $user['email']) !== 0) {
        http_response_code(403);
        echo json_encode(['error' => 'You do not have permission to modify this event.']);
        return;
    }

    if (strtolower((string) $event['status']) !== 'pending') {
        http_response_code(409);
        echo json_encode(['error' => 'Only pending events can be cancelled.']);
        return;
    }

    $delete = $pdo->prepare('DELETE FROM events WHERE id = :id');
    $delete->execute([':id' => $eventId]);

    echo json_encode(['success' => true]);
}

function formatEvents(array $rows): array
{
    $formatted = [];

    foreach ($rows as $row) {
        $contact = null;
        if ($row['contact_type'] !== null && $row['contact_value'] !== null &&
            $row['contact_type'] !== '' && $row['contact_value'] !== '') {
            $contact = [
                'type' => $row['contact_type'],
                'value' => $row['contact_value'],
            ];
        }

        $status = null;
        if ($row['status'] !== null) {
            $normalized = strtolower((string) $row['status']);
            switch ($normalized) {
                case 'live':
                case 'approved':
                case 'active':
                case 'published':
                    $status = 'live';
                    break;
                case 'pending':
                case 'pending approval':
                case 'awaiting approval':
                case 'under review':
                    $status = 'pending';
                    break;
                case 'expired':
                    $status = 'expired';
                    break;
                case 'cancelled':
                case 'canceled':
                    $status = 'cancelled';
                    break;
                default:
                    $status = $normalized;
            }
        }

        if ($status === null) {
            $status = 'pending';
        }

        $formatted[] = [
            'id' => (int) $row['id'],
            'title' => (string) $row['title'],
            'startTime' => iso8601($row['start_time']),
            'endTime' => iso8601($row['end_time']),
            'location' => $row['location'],
            'description' => $row['description'],
            'organization' => $row['organization'],
            'category' => $row['category'],
            'imageUrl' => null,
            'status' => $status,
            'latitude' => $row['latitude'] !== null ? (float) $row['latitude'] : null,
            'longitude' => $row['longitude'] !== null ? (float) $row['longitude'] : null,
            'contact' => $contact,
            'creator' => $row['creator'],
        ];
    }

    return $formatted;
}

function parseIsoDate(mixed $value): ?DateTimeImmutable
{
    if (!is_string($value) || $value === '') {
        return null;
    }

    try {
        $date = new DateTimeImmutable($value);
    } catch (Exception $exception) {
        return null;
    }

    return $date;
}

function iso8601(mixed $value): ?string
{
    if ($value === null) {
        return null;
    }

    try {
        $date = new DateTimeImmutable((string) $value);
    } catch (Exception $exception) {
        return null;
    }

    return $date->setTimezone(new DateTimeZone('UTC'))->format(DateTimeInterface::ATOM);
}

function decodeJsonPayload(): ?array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || $raw === '') {
        return null;
    }

    $decoded = json_decode($raw, true);
    if (!is_array($decoded)) {
        return null;
    }

    return $decoded;
}

function extractBearerToken(): ?string
{
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';

    if ($header === '' && function_exists('apache_request_headers')) {
        $headers = apache_request_headers();
        if (isset($headers['Authorization'])) {
            $header = $headers['Authorization'];
        }
    }

    if ($header === '') {
        return null;
    }

    if (stripos($header, 'Bearer ') === 0) {
        return trim(substr($header, 7));
    }

    return null;
}

function findUserByToken(PDO $pdo, string $token): ?array
{
    $stmt = $pdo->prepare('SELECT id, email FROM users WHERE login_token = :token LIMIT 1');
    $stmt->execute([':token' => $token]);
    $user = $stmt->fetch();

    if (!$user) {
        return null;
    }

    return [
        'id' => (int) $user['id'],
        'email' => strtolower((string) $user['email']),
    ];
}

function expireOldEvents(PDO $pdo): void
{
    $now = new DateTimeImmutable('now');
    $cutoff = $now->sub(new DateInterval('PT2H'));

    $stmt = $pdo->prepare(
        "UPDATE events
         SET status = 'expired'
         WHERE status <> 'expired'
           AND ((end_time IS NOT NULL AND end_time <= :now)
                OR (end_time IS NULL AND start_time <= :cutoff))"
    );

    $stmt->execute([
        ':now' => $now->format('Y-m-d H:i:s'),
        ':cutoff' => $cutoff->format('Y-m-d H:i:s'),
    ]);
}
