<?php
declare(strict_types=1);

/**
 * Lightweight APNs notification helper used by both the API layer and the admin dashboard.
 */
final class NotificationService
{
    private const PLATFORM_IOS = 'ios';
    private const VALID_PLATFORMS = [self::PLATFORM_IOS];
    private const VALID_ENVIRONMENTS = ['sandbox', 'production'];

    private PDO $pdo;
    private string $logFile;

    private ?string $apnsKeyId;
    private ?string $apnsTeamId;
    private ?string $apnsBundleId;
    private ?string $apnsAuthKey;
    private bool $apnsUseSandbox;

    /** @var OpenSSLAsymmetricKey|resource|null */
    private $apnsPrivateKeyResource = null;

    public function __construct(PDO $pdo, array $options = [])
    {
        $this->pdo = $pdo;
        $this->logFile = $options['logFile'] ?? __DIR__ . '/../notifications.log';

        $this->apnsKeyId = $options['apnsKeyId'] ?? getenv('APNS_KEY_ID') ?: null;
        $this->apnsTeamId = $options['apnsTeamId'] ?? getenv('APNS_TEAM_ID') ?: null;
        $this->apnsBundleId = $options['apnsBundleId'] ?? getenv('APNS_BUNDLE_ID') ?: null;

        $authKey = $options['apnsAuthKey'] ?? getenv('APNS_AUTH_KEY') ?: null;
        $authKeyPath = $options['apnsAuthKeyPath'] ?? getenv('APNS_AUTH_KEY_PATH') ?: null;
        if (($authKey === null || $authKey === '') && $authKeyPath) {
            $loaded = $this->loadFileIfExists($authKeyPath);
            if ($loaded !== null) {
                $authKey = $loaded;
            }
        }
        $this->apnsAuthKey = $authKey ? trim($authKey) : null;

        $sandboxFlag = $options['apnsUseSandbox'] ?? getenv('APNS_USE_SANDBOX');
        $this->apnsUseSandbox = filter_var($sandboxFlag, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE) ?? false;

        $this->log('NotificationService initialised. APNs configured=' . ($this->isApnsConfigured() ? 'yes' : 'no'));
    }

    public function isApnsConfigured(): bool
    {
        return $this->apnsKeyId !== null
            && $this->apnsTeamId !== null
            && $this->apnsBundleId !== null
            && $this->apnsAuthKey !== null
            && $this->apnsAuthKey !== '';
    }

    public function registerDeviceToken(string $email, string $deviceToken, array $metadata = []): void
    {
        $normalizedEmail = $this->normalizeEmail($email);
        $normalizedToken = $this->normalizeToken($deviceToken);

        if ($normalizedEmail === '' || $normalizedToken === '') {
            throw new InvalidArgumentException('Email and device token are required.');
        }

        $platform = strtolower((string) ($metadata['platform'] ?? self::PLATFORM_IOS));
        if (!in_array($platform, self::VALID_PLATFORMS, true)) {
            $platform = self::PLATFORM_IOS;
        }

        $environment = strtolower((string) ($metadata['environment'] ?? ($this->apnsUseSandbox ? 'sandbox' : 'production')));
        if (!in_array($environment, self::VALID_ENVIRONMENTS, true)) {
            $environment = $this->apnsUseSandbox ? 'sandbox' : 'production';
        }

        $appVersion = $this->sanitizeNullable($metadata['appVersion'] ?? null);
        $osVersion = $this->sanitizeNullable($metadata['osVersion'] ?? null);

        $sql = <<<SQL
            INSERT INTO notification_devices (email, device_token, platform, environment, app_version, os_version, is_active, last_used_at)
            VALUES (:email, :token, :platform, :environment, :appVersion, :osVersion, 1, NOW())
            ON DUPLICATE KEY UPDATE
                email = VALUES(email),
                platform = VALUES(platform),
                environment = VALUES(environment),
                app_version = VALUES(app_version),
                os_version = VALUES(os_version),
                is_active = 1,
                updated_at = NOW(),
                last_used_at = NOW()
        SQL;

        $stmt = $this->pdo->prepare($sql);
        $stmt->execute([
            ':email' => $normalizedEmail,
            ':token' => $normalizedToken,
            ':platform' => $platform,
            ':environment' => $environment,
            ':appVersion' => $appVersion,
            ':osVersion' => $osVersion,
        ]);

        $this->log("Registered device token for {$normalizedEmail} ({$environment}).");
    }

    public function unregisterDeviceToken(string $email, string $deviceToken): void
    {
        $normalizedEmail = $this->normalizeEmail($email);
        $normalizedToken = $this->normalizeToken($deviceToken);

        if ($normalizedEmail === '' || $normalizedToken === '') {
            return;
        }

        $sql = 'UPDATE notification_devices SET is_active = 0, updated_at = NOW(), last_used_at = NOW() WHERE device_token = :token AND email = :email';
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute([
            ':token' => $normalizedToken,
            ':email' => $normalizedEmail,
        ]);

        $this->log("Unregistered device token for {$normalizedEmail}.");
    }

    public function sendMessageReplyNotification(
        string $receiverEmail,
        string $senderEmail,
        int $pinId,
        string $messageText,
        int $messageId,
        ?string $messageAuthor = null
    ): void
    {
        $receiver = $this->normalizeEmail($receiverEmail);
        if ($receiver === '') {
            return;
        }

        $senderDescriptor = $this->resolveSenderDescriptor($senderEmail, $messageAuthor);
        $title = "📌 {$senderDescriptor} replied to your pin!";
        $body = 'Check out what they said 👀';

        $extra = [
            'type' => 'message.reply',
            'pinId' => $pinId,
            'messageId' => $messageId,
            'senderEmail' => $this->normalizeEmail($senderEmail),
            'senderName' => $senderDescriptor,
            'messagePreview' => $this->truncate($messageText, 140),
        ];

        if ($messageAuthor !== null && trim($messageAuthor) !== '') {
            $extra['author'] = trim($messageAuthor);
        }

        $options = [
            'threadId' => 'whiteboard-replies',
            'category' => 'MESSAGE_REPLY',
            'contentAvailable' => true,
            'collapseId' => 'message_reply_' . $pinId,
            'extra' => $extra,
        ];

        $sent = $this->sendToEmail($receiver, $title, $body, $options);
        $this->log("Message reply notification for {$receiver} attempted → {$sent} deliveries queued.");
    }

    public function sendToEmail(string $email, string $title, string $body, array $options = []): int
    {
        $normalizedEmail = $this->normalizeEmail($email);
        if ($normalizedEmail === '') {
            return 0;
        }

        $devices = $this->fetchActiveDevices($normalizedEmail);
        if (empty($devices)) {
            $this->log("No active devices for {$normalizedEmail}, skipping push.");
            return 0;
        }

        $payload = $this->buildApnsPayload($title, $body, $options);
        $collapseId = $options['collapseId'] ?? null;
        $priority = isset($options['priority']) ? (string) $options['priority'] : '10';

        $sentCount = 0;
        foreach ($devices as $device) {
            if (($device['platform'] ?? self::PLATFORM_IOS) !== self::PLATFORM_IOS) {
                continue;
            }

            $token = (string) $device['device_token'];
            $environment = (string) ($device['environment'] ?? ($this->apnsUseSandbox ? 'sandbox' : 'production'));

            if ($this->sendApnsRequest($token, $payload, $environment, $collapseId, $priority)) {
                $sentCount++;
                $this->touchDevice($token);
            }
        }

        if ($sentCount > 0) {
            $this->logNotificationRecord($normalizedEmail, $title, $body, $options['extra'] ?? []);
        }

        return $sentCount;
    }

    public function listActiveDevices(?string $emailFilter = null): array
    {
        $sql = 'SELECT email, device_token, platform, environment, app_version, os_version, updated_at, last_used_at FROM notification_devices WHERE is_active = 1';
        $params = [];

        if ($emailFilter !== null && $emailFilter !== '') {
            $sql .= ' AND email = :email';
            $params[':email'] = $this->normalizeEmail($emailFilter);
        }

        $sql .= ' ORDER BY updated_at DESC';

        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);

        return $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
    }

    private function fetchActiveDevices(string $email): array
    {
        $stmt = $this->pdo->prepare('SELECT device_token, platform, environment FROM notification_devices WHERE email = :email AND is_active = 1');
        $stmt->execute([':email' => $email]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
    }

    private function touchDevice(string $token): void
    {
        $stmt = $this->pdo->prepare('UPDATE notification_devices SET last_used_at = NOW() WHERE device_token = :token');
        $stmt->execute([':token' => $this->normalizeToken($token)]);
    }

    private function buildApnsPayload(string $title, string $body, array $options = []): array
    {
        $aps = [
            'alert' => [
                'title' => $title,
                'body' => $body,
            ],
            'sound' => $options['sound'] ?? 'default',
        ];

        if (!empty($options['contentAvailable'])) {
            $aps['content-available'] = 1;
        }

        if (!empty($options['mutableContent'])) {
            $aps['mutable-content'] = 1;
        }

        if (!empty($options['threadId'])) {
            $aps['thread-id'] = (string) $options['threadId'];
        }

        if (!empty($options['category'])) {
            $aps['category'] = (string) $options['category'];
        }

        if (isset($options['badge'])) {
            $aps['badge'] = (int) $options['badge'];
        }

        $payload = ['aps' => $aps];

        if (!empty($options['extra']) && is_array($options['extra'])) {
            foreach ($options['extra'] as $key => $value) {
                if ($key === 'aps') {
                    continue;
                }
                $payload[$key] = $value;
            }
        }

        return $payload;
    }

    private function sendApnsRequest(string $deviceToken, array $payload, string $environment, ?string $collapseId, string $priority): bool
    {
        if (!$this->isApnsConfigured()) {
            $this->log('APNs credentials are not configured; skipping remote send.');
            return false;
        }

        $jwt = $this->buildJwt();
        if ($jwt === null) {
            $this->log('Unable to build APNs JWT; skipping send.');
            return false;
        }

        $host = $environment === 'sandbox' ? 'https://api.sandbox.push.apple.com' : 'https://api.push.apple.com';
        $url = sprintf('%s/3/device/%s', $host, $deviceToken);

        $headers = [
            'apns-topic: ' . $this->apnsBundleId,
            'authorization: bearer ' . $jwt,
            'content-type: application/json',
            'apns-priority: ' . $priority,
        ];

        if ($collapseId !== null && $collapseId !== '') {
            $headers[] = 'apns-collapse-id: ' . $collapseId;
        }

        $jsonPayload = json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        if ($jsonPayload === false) {
            $this->log('Failed to encode APNs payload: ' . json_last_error_msg());
            return false;
        }

        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL => $url,
            CURLOPT_PORT => 443,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $jsonPayload,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 10,
            CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_2_0,
            CURLOPT_HTTPHEADER => $headers,
        ]);

        $response = curl_exec($ch);
        $httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError = curl_errno($ch) ? curl_error($ch) : null;
        curl_close($ch);

        if ($curlError !== null) {
            $this->log("APNs send failed (curl): {$curlError}");
            return false;
        }

        if ($httpCode >= 200 && $httpCode < 300) {
            $this->log('APNs send succeeded for token ' . $deviceToken);
            return true;
        }

        $this->log("APNs send failed ({$httpCode}): {$response}");
        return false;
    }

    private function buildJwt(): ?string
    {
        $privateKey = $this->getPrivateKeyResource();
        if (!$privateKey) {
            return null;
        }

        $header = ['alg' => 'ES256', 'kid' => $this->apnsKeyId];
        $claims = ['iss' => $this->apnsTeamId, 'iat' => time()];

        $segments = [
            $this->base64UrlEncode(json_encode($header)),
            $this->base64UrlEncode(json_encode($claims)),
        ];

        if (in_array(null, $segments, true)) {
            $this->log('Failed to encode APNs JWT header/claims.');
            return null;
        }

        $signingInput = implode('.', $segments);
        $signature = '';
        $success = openssl_sign($signingInput, $signature, $privateKey, OPENSSL_ALGO_SHA256);

        if (!$success) {
            $this->log('openssl_sign failed when building APNs JWT.');
            return null;
        }

        $segments[] = $this->base64UrlEncode($signature);
        if (in_array(null, $segments, true)) {
            $this->log('Failed to encode APNs JWT signature.');
            return null;
        }

        return implode('.', $segments);
    }

    /**
     * @return OpenSSLAsymmetricKey|resource|null
     */
    private function getPrivateKeyResource()
    {
        if ($this->apnsPrivateKeyResource !== null) {
            return $this->apnsPrivateKeyResource;
        }

        if ($this->apnsAuthKey === null || $this->apnsAuthKey === '') {
            return null;
        }

        $keyMaterial = $this->apnsAuthKey;
        if (strpos($keyMaterial, 'BEGIN PRIVATE KEY') === false) {
            $decoded = base64_decode($keyMaterial, true);
            if ($decoded !== false) {
                $keyMaterial = $decoded;
            }
        }

        $resource = openssl_pkey_get_private($keyMaterial);
        if ($resource === false) {
            $this->log('Unable to load APNs private key.');
            return null;
        }

        $this->apnsPrivateKeyResource = $resource;
        return $resource;
    }

    private function logNotificationRecord(string $email, string $title, string $body, array $payload): void
    {
        $sql = 'INSERT INTO notification_log (email, title, body, payload) VALUES (:email, :title, :body, :payload)';
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute([
            ':email' => $email,
            ':title' => $title,
            ':body' => $body,
            ':payload' => json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
        ]);
    }

    private function normalizeEmail(?string $email): string
    {
        if ($email === null) {
            return '';
        }
        return strtolower(trim($email));
    }

    private function normalizeToken(?string $token): string
    {
        if ($token === null) {
            return '';
        }
        $stripped = preg_replace('/\s+/', '', $token);
        return strtolower($stripped ?? '');
    }

    private function sanitizeNullable($value): ?string
    {
        if ($value === null) {
            return null;
        }

        $trimmed = trim((string) $value);
        return $trimmed === '' ? null : $trimmed;
    }

    private function truncate(string $text, int $maxLength): string
    {
        $trimmed = trim($text);
        if (mb_strlen($trimmed) <= $maxLength) {
            return $trimmed;
        }

        return mb_substr($trimmed, 0, $maxLength - 1) . '…';
    }

    private function resolveSenderDescriptor(string $senderEmail, ?string $author): string
    {
        $normalizedAuthor = $author !== null ? trim($author) : '';
        if ($normalizedAuthor !== '') {
            return $normalizedAuthor;
        }

        return $this->displayNameForEmail($senderEmail);
    }

    private function displayNameForEmail(string $email): string
    {
        $normalized = $this->normalizeEmail($email);
        if ($normalized === '') {
            return 'Someone';
        }

        $parts = explode('@', $normalized, 2);
        $local = $parts[0] ?? $normalized;
        $local = str_replace(['.', '_', '-'], ' ', $local);
        $local = ucwords($local);

        return $local === '' ? $normalized : $local;
    }

    private function base64UrlEncode($value): ?string
    {
        if ($value === null) {
            return null;
        }

        $encoded = base64_encode($value);
        if ($encoded === false) {
            return null;
        }

        return rtrim(strtr($encoded, '+/', '-_'), '=');
    }

    private function loadFileIfExists(string $path): ?string
    {
        if (is_file($path) && is_readable($path)) {
            $contents = file_get_contents($path);
            if ($contents !== false) {
                return $contents;
            }
        }
        return null;
    }

    private function log(string $message): void
    {
        $timestamp = date('Y-m-d H:i:s');
        file_put_contents($this->logFile, "[{$timestamp}] {$message}\n", FILE_APPEND);
    }
}
