<?php
declare(strict_types=1);

require_once __DIR__ . '/../config.php';

header('Content-Type: application/json');

const DEMO_EMAIL = 'demo@lse.ac.uk';

$email = isset($_POST['email']) ? trim((string) $_POST['email']) : '';

if ($email === '') {
    http_response_code(400);
    echo json_encode(['error' => 'Email is required.']);
    exit;
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid email address.']);
    exit;
}

$isDemoAccount = strcasecmp($email, DEMO_EMAIL) === 0;

if ($isDemoAccount) {
    $code = '000000';
} else {
    try {
        $code = (string) random_int(100000, 999999);
    } catch (Throwable $exception) {
        http_response_code(500);
        echo json_encode(['error' => 'Unable to generate verification code.']);
        exit;
    }
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

if (!$isDemoAccount) {
    $subject = 'Your BeavR Login Code';
    $message = sprintf("Your login code is: %s (valid for 5 minutes).", $code);
    $headers = "From: BeavR <noreply@beavr.net>\r\n";

    $mailSent = mail($email, $subject, $message, $headers);

    if (!$mailSent) {
        http_response_code(500);
        echo json_encode(['error' => 'Failed to send verification email.']);
        exit;
    }
}

echo json_encode(['success' => true]);