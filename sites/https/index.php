<?php
$pdo = null;
$error = null;
try {
    $pdo = new PDO(
        'mysql:host=' . getenv('DB_HOST') . ';dbname=' . getenv('DB_NAME') . ';charset=utf8mb4',
        getenv('DB_USER'),
        getenv('DB_PASSWORD'),
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    $message = $pdo->query('SELECT message FROM site_check LIMIT 1')->fetchColumn();
} catch (Throwable $e) {
    http_response_code(500);
    $error = $e->getMessage();
}
?>
<!doctype html>
<html lang="es"><meta charset="utf-8"><title>Sitio HTTPS</title>
<h1>Sitio dinámico HTTPS</h1>
<p>Conexión a la base de datos: <?= $error ? 'ERROR: ' . htmlspecialchars($error) : 'OK' ?></p>
<?php if (!$error): ?><p>Mensaje de MariaDB: <?= htmlspecialchars($message) ?></p><?php endif; ?>
</html>
