<?php
declare(strict_types=1);

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../services/NotificationService.php';
require_once __DIR__ . '/whiteboard_helpers.php';

header('Content-Type: application/json');

$logFile = __DIR__ . '/../notification_tokens.log';

function logNotificationApi(string $message): void
{
    global $logFile;
    $timestamp = date('Y-m-d H:i:s');
    file_put_contents($logFile, "[{$timestamp}] {$message}\n", FILE_APPEND);
}

try {
    $method = strtoupper($_SERVER['REQUEST_METHOD'] ?? '');
    switch ($method) {
        case 'POST':
            registerNotificationToken($pdo);
            break;
        case 'DELETE':
            deleteNotificationToken($pdo);
            break;
        case 'OPTIONS':
            http_response_code(204);
            break;
        default:
            http_response_code(405);
            echo json_encode(['error' => 'Method not allowed.']);
    }
} catch (Throwable $exception) {
    logNotificationApi('Unhandled exception: ' . $exception->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Unexpected server error.']);
}

function registerNotificationToken(PDO $pdo): void
{
    $token = extractBearerToken();
    if ($token === null) {
        http_response_code(401);
        echo json_encode(['error' => 'Authentication required.']);
        logNotificationApi('POST rejected: missing bearer token.');
        return;
    }

    $user = findUserByToken($pdo, $token);
    if ($user === null) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid login token.']);
        logNotificationApi('POST rejected: invalid token.');
        return;
    }

    $payload = decodeJsonPayload();
    if (!is_array($payload)) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid JSON payload.']);
        logNotificationApi('POST rejected: invalid JSON payload.');
        return;
    }

    $deviceToken = trim((string) ($payload['deviceToken'] ?? ''));
    if ($deviceToken === '') {
        http_response_code(400);
        echo json_encode(['error' => 'deviceToken is required.']);
        logNotificationApi('POST rejected: missing deviceToken.');
        return;
    }

    $metadata = [
        'platform' => $payload['platform'] ?? null,
        'environment' => $payload['environment'] ?? null,
        'appVersion' => $payload['appVersion'] ?? null,
        'osVersion' => $payload['osVersion'] ?? null,
    ];

    $service = new NotificationService($pdo);
    $service->registerDeviceToken($user['email'], $deviceToken, $metadata);

    http_response_code(201);
    echo json_encode(['success' => true]);
    logNotificationApi('POST success: token registered for ' . $user['email']);
}

function deleteNotificationToken(PDO $pdo): void
{
    $token = extractBearerToken();
    if ($token === null) {
        http_response_code(401);
        echo json_encode(['error' => 'Authentication required.']);
        logNotificationApi('DELETE rejected: missing bearer token.');
        return;
    }

    $user = findUserByToken($pdo, $token);
    if ($user === null) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid login token.']);
        logNotificationApi('DELETE rejected: invalid token.');
        return;
    }

    $payload = decodeJsonPayload();
    if (!is_array($payload)) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid JSON payload.']);
        logNotificationApi('DELETE rejected: invalid JSON payload.');
        return;
    }

    $deviceToken = trim((string) ($payload['deviceToken'] ?? ''));
    if ($deviceToken === '') {
        http_response_code(400);
        echo json_encode(['error' => 'deviceToken is required.']);
        logNotificationApi('DELETE rejected: missing deviceToken.');
        return;
    }

    $service = new NotificationService($pdo);
    $service->unregisterDeviceToken($user['email'], $deviceToken);

    http_response_code(200);
    echo json_encode(['success' => true]);
    logNotificationApi('DELETE success: token unregistered for ' . $user['email']);
}
