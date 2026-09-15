# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest (main branch) | ✅ |

This is a Proof-of-Concept project. Only the latest version on the main branch receives security updates.

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability in this project, please report it responsibly.

### How to Report

**Do not** create a public GitHub issue for security vulnerabilities.

Instead, email us at: **security@your-domain.com** (replace with actual contact)

Include the following information:

1. **Description** of the vulnerability
2. **Steps to reproduce** (if applicable)
3. **Potential impact** assessment
5. **Suggested fix** (if you have one)

### What to Expect

- **Acknowledgment** within 48 hours
- **Initial assessment** within 7 days
- **Regular updates** on progress
- **Public disclosure** coordinated after fix is deployed

## Scope

This policy covers:

- Security vulnerabilities in the PoC codebase (scripts, Dockerfiles, Angular app)
- Container image vulnerabilities (we pin versions to mitigate)
- Docker Compose configuration issues

Out of scope:

- Upstream vulnerabilities in DefectDojo, Semgrep, Trivy, ZAP, etc. (report to respective projects)
- Vulnerabilities in the intentionally vulnerable mock application (by design)

## Known Limitations

This PoC intentionally includes a vulnerable application (`mock-app/`) for demonstration purposes. The following are **by design**, not vulnerabilities:

- Hardcoded secrets in `.env.example` and `app.component.ts`
- Missing security headers in `nginx.conf`
- Vulnerable dependencies in `package.json`
- Outdated nginx base image in `Dockerfile`

These are **intended** to generate findings for demonstration.

## Container Image Security

We pin all container images to specific versions:

| Component | Version | Update Frequency |
|-----------|---------|------------------|
| DefectDojo Django | 3.2.400 | Monthly |
| PostgreSQL | 15-alpine | Monthly |
| Redis | 7-alpine | Monthly |
| Semgrep | latest (official) | Weekly |
| Trivy | 0.74.0 | Monthly |
| OWASP ZAP | 2.17.0 | Per release |

Run `docker image prune -f` and rebuild periodically to pick up security patches.

## Responsible Disclosure Timeline

| Phase | Timeline |
|-------|----------|
| Acknowledgment | 48 hours |
| Initial assessment | 7 days |
| Fix development | 30 days (target) |
| Coordinated disclosure | After fix deployed |

We aim to follow [Coordinated Vulnerability Disclosure](https://en.wikipedia.org/wiki/Responsible_disclosure) best practices.

---

**Thank you for helping keep this project secure!** 🔒