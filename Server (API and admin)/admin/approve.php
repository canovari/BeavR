<?php
session_start();
if (!isset($_SESSION['admin']) || $_SESSION['admin'] !== true) {
    header("Location: login.php");
    exit;
}

require_once __DIR__ . '/../config.php';
$pdo = getPDO();

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['id'])) {
    $id = (int)$_POST['id'];

    if ($id > 0) {
        $stmt = $pdo->prepare("UPDATE events SET status = 'approved' WHERE id = :id");
        $stmt->execute([':id' => $id]);
    }
}

header("Location: dashboard.php?tab=live");
exit;
