<?php
declare(strict_types=1);

// Shared database connection for API endpoints.
// Configure these credentials via environment variables on the server.
$host = getenv('DB_HOST');
$dbName = getenv('DB_NAME');
$user = getenv('DB_USER');
$password = getenv('DB_PASS');

if ($host === false || $dbName === false || $user === false || $password === false) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Database environment variables are not configured.']);
    exit;
}

$dsn = sprintf('mysql:host=%s;dbname=%s;charset=utf8mb4', $host, $dbName);

$options = [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES => false,
];

try {
    $pdo = new PDO($dsn, $user, $password, $options);
} catch (PDOException $exception) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Database connection failed.']);
    exit;
}
