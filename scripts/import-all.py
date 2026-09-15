#!/usr/bin/env python3
"""Import all scanner reports to DefectDojo.

Usage:
    python scripts/import-all.py [--host HOST] [--username USER] [--password PASS]
                               [--artifacts-dir DIR] [--engagement-id ID]

Environment variables:
    DEFECTDOJO_HOST        - DefectDojo URL (default: http://localhost:8080)
    DEFECTDOJO_USER        - Username (default: admin)
    DEFECTDOJO_PASS        - Password (default: admin)
    ARTIFACTS_DIR          - Artifacts directory (default: artifacts)
    ENGAGEMENT_ID          - Engagement ID (default: 1)
"""

import argparse
import os
import sys
from pathlib import Path

import requests

DEFAULT_REPORTS = [
    ("npq", "npq.sarif", "SARIF"),
    ("semgrep", "semgrep.sarif", "SARIF"),
    ("trivy-fs", "trivy-fs.sarif", "SARIF"),
    ("trivy-container", "trivy-container.sarif", "SARIF"),
    ("owasp-zap", "zap-report.xml", "ZAP Scan"),
]


def parse_args():
    parser = argparse.ArgumentParser(description="Import scanner reports to DefectDojo")
    parser.add_argument("--host", default=os.getenv("DEFECTDOJO_HOST", "http://localhost:8080"),
                        help="DefectDojo host URL")
    parser.add_argument("--username", default=os.getenv("DEFECTDOJO_USER", "admin"),
                        help="Username for basic auth")
    parser.add_argument("--password", default=os.getenv("DEFECTDOJO_PASS", "admin"),
                        help="Password for basic auth")
    parser.add_argument("--artifacts-dir", default=os.getenv("ARTIFACTS_DIR", "artifacts"),
                        help="Directory containing scanner reports")
    parser.add_argument("--engagement-id", default=os.getenv("ENGAGEMENT_ID", "1"),
                        help="Engagement ID in DefectDojo")
    parser.add_argument("--reports", nargs="+",
                        help="Specific reports to import (default: all)")
    return parser.parse_args()


def import_reports(args):
    url = f"{args.host.rstrip('/')}/api/v2/import-scan/"
    auth = (args.username, args.password)
    artifacts_path = Path(args.artifacts_dir).resolve()

    reports = DEFAULT_REPORTS
    if args.reports:
        reports = [r for r in DEFAULT_REPORTS if r[0] in args.reports]

    for name, filename, scan_type in reports:
        filepath = artifacts_path / filename
        if not filepath.exists():
            print(f"{name}: SKIPPED - {filepath} not found")
            continue

        try:
            with open(filepath, "rb") as fp:
                files = {"file": fp}
                data = {
                    "scan_type": scan_type,
                    "engagement": args.engagement_id,
                    "scan_date": "2026-09-15",
                    "minimum_severity": "Info",
                    "auto_create_context": "false"
                }
                r = requests.post(url, files=files, data=data, auth=(args.username, args.password))
                stats = r.json().get("statistics", {}).get("after", {}).get("total", {}).get("total", 0)
                print(f"{name}: {r.status_code} - {stats} findings")
        except Exception as e:
            print(f"{name}: ERROR - {e}")


def main():
    args = parse_args()
    import_reports(args)


if __name__ == "__main__":
    main()