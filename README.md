# Pila LAMP: Ubuntu 26.04, Apache, PHP y MariaDB

Proyecto de ejemplo que ejecuta una pila LAMP con Docker Compose. Apache y PHP se ejecutan juntos en un contenedor basado en Ubuntu 26.04; MariaDB se ejecuta en un servicio separado. Hay dos sitios dinámicos, cada uno con su propio host virtual: uno HTTP y otro HTTPS. Ambos consultan la misma base de datos para confirmar la conectividad.

> Esta configuración es para desarrollo y pruebas. El sitio HTTPS usa un certificado autofirmado y las credenciales de la base de datos son de ejemplo; no usar así en producción.

## Requisitos

- Docker con Docker Compose disponible mediante el comando `docker compose`.
- Puertos `8080` y `8443` disponibles en el equipo.

## Estructura del proyecto

```text
.
├── Dockerfile
├── docker-compose.yml
├── .env              # credenciales locales; excluido de Git
├── .gitignore
├── .dockerignore
├── apache/
│   ├── http.conf
│   └── https.conf
├── database/
│   └── init.sql
└── sites/
    ├── http/
    │   └── index.php
    └── https/
        └── index.php
```

- `Dockerfile`: parte de `ubuntu:26.04` e instala Apache, PHP, el controlador PDO MySQL y OpenSSL. Habilita SSL y genera un certificado autofirmado al construir la imagen.
- `docker-compose.yml`: define el servicio web y el de MariaDB, sus puertos, variables, healthcheck, persistencia y dependencia de arranque.
- `.env`: contiene localmente las credenciales que usa Compose; no debe subirse al repositorio.
- `.gitignore`: excluye `.env` y otros ficheros de entorno locales de Git.
- `apache/http.conf` y `apache/https.conf`: hosts virtuales independientes para `site-http.local` y `site-https.local`.
- `sites/http/index.php` y `sites/https/index.php`: páginas PHP que abren una conexión PDO, ejecutan una consulta y muestran el resultado.
- `database/init.sql`: crea `site_check` e inserta el mensaje de comprobación.
- `.dockerignore`: excluye del contexto de build algunos ficheros locales.

## Servicios, puertos y datos

| Servicio | Función | Acceso desde el host |
|---|---|---|
| `web` | Apache y PHP; host virtual HTTP | `http://localhost:8080` |
| `web` | Apache y PHP; host virtual HTTPS | `https://localhost:8443` |
| `db` | MariaDB; solo accesible en la red interna de Compose | No se publica un puerto al host |

En la red de Compose, PHP llega a MariaDB usando el hostname `db` y la base `lampdemo`. El usuario de aplicación configurado es `lampuser`. El volumen nombrado `db_data` conserva los datos aunque se recreen los contenedores.

Las credenciales de MariaDB se leen desde `.env`; Compose pasa al servicio web los valores `DB_NAME`, `DB_USER` y `DB_PASSWORD`, y al servicio `db` las variables `MARIADB_*`. El archivo `.env` se excluye de Git. No guardes secretos reales en el repositorio ni los incluyas en una imagen.

## Variables de entorno

El fichero `.env` de la raíz contiene las credenciales locales y está excluido del repositorio mediante `.gitignore`. Revisa y sustituye los valores por credenciales únicas para tu entorno. No compartas ni subas `.env`; si necesitas compartir la configuración, hazlo sin credenciales reales.

Compose carga automáticamente `.env` al ejecutar comandos desde la raíz del proyecto.

## Arranque y uso

Desde la raíz del proyecto, construir y levantar los servicios:

```sh
docker compose up --pull always --build -d
```

Verificar el estado:

```sh
docker compose ps
```

El servicio `db` debe aparecer como `healthy` y `web` como `Up`. Abrir en el navegador:

- HTTP: <http://localhost:8080>
- HTTPS: <https://localhost:8443>

El navegador advertirá que el certificado HTTPS no es de confianza porque es autofirmado y se genera localmente. Para esta prueba, se puede aceptar la excepción del navegador o usar `curl -k`; no se debe usar ese certificado como configuración de producción.

Para detener los servicios sin borrar la base:

```sh
docker compose down
```

Para detenerlos y eliminar también el volumen y los datos persistidos (acción destructiva):

```sh
docker compose down -v
```

## Batería de pruebas

Ejecuta estos comandos desde la raíz del proyecto después del arranque.

### 1. Estado y healthcheck de MariaDB

```sh
docker compose ps
```

Confirma que `db` indique `healthy` y `web` esté en ejecución. El healthcheck comprueba que MariaDB está conectada y que InnoDB terminó de inicializarse.

### 2. Respuesta de HTTP y consulta de base de datos

```sh
curl -fsS http://localhost:8080/
```

El HTML debe incluir `Sitio dinámico HTTP`, `Conexión a la base de datos: OK` y `Consulta a MariaDB correcta`.

### 3. Respuesta de HTTPS y consulta de base de datos

```sh
curl -kfsS https://localhost:8443/
```

El HTML debe incluir `Sitio dinámico HTTPS`, `Conexión a la base de datos: OK` y `Consulta a MariaDB correcta`. `-k` omite la validación del certificado autofirmado únicamente para esta prueba local.

### 4. Validar el código de estado HTTP

```sh
curl -sS -o /dev/null -w 'HTTP %{http_code}\n' http://localhost:8080/
curl -ksS -o /dev/null -w 'HTTPS %{http_code}\n' https://localhost:8443/
```

Ambas peticiones deben responder `200`. Un error de conexión a la base de datos devuelve `500` desde PHP.

### 5. Comprobar que PHP se ejecuta y no se entrega como texto

```sh
curl -fsS http://localhost:8080/ | grep 'Sitio dinámico HTTP'
curl -kfsS https://localhost:8443/ | grep 'Sitio dinámico HTTPS'
```

La salida debe mostrar los títulos renderizados en HTML; no debe aparecer el código fuente PHP.

### 6. Consultar la fila de prueba directamente en MariaDB

```sh
docker compose exec db sh -c 'mariadb -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" "$MARIADB_DATABASE" -e "SELECT id, message FROM site_check;"'
```

Debe aparecer la fila con el mensaje `Consulta a MariaDB correcta`.

### 7. Ejecutar todas las verificaciones básicas de una vez

```sh
set -e

docker compose ps
curl -fsS http://localhost:8080/ | grep -E 'Sitio dinámico HTTP|Conexión a la base de datos: OK|Consulta a MariaDB correcta'
curl -kfsS https://localhost:8443/ | grep -E 'Sitio dinámico HTTPS|Conexión a la base de datos: OK|Consulta a MariaDB correcta'
docker compose exec -T db sh -c 'mariadb -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" "$MARIADB_DATABASE" -e "SELECT id, message FROM site_check;"'
```

Si `set -e` termina el script con error, la primera comprobación que falla indica qué componente investigar.

## Consulta de logs

### Logs de ambos servicios

```sh
docker compose logs
```

Seguir los logs en tiempo real:

```sh
docker compose logs -f
```

### Logs de un servicio concreto

```sh
docker compose logs web
docker compose logs db
```

### Logs de Apache dentro del contenedor web

Los hosts virtuales escriben los logs de acceso y error en los ficheros indicados en su configuración:

```sh
docker compose exec web tail -n 100 /var/log/apache2/http-access.log
docker compose exec web tail -n 100 /var/log/apache2/http-error.log
docker compose exec web tail -n 100 /var/log/apache2/https-access.log
docker compose exec web tail -n 100 /var/log/apache2/https-error.log
```

## Troubleshooting

### No se puede abrir `localhost:8080` o `localhost:8443`

1. Comprueba el estado con `docker compose ps`.
2. Revisa `docker compose logs web` y `docker compose logs db`.
3. Confirma que los puertos locales estén libres. Si están ocupados, cambia la parte izquierda de `8080:80` o `8443:443` en `docker-compose.yml` y vuelve a crear los servicios con `docker compose up --pull always --build -d`.
4. Comprueba que Docker esté iniciado.

### El navegador avisa sobre el certificado HTTPS

Es lo esperado en esta configuración: el certificado es autofirmado, no fue emitido por una autoridad de confianza y su nombre es `site-https.local`. Para la comprobación local se puede aceptar la advertencia o usar `curl -k`. Para un despliegue real, instala un certificado válido y protege su clave privada.

### La página devuelve `500` o muestra un error de base de datos

1. Comprueba que `db` esté `healthy` con `docker compose ps`.
2. Consulta `docker compose logs db` para revisar el arranque de MariaDB.
3. Revisa `docker compose logs web` y `/var/log/apache2/*-error.log`.
4. Confirma que las variables `DB_*` de `web` se derivan de las correspondientes variables `MARIADB_*` de `.env`.
5. Verifica que la tabla y la fila existan con la consulta SQL de la sección de pruebas.

### MariaDB no se pone en estado `healthy`

Inspecciona los logs con `docker compose logs db`. Espera a que termine la inicialización; si el servicio se reinicia repetidamente, busca errores de configuración, problemas de permisos o falta de recursos. No elimines el volumen como primer paso, porque contiene la base persistida.

### Los cambios de `database/init.sql` no aparecen en la base existente

El script de inicialización se ejecuta al crear por primera vez el directorio de datos de MariaDB. Si `db_data` ya contiene una base, los cambios posteriores al SQL no se aplican automáticamente. Añade una migración SQL explícita o, si puedes perder los datos locales, elimina el volumen con `docker compose down -v` y vuelve a levantar la pila.

### Cambié el Dockerfile o la configuración, pero no veo los cambios

Reconstruye la imagen y recrea los servicios:

```sh
docker compose up --pull always --build -d
```

### La consulta directa a MariaDB informa de acceso denegado

Comprueba que las variables de usuario y contraseña de `.env` coincidan con las credenciales con las que se inicializó la base. Las variables de inicialización de MariaDB no actualizan las credenciales de una base que ya fue inicializada y persiste en `db_data`. Si se trata de un entorno de pruebas y aceptas borrar los datos, recrea el volumen con `docker compose down -v` y levanta la pila otra vez.

### Apache no arranca o no carga un host virtual

Consulta `docker compose logs web` y los logs de error de Apache. Comprueba los ficheros `apache/http.conf` y `apache/https.conf`, que se copian a `sites-available` al construir la imagen; tras cambiarlos, reconstruye con `docker compose up --pull always --build -d`.

## Seguridad y notas de desarrollo

- El certificado generado durante el build es autofirmado, sirve solo para pruebas y no debe utilizarse en producción.
- Las credenciales están en `.env`, excluido de Git; sustituye los valores de desarrollo y usa un gestor de secretos apropiado para despliegues reales.
- No se publica el puerto de MariaDB al host; PHP la alcanza mediante la red interna de Compose.
- `docker compose down -v` elimina el volumen de datos de MariaDB. Úsalo solo cuando la pérdida de datos sea intencional.
- Los nombres `site-http.local` y `site-https.local` están configurados como `ServerName` de Apache. Para acceder por esos nombres desde el navegador, hay que configurar su resolución local (por ejemplo, `/etc/hosts`) hacia `127.0.0.1` y conservar los puertos publicados `8080` y `8443`.
