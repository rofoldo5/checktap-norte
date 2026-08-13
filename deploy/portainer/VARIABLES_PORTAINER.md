# Portainer variables

| Variable | Example | Purpose |
|---|---|---|
| SERVER_IP | 192.168.30.51 | Documentation and verification target |
| API_BIND_ADDRESS | 0.0.0.0 | Host interface used by Docker |
| API_PORT | 8080 | LAN port published for CheckTap |
| API_BASE_URL | http://192.168.30.51:8080 | URL used by verification and Flutter builds |
| CHECKTAP_IMAGE | checktap-backend | Local Docker image name |
| CHECKTAP_IMAGE_TAG | 0.14.1 | Deployable image version |
| SELF_REGISTRATION_ENABLED | true | Habilita el registro con aprobación administrativa |
| POSTGRES_DB | checktap | PostgreSQL database |
| POSTGRES_USER | checktap | PostgreSQL role |
| POSTGRES_PASSWORD | random | Database secret; use letters and numbers |
| JWT_SECRET | random | JWT signing secret; minimum 64 characters |
| ACCESS_TOKEN_MINUTES | 480 | Access token lifetime |
| BOOTSTRAP_ADMIN_NAME | Administrador | Initial administrator name |
| BOOTSTRAP_ADMIN_EMAIL | admin@checktap.com | Initial administrator login |
| BOOTSTRAP_ADMIN_PASSWORD | random | Initial administrator password |
| CORS_ORIGINS | * | Allowed browser origins; mobile is not restricted by CORS |
| REPORT_TIMEZONE | America/Montreal | Business day used by daily reports |

The bootstrap administrator is only created if the configured email does not
already exist. Changing its password variable later does not reset an existing
user password.
