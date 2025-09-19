<?php
// Central DB config — supports both global $pdo and getPDO()

$host = "sql.canovari.com";
$db   = "canovari46540";
$user = "canovari46540";
$pass = "cano99880";

$dsn = "mysql:host=$host;dbname=$db;charset=utf8mb4";

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
