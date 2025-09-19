<?php
declare(strict_types=1);

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/whiteboard_helpers.php';

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
        echo json_encode(['error' => 'Authentication required.']);
        exit;
    }

    $user = findUserByToken($pdo, $token);
    if ($user === null) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid login token.']);
        exit;
    }

    $payload = decodeJsonPayload();
    if ($payload === null) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid JSON payload.']);
        exit;
    }

    $latitude = $payload['latitude'] ?? null;
    $longitude = $payload['longitude'] ?? null;
    $timestampRaw = $payload['timestamp'] ?? null;

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

    $stmt = $pdo->prepare(
        'INSERT INTO user_locations (user_id, latitude, longitude, recorded_at)
         VALUES (:user_id, :latitude, :longitude, :recorded_at)
         ON DUPLICATE KEY UPDATE
             latitude = VALUES(latitude),
             longitude = VALUES(longitude),
             recorded_at = VALUES(recorded_at),
             updated_at = CURRENT_TIMESTAMP'
    );

    $stmt->execute([
        ':user_id' => $user['id'],
        ':latitude' => (float) $latitude,
        ':longitude' => (float) $longitude,
        ':recorded_at' => $recordedAt,
    ]);

    echo json_encode(['success' => true]);
} catch (Throwable $exception) {
    http_response_code(500);
    echo json_encode(['error' => 'Unexpected server error.']);
}
