<?php
require_once __DIR__ . "/../config.php"; // adjust path if needed
require_once __DIR__ . '/auth_helpers.php';

const PIN_LIFETIME_SECONDS = 8 * 60 * 60;

function pruneExpiredPins(PDO $pdo, int $lifetimeSeconds): void
{
    $lifetimeSeconds = max(0, $lifetimeSeconds);
    if ($lifetimeSeconds === 0) {
        return;
    }

    $cleanupQuery = sprintf(
        "DELETE FROM pins WHERE created_at <= (NOW() - INTERVAL %d SECOND)",
        $lifetimeSeconds
    );

    $pdo->exec($cleanupQuery);
}

$pdo = getPDO();
header("Content-Type: application/json");

pruneExpiredPins($pdo, PIN_LIFETIME_SECONDS);

$method = $_SERVER["REQUEST_METHOD"];

if ($method === "GET") {
    // Fetch pins from DB
    $stmt = $pdo->query("SELECT * FROM pins ORDER BY created_at DESC");
    $pins = [];

    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $pins[] = [
            "id" => (int)$row["id"],
            "emoji" => $row["emoji"],
            "text" => $row["text"],
            "author" => $row["author"],
            "creatorEmail" => $row["creator_email"],
            "gridRow" => (int)$row["grid_row"],
            "gridCol" => (int)$row["grid_col"],
            "createdAt" => $row["created_at"] // MySQL timestamp string
        ];
    }

    echo json_encode($pins);
    exit;
}

if ($method === "POST") {
    $data = json_decode(file_get_contents("php://input"), true);

    if (
        !$data ||
        empty($data["emoji"]) ||
        empty($data["text"]) ||
        !isset($data["gridRow"]) ||
        !isset($data["gridCol"]) ||
        empty($data["creatorEmail"])
    ) {
        http_response_code(400);
        echo json_encode(["error" => "Missing required fields"]);
        exit;
    }

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

    if (userIsMuted($user)) {
        http_response_code(403);
        echo json_encode(['error' => 'Your account is muted and cannot add pins.']);
        exit;
    }

    $author = $data["author"] ?? null;
    $creatorEmail = $user['email'];

    $stmt = $pdo->prepare("
        INSERT INTO pins (emoji, text, author, creator_email, grid_row, grid_col)
        VALUES (?, ?, ?, ?, ?, ?)
    ");

    $stmt->execute([
        $data["emoji"],
        $data["text"],
        $author,
        $creatorEmail,
        $data["gridRow"],
        $data["gridCol"]
    ]);

    $id = $pdo->lastInsertId();

    $newPin = [
        "id" => (int)$id,
        "emoji" => $data["emoji"],
        "text" => $data["text"],
        "author" => $author,
        "creatorEmail" => $creatorEmail,
        "gridRow" => (int)$data["gridRow"],
        "gridCol" => (int)$data["gridCol"],
        "createdAt" => date("c") // ISO-8601 string
    ];

    echo json_encode($newPin);
    exit;
}

if ($method === "DELETE") {
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

    $payload = json_decode(file_get_contents('php://input'), true);

    if (!$payload || !isset($payload['id'])) {
        http_response_code(400);
        echo json_encode(['error' => 'Missing pin id.']);
        exit;
    }

    $pinId = (int) $payload['id'];
    if ($pinId <= 0) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid pin id.']);
        exit;
    }

    $stmt = $pdo->prepare('SELECT creator_email FROM pins WHERE id = :id LIMIT 1');
    $stmt->execute([':id' => $pinId]);
    $pin = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$pin) {
        http_response_code(404);
        echo json_encode(['error' => 'Pin not found.']);
        exit;
    }

    $creatorEmail = strtolower(trim((string) $pin['creator_email']));
    $requesterEmail = strtolower(trim((string) $user['email']));

    if ($creatorEmail === '' || $creatorEmail !== $requesterEmail) {
        http_response_code(403);
        echo json_encode(['error' => 'You can only delete pins you created.']);
        exit;
    }

    $deleteStmt = $pdo->prepare('DELETE FROM pins WHERE id = :id LIMIT 1');
    $deleteStmt->execute([':id' => $pinId]);

    echo json_encode(['success' => true]);
    exit;
}

http_response_code(405);
echo json_encode(["error" => "Method not allowed"]);

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
