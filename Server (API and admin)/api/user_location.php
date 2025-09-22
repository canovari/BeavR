<?php
declare(strict_types=1);

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/auth_helpers.php';

header('Content-Type: application/json');

$method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
if ($method !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed.']);
    exit;
}

try {
    $token = extractBearerToken();
    if ($token === null) {
        http_response_code(401);
        echo json_encode(['error' => 'Missing bearer token.']);
        exit;
    }

    $user = fetchUserByToken($pdo, $token);
    if ($user === null) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid or expired token.']);
        exit;
    }

    if (userIsBanned($user)) {
        http_response_code(403);
        echo json_encode(['error' => ACCOUNT_SUSPENDED_MESSAGE]);
        exit;
    }

    // Parse JSON body
    $payload = json_decode(file_get_contents('php://input'), true);
    if (!is_array($payload)) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid JSON payload.']);
        exit;
    }

    $email = $payload['email'] ?? null;
    $latitude = $payload['latitude'] ?? null;
    $longitude = $payload['longitude'] ?? null;
    $timestampRaw = $payload['timestamp'] ?? null;

    // Validate
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $email = $user['email'];
    }

    if (strcasecmp((string) $email, $user['email']) !== 0) {
        http_response_code(403);
        echo json_encode(['error' => 'Authenticated email does not match payload.']);
        exit;
    }

    $email = $user['email'];
    if (!is_numeric($latitude) || !is_numeric($longitude)) {
        http_response_code(400);
        echo json_encode(['error' => 'Latitude and longitude are required.']);
        exit;
    }
    if (!is_string($timestampRaw) || $timestampRaw === '') {
        http_response_code(400);
        echo json_encode(['error' => 'A timestamp is required.']);
        exit;
    }

    try {
        $timestamp = new DateTimeImmutable($timestampRaw);
    } catch (Exception $exception) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid timestamp.']);
        exit;
    }

    $recordedAt = $timestamp->setTimezone(new DateTimeZone('UTC'))->format('Y-m-d H:i:s');

    // Insert or update by email
    $stmt = $pdo->prepare(
    'INSERT INTO user_locations (email, latitude, longitude, recorded_at, updated_at)
     VALUES (:email, :latitude, :longitude, :recorded_at, CURRENT_TIMESTAMP)
     ON DUPLICATE KEY UPDATE
         latitude = VALUES(latitude),
         longitude = VALUES(longitude),
         recorded_at = VALUES(recorded_at),
         updated_at = CURRENT_TIMESTAMP'
);

    $stmt->execute([
        ':email' => $email,
        ':latitude' => (float) $latitude,
        ':longitude' => (float) $longitude,
        ':recorded_at' => $recordedAt,
    ]);

    echo json_encode(['success' => true]);
} catch (Throwable $exception) {
    http_response_code(500);
    echo json_encode(['error' => 'Unexpected server error.']);
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

