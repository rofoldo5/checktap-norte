# CheckTap v0.7 - Portainer

The production-oriented deployment files are located in:

    deploy/portainer/

Target API URL:

    http://192.168.30.51:8080

Start with:

    cd deploy/portainer
    ./01_GENERAR_VARIABLES.sh
    ./02_PREPARAR_HOST_DOCKER.sh

Then create the `checktap` stack in Portainer using
`compose.portainer.yaml` and the generated `.env.portainer` variables.

After deployment:

    ./04_VERIFICAR_DESPLIEGUE.sh

Full instructions are in `deploy/portainer/README_PORTAINER.md`.
