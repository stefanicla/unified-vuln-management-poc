#!/usr/bin/env bash
# Complete setup script for DefectDojo PoC
# Run from repo root in WSL: bash scripts/setup-all.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR="${REPO_ROOT}/artifacts"
MOCK_APP_DIR="${REPO_ROOT}/mock-app"

log() { echo "[$(date '+%H:%M:%S')] $1"; }
error() { echo "[$(date '+%H:%M:%S')] ERROR: $1" >&2; exit 1; }

check_docker() {
    if ! docker info >/dev/null 2>&1; then
        error "Docker not running. Start Docker Desktop first."
    fi
    log "Docker is running"
}

run_scanners() {
    log "Running security scanners..."
    if [[ -f "${REPO_ROOT}/scripts/run-scanners.sh" ]]; then
        bash "${REPO_ROOT}/scripts/run-scanners.sh"
    else
        error "run-scanners.sh not found"
    fi
    log "Scanners complete. Reports in ${ARTIFACTS_DIR}"
}

start_defectdojo() {
    log "Starting DefectDojo stack..."
    cd "${REPO_ROOT}"
    docker compose -f infra/docker-compose.defectdojo.yml up -d
    log "Waiting for PostgreSQL and Redis to be healthy..."
    sleep 10
}

wait_for_initializer() {
    log "Waiting for initializer to complete migrations..."
    local timeout=300
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if docker compose -f infra/docker-compose.defectdojo.yml logs initializer 2>/dev/null | grep -q "spawned uWSGI worker"; then
            log "Initializer ready"
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
    error "Initializer timeout. Check logs: docker compose -f infra/docker-compose.defectdojo.yml logs initializer"
}

setup_database() {
    log "Running Django migrations..."
    docker exec defectdojo-uwsgi python manage.py migrate --noinput

    log "Creating admin user..."
    docker exec defectdojo-uwsgi python manage.py createsuperuser --username admin --email admin@example.com --noinput >/dev/null 2>&1 || true
    docker exec defectdojo-uwsgi python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
u = User.objects.get(username='admin')
u.set_password('admin')
u.save()
print('Admin password set to: admin')
" >/dev/null

    log "Loading fixtures..."
    docker exec defectdojo-uwsgi python manage.py loaddata product_type role regulation >/dev/null

    log "Creating Development environment..."
    docker exec defectdojo-uwsgi python manage.py shell -c "
from dojo.models import Development_Environment
env, created = Development_Environment.objects.get_or_create(name='Development')
print(f'Environment: {env.name}, Created: {created}')
" >/dev/null
}

collect_static() {
    log "Collecting static files..."
    docker exec -u root defectdojo-uwsgi chmod -R 777 /app/static /app/media >/dev/null 2>&1
    docker exec defectdojo-uwsgi python manage.py collectstatic --noinput >/dev/null
}

start_nginx() {
    log "Starting Nginx..."
    docker start defectdojo-nginx >/dev/null 2>&1 || true
    sleep 3
}

create_product_engagement() {
    log "Creating Product and Engagement..."
    docker exec defectdojo-uwsgi python manage.py shell -c "
from dojo.models import Product, Engagement, Product_Type
from django.contrib.auth import get_user_model
from datetime import date, timedelta

User = get_user_model()
admin = User.objects.get(username='admin')
prod_type = Product_Type.objects.get(name='Research and Development')

# Create product if not exists
product, created = Product.objects.get_or_create(
    name='DefectDojo PoC App',
    defaults={'prod_type': prod_type, 'description': 'Mock application for DefectDojo PoC'}
)
print(f'Product ID: {product.id} (created: {created})')

# Create engagement if not exists
engagement, created = Engagement.objects.get_or_create(
    product=product,
    name='PoC Scan Run',
    defaults={
        'description': 'Automated security scan run for PoC demonstration',
        'target_start': date.today(),
        'target_end': date.today() + timedelta(days=30),
        'status': 'In Progress',
        'lead': admin
    }
)
print(f'Engagement ID: {engagement.id} (created: {created})')
"
}

import_reports() {
    log "Importing scanner reports..."
    if [[ -f "${REPO_ROOT}/scripts/import-all.py" ]]; then
        python3 "${REPO_ROOT}/scripts/import-all.py"
    else
        error "import-all.py not found"
    fi
}

verify_import() {
    log "Verifying import..."
    docker exec defectdojo-uwsgi python manage.py shell -c "
from dojo.models import Finding, Test
test = Test.objects.get(id=1)
findings = Finding.objects.filter(test=test)
print(f'Total findings in test: {findings.count()}')
for f in findings[:5]:
    print(f'  - {f.severity}: {f.title[:80]}')
" 2>/dev/null || true
}

print_summary() {
    echo ""
    echo "=========================================="
    echo "  DefectDojo PoC Setup Complete!"
    echo "=========================================="
    echo ""
    echo "Access DefectDojo: http://localhost:8080"
    echo "  Username: admin"
    echo "  Password: admin"
    echo ""
    echo "View findings:"
    echo "  http://localhost:8080/product/1"
    echo "  http://localhost:8080/engagement/1"
    echo "  http://localhost:8080/test/1"
    echo ""
    echo "Run scanners again:"
    echo "  bash scripts/run-scanners.sh"
    echo ""
    echo "Re-import reports:"
    echo "  python3 scripts/import-all.py"
    echo ""
    echo "Stop everything:"
    echo "  docker compose -f infra/docker-compose.defectdojo.yml down -v"
    echo ""
}

main() {
    echo "=========================================="
    echo "  DefectDojo PoC - Full Automated Setup"
    echo "=========================================="
    echo ""

    check_docker
    run_scanners
    start_defectdojo
    wait_for_initializer
    setup_database
    collect_static
    start_nginx
    create_product_engagement
    import_reports
    verify_import
    print_summary
}

main "$@"