#!/usr/bin/env python3
"""
DefectDojo API v2 Import Script

Imports SARIF/JSON scanner reports into DefectDojo via the REST API.
Creates Product, Engagement, and Test objects, then uploads findings.

Usage:
    python scripts/import-to-defectdojo.py [--host HOST] [--api-key KEY] [--artifacts-dir DIR]

Environment variables:
    DEFECTDOJO_HOST - DefectDojo URL (default: http://localhost:8080)
    DEFECTDOJO_API_KEY - API v2 key (get from DefectDojo UI > API Tokens)
    ARTIFACTS_DIR - Directory containing scanner reports (default: artifacts)

Architecture:
    This script uses DefectDojo API v2 to:
    1. Create/find Product → Engagement → Test hierarchy
    2. POST each scanner report to /api/v2/import-scan/ as multipart/form-data
    3. DefectDojo's ImportScanView processes the upload:
       - Validates via ImportScanSerializer
       - Uses AutoCreateContextManager for auto-creation
       - Delegates to parser based on scan_type (SARIF, ZAP, etc.)
       - Creates Finding objects linked to the Test

Supported scan types:
    - SARIF 2.1.0 (Semgrep, Trivy, npq)
    - ZAP Scan (ZAP XML report)
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Any

import requests
from requests.auth import HTTPBasicAuth


class DefectDojoClient:
    """Client for DefectDojo API v2.

    Handles authentication (API key or basic auth) and provides
    methods for CRUD operations on Products, Engagements, Tests,
    and importing scan reports via /import-scan/ endpoint.
    """

    def __init__(self, host: str, api_key: str = None, username: str = None, password: str = None):
        self.host = host.rstrip('/')
        self.api_url = f"{self.host}/api/v2"
        self.session = requests.Session()

        if api_key:
            self.session.headers.update({"Authorization": f"Token {api_key}"})
        elif username and password:
            self.session.auth = HTTPBasicAuth(username, password)
        else:
            raise ValueError("Either api_key or username/password required")

        self.session.headers.update({"Content-Type": "application/json"})

    def _request(self, method: str, endpoint: str, **kwargs) -> requests.Response:
        url = f"{self.api_url}{endpoint}"
        response = self.session.request(method, url, **kwargs)
        if response.status_code >= 400:
            raise RuntimeError(f"API error {response.status_code}: {response.text}")
        return response

    def get(self, endpoint: str, params: dict = None) -> dict:
        return self._request("GET", endpoint, params=params).json()

    def post(self, endpoint: str, data: dict = None, files: dict = None, json_data: dict = None) -> dict:
        if files:
            headers = dict(self.session.headers)
            headers.pop("Content-Type", None)
            response = self.session.post(f"{self.api_url}{endpoint}", data=data, files=files, headers=headers)
        else:
            response = self._request("POST", endpoint, json=json_data)
        return response.json()

    def put(self, endpoint: str, json_data: dict = None) -> dict:
        return self._request("PUT", endpoint, json=json_data).json()

    # Product operations
    def create_product(self, name: str, description: str = "") -> dict:
        return self.post("/products/", json_data={
            "name": name,
            "description": description,
            "prod_type": 1
        })

    def get_product(self, name: str) -> dict:
        result = self.get("/products/", params={"name": name})
        if result["count"] > 0:
            return result["results"][0]
        return None

    def get_or_create_product(self, name: str, description: str = "") -> dict:
        product = self.get_product(name)
        if product:
            print(f"  Using existing product: {name} (ID: {product['id']})")
            return product
        print(f"  Creating product: {name}")
        return self.create_product(name, description)

    # Engagement operations
    def create_engagement(self, product_id: int, name: str, description: str = "") -> dict:
        return self.post("/engagements/", json_data={
            "product": product_id,
            "name": name,
            "description": description,
            "status": "In Progress",
            "target_start": time.strftime("%Y-%m-%d"),
            "target_end": time.strftime("%Y-%m-%d", time.localtime(time.time() + 86400 * 30))
        })

    def get_engagement(self, product_id: int, name: str) -> dict:
        result = self.get("/engagements/", params={"product": product_id, "name": name})
        if result["count"] > 0:
            return result["results"][0]
        return None

    def get_or_create_engagement(self, product_id: int, name: str, description: str = "") -> dict:
        engagement = self.get_engagement(product_id, name)
        if engagement:
            print(f"  Using existing engagement: {name} (ID: {engagement['id']})")
            return engagement
        print(f"  Creating engagement: {name}")
        return self.create_engagement(product_id, name, description)

    # Test operations
    def create_test(self, engagement_id: int, test_type: int, title: str = None) -> dict:
        return self.post("/tests/", json_data={
            "engagement": engagement_id,
            "test_type": test_type,
            "title": title or f"Scan {time.strftime('%Y-%m-%d %H:%M')}",
            "target_start": time.strftime("%Y-%m-%d"),
            "target_end": time.strftime("%Y-%m-%d"),
            "tags": ["automated", "poc"]
        })

    

    # Import scan
    def import_scan(self, test_id: int, scan_type: str, file_path: Path,
                    minimum_severity: str = "Info", active: bool = True,
                    verified: bool = False, close_old_findings: bool = False) -> dict:
        with open(file_path, "rb") as f:
            files = {"file": (file_path.name, f, "application/json")}
            data = {
                "scan_type": scan_type,
                "minimum_severity": minimum_severity,
                "active": str(active).lower(),
                "verified": str(verified).lower(),
                "close_old_findings": str(close_old_findings).lower(),
                "scan_date": time.strftime("%Y-%m-%d"),
                "tags": "automated,poc"
            }
            return self._request("POST", f"/import-scan/", data=data, files=files).json()

    # Test types
    def get_test_types(self) -> list:
        result = self.get("/test_types/")
        return result["results"]


SCANNER_CONFIG = [
    {
        "tool_name": "npq",
        "file_pattern": "npq.sarif",
        "scan_type": "SARIF",
        "description": "Malicious package detection (npq)"
    },
    {
        "tool_name": "semgrep",
        "file_pattern": "semgrep.sarif",
        "scan_type": "SARIF",
        "description": "SAST - OWASP Top 10 (Semgrep)"
    },
    {
        "tool_name": "trivy-fs",
        "file_pattern": "trivy-fs.sarif",
        "scan_type": "SARIF",
        "description": "Filesystem scan (Trivy)"
    },
    {
        "tool_name": "trivy-container",
        "file_pattern": "trivy-container.sarif",
        "scan_type": "SARIF",
        "description": "Container image scan (Trivy)"
    },
    {
        "tool_name": "owasp-zap",
        "file_pattern": "zap-report.json",
        "scan_type": "ZAP Scan",
        "description": "DAST baseline scan (OWASP ZAP)"
    }
]


def wait_for_defectdojo(host: str, timeout: int = 180) -> bool:
    """Wait for DefectDojo to be ready."""
    print(f"Waiting for DefectDojo at {host}...")
    start = time.time()
    while time.time() - start < timeout:
        try:
            response = requests.get(f"{host}/login", timeout=5)
            if response.status_code == 200:
                print("DefectDojo is ready!")
                return True
        except requests.RequestException:
            pass
        time.sleep(3)
    return False


def main():
    parser = argparse.ArgumentParser(description="Import scanner reports to DefectDojo")
    parser.add_argument("--host", default=os.getenv("DEFECTDOJO_HOST", "http://localhost:8080"),
                        help="DefectDojo host URL")
    parser.add_argument("--api-key", default=os.getenv("DEFECTDOJO_API_KEY"),
                        help="API v2 token (from DefectDojo UI)")
    parser.add_argument("--username", default=os.getenv("DEFECTDOJO_USER", "admin"),
                        help="Username for basic auth")
    parser.add_argument("--password", default=os.getenv("DEFECTDOJO_PASS", "admin"),
                        help="Password for basic auth")
    parser.add_argument("--artifacts-dir", default=os.getenv("ARTIFACTS_DIR", "artifacts"),
                        help="Directory containing scanner reports")
    parser.add_argument("--product-name", default="DefectDojo PoC App",
                        help="Product name in DefectDojo")
    parser.add_argument("--engagement-name", default="PoC Scan Run",
                        help="Engagement name in DefectDojo")
    parser.add_argument("--wait", action="store_true",
                        help="Wait for DefectDojo to be ready before importing")
    args = parser.parse_args()

    artifacts_path = Path(args.artifacts_dir).resolve()
    if not artifacts_path.exists():
        print(f"Error: Artifacts directory not found: {artifacts_path}")
        sys.exit(1)

    if args.wait:
        if not wait_for_defectdojo(args.host):
            print("Error: DefectDojo not ready after timeout")
            sys.exit(1)

    # Initialize client
    client = DefectDojoClient(
        host=args.host,
        api_key=args.api_key,
        username=args.username,
        password=args.password
    )

    # Verify connection
    try:
        client.get("/products/", params={"limit": 1})
        print(f"Connected to DefectDojo at {args.host}")
    except Exception as e:
        print(f"Error connecting to DefectDojo: {e}")
        sys.exit(1)

    # Get or create product
    product = client.get_or_create_product(args.product_name, "Mock application for DefectDojo PoC")

    # Get or create engagement
    engagement = client.get_or_create_engagement(product["id"], args.engagement_name,
                                                  "Automated security scan run for PoC demonstration")

    # Get test types to find scan type IDs
    test_types = {tt["name"]: tt["id"] for tt in client.get_test_types()}
    print(f"Available test types: {list(test_types.keys())}")

    # Process each scanner
    print("\nImporting scanner reports...")
    for scanner in SCANNER_CONFIG:
        file_path = artifacts_path / scanner["file_pattern"]
        if not file_path.exists():
            print(f"  Skipping {scanner['tool_name']}: {file_path} not found")
            continue

        print(f"  Importing {scanner['tool_name']} ({scanner['description']})...")

        # Create test - use first available test type since SARIF might not be listed
        test_type_id = test_types.get(scanner["scan_type"])
        if not test_type_id:
            print(f"    Warning: Test type '{scanner['scan_type']}' not found, using first available")
            test_type_id = list(test_types.values())[0]

        test = client.create_test(engagement["id"], test_type_id,
                                   title=f"{scanner['tool_name']} - {time.strftime('%Y-%m-%d')}")

        # Import scan
        try:
            result = client.import_scan(
                test_id=test["id"],
                scan_type=scanner["scan_type"],
                file_path=file_path
            )
            print(f"    Success: Imported {result.get('findings', 0)} findings "
                  f"({result.get('new_findings', 0)} new, {result.get('closed_findings', 0)} closed)")
        except Exception as e:
            print(f"    Error importing {scanner['tool_name']}: {e}")

    print("\nImport complete!")
    print(f"View findings at: {args.host}/product/{product['id']}")


if __name__ == "__main__":
    main()