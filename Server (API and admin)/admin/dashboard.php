<?php
session_start();
if (!isset($_SESSION["admin"])) {
    header("Location: login.php");
    exit;
}

require_once __DIR__ . "/../config.php";
$pdo = getPDO();

// Get selected tab (pending / live / old / map / users)
$tab = $_GET["tab"] ?? "pending";

switch ($tab) {
    case "live":
        $stmt = $pdo->prepare("SELECT * FROM events WHERE status = 'approved' AND end_time >= NOW() ORDER BY start_time ASC");
        $stmt->execute();
        $events = $stmt->fetchAll();
        break;

    case "old":
        $stmt = $pdo->prepare("SELECT * FROM events WHERE status = 'approved' AND end_time < NOW() ORDER BY start_time DESC");
        $stmt->execute();
        $events = $stmt->fetchAll();
        break;

    case "map":
        $events = [];
        break;

    case "users":
        // ✅ Now pulling from user_locations instead of users
        $stmt = $pdo->prepare("SELECT email, latitude, longitude, recorded_at, updated_at
                               FROM user_locations
                               WHERE TIMESTAMPDIFF(SECOND, updated_at, NOW()) <= 60
                               ORDER BY updated_at DESC");
        $stmt->execute();
        $liveUsers = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $events = [];
        break;

    default:
        $stmt = $pdo->prepare("SELECT * FROM events WHERE status = 'pending' ORDER BY start_time ASC");
        $stmt->execute();
        $events = $stmt->fetchAll();
        break;
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Admin Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        nav a { margin-right: 15px; text-decoration: none; font-weight: bold; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ccc; padding: 8px; text-align: left; }
        th { background: #f4f4f4; }
        .approve-btn { background: green; color: white; border: none; padding: 6px 12px; cursor: pointer; }
        .revert-btn { background: orange; color: white; border: none; padding: 6px 12px; cursor: pointer; }
        .details-btn { background: blue; color: white; border: none; padding: 6px 12px; cursor: pointer; text-decoration: none; }
        #map { height: 600px; margin-top: 20px; }
    </style>
    <?php if ($tab === "map"): ?>
        <link rel="stylesheet" href="https://unpkg.com/leaflet/dist/leaflet.css"/>
        <script src="https://unpkg.com/leaflet/dist/leaflet.js"></script>
    <?php endif; ?>
</head>
<body>
    <h1>Admin Dashboard</h1>

    <nav>
        <a href="?tab=pending" <?= $tab === "pending" ? "style='color:red'" : "" ?>>Pending</a>
        <a href="?tab=live" <?= $tab === "live" ? "style='color:red'" : "" ?>>Live</a>
        <a href="?tab=old" <?= $tab === "old" ? "style='color:red'" : "" ?>>Old</a>
        <a href="?tab=map" <?= $tab === "map" ? "style='color:red'" : "" ?>>Live Users Map</a>
        <a href="?tab=users" <?= $tab === "users" ? "style='color:red'" : "" ?>>Live Users</a>
        <a href="logout.php" style="float:right">Logout</a>
    </nav>

    <?php if ($tab === "map"): ?>
        <div id="map"></div>
        <script>
            let map = L.map('map').setView([51.5074, -0.1278], 13); // Default London
            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                maxZoom: 19,
            }).addTo(map);

            async function fetchLocations() {
                const res = await fetch('get_locations.php');
                const users = await res.json();

                users.forEach(user => {
                    if (user.latitude && user.longitude) {
                        L.marker([user.latitude, user.longitude])
                          .addTo(map)
                          .bindPopup(`<b>Email:</b> ${user.email}<br><b>Last Update:</b> ${user.updated_at}`);
                    }
                });
            }
            fetchLocations();
            setInterval(fetchLocations, 30000);
        </script>

    <?php elseif ($tab === "users"): ?>
        <h2>Live Users (last 1 min)</h2>
        <table>
            <tr>
                <th>Email</th>
                <th>Latitude</th>
                <th>Longitude</th>
                <th>Recorded At</th>
                <th>Updated At</th>
            </tr>
            <?php if (!empty($liveUsers)): ?>
                <?php foreach ($liveUsers as $u): ?>
                    <tr>
                        <td><?= htmlspecialchars($u['email']) ?></td>
                        <td><?= htmlspecialchars($u['latitude']) ?></td>
                        <td><?= htmlspecialchars($u['longitude']) ?></td>
                        <td><?= htmlspecialchars($u['recorded_at']) ?></td>
                        <td><?= htmlspecialchars($u['updated_at']) ?></td>
                    </tr>
                <?php endforeach; ?>
            <?php else: ?>
                <tr><td colspan="5">No users active in the last minute.</td></tr>
            <?php endif; ?>
        </table>

    <?php else: ?>
        <table>
            <tr>
                <th>ID</th>
                <th>Title</th>
                <th>Start</th>
                <th>End</th>
                <th>Status</th>
                <th>Actions</th>
            </tr>
            <?php foreach ($events as $e): ?>
                <tr>
                    <td><?= htmlspecialchars($e['id']) ?></td>
                    <td><?= htmlspecialchars($e['title']) ?></td>
                    <td><?= htmlspecialchars($e['start_time']) ?></td>
                    <td><?= htmlspecialchars($e['end_time'] ?? '') ?></td>
                    <td><?= htmlspecialchars($e['status']) ?></td>
                    <td>
                        <a class="details-btn" href="details.php?id=<?= $e['id'] ?>">Details</a>
                        <?php if ($tab === "pending"): ?>
                            <form action="approve.php" method="post" style="display:inline">
                                <input type="hidden" name="id" value="<?= $e['id'] ?>">
                                <button type="submit" class="approve-btn">Approve</button>
                            </form>
                        <?php elseif ($tab === "live"): ?>
                            <form action="revert.php" method="post" style="display:inline">
                                <input type="hidden" name="id" value="<?= $e['id'] ?>">
                                <button type="submit" class="revert-btn">Revert</button>
                            </form>
                        <?php endif; ?>
                    </td>
                </tr>
            <?php endforeach; ?>
        </table>
    <?php endif; ?>
</body>
</html>
