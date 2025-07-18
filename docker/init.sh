#!/bin/bash

# Exit on error
set -e

# --- Configuration ---
# The new name for your app (must be a valid Python identifier)
APP_NAME="hrms"
# The URL to YOUR forked and renamed GitHub repository
APP_REPO_URL="https://github.com/itsanubhav009/hrms.git"
# The branch you are working on
APP_BRANCH="develop"
# The name for your local development site
SITE_NAME="${APP_NAME}.localhost"


# Check if the bench has already been initialized
if [ -d "/home/frappe/frappe-bench/apps/frappe" ]; then
    echo "Bench already exists, skipping init and starting."
    cd /home/frappe/frappe-bench
    bench start
else
    echo "Creating new bench..."
    # This line is for specific node version management, keep if needed
    # export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"

    bench init --skip-redis-config-generation frappe-bench

    cd /home/frappe/frappe-bench

    # Use containers instead of localhost
    bench set-mariadb-host mariadb
    bench set-redis-cache-host redis://redis:6379
    bench set-redis-queue-host redis://redis:6379
    bench set-redis-socketio-host redis://redis:6379

    # Remove redis, watch from Procfile as they are handled by docker-compose
    sed -i '/redis/d' ./Procfile
    sed -i '/watch/d' ./Procfile

    # Get the core ERPNext app
    bench get-app erpnext

    # --- MODIFIED PART ---
    # Get YOUR custom app from YOUR repository
    echo "Getting custom app from ${APP_REPO_URL}"
    bench get-app --branch "${APP_BRANCH}" "${APP_REPO_URL}"
    # --- END OF MODIFIED PART ---

    # Create the new site with the new name
    echo "Creating site ${SITE_NAME}"
    bench new-site "${SITE_NAME}" \
        --force \
        --mariadb-root-password 123 \
        --admin-password admin \
        --no-mariadb-socket

    # Install the apps onto the new site
    bench --site "${SITE_NAME}" install-app erpnext
    bench --site "${SITE_NAME}" install-app "${APP_NAME}"
    
    # Set developer mode and enable the scheduler
    bench --site "${SITE_NAME}" set-config developer_mode 1
    bench --site "${SITE_NAME}" enable-scheduler

    # Disable the "Login via Frappe" button
    echo "Disabling Frappe Social Login Key..."
    bench --site "${SITE_NAME}" execute "frappe.db.set_value" --args '["Social Login Key", "Frappe", "enabled", 0]'
    bench --site "${SITE_NAME}" execute "frappe.db.commit"

    bench --site "${SITE_NAME}" clear-cache
    bench use "${SITE_NAME}"

    echo "Starting bench..."
    bench start
fi