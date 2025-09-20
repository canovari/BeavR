<?php
require_once __DIR__ . "/../config.php"; // adjust path if needed

$pdo = getPDO();
header("Content-Type: application/json");

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

    // TODO: validate auth token from headers
    $author = $data["author"] ?? null;
    $creatorEmail = strtolower(trim($data["creatorEmail"]));

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

http_response_code(405);
echo json_encode(["error" => "Method not allowed"]);
