<?php
declare(strict_types=1);

$logFile = __DIR__ . '/../messages_log.txt';

require_once __DIR__ . '/auth_helpers.php';

/**
 * Debug log helper (safe to call everywhere)
 */
function helperLog(string $msg): void {
    global $logFile;
    $timestamp = date('Y-m-d H:i:s');
    file_put_contents($logFile, "[$timestamp] [helpers] $msg\n", FILE_APPEND);
}

function decodeJsonPayload(): ?array
{
    $raw = file_get_contents('php://input');
    helperLog("decodeJsonPayload raw=" . ($raw === '' ? 'EMPTY' : $raw));

    if ($raw === false || $raw === '') {
        return null;
    }

    $decoded = json_decode($raw, true);
    if (!is_array($decoded)) {
        helperLog("decodeJsonPayload failed → json_last_error=" . json_last_error_msg());
        return null;
    }

    helperLog("decodeJsonPayload success → " . json_encode($decoded));
    return $decoded;
}

function extractBearerToken(): ?string
{
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';

    // Try apache_request_headers() if nothing found
    if ($header === '' && function_exists('apache_request_headers')) {
        $headers = apache_request_headers();
        helperLog("extractBearerToken apache_request_headers=" . json_encode($headers));
        if (isset($headers['Authorization'])) {
            $header = $headers['Authorization'];
        }
    }

    if ($header === '') {
        helperLog("extractBearerToken → no header found");
        return null;
    }

    helperLog("extractBearerToken raw header='{$header}'");

    if (stripos($header, 'Bearer ') === 0) {
        $token = trim(substr($header, 7));
        helperLog("extractBearerToken found token='{$token}'");
        return $token;
    }

    helperLog("extractBearerToken header present but not Bearer");
    return null;
}

function findUserByToken(PDO $pdo, string $token): ?array
{
    helperLog("findUserByToken searching for token='{$token}'");
    $stmt = $pdo->prepare('SELECT id, email, status FROM users WHERE login_token = :token LIMIT 1');
    $stmt->execute([':token' => $token]);
    $user = $stmt->fetch();

    if (!$user) {
        helperLog("findUserByToken failed → no user for token");
        return null;
    }

    $normalizedEmail = normalizeEmail($user['email'] ?? null);
    $status = normalizeUserStatus($user['status'] ?? null);
    helperLog("findUserByToken success → id={$user['id']} email={$normalizedEmail} status={$status}");

    return [
        'id' => (int) $user['id'],
        'email' => $normalizedEmail,
        'status' => $status,
    ];
}

function ensureUtf8String(?string $value): string
{
    if ($value === null || $value === '') {
        return '';
    }

    $string = (string) $value;

    if (function_exists('mb_detect_encoding')) {
        $detected = @mb_detect_encoding($string, 'UTF-8', true);
        if ($detected === 'UTF-8') {
            return $string;
        }
    }

    if (function_exists('mb_convert_encoding')) {
        $converted = @mb_convert_encoding($string, 'UTF-8', 'UTF-8, ISO-8859-1, Windows-1252');
        if ($converted !== false) {
            return $converted;
        }
    }

    if (function_exists('iconv')) {
        $iconv = @iconv('ISO-8859-1', 'UTF-8//IGNORE', $string);
        if ($iconv !== false) {
            return $iconv;
        }
    }

    $fallback = @utf8_encode($string);
    if ($fallback !== false) {
        return $fallback;
    }

    return preg_replace('/[\x80-\xFF]/', '', $string) ?? $string;
}

function normalizeOptionalString(?string $value): ?string
{
    if ($value === null) {
        return null;
    }

    $string = ensureUtf8String($value);
    $trimmed = trim($string);
    return $trimmed === '' ? null : $trimmed;
}

function normalizeEmail(?string $value): string
{
    if ($value === null) {
        return '';
    }

    $string = ensureUtf8String($value);
    return strtolower(trim($string));
}

function iso8601($value): ?string
{
    if ($value === null) {
        return null;
    }

    try {
        $date = new DateTimeImmutable((string) $value);
    } catch (Exception $exception) {
        helperLog("iso8601 failed → " . $exception->getMessage());
        return null;
    }

    return $date->setTimezone(new DateTimeZone('UTC'))->format(DateTimeInterface::ATOM);
}

function decodeMessagePayload(string $stored): array
{
    $decoded = json_decode($stored, true);
    if (is_array($decoded) && isset($decoded['text'])) {
        $text = trim(ensureUtf8String((string) ($decoded['text'] ?? '')));
        $author = normalizeOptionalString($decoded['author'] ?? null);

        helperLog("decodeMessagePayload JSON success → text='{$text}' author=" . ($author ?? 'null'));

        return [
            'text' => $text,
            'author' => $author,
        ];
    }

    $text = trim(ensureUtf8String($stored));
    helperLog("decodeMessagePayload fallback → '{$text}'");

    return [
        'text' => $text,
        'author' => null,
    ];
}
