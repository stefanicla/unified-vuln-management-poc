# DefectDojo PoC — Security Scanner Aggregation

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![WSL](https://img.shields.io/badge/WSL-Compatible-0078D4?style=for-the-badge&logo=windows&logoColor=white)](https://docs.microsoft.com/en-us/windows/wsl/)
[![DefectDojo](https://img.shields.io/badge/DefectDojo-3.2.400-FF6B35?style=for-the-badge&logo=owasp&logoColor=white)](https://github.com/DefectDojo/django-DefectDojo)
[![Semgrep](https://img.shields.io/badge/Semgrep-Latest-2F80ED?style=for-the-badge&logo=semgrep&logoColor=white)](https://semgrep.dev/)
[![Trivy](https://img.shields.io/badge/Trivy-0.74.0-1904DA?style=for-the-badge&logo=trivy&logoColor=white)](https://github.com/aquasecurity/trivy)
[![OWASP ZAP](https://img.shields.io/badge/OWASP%20ZAP-2.17.0-5A2D82?style=for-the-badge&logo=owasp&logoColor=white)](https://www.zaproxy.org/)
[![GitLab CI](https://img.shields.io/badge/GitLab%20CI-Reference-FCA121?style=for-the-badge&logo=gitlab&logoColor=white)](https://docs.gitlab.com/ee/ci/)
[![SARIF](https://img.shields.io/badge/SARIF-2.1.0-4A90D9?style=for-the-badge&logo=oasis&logoColor=white)](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html)

> **TL;DR** — Run `bash scripts/setup-all.sh` in WSL. Opens DefectDojo at `http://localhost:8080` (admin/admin) with 130+ findings from 4 scanners.

---

## Overview

This project demonstrates how to aggregate security scanner results into **DefectDojo** (open source) for unified vulnerability management.

| Scanner | Category | Output | DefectDojo Scan Type | Findings |
|---------|----------|--------|---------------------|----------|
| **npq** | SCA — Malicious packages | SARIF | SARIF | 0* |
| **Semgrep** | SAST — OWASP Top 10 | SARIF | SARIF | 2 |
| **Trivy FS** | SCA/Secrets/Misconfig/License | SARIF | SARIF | 3 |
| **Trivy Image** | Container scanning | SARIF | SARIF | 120 |
| **OWASP ZAP** | DAST — Baseline | XML | ZAP Scan | 10 |

\* npq output is plain text (not SARIF) — skipped in import.

**Total: ~135 findings** from a deliberately vulnerable Angular application.

---

## Project Description

This Proof-of-Concept demonstrates how to aggregate findings from multiple security scanners into **DefectDojo** (open-source vulnerability management) for unified visibility, deduplication, and remediation tracking.

**Scanners integrated:** Semgrep (SAST, OWASP Top 10), Trivy (filesystem + container scanning), npq (malicious package detection), OWASP ZAP (DAST baseline).

**Key features:**
- One-command automated setup: `bash scripts/setup-all.sh`
- Pinned container images for reproducibility
- SARIF/XML report generation + DefectDojo API v2 import
- GitLab CI/CD reference pipeline with auto-create context
- Stakeholder demo script with talking points
- Deliberately vulnerable Angular app with 8 vulnerability classes

**Tech stack:** Docker, WSL2, DefectDojo 3.2.400, Semgrep, Trivy 0.74, ZAP 2.17

---

## Quick Start — One Command (Recommended)

```bash
# Clone, run everything, open DefectDojo with findings
git clone https://github.com/<your-org>/unified-vuln-management-poc.git
cd unified-vuln-management-poc

# Run complete automated setup (scanners + DefectDojo + import)
# Run in WSL terminal (Ubuntu):
bash scripts/setup-all.sh

# Open DefectDojo dashboard
# http://localhost:8080  (admin / admin)
```

## Quick Start — Manual Steps

If you prefer step-by-step control:

**From Windows PowerShell:**
```powershell
# 1. Clone and enter repository
git clone https://github.com/<your-org>/unified-vuln-management-poc.git
cd unified-vuln-management-poc

# 2. Run all scanners (generates reports in ./artifacts)
# Run in WSL terminal (Ubuntu):
wsl bash scripts/run-scanners.sh

# 3. Start DefectDojo stack
docker compose -f infra/docker-compose.defectdojo.yml up -d

# 4. Initialize database, create admin, import reports (automated)
# Run in WSL terminal (Ubuntu):
wsl bash scripts/setup-all.sh --skip-scanners  # if already ran step 2

# 5. Open DefectDojo UI
# http://localhost:8080 (login: admin / admin)
```

---

## Stakeholder Demo

```bash
# Show key URLs and demo flow for stakeholder presentation
# Run in WSL terminal (Ubuntu):
bash scripts/stakeholder-demo.sh

# From Windows PowerShell:
wsl bash scripts/stakeholder-demo.sh

# Quick demo URLs:
# Dashboard:      http://localhost:8080
# Product view:   http://localhost:8080/product/1
# Engagement:     http://localhost:8080/engagement/1
# All findings:   http://localhost:8080/finding?test=1&o=-severity
```

### Suggested 10-Minute Demo Flow

1. **Dashboard (1 min)** → `http://localhost:8080` — "Single pane of glass"
2. **Product View (2 min)** → `http://localhost:8080/product/1` — Engagement timeline, findings trend
3. **Engagement View (2 min)** → `http://localhost:8080/engagement/1` — Test list with scanner names
4. **Test Views — Scanner Deep Dive (3 min)** — SAST, SCA, Container, DAST findings
5. **Findings Table (2 min)** → Filter by severity, Verify/Close, Export CSV

---

## Project Structure

```
unified-vuln-management-poc/
├── mock-app/                      # Deliberately vulnerable Angular app
│   ├── package.json               # Malicious deps: lodash@4.17.20, axios@0.21.1, etc.
│   ├── Dockerfile                 # Multi-stage build (nginx:1.27-alpine base)
│   ├── nginx.conf                 # Missing security headers (for ZAP)
│   ├── .env.example               # Hardcoded secrets (for Trivy secret scanning)
│   └── src/app/app.component.ts   # 8 vulnerability demos
├── infra/
│   └── docker-compose.defectdojo.yml  # Full DefectDojo stack (pinned v3.2.400)
├── scripts/
│   ├── setup-all.sh               # 🆕 Complete automated setup (scanners + DefectDojo + import)
│   ├── run-scanners.sh            # Orchestrates all 5 Docker-based scanners (run in WSL)
│   ├── run-scanners.ps1           # PowerShell version (legacy)
│   ├── import-to-defectdojo.py    # Full-featured import with auto-create (legacy)
│   ├── import-all.py              # 🆕 Quick import of all artifact reports
│   └── stakeholder-demo.sh        # 🆕 Demo URLs & talking points for stakeholders
├── artifacts/                     # Generated reports (gitignored)
├── .gitlab-ci.yml                 # GitLab CI reference pipeline
├── LICENSE                        # MIT License
├── CONTRIBUTING.md                # Contribution guidelines
├── SECURITY.md                    # Security policy
└── README.md
```

---

## Vulnerabilities in Mock App

The Angular app (`mock-app/src/app/app.component.ts`) contains intentional findings:

| Vulnerability | Location | Detected By |
|---------------|----------|-------------|
| SQL Injection | `sqlInjection()` — string concat in query | Semgrep |
| Reflected XSS | `reflectedXss()` — `[innerHTML]` with user input | Semgrep, ZAP |
| Path Traversal | `pathTraversal()` — unsanitized filename | Semgrep |
| Hardcoded Secrets | `API_KEY`, `DB_PASSWORD`, `STRIPE_KEY` constants | Trivy FS, Semgrep |
| JWT Weak Secret | Hardcoded `JWT_SECRET` used for verification | Semgrep |
| Prototype Pollution | `Object.assign(Object.prototype, ...)` | Semgrep |
| Weak Randomness | `Math.random()` for security tokens | Semgrep |
| Command Injection | `ping` command with user input | Semgrep |
| Vulnerable Dependencies | `lodash@4.17.20`, `axios@0.21.1` | Trivy FS |
| Container Vulnerabilities | `nginx:1.27-alpine` base image (120 CVEs) | Trivy Image |
| Missing Security Headers | No CSP, HSTS, X-Content-Type-Options | ZAP |

---

## Architecture — How Integration Works

```
┌─────────────────┐     ┌──────────────────┐     ┌──────────────────┐     ┌──────────────┐
│  Mock App       │     │  Scanners        │     │  Artifacts Dir   │     │  DefectDojo  │
│  (Source Code,  │────▶│  (npq, Semgrep,  │────▶│  (SARIF, JSON,   │────▶│  API v2      │
│   Dockerfile,   │     │   Trivy, ZAP)    │     │   XML)           │     │  /import-scan│
│   .env.example) │     │                  │     │                  │     │              │
└─────────────────┘     └──────────────────┘     └──────────────────┘     └──────┬───────┘
                                                                                 │
                          ┌──────────────────────────────────────────────────────┘
                          ▼
                ┌──────────────────┐
                │  DefectDojo DB   │
                │  (PostgreSQL)    │
                │  Products,       │
                │  Engagements,    │
                │  Tests, Findings │
                └──────────────────┘
```

### Integration Flow

1. **Scanner Execution** (`scripts/run-scanners.sh`)
   - Each scanner runs in its own Docker container (pinned versions)
   - Source code/Dockerfile mounted read-only
   - Reports written to `artifacts/` as SARIF (industry standard) or native JSON/XML

2. **Report Standardization**
   - SAST/SCA tools output **SARIF 2.1.0** (Semgrep, Trivy)
   - DAST tool (ZAP) outputs native XML + JSON/HTML
   - SARIF enables consistent parsing across different tool vendors

3. **DefectDojo Import** (`scripts/import-all.py` via API v2)
   - Creates/finds **Product** → **Engagement** → **Test** hierarchy
   - POSTs each report to `/api/v2/import-scan/` as multipart/form-data
   - DefectDojo's `ImportScanView` processes the upload:
     - Validates via `ImportScanSerializer`
     - Delegates to parser based on `scan_type` (SARIF, ZAP, etc.)
     - Creates `Finding` objects linked to the `Test`

4. **Finding Lifecycle in DefectDojo**
   - Findings are deduplicated (configurable per engagement/product)
   - SLA tracking starts based on severity
   - Notifications triggered (Slack, email, Jira, etc.)
   - Risk acceptance, verification, mitigation workflows available

### Key Integration Points

| Component | Role | Technology |
|-----------|------|------------|
| Scanner Containers | Isolated, reproducible execution | Docker (pinned versions) |
| SARIF Format | Universal exchange format | OASIS standard |
| DefectDojo API v2 | Programmatic import | REST, multipart/form-data |
| AutoCreateContextManager | Handles product/engagement lookup/creation | Django ORM |
| Parser Registry | Maps scan_type → parser class | Plugin architecture |

---

## Production Deployment — GitLab CI/CD

See `.gitlab-ci.yml` for a reference pipeline. Key differences from local PoC:

| Aspect | PoC (Local) | Production (GitLab CI) |
|--------|-------------|------------------------|
| **Report storage** | Local `artifacts/` | GitLab CI artifacts (expire: 30d) |
| **Import trigger** | Manual script | Automated CI job |
| **Auth** | Basic auth (admin/admin) | **API v2 Token** (Project > Settings > API Tokens) |
| **Correlation** | Manual product/engagement | Auto via `auto_create_context` + GitLab vars |
| **Deduplication** | Per-run | **Cross-run** (same engagement) |
| **Secrets** | Hardcoded in script | **CI/CD Variables** (masked/protected) |

### Required GitLab CI/CD Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DEFECTDOJO_HOST` | DefectDojo URL | `https://defectdojo.company.com` |
| `DEFECTDOJO_API_KEY` | API v2 token (Project > Settings > API Tokens) | `dd_v2_xxxxx...` |
| `DEFECTDOJO_PRODUCT` | Product name in DefectDojo | `My Web App` |
| `DEFECTDOJO_ENGAGEMENT` | Engagement name (branch/tag) | `$CI_COMMIT_REF_NAME` |
| `DEFECTDOJO_PRODUCT_TYPE` | Product type (must exist) | `Web Application` |

---

## Scripts Reference

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `scripts/setup-all.sh` | **Complete automated setup** — scanners + DefectDojo + DB init + admin + import | **First run** — one command does everything |
| `scripts/run-scanners.sh` | Runs all 5 scanners via Docker, outputs to `artifacts/` | Re-run scans after code changes |
| `scripts/import-all.py` | Imports all reports from `artifacts/` to existing DefectDojo | After re-running scanners |
| `scripts/stakeholder-demo.sh` | Prints demo URLs, flow, talking points for stakeholders | Before stakeholder demo |
| `scripts/run-scanners.ps1` | PowerShell version of scanner orchestrator (legacy) | Windows without WSL |
| `scripts/import-to-defectdojo.py` | Full-featured import with auto-create (legacy) | Advanced use cases |

---

## Image Versions (Pinned for Reproducibility)

| Component | Version | Source |
|-----------|---------|--------|
| DefectDojo Django | `3.2.400` | [Docker Hub](https://hub.docker.com/r/defectdojo/defectdojo-django/tags) |
| DefectDojo Nginx | `latest` | No versioned tags available |
| PostgreSQL | `15-alpine` | PostgreSQL 15 LTS |
| Redis | `7-alpine` | Redis 7 LTS |
| Node (scanners) | `20.18.0-alpine` | Node.js 20 LTS |
| Node (build) | `18.20.0-alpine` | Node.js 18 LTS |
| Semgrep | `semgrep/semgrep:latest` | [Official](https://hub.docker.com/r/semgrep/semgrep) |
| Trivy | `0.74.0` | [Aqua Security](https://hub.docker.com/r/aquasec/trivy/tags) |
| OWASP ZAP | `2.17.0` | [ZAP Stable](https://hub.docker.com/r/zaproxy/zap-stable/tags) |
| Nginx (mock app) | `1.27-alpine` | Nginx 1.27 stable |

> **Note:** Pinning versions ensures reproducibility. Update versions in `scripts/run-scanners.sh` and `infra/docker-compose.defectdojo.yml` when upgrading.

---

## Cleanup

```bash
# Stop DefectDojo and remove volumes
docker compose -f infra/docker-compose.defectdojo.yml down -v

# Remove scanner images
docker image prune -f

# Clean artifacts
bash scripts/run-scanners.sh --clean
```

---

## Troubleshooting

### DefectDojo not starting
```bash
# Check logs
docker compose -f infra/docker-compose.defectdojo.yml logs -f initializer
docker compose -f infra/docker-compose.defectdojo.yml logs -f uwsgi
```

### Import script fails
- Verify DefectDojo is fully initialized (check initializer logs for "spawned uWSGI worker")
- Ensure API key has correct permissions (Admin role)
- Check network connectivity from script host to DefectDojo

### ZAP scan finds nothing
- Ensure Angular app is accessible at `http://host.docker.internal:4200`
- Increase wait time in `run-scanners.sh` before ZAP runs
- Use `zap-full-scan.py` for more thorough (slower) scanning

### Semgrep no findings
- Verify `p/owasp-top-ten` config is available (requires internet for first run)
- Check TypeScript files are in `/src` mount path

---

## License

MIT — Free for any use.

---

## References

- [DefectDojo Documentation](https://defectdojo.github.io/)
- [DefectDojo Docker Compose](https://github.com/DefectDojo/django-DefectDojo/tree/master/docker)
- [Semgrep OWASP Top 10](https://semgrep.dev/p/owasp-top-ten)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [OWASP ZAP Baseline](https://www.zaproxy.org/docs/docker/baseline-scan/)
- [npq](https://github.com/lirantal/npq)
- [SARIF Specification](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html)

---

## Security

See [SECURITY.md](SECURITY.md) for responsible disclosure policy.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

**Built for demonstrating DevSecOps scanner aggregation with DefectDojo.** 🛡️
