<?php
session_start();
if (!isset($_SESSION['admin'])) {
    header('Location: login.php');
    exit;
}

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../services/NotificationService.php';

$pdo = getPDO();
$service = new NotificationService($pdo);

$title = '';
$body = '';
$targetEmail = '';
$extraJson = '';
$sendAll = false;
$statusMessage = null;
$errorMessage = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $title = trim($_POST['title'] ?? '');
    $body = trim($_POST['body'] ?? '');
    $targetEmail = strtolower(trim($_POST['target_email'] ?? ''));
    $sendAll = isset($_POST['send_all']);
    $extraJson = trim($_POST['extra'] ?? '');

    if ($title === '' || $body === '') {
        $errorMessage = 'A title and message body are required.';
    } else {
        $extraPayload = [];
        if ($extraJson !== '') {
            $decoded = json_decode($extraJson, true);
            if (!is_array($decoded)) {
                $errorMessage = 'Unable to parse the custom payload. Please provide valid JSON.';
            } else {
                $extraPayload = $decoded;
            }
        }

        if ($errorMessage === null) {
            $targets = [];
            if ($sendAll) {
                $devices = $service->listActiveDevices();
                $targets = array_values(array_unique(array_map(
                    static function (array $device): string {
                        return strtolower((string) ($device['email'] ?? ''));
                    },
                    $devices
                )));
                $targets = array_filter($targets, static fn($email) => $email !== '');
            } else {
                if ($targetEmail === '') {
                    $errorMessage = 'Provide a target email or choose "Send to everyone".';
                } else {
                    $targets = [$targetEmail];
                }
            }

            if ($errorMessage === null && empty($targets)) {
                $errorMessage = 'No target devices were found for the requested action.';
            }

            if ($errorMessage === null) {
                $deliveries = 0;
                foreach ($targets as $email) {
                    $deliveries += $service->sendToEmail(
                        $email,
                        $title,
                        $body,
                        [
                            'threadId' => 'admin-broadcast',
                            'category' => 'ADMIN_BROADCAST',
                            'extra' => array_merge([
                                'type' => 'admin.broadcast',
                                'targetEmail' => $email,
                            ], $extraPayload),
                            'collapseId' => 'admin_' . substr(sha1($title . $body), 0, 24),
                        ]
                    );
                }

                $statusMessage = sprintf(
                    'Notification queued for %d user(s); %d device deliveries attempted.',
                    count($targets),
                    $deliveries
                );
            }
        }
    }
}

$activeDevices = $service->listActiveDevices();
$apnsConfigured = $service->isApnsConfigured();

function shortToken(string $token): string
{
    $clean = preg_replace('/\s+/', '', $token) ?? $token;
    $length = strlen($clean);
    if ($length <= 12) {
        return $clean;
    }
    return substr($clean, 0, 6) . '…' . substr($clean, -6);
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Notification Broadcasts</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f7f7f9; }
        header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; }
        h1 { margin: 0; }
        nav a { margin-right: 15px; text-decoration: none; font-weight: bold; }
        .card { background: #fff; border-radius: 12px; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.08); margin-bottom: 24px; }
        label { display: block; font-weight: 600; margin-top: 12px; }
        input[type="text"], textarea { width: 100%; padding: 10px; border-radius: 8px; border: 1px solid #ccc; font-size: 15px; }
        textarea { min-height: 120px; resize: vertical; }
        .actions { margin-top: 16px; display: flex; gap: 12px; align-items: center; }
        button { background: #c8102e; color: white; border: none; padding: 10px 18px; border-radius: 8px; cursor: pointer; font-size: 15px; }
        button:hover { background: #a80d25; }
        table { width: 100%; border-collapse: collapse; margin-top: 12px; }
        th, td { padding: 10px; border-bottom: 1px solid #e3e3e3; text-align: left; }
        th { background: #fafafa; }
        .status { padding: 12px 16px; border-radius: 8px; margin-bottom: 18px; }
        .status.success { background: #e6f4ea; color: #1e7c36; border: 1px solid #a6d6b5; }
        .status.error { background: #fceaea; color: #c1121f; border: 1px solid #f5b5b5; }
        .badge { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: 12px; background: #eef0f4; margin-left: 6px; }
    </style>
</head>
<body>
    <header>
        <h1>Push Notifications</h1>
        <nav>
            <a href="dashboard.php">&larr; Back to dashboard</a>
            <a href="logout.php">Logout</a>
        </nav>
    </header>

    <section class="card">
        <h2>Send Notification</h2>
        <p>APNs configuration status: <strong><?= $apnsConfigured ? 'Ready' : 'Missing credentials' ?></strong></p>

        <?php if ($statusMessage): ?>
            <div class="status success"><?= htmlspecialchars($statusMessage, ENT_QUOTES, 'UTF-8') ?></div>
        <?php endif; ?>
        <?php if ($errorMessage): ?>
            <div class="status error"><?= htmlspecialchars($errorMessage, ENT_QUOTES, 'UTF-8') ?></div>
        <?php endif; ?>

        <form method="post">
            <label for="title">Title</label>
            <input type="text" id="title" name="title" value="<?= htmlspecialchars($title, ENT_QUOTES, 'UTF-8') ?>" required>

            <label for="body">Message</label>
            <textarea id="body" name="body" required><?= htmlspecialchars($body, ENT_QUOTES, 'UTF-8') ?></textarea>

            <label for="target_email">Target email</label>
            <input type="text" id="target_email" name="target_email" value="<?= htmlspecialchars($targetEmail, ENT_QUOTES, 'UTF-8') ?>" placeholder="student@lse.ac.uk">

            <label for="extra">Optional JSON payload</label>
            <textarea id="extra" name="extra" placeholder='{"url":"https://..."}'><?= htmlspecialchars($extraJson, ENT_QUOTES, 'UTF-8') ?></textarea>

            <div class="actions">
                <label><input type="checkbox" name="send_all" value="1" <?= $sendAll ? 'checked' : '' ?>> Send to everyone with an active device</label>
            </div>

            <button type="submit">Send push notification</button>
        </form>
    </section>

    <section class="card">
        <h2>Active Devices <span class="badge"><?= count($activeDevices) ?></span></h2>
        <?php if (empty($activeDevices)): ?>
            <p>No active devices have registered for notifications yet.</p>
        <?php else: ?>
            <table>
                <tr>
                    <th>Email</th>
                    <th>Token</th>
                    <th>Platform</th>
                    <th>Environment</th>
                    <th>App Version</th>
                    <th>OS Version</th>
                    <th>Last Seen</th>
                </tr>
                <?php foreach ($activeDevices as $device): ?>
                    <tr>
                        <td><?= htmlspecialchars($device['email'] ?? '', ENT_QUOTES, 'UTF-8') ?></td>
                        <td><?= htmlspecialchars(shortToken((string) ($device['device_token'] ?? '')), ENT_QUOTES, 'UTF-8') ?></td>
                        <td><?= htmlspecialchars($device['platform'] ?? 'ios', ENT_QUOTES, 'UTF-8') ?></td>
                        <td><?= htmlspecialchars($device['environment'] ?? 'production', ENT_QUOTES, 'UTF-8') ?></td>
                        <td><?= htmlspecialchars($device['app_version'] ?? '-', ENT_QUOTES, 'UTF-8') ?></td>
                        <td><?= htmlspecialchars($device['os_version'] ?? '-', ENT_QUOTES, 'UTF-8') ?></td>
                        <td><?= htmlspecialchars($device['updated_at'] ?? '-', ENT_QUOTES, 'UTF-8') ?></td>
                    </tr>
                <?php endforeach; ?>
            </table>
        <?php endif; ?>
    </section>
</body>
</html>
