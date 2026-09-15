#!/usr/bin/env bash
# Security Scanner Orchestration for DefectDojo PoC
# Run in WSL: bash scripts/run-scanners.sh
#
# Image versions pinned for reproducibility:
#   node:20.18.0-alpine           (Node.js 20 LTS)
#   semgrep/semgrep:latest        (Official Semgrep image)
#   aquasec/trivy:0.74.0          (Trivy 0.74.0)
#   zaproxy/zap-stable:2.17.0     (ZAP 2.17.0)
#   node:18.20.0-alpine           (Node.js 18 LTS for build)
#   nginx:1.27-alpine             (Nginx 1.27 stable)

set -euo pipefail

# Pinned image versions (override via env if needed)
NODE_VERSION="${NODE_VERSION:-20.18.0-alpine}"
NODE_BUILD_VERSION="${NODE_BUILD_VERSION:-18.20.0-alpine}"
SEMGREP_VERSION="${SEMGREP_VERSION:-latest}"
TRIVY_VERSION="${TRIVY_VERSION:-0.74.0}"
ZAP_VERSION="${ZAP_VERSION:-2.17.0}"
NGINX_VERSION="${NGINX_VERSION:-1.27-alpine}"

ARTIFACTS_DIR="${ARTIFACTS_DIR:-artifacts}"
MOCK_APP_DIR="${MOCK_APP_DIR:-mock-app}"
ZAP_PORT="${ZAP_PORT:-4200}"
CLEAN="${CLEAN:-false}"
SKIP_BUILD="${SKIP_BUILD:-false}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_PATH="${REPO_ROOT}/${ARTIFACTS_DIR}"
MOCK_APP_PATH="${REPO_ROOT}/${MOCK_APP_DIR}"

log() {
    local level="${2:-INFO}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] $1"
}

run_in_docker() {
    local image="$1"
    local command="$2"
    local volumes=("${@:3}")
    local workdir="${WORKDIR:-/app}"
    local name="${NAME:-}"
    local use_shell="${USE_SHELL:-true}"

    local volume_args=()
    for vol in "${volumes[@]}"; do
        volume_args+=("-v" "$vol")
    done

    local name_arg=()
    [[ -n "$name" ]] && name_arg=("--name" "$name")

    local cmd
    if [[ "$use_shell" == "true" ]]; then
        cmd=(docker run --rm "${name_arg[@]}" -w "$workdir" "${volume_args[@]}" "$image" sh -c "$command")
    else
        # Split command into array (simple space split, sufficient for our use case)
        read -ra cmd_parts <<< "$command"
        cmd=(docker run --rm "${name_arg[@]}" -w "$workdir" "${volume_args[@]}" "$image" "${cmd_parts[@]}")
    fi
    log "Running: ${cmd[*]}"
    "${cmd[@]}"
}

start_zap_target() {
    local mock_app_dir="$1"
    local port="$2"
    log "Building and starting Angular app for ZAP scan on port $port..."
    local image_name="mock-app:zap-target"
    docker build -t "$image_name" "$mock_app_dir"
    local container_id
    # Use --rm so container is auto-removed when stopped
    container_id=$(docker run -d --rm -p "${port}:80" --name "mock-app-zap" "$image_name")
    log "Started container $container_id on port $port"
    sleep 5
    echo "$container_id"
}

stop_zap_target() {
    local container_id="$1"
    if [[ -n "$container_id" ]]; then
        log "Stopping ZAP target container..."
        docker stop "$container_id" >/dev/null 2>&1 || true
        # Container with --rm is auto-removed on stop
    fi
}

# Trap to ensure cleanup on script exit (success or error)
cleanup() {
    if [[ -n "${zap_container_id:-}" ]]; then
        stop_zap_target "$zap_container_id"
    fi
}
trap cleanup EXIT INT TERM

main() {
    if [[ "$CLEAN" == "true" ]]; then
        log "Cleaning artifacts directory..."
        rm -rf "$ARTIFACTS_PATH"
        docker image prune -f >/dev/null
        log "Clean complete."
        exit 0
    fi

    mkdir -p "$ARTIFACTS_PATH"

    log "=========================================="
    log "Starting Security Scanner Orchestration"
    log "=========================================="

    # 1. npq - Malicious package check
    log ""
    log "===== 1/5: npq (Malicious Package Check) ====="
    if run_in_docker "node:${NODE_VERSION}" \
        "cd /app && npx -y npq --format=sarif > /out/npq.sarif" \
        "${MOCK_APP_PATH}:/app" "${ARTIFACTS_PATH}:/out" \
        --name "npq-scanner"; then
        log "npq scan completed. Report: ${ARTIFACTS_PATH}/npq.sarif"
    else
        log "npq scan failed" "ERROR"
    fi

    # 2. semgrep - SAST with OWASP Top 10
    log ""
    log "===== 2/5: semgrep (SAST - OWASP Top 10) ====="
    if run_in_docker "semgrep/semgrep:${SEMGREP_VERSION}" \
        "semgrep scan --config=p/owasp-top-ten --sarif --output=/out/semgrep.sarif /src" \
        "${MOCK_APP_PATH}:/src" "${ARTIFACTS_PATH}:/out" \
        --workdir "/src" --name "semgrep-scanner"; then
        log "semgrep scan completed. Report: ${ARTIFACTS_PATH}/semgrep.sarif"
    else
        log "semgrep scan failed" "ERROR"
    fi

    # 3. trivy fs - Filesystem scanning
    log ""
    log "===== 3/5: trivy fs (Filesystem Scan) ====="
    if USE_SHELL=false run_in_docker "aquasec/trivy:${TRIVY_VERSION}" \
        "fs --format sarif --output /out/trivy-fs.sarif --scanners vuln,misconfig,secret,license /scan" \
        "${MOCK_APP_PATH}:/scan" "${ARTIFACTS_PATH}:/out" \
        --name "trivy-fs-scanner"; then
        log "trivy fs scan completed. Report: ${ARTIFACTS_PATH}/trivy-fs.sarif"
    else
        log "trivy fs scan failed" "ERROR"
    fi

    # 4. trivy image - Container scanning
    if [[ "$SKIP_BUILD" != "true" ]]; then
        log ""
        log "===== 4/5: Building mock app container image ====="
        if docker build -t mock-app:test "$MOCK_APP_PATH"; then
            log "Container image built: mock-app:test"
        else
            log "Container build failed" "ERROR"
        fi
    fi

    log ""
    log "===== 4/5: trivy image (Container Scan) ====="
    if USE_SHELL=false run_in_docker "aquasec/trivy:${TRIVY_VERSION}" \
        "image --format sarif --output /out/trivy-container.sarif mock-app:test" \
        "/var/run/docker.sock:/var/run/docker.sock" "${ARTIFACTS_PATH}:/out" \
        --name "trivy-container-scanner"; then
        log "trivy container scan completed. Report: ${ARTIFACTS_PATH}/trivy-container.sarif"
    else
        log "trivy container scan failed" "ERROR"
    fi

    # 5. OWASP ZAP - DAST baseline scan
    log ""
    log "===== 5/5: OWASP ZAP (DAST Baseline Scan) ====="
    zap_container_id=""
    if zap_container_id=$(start_zap_target "$MOCK_APP_PATH" "$ZAP_PORT"); then
        log "Waiting for app to be ready..."
        sleep 10

        if USE_SHELL=false run_in_docker "zaproxy/zap-stable:${ZAP_VERSION}" \
            "zap-baseline.py -t http://host.docker.internal:${ZAP_PORT} -r zap-report.html -J zap-report.json -x zap-report.xml" \
            "${ARTIFACTS_PATH}:/zap/wrk:rw" \
            --workdir "/zap/wrk" --name "zap-scanner"; then
            log "ZAP scan completed. Reports: ${ARTIFACTS_PATH}/zap-report.*"
        else
            log "ZAP scan failed" "ERROR"
        fi
    else
        log "Failed to start ZAP target" "ERROR"
    fi

    # Summary
    log ""
    log "=========================================="
    log "Scanner Orchestration Complete"
    log "=========================================="
    log "Reports generated in: ${ARTIFACTS_PATH}"
    ls -la "$ARTIFACTS_PATH" | while read -r line; do
        log "  $line"
    done

    log ""
    log "Next steps:"
    log "  1. Start DefectDojo: docker compose -f infra/docker-compose.defectdojo.yml up -d"
    log "  2. Import reports: python scripts/import-to-defectdojo.py --wait"
    log "  3. View findings in DefectDojo UI at http://localhost:8080"
}

# Handle arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean) CLEAN=true ;;
        --skip-build) SKIP_BUILD=true ;;
        --artifacts-dir) ARTIFACTS_DIR="$2"; shift ;;
        --mock-app-dir) MOCK_APP_DIR="$2"; shift ;;
        --zap-port) ZAP_PORT="$2"; shift ;;
        *) log "Unknown option: $1" "ERROR"; exit 1 ;;
    esac
    shift
done

main