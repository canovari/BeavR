<?php
declare(strict_types=1);

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/whiteboard_helpers.php';

header('Content-Type: application/json');

$method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');

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
    }
} catch (Throwable $exception) {
    http_response_code(500);
    echo json_encode(['error' => 'Unexpected server error.']);
}

function listMessages(PDO $pdo): void
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

    $box = strtolower((string) ($_GET['box'] ?? 'received'));
    if ($box !== 'sent') {
        $box = 'received';
    }

    if ($box === 'sent') {
        $query = $pdo->prepare(
            'SELECT id, sender_email, receiver_email, message, created_at
             FROM messages
             WHERE sender_email = :email
             ORDER BY created_at DESC'
        );
    } else {
        $query = $pdo->prepare(
            'SELECT id, sender_email, receiver_email, message, created_at
             FROM messages
             WHERE receiver_email = :email
             ORDER BY created_at DESC'
        );
    }

    $query->execute([':email' => $user['email']]);
    $rows = $query->fetchAll() ?: [];

    $messages = array_map('formatMessageRow', $rows);
    echo json_encode($messages);
}

function createMessage(PDO $pdo): void
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

    if (!isset($payload['pinId']) || !is_numeric($payload['pinId'])) {
        http_response_code(400);
        echo json_encode(['error' => 'pinId is required.']);
        return;
    }

    $pinId = (int) $payload['pinId'];
    if ($pinId <= 0) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid pin id.']);
        return;
    }

    $messageText = trim((string) ($payload['message'] ?? ''));
    if ($messageText === '') {
        http_response_code(400);
        echo json_encode(['error' => 'Message text is required.']);
        return;
    }

    $author = normalizeOptionalString($payload['author'] ?? null);

    $pinQuery = $pdo->prepare('SELECT id, creator_email FROM pins WHERE id = :id LIMIT 1');
    $pinQuery->execute([':id' => $pinId]);
    $pin = $pinQuery->fetch();

    if (!$pin) {
        http_response_code(404);
        echo json_encode(['error' => 'Pin not found.']);
        return;
    }

    $receiverEmail = strtolower((string) $pin['creator_email']);
    $senderEmail = $user['email'];

    $stored = json_encode([
        'text' => $messageText,
        'author' => $author,
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

    if ($stored === false) {
        $stored = $messageText;
    }

    $insert = $pdo->prepare(
        'INSERT INTO messages (sender_email, receiver_email, message)
         VALUES (:sender, :receiver, :message)'
    );

    $insert->execute([
        ':sender' => $senderEmail,
        ':receiver' => $receiverEmail,
        ':message' => $stored,
    ]);

    $messageId = (int) $pdo->lastInsertId();
    $select = $pdo->prepare(
        'SELECT id, sender_email, receiver_email, message, created_at
         FROM messages
         WHERE id = :id
         LIMIT 1'
    );
    $select->execute([':id' => $messageId]);

    $row = $select->fetch();
    if (!$row) {
        http_response_code(500);
        echo json_encode(['error' => 'Message could not be retrieved.']);
        return;
    }

    http_response_code(201);
    echo json_encode([
        'success' => true,
        'message' => formatMessageRow($row),
    ]);
}

function formatMessageRow(array $row): array
{
    $decoded = decodeMessagePayload((string) $row['message']);

    return [
        'id' => (int) $row['id'],
        'senderEmail' => strtolower((string) $row['sender_email']),
        'receiverEmail' => strtolower((string) $row['receiver_email']),
        'message' => $decoded['text'],
        'author' => $decoded['author'],
        'createdAt' => iso8601($row['created_at'] ?? null),
    ];
}
