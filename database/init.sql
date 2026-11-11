CREATE TABLE IF NOT EXISTS site_check (
    id INT AUTO_INCREMENT PRIMARY KEY,
    message VARCHAR(255) NOT NULL
);
INSERT INTO site_check (message) VALUES ('Consulta a MariaDB correcta');
