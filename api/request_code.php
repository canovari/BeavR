<?php
declare(strict_types=1);

require_once __DIR__ . '/../config.php';

header('Content-Type: application/json');

$email = isset($_POST['email']) ? trim((string) $_POST['email']) : '';

if ($email === '') {
    http_response_code(400);
    echo json_encode(['error' => 'Email is required.']);
    exit;
}

if (!preg_match('/^[A-Za-z0-9._%+-]+@lse\.ac\.uk$/', $email)) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid email domain.']);
    exit;
}

try {
    $code = (string) random_int(100000, 999999);
} catch (Throwable $exception) {
    http_response_code(500);
    echo json_encode(['error' => 'Unable to generate verification code.']);
    exit;
}

$expiry = (new DateTimeImmutable('+5 minutes'))->format('Y-m-d H:i:s');

try {
    $stmt = $pdo->prepare(
        'INSERT INTO users (email, code, code_expires_at, verified)
         VALUES (:email, :code, :expires_at, 0)
         ON DUPLICATE KEY UPDATE
            code = VALUES(code),
            code_expires_at = VALUES(code_expires_at),
            verified = 0'
    );
    $stmt->execute([
        ':email' => $email,
        ':code' => $code,
        ':expires_at' => $expiry,
    ]);
} catch (PDOException $exception) {
    http_response_code(500);
    echo json_encode(['error' => 'Unable to persist verification code.']);
    exit;
}

$subject = 'Your LSE Events Login Code';
$message = sprintf("Your login code is: %s (valid for 5 minutes).", $code);
$headers = "From: LSE Events <noreply@canovari.com>\r\n";

$mailSent = mail($email, $subject, $message, $headers);

if (!$mailSent) {
    http_response_code(500);
    echo json_encode(['error' => 'Failed to send verification email.']);
    exit;
}

echo json_encode(['success' => true]);
