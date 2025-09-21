<?php
declare(strict_types=1);

// 🔹 Force a test log write immediately
file_put_contents(__DIR__ . '/messages_log.txt', "[DEBUG] File write test\n", FILE_APPEND);

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../services/NotificationService.php';
require_once __DIR__ . '/whiteboard_helpers.php';

header('Content-Type: application/json');

// 🔹 Enable logging
ini_set('log_errors', '1');
ini_set('error_log', __DIR__ . '/../messages_error.log');
$logFile = __DIR__ . '/messages_log.txt'; // <-- stay in api/ folder

// 🔹 Log helper
function logMessage(string $msg): void {
    global $logFile;
    $timestamp = date('Y-m-d H:i:s');
    file_put_contents($logFile, "[$timestamp] $msg\n", FILE_APPEND);
}

logMessage("🚀 messages.php started");

$method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
logMessage("Incoming {$method} request → URI: " . ($_SERVER['REQUEST_URI'] ?? ''));

try {
    switch ($method) {
        case 'GET':
            listMessages($pdo);
            break;
        case 'POST':
            createMessage($pdo);
            break;
        case 'OPTIONS':
            http_response_code(204);
            break;
        default:
            http_response_code(405);
            echo json_encode(['error' => 'Method not allowed.']);
            logMessage("❌ Method not allowed: {$method}");
    }
} catch (Throwable $exception) {
    error_log("❌ Server error in messages.php: " . $exception->getMessage());
    logMessage("❌ Exception: " . $exception->getMessage() . " in " . $exception->getFile() . ":" . $exception->getLine());
    http_response_code(500);
    echo json_encode(['error' => 'Unexpected server error.']);
}

/**
 * GET /messages.php?box=received|sent
 */
function listMessages(PDO $pdo): void
{
    $token = extractBearerToken();
    logMessage("🔹 Extracted token (GET): " . ($token ?? 'null'));

    if ($token === null) {
        http_response_code(401);
        echo json_encode(['error' => 'Authentication required.']);
        logMessage("❌ GET failed → no token");
        return;
    }

    $user = findUserByToken($pdo, $token);
    if ($user === null) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid login token.']);
        logMessage("❌ GET failed → invalid token: $token");
        return;
    }

    $box = strtolower((string) ($_GET['box'] ?? 'received'));
    if ($box !== 'sent') {
        $box = 'received';
    }

    logMessage("✅ Listing messages for {$user['email']} in box: {$box}");

    $query = $box === 'sent'
        ? $pdo->prepare('SELECT id, pin_id, sender_email, receiver_email, message, created_at FROM messages WHERE sender_email = :email ORDER BY created_at DESC')
        : $pdo->prepare('SELECT id, pin_id, sender_email, receiver_email, message, created_at FROM messages WHERE receiver_email = :email ORDER BY created_at DESC');

    $query->execute([':email' => $user['email']]);
    $rows = $query->fetchAll() ?: [];

    logMessage("🔹 Found " . count($rows) . " messages");

    $messages = array_map('formatMessageRow', $rows);
    echo json_encode($messages);
}

/**
 * POST /messages.php
 */
function createMessage(PDO $pdo): void
{
    logMessage("📩 createMessage() called");

    $token = extractBearerToken();
    logMessage("🔹 Extracted token (POST): " . ($token ?? 'null'));

    if ($token === null) {
        http_response_code(401);
        echo json_encode(['error' => 'Authentication required.']);
        logMessage("❌ POST failed → no token");
        return;
    }

    $user = findUserByToken($pdo, $token);
    if ($user === null) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid login token.']);
        logMessage("❌ POST failed → invalid token: $token");
        return;
    }
    logMessage("✅ Authenticated user: {$user['email']}");

    $payload = decodeJsonPayload();
    logMessage("🔹 Raw POST payload: " . json_encode($payload));

    if ($payload === null) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid JSON payload.']);
        logMessage("❌ POST failed → invalid JSON payload");
        return;
    }

    if (!isset($payload['pinId']) || !is_numeric($payload['pinId'])) {
        http_response_code(400);
        echo json_encode(['error' => 'pinId is required.']);
        logMessage("❌ POST failed → pinId missing or not numeric");
        return;
    }

    $pinId = (int) $payload['pinId'];
    $messageText = trim((string) ($payload['message'] ?? ''));
    $author = normalizeOptionalString($payload['author'] ?? null);

    logMessage("🔹 Validated payload → pinId={$pinId}, text='{$messageText}', author=" . ($author ?? 'null'));

    $pinQuery = $pdo->prepare('SELECT id, creator_email FROM pins WHERE id = :id LIMIT 1');
    $pinQuery->execute([':id' => $pinId]);
    $pin = $pinQuery->fetch();

    if (!$pin) {
        http_response_code(404);
        echo json_encode(['error' => 'Pin not found.']);
        logMessage("❌ POST failed → pin not found: {$pinId}");
        return;
    }

    $receiverEmail = strtolower((string) $pin['creator_email']);
    $senderEmail = $user['email'];

    logMessage("🔹 Preparing insert for pin {$pinId} from {$senderEmail} to {$receiverEmail}");

    $stored = json_encode([
        'text' => $messageText,
        'author' => $author,
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) ?: $messageText;

    try {
        $insert = $pdo->prepare(
            'INSERT INTO messages (pin_id, sender_email, receiver_email, message)
             VALUES (:pin, :sender, :receiver, :message)'
        );
        $insert->execute([
            ':pin' => $pinId,
            ':sender' => $senderEmail,
            ':receiver' => $receiverEmail,
            ':message' => $stored,
        ]);
    } catch (Throwable $e) {
        logMessage("❌ DB insert failed: " . $e->getMessage());
        http_response_code(500);
        echo json_encode(['error' => 'Database insert failed: ' . $e->getMessage()]);
        return;
    }

    $messageId = (int) $pdo->lastInsertId();
    logMessage("✅ Inserted new message id {$messageId}");

    $select = $pdo->prepare(
        'SELECT id, pin_id, sender_email, receiver_email, message, created_at
         FROM messages
         WHERE id = :id LIMIT 1'
    );
    $select->execute([':id' => $messageId]);
    $row = $select->fetch();

    if (!$row) {
        http_response_code(500);
        echo json_encode(['error' => 'Message could not be retrieved.']);
        logMessage("❌ POST failed → insert succeeded but fetch failed for message {$messageId}");
        return;
    }

    $formattedMessage = formatMessageRow($row);
    logMessage("✅ New message {$messageId} delivered to {$receiverEmail}");

    if (strcasecmp($senderEmail, $receiverEmail) !== 0) {
        try {
            $notificationService = new NotificationService($pdo);
            $notificationService->sendMessageReplyNotification(
                $receiverEmail,
                $senderEmail,
                (int) $row['pin_id'],
                $formattedMessage['message'] ?? '',
                $messageId,
                $formattedMessage['author'] ?? null
            );
        } catch (Throwable $notifyException) {
            logMessage('⚠️ Notification send failed → ' . $notifyException->getMessage());
        }
    } else {
        logMessage('ℹ️ Skipping push because sender and receiver are identical.');
    }

    http_response_code(201);
    echo json_encode([
        'success' => true,
        'message' => $formattedMessage,
    ]);
}

/**
 * Normalize DB row into API JSON
 */
function formatMessageRow(array $row): array
{
    $decoded = [
        'text' => (string) $row['message'],
        'author' => null,
    ];

    $parsed = json_decode((string) $row['message'], true);
    if (json_last_error() === JSON_ERROR_NONE && is_array($parsed)) {
        $decoded['text'] = $parsed['text'] ?? (string) $row['message'];
        $decoded['author'] = $parsed['author'] ?? null;
    }

    return [
        'id' => (int) $row['id'],            // unique message ID
        'pinId' => (int) $row['pin_id'],     // which pin it belongs to
        'senderEmail' => strtolower((string) $row['sender_email']),
        'receiverEmail' => strtolower((string) $row['receiver_email']),
        'message' => $decoded['text'],
        'author' => $decoded['author'],
        'createdAt' => iso8601($row['created_at'] ?? null),
    ];
}
