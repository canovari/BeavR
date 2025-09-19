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
        'email' => strtolower((string) $user['email']),
    ];
}

function normalizeOptionalString(mixed $value): ?string
{
    if ($value === null) {
        return null;
    }

    $trimmed = trim((string) $value);
    return $trimmed === '' ? null : $trimmed;
}

function isSingleEmoji(string $value): bool
{
    $value = trim($value);

    if ($value === '') {
        return false;
    }

    if (preg_match('/^\X$/u', $value) !== 1) {
        return false;
    }

    return preg_match('/[\p{Extended_Pictographic}\p{RI}]/u', $value) === 1;
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
        $text = trim((string) ($decoded['text'] ?? ''));
        $author = normalizeOptionalString($decoded['author'] ?? null);

        return [
            'text' => $text,
            'author' => $author,
        ];
    }

    return [
        'text' => trim($stored),
        'author' => null,
    ];
}
