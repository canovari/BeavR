<?php
declare(strict_types=1);

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/whiteboard_helpers.php';

header('Content-Type: application/json; charset=utf-8');

const PIN_EXPIRATION_HOURS = 8;

$method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');

try {
    switch ($method) {
        case 'GET':
            listPins($pdo);
            break;
        case 'POST':
            createPin($pdo);
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

function listPins(PDO $pdo): void
{
    $sql = sprintf(
        'SELECT id, emoji, text, author, creator_email, grid_row, grid_col, created_at
         FROM pins
         WHERE grid_row BETWEEN 0 AND 7
           AND grid_col BETWEEN 0 AND 4
           AND %s
         ORDER BY created_at DESC',
        pinExpirationClause()
    );

    $query = $pdo->query($sql);

    $rows = $query->fetchAll() ?: [];
    $pins = array_map('formatPinRow', $rows);

    $encoded = json_encode($pins, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    echo $encoded === false ? '[]' : $encoded;
}

function createPin(PDO $pdo): void
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

    $emoji = trim(ensureUtf8String((string) ($payload['emoji'] ?? '')));
    $text = trim(ensureUtf8String((string) ($payload['text'] ?? '')));
    $author = isset($payload['author']) ? normalizeOptionalString($payload['author']) : null;
    $gridRow = isset($payload['gridRow']) ? (int) $payload['gridRow'] : null;
    $gridCol = isset($payload['gridCol']) ? (int) $payload['gridCol'] : null;

    if ($emoji === '' || $text === '' || $gridRow === null || $gridCol === null) {
        http_response_code(400);
        echo json_encode(['error' => 'Emoji, text, row, and column are required.']);
        return;
    }

    if (!is_numeric($payload['gridRow']) || !is_numeric($payload['gridCol'])) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid grid coordinates.']);
        return;
    }

    if ($gridRow < 0 || $gridRow > 7 || $gridCol < 0 || $gridCol > 4) {
        http_response_code(400);
        echo json_encode(['error' => 'Grid location is out of range.']);
        return;
    }

    if (mb_strlen($emoji) > 10) {
        http_response_code(400);
        echo json_encode(['error' => 'Emoji must be at most 10 characters.']);
        return;
    }

    $slotSql = sprintf(
        'SELECT id FROM pins WHERE grid_row = :row AND grid_col = :col AND %s LIMIT 1',
        pinExpirationClause()
    );
    $slotCheck = $pdo->prepare($slotSql);
    $slotCheck->execute([
        ':row' => $gridRow,
        ':col' => $gridCol,
    ]);

    if ($slotCheck->fetch()) {
        http_response_code(409);
        echo json_encode(['error' => 'That slot already has a pin.']);
        return;
    }

    $insert = $pdo->prepare(
        'INSERT INTO pins (emoji, text, author, creator_email, grid_row, grid_col)
         VALUES (:emoji, :text, :author, :creator, :row, :col)'
    );

    $insert->execute([
        ':emoji' => $emoji,
        ':text' => $text,
        ':author' => $author,
        ':creator' => normalizeEmail($user['email'] ?? ''),
        ':row' => $gridRow,
        ':col' => $gridCol,
    ]);

    $pinId = (int) $pdo->lastInsertId();
    $select = $pdo->prepare(
        'SELECT id, emoji, text, author, creator_email, grid_row, grid_col, created_at
         FROM pins
         WHERE id = :id
         LIMIT 1'
    );
    $select->execute([':id' => $pinId]);

    $pin = $select->fetch();
    if (!$pin) {
        http_response_code(500);
        echo json_encode(['error' => 'Pin could not be retrieved.']);
        return;
    }

    http_response_code(201);
    echo json_encode(formatPinRow($pin), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
}

function formatPinRow(array $row): array
{
    return [
        'id' => (int) $row['id'],
        'emoji' => ensureUtf8String((string) $row['emoji']),
        'text' => ensureUtf8String((string) $row['text']),
        'author' => normalizeOptionalString($row['author'] ?? null),
        'creatorEmail' => normalizeEmail($row['creator_email'] ?? ''),
        'gridRow' => (int) $row['grid_row'],
        'gridCol' => (int) $row['grid_col'],
        'createdAt' => iso8601($row['created_at'] ?? null),
    ];
}

function pinExpirationClause(): string
{
    return sprintf('created_at >= (UTC_TIMESTAMP() - INTERVAL %d HOUR)', (int) PIN_EXPIRATION_HOURS);
}

