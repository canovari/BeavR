<?php
session_start();
if (!isset($_SESSION['admin']) || $_SESSION['admin'] !== true) {
    header("Location: login.php");
    exit;
}

require_once __DIR__ . '/../config.php';
$pdo = getPDO();

$id = $_POST['id'] ?? null;

if ($id) {
    $stmt = $pdo->prepare("UPDATE events SET status = 'approved' WHERE id = :id");
    $stmt->execute([':id' => $id]);
}

header("Location: dashboard.php?tab=pending");
exit;
