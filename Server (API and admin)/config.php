<?php
// Central DB config — supports both global $pdo and getPDO()
// ✅ Only loads from config.local.php

function loadPhpConfig(string $path): void
{
    if (!is_file($path) || !is_readable($path)) {
        return;
    }

    $data = include $path;

    if (!is_array($data)) {
        return;
    }

    foreach ($data as $name => $value) {
        if (!is_string($name)) {
            continue;
        }

        $name = trim($name);
        if ($name === '') {
            continue;
        }

        if ($value === null || is_array($value) || is_object($value)) {
            continue;
        }

        $value = trim((string) $value);

        if (!isset($_ENV)) {
            $_ENV = [];
        }
        if (!isset($_SERVER)) {
            $_SERVER = [];
        }

        putenv(sprintf('%s=%s', $name, $value));
        $_ENV[$name] = $value;
        $_SERVER[$name] = $value;
    }
}

$phpConfigPaths = [
    __DIR__ . '/config.local.php',
];

foreach ($phpConfigPaths as $phpConfigPath) {
    loadPhpConfig($phpConfigPath);
}

function readEnv(string $key): ?string {
    $candidates = [
        getenv($key),
        $_ENV[$key] ?? null,
        $_SERVER[$key] ?? null,
    ];

    foreach ($candidates as $candidate) {
        if ($candidate === false || $candidate === null) {
            continue;
        }

        $value = trim((string) $candidate);
        if ($value !== '') {
            return $value;
        }
    }

    return null;
}

function requireEnv(string $key): string {
    $value = readEnv($key);

    if ($value === null) {
        throw new RuntimeException("Missing required environment variable: {$key}");
    }

    return $value;
}

try {
    $host = requireEnv('DB_HOST');
    $db   = requireEnv('DB_NAME');
    $user = requireEnv('DB_USER');
    $pass = requireEnv('DB_PASS');
} catch (RuntimeException $exception) {
    error_log('[config] ' . $exception->getMessage());

    if (PHP_SAPI !== 'cli' && function_exists('http_response_code')) {
        http_response_code(500);
    }

    exit('Server configuration error.');
}

$dsn = "mysql:host={$host};dbname={$db};charset=utf8mb4";

function getPDO(): PDO {
    global $dsn, $user, $pass;
    return new PDO($dsn, $user, $pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
}

// ✅ Define a global $pdo for backwards compatibility
if (!isset($pdo) || !$pdo instanceof PDO) {
    try {
        $pdo = getPDO();
    } catch (PDOException $e) {
        die("DB Connection failed: " . $e->getMessage());
    }
}
