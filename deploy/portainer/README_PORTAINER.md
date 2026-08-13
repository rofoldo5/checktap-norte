# CheckTap v0.7 - Portainer deployment

This package targets a Docker Standalone environment managed by Portainer.
The published API URL is:

    http://192.168.30.51:8080

## Services

- checktap-api: FastAPI, Alembic migrations, REST, WebSocket, and PDF reports.
- checktap-postgres: PostgreSQL with persistent external volume.

The PostgreSQL port is not published to the LAN. Only the API port is exposed.

## Important architecture rule

Keep one API replica and UVICORN_WORKERS=1. The current WebSocket connection
manager is stored in memory. Multiple API workers or replicas require Redis
Pub/Sub, which is not included in v0.7.

## Recommended deployment method: local image plus Portainer stack

### 1. Copy the project to the Docker host

Example:

    /opt/checktap/system

The Docker host must contain the backend source so the image can be built once.

### 2. Generate variables

On the Docker host:

    cd /opt/checktap/system/deploy/portainer
    ./01_GENERAR_VARIABLES.sh

This creates `.env.portainer` with random database, JWT, and administrator
credentials. Save the generated administrator password securely.

Review these values before deployment:

- SERVER_IP=192.168.30.51
- API_PORT=8080
- REPORT_TIMEZONE
- BOOTSTRAP_ADMIN_EMAIL

### 3. Build the backend image and create the external volume

    ./02_PREPARAR_HOST_DOCKER.sh

Expected resources:

- Image: checktap-backend:0.14.0
- Volume: checktap_postgres_data

The volume is external so deleting and recreating the Portainer stack does not
automatically delete the database.

### 4. Create the stack in Portainer

In Portainer:

1. Open the Docker Standalone environment.
2. Go to Stacks and choose Add stack.
3. Name it `checktap`.
4. Choose Web editor.
5. Paste `compose.portainer.yaml`.
6. Load the variables from `.env.portainer`, or enter them in the Environment
   variables section.
7. Disable forced image pulling when using the locally built image.
8. Deploy the stack.

Portainer environment variables are referenced by `${VARIABLE}` in the Compose
file. Do not paste secrets directly into `compose.portainer.yaml`.

## Alternative deployment with Docker Compose

This is useful for testing the same stack outside the Portainer UI:

    ./03_DESPLEGAR_CON_DOCKER_COMPOSE.sh

## Verify deployment

    ./04_VERIFICAR_DESPLIEGUE.sh

The script checks:

- Database-backed health endpoint.
- Administrator login.
- Current user endpoint.
- User and task lists.
- Daily PDF report.

Expected final message:

    RESULT: CHECKTAP PORTAINER DEPLOYMENT APPROVED

## Access URLs

- Health: http://192.168.30.51:8080/health
- Swagger: http://192.168.30.51:8080/docs
- API root: http://192.168.30.51:8080/api/v1
- WebSocket: ws://192.168.30.51:8080/api/v1/ws/tasks

## Build the Android application for the server

Run this on the Flutter development computer, not necessarily on the server:

    cd deploy/portainer
    API_BASE_URL=http://192.168.30.51:8080 ./09_COMPILAR_APK_SERVIDOR.sh

The APK is written to:

    dist/checktap-0.14.0.apk

`adb reverse` is not required when the phone can reach 192.168.30.51 on the LAN.

## Migrate the current local PostgreSQL data

On the development computer:

    ./08_EXPORTAR_POSTGRES_LOCAL.sh

Copy the generated `.dump` file to the Docker host. On the Docker host:

    ./06_RESTAURAR_POSTGRES.sh /path/to/checktap_local_TIMESTAMP.dump

Do this before users begin working against the server, or during a maintenance
window.

## Backups

Create a backup:

    ./05_RESPALDAR_POSTGRES.sh

Restore a backup:

    ./06_RESTAURAR_POSTGRES.sh backups/checktap_TIMESTAMP.dump

Copy backups to storage outside the Docker host as part of the operational
backup policy.

## Diagnostics

    ./07_DIAGNOSTICO.sh

The script displays container status, health response, logs, volume, and network.

## Firewall

The LAN clients need TCP access to port 8080 on 192.168.30.51. PostgreSQL port
5432 should remain unpublished. If UFW is enabled, permit only the required LAN
subnet, for example:

    sudo ufw allow from 192.168.30.0/24 to any port 8080 proto tcp

## Updating CheckTap

1. Update the source on the Docker host.
2. Change CHECKTAP_IMAGE_TAG in `.env.portainer`.
3. Build the new image with `02_PREPARAR_HOST_DOCKER.sh`.
4. Update and redeploy the Portainer stack.
5. Run `04_VERIFICAR_DESPLIEGUE.sh`.
6. Keep the previous image until validation is complete.

Alembic migrations run automatically before the API starts.
