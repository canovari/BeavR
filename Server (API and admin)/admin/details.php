<?php
session_start();
if (!isset($_SESSION["admin"])) {
    header("Location: login.php");
    exit;
}

require_once __DIR__ . "/../config.php";
$pdo = getPDO();

$id = $_GET["id"] ?? null;
if (!$id) {
    die("No event ID provided.");
}

$stmt = $pdo->prepare("SELECT * FROM events WHERE id = ?");
$stmt->execute([$id]);
$event = $stmt->fetch();

if (!$event) {
    die("Event not found.");
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Event Details</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; line-height: 1.6; }
        .label { font-weight: bold; }
        a { color: blue; text-decoration: none; }
        a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <h1>Event Details</h1>

    <p><span class="label">Title:</span> <?= htmlspecialchars($event['title']) ?></p>
    <p><span class="label">Description:</span> <?= nl2br(htmlspecialchars($event['description'] ?? '')) ?></p>
    <p><span class="label">Start:</span> <?= htmlspecialchars($event['start_time']) ?></p>
    <p><span class="label">End:</span> <?= htmlspecialchars($event['end_time'] ?? '') ?></p>
    <p><span class="label">Location:</span> 
        <?= htmlspecialchars($event['location'] ?? '') ?>
        <?php if (!empty($event['latitude']) && !empty($event['longitude'])): ?>
            (<a href="https://maps.google.com/?q=<?= $event['latitude'] ?>,<?= $event['longitude'] ?>" target="_blank">View on Map</a>)
        <?php endif; ?>
    </p>
    <p><span class="label">Organization:</span> <?= htmlspecialchars($event['organization'] ?? '') ?></p>
    <p><span class="label">Category:</span> <?= htmlspecialchars($event['category'] ?? '') ?></p>
    <p><span class="label">Contact:</span>
        <?php if (!empty($event['contact_type']) && !empty($event['contact_value'])): ?>
            <?= htmlspecialchars($event['contact_type']) ?> → <?= htmlspecialchars($event['contact_value']) ?>
        <?php else: ?>
            Not provided
        <?php endif; ?>
    </p>
    <p><span class="label">Status:</span> <?= htmlspecialchars($event['status']) ?></p>
    <p><a href="dashboard.php?tab=pending">← Back to Dashboard</a></p>
</body>
</html>
