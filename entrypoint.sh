#!/bin/bash

set -e

# set the postgres database host, port, user and password according to the environment
# and pass them as arguments to the odoo process if not present in the config file
: ${HOST:=${DB_PORT_5432_TCP_ADDR:='db'}}
: ${PORT:=${DB_PORT_5432_TCP_PORT:=5432}}
: ${USER:=${DB_ENV_POSTGRES_USER:=${POSTGRES_USER:='odoo'}}}
: ${PASSWORD:=${DB_ENV_POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:='odoo18@2024'}}}

# install python packages
# pip3 install pip --upgrade                # may cause errors
pip3 install -r /etc/odoo/requirements.txt

# sed -i 's|raise werkzeug.exceptions.BadRequest(msg)|self.jsonrequest = {}|g' /usr/lib/python3/dist-packages/odoo/http.py

# Ensure wkhtmltopdf 0.12.5 is installed (uninstall and reinstall if different version)
echo "Ensuring wkhtmltopdf 0.12.5 is installed..."
apt-get update
# Install wget if not available
if ! command -v wget &> /dev/null; then
    apt-get install -y wget
fi

# Check if wkhtmltopdf is installed and get version
INSTALLED_VERSION=""
if command -v wkhtmltopdf &> /dev/null; then
    VERSION_OUTPUT=$(wkhtmltopdf --version 2>&1 | head -n1)
    INSTALLED_VERSION=$(echo "$VERSION_OUTPUT" | sed -n 's/.*wkhtmltopdf \([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' | head -n1)
    echo "Current wkhtmltopdf version: ${INSTALLED_VERSION:-unknown}"
fi

# Uninstall existing version if it's not 0.12.5 or if version detection failed
if [ -n "$INSTALLED_VERSION" ] && [ "$INSTALLED_VERSION" != "0.12.5" ]; then
    echo "Uninstalling existing wkhtmltopdf version $INSTALLED_VERSION..."
    apt-get remove -y wkhtmltopdf wkhtmltox || true
    apt-get purge -y wkhtmltopdf wkhtmltox || true
    INSTALLED_VERSION=""  # Reset to trigger installation
elif [ -z "$INSTALLED_VERSION" ] && command -v wkhtmltopdf &> /dev/null; then
    # Version detection failed but wkhtmltopdf exists - uninstall to be safe
    echo "Could not detect wkhtmltopdf version, uninstalling to ensure correct version..."
    apt-get remove -y wkhtmltopdf wkhtmltox || true
    apt-get purge -y wkhtmltopdf wkhtmltox || true
    INSTALLED_VERSION=""  # Reset to trigger installation
fi

# Install version 0.12.5 if not installed or if version doesn't match
if [ -z "$INSTALLED_VERSION" ] || [ "$INSTALLED_VERSION" != "0.12.5" ]; then
    echo "Installing wkhtmltopdf 0.12.5..."
    # Always use version 0.12.5 bionic_amd64
    wget -q https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb -O /tmp/wkhtmltox.deb
    dpkg -i /tmp/wkhtmltox.deb || true
    apt-get install -f -y
    rm -f /tmp/wkhtmltox.deb
    echo "wkhtmltopdf 0.12.5 installed successfully"
else
    echo "wkhtmltopdf 0.12.5 is already installed"
fi

# Install logrotate if not already installed
if ! dpkg -l | grep -q logrotate; then
    apt-get update && apt-get install -y logrotate
fi

# Copy logrotate config
cp /etc/odoo/logrotate /etc/logrotate.d/odoo

# Start cron daemon (required for logrotate)
cron

DB_ARGS=()
function check_config() {
    param="$1"
    value="$2"
    if grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" ; then       
        value=$(grep -E "^\s*\b${param}\b\s*=" "$ODOO_RC" |cut -d " " -f3|sed 's/["\n\r]//g')
    fi;
    DB_ARGS+=("--${param}")
    DB_ARGS+=("${value}")
}
check_config "db_host" "$HOST"
check_config "db_port" "$PORT"
check_config "db_user" "$USER"
check_config "db_password" "$PASSWORD"

case "$1" in
    -- | odoo)
        shift
        if [[ "$1" == "scaffold" ]] ; then
            exec odoo "$@"
        else
            wait-for-psql.py ${DB_ARGS[@]} --timeout=30
            exec odoo "$@" "${DB_ARGS[@]}"
        fi
        ;;
    -*)
        wait-for-psql.py ${DB_ARGS[@]} --timeout=30
        exec odoo "$@" "${DB_ARGS[@]}"
        ;;
    *)
        exec "$@"
esac

exit 1