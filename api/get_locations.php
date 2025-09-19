<?php
require_once __DIR__ . "/../config.php";

$pdo = getPDO();

// ✅ Pull from user_locations instead of users
$stmt = $pdo->prepare("SELECT email, latitude, longitude, recorded_at, updated_at
                       FROM user_locations
                       WHERE latitude IS NOT NULL 
                       AND longitude IS NOT NULL 
                       AND TIMESTAMPDIFF(MINUTE, updated_at, NOW()) < 5
                       ORDER BY updated_at DESC");
$stmt->execute();
$users = $stmt->fetchAll(PDO::FETCH_ASSOC);

header('Content-Type: application/json');
echo json_encode($users);
