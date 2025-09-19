<?php
declare(strict_types=1);

function decodeJsonPayload(): ?array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || $raw === '') {
        return null;
    }

    $decoded = json_decode($raw, true);
    if (!is_array($decoded)) {
        return null;
    }

    return $decoded;
}

function extractBearerToken(): ?string
{
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';

    if ($header === '' && function_exists('apache_request_headers')) {
        $headers = apache_request_headers();
        if (isset($headers['Authorization'])) {
            $header = $headers['Authorization'];
        }
    }

    if ($header === '') {
        return null;
    }

    if (stripos($header, 'Bearer ') === 0) {
        return trim(substr($header, 7));
    }

    return null;
}

function findUserByToken(PDO $pdo, string $token): ?array
{
    $stmt = $pdo->prepare('SELECT id, email FROM users WHERE login_token = :token LIMIT 1');
    $stmt->execute([':token' => $token]);
    $user = $stmt->fetch();

    if (!$user) {
        return null;
    }

    return [
        'id' => (int) $user['id'],
        'email' => normalizeEmail($user['email'] ?? ''),
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

function normalizeOptionalString(mixed $value): ?string
{
    if ($value === null) {
        return null;
    }

    $string = ensureUtf8String((string) $value);
    $trimmed = trim($string);
    return $trimmed === '' ? null : $trimmed;
}

function normalizeEmail(mixed $value): string
{
    $string = ensureUtf8String((string) $value);
    return strtolower(trim($string));
}

function iso8601(mixed $value): ?string
{
    if ($value === null) {
        return null;
    }

    try {
        $date = new DateTimeImmutable((string) $value);
    } catch (Exception $exception) {
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

        return [
            'text' => $text,
            'author' => $author,
        ];
    }

    $text = trim(ensureUtf8String($stored));

    return [
        'text' => $text,
        'author' => null,
    ];
}
