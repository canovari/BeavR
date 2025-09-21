<?php
session_start();
if (!isset($_SESSION['admin'])) {
    header("Location: login.php");
    exit;
}

require_once __DIR__ . '/../config.php';
$pdo = getPDO();

$id = $_GET['id'] ?? null;
if (!$id) {
    die('No deal ID provided.');
}

$stmt = $pdo->prepare('SELECT * FROM deals WHERE id = ?');
$stmt->execute([$id]);
$deal = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$deal) {
    die('Deal not found.');
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Deal Details</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; line-height: 1.6; }
        .label { font-weight: bold; }
        a { color: blue; text-decoration: none; }
        a:hover { text-decoration: underline; }
        .container { max-width: 640px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Deal Details</h1>

        <p><span class="label">Name:</span> <?= htmlspecialchars($deal['name']) ?></p>
        <p><span class="label">Type:</span> <?= htmlspecialchars(ucfirst($deal['type'])) ?></p>
        <p><span class="label">Discount:</span> <?= htmlspecialchars($deal['discount']) ?></p>
        <p><span class="label">Description:</span><br><?= nl2br(htmlspecialchars($deal['description'] ?? '')) ?></p>
        <p><span class="label">Location:</span> <?= htmlspecialchars($deal['location'] ?? 'Not provided') ?></p>
        <p><span class="label">Valid From:</span> <?= htmlspecialchars($deal['start_date']) ?></p>
        <p><span class="label">Valid To:</span> <?= htmlspecialchars($deal['end_date'] ?? 'No end date') ?></p>
        <p><span class="label">Status:</span> <?= htmlspecialchars($deal['status']) ?></p>
        <p><span class="label">Submitted By:</span> <?= htmlspecialchars($deal['creator'] ?? 'Unknown') ?></p>
        <p><span class="label">Created:</span> <?= htmlspecialchars($deal['created_at'] ?? '') ?></p>
        <p><span class="label">Updated:</span> <?= htmlspecialchars($deal['updated_at'] ?? '') ?></p>

        <p><a href="dashboard.php?tab=deals_pending">← Back to Deals</a></p>
    </div>
</body>
</html>
