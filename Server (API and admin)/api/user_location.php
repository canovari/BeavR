<?php
declare(strict_types=1);

require_once __DIR__ . '/../config.php';

header('Content-Type: application/json');

$method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
if ($method !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed.']);
    exit;
}

try {
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
        http_response_code(400);
        echo json_encode(['error' => 'Valid email is required.']);
        exit;
    }
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

