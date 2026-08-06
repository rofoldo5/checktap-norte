# CheckTap Portainer v0.7 patch

Apply to the current CheckTap project:

    chmod +x APLICAR_PORTAINER_V0_7.sh
    ./APLICAR_PORTAINER_V0_7.sh ~/Documents/checktap/system

The patch creates a backup before replacing files. It does not modify the
current local `.env`, PostgreSQL data, Flutter SQLite data, or user tasks.

After applying, read:

    deploy/portainer/README_PORTAINER.md
