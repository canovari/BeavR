<?php
declare(strict_types=1);

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/auth_helpers.php';

header('Content-Type: application/json');

const DEMO_EMAIL = 'demo@lse.ac.uk';

$email = isset($_POST['email']) ? trim((string) $_POST['email']) : '';
$code = isset($_POST['code']) ? trim((string) $_POST['code']) : '';

if ($email === '' || $code === '') {
    http_response_code(400);
    echo json_encode(['error' => 'Email and code are required.']);
    exit;
}

if (!preg_match('/^[0-9]{6}$/', $code)) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid verification code.']);
    exit;
}

$isDemoAccount = strcasecmp($email, DEMO_EMAIL) === 0;

$existingStatus = null;
try {
    $lookup = $pdo->prepare('SELECT status FROM users WHERE email = :email LIMIT 1');
    $lookup->execute([':email' => $email]);
    $existing = $lookup->fetch();
    if ($existing) {
        $existingStatus = normalizeUserStatus($existing['status'] ?? null);
    }
} catch (PDOException $exception) {
    http_response_code(500);
    echo json_encode(['error' => 'Unable to verify code.']);
    exit;
}

if ($existingStatus === USER_STATUS_BANNED) {
    http_response_code(403);
    echo json_encode(['error' => ACCOUNT_SUSPENDED_MESSAGE]);
    exit;
}

if ($isDemoAccount) {
    if ($code !== '000000') {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid or expired code.']);
        exit;
    }

    try {
        $token = bin2hex(random_bytes(32));
    } catch (Throwable $exception) {
        http_response_code(500);
        echo json_encode(['error' => 'Unable to generate login token.']);
        exit;
    }

    try {
        $upsert = $pdo->prepare(
            'INSERT INTO users (email, verified, code, code_expires_at, login_token)
             VALUES (:email, 1, NULL, NULL, :token)
             ON DUPLICATE KEY UPDATE
                verified = VALUES(verified),
                code = VALUES(code),
                code_expires_at = VALUES(code_expires_at),
                login_token = VALUES(login_token)'
        );
        $upsert->execute([
            ':email' => $email,
            ':token' => $token,
        ]);
    } catch (PDOException $exception) {
        http_response_code(500);
        echo json_encode(['error' => 'Failed to finalize verification.']);
        exit;
    }

    echo json_encode(['success' => true, 'token' => $token]);
    exit;
}

try {
    $stmt = $pdo->prepare('SELECT id, code_expires_at, status FROM users WHERE email = :email AND code = :code LIMIT 1');
    $stmt->execute([
        ':email' => $email,
        ':code' => $code,
    ]);
    $user = $stmt->fetch();
} catch (PDOException $exception) {
    http_response_code(500);
    echo json_encode(['error' => 'Unable to verify code.']);
    exit;
}

if (!$user) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid or expired code.']);
    exit;
}

$status = normalizeUserStatus($user['status'] ?? $existingStatus);
if ($status === USER_STATUS_BANNED) {
    http_response_code(403);
    echo json_encode(['error' => ACCOUNT_SUSPENDED_MESSAGE]);
    exit;
}

$expiresAt = $user['code_expires_at'];
if ($expiresAt === null || strtotime($expiresAt) < time()) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid or expired code.']);
    exit;
}

try {
    $token = bin2hex(random_bytes(32));
} catch (Throwable $exception) {
    http_response_code(500);
    echo json_encode(['error' => 'Unable to generate login token.']);
    exit;
}

try {
    $update = $pdo->prepare(
        'UPDATE users
         SET verified = 1,
             code = NULL,
             code_expires_at = NULL,
             login_token = :token
         WHERE id = :id'
    );
    $update->execute([
        ':token' => $token,
        ':id' => $user['id'],
    ]);
} catch (PDOException $exception) {
    http_response_code(500);
    echo json_encode(['error' => 'Failed to finalize verification.']);
    exit;
}

echo json_encode(['success' => true, 'token' => $token]);