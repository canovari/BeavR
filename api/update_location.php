<?php
declare(strict_types=1);

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/whiteboard_helpers.php';

header('Content-Type: application/json; charset=utf-8');

$method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');

try {
    if ($method === 'OPTIONS') {
        http_response_code(204);
        return;
    }

    if ($method !== 'POST') {
        http_response_code(405);
        echo json_encode(['error' => 'Method not allowed.']);
        return;
    }

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

    $latitude = $payload['latitude'] ?? null;
    $longitude = $payload['longitude'] ?? null;

    if (!is_numeric($latitude) || !is_numeric($longitude)) {
        http_response_code(400);
        echo json_encode(['error' => 'Latitude and longitude are required.']);
        return;
    }

    $latitude = (float) $latitude;
    $longitude = (float) $longitude;

    if ($latitude < -90 || $latitude > 90 || $longitude < -180 || $longitude > 180) {
        http_response_code(400);
        echo json_encode(['error' => 'Coordinates are out of range.']);
        return;
    }

    $update = $pdo->prepare(
        'UPDATE users
         SET latitude = :latitude,
             longitude = :longitude,
             location_updated_at = UTC_TIMESTAMP()
         WHERE id = :id'
    );

    $update->execute([
        ':latitude' => $latitude,
        ':longitude' => $longitude,
        ':id' => $user['id'],
    ]);

    $timestamp = gmdate(DateTimeInterface::ATOM);

    echo json_encode([
        'success' => true,
        'latitude' => $latitude,
        'longitude' => $longitude,
        'locationUpdatedAt' => $timestamp,
    ]);
} catch (Throwable $exception) {
    http_response_code(500);
    echo json_encode(['error' => 'Unexpected server error.']);
}
