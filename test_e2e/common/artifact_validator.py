"""
Artifact Validator for SmartLocker E2E Testing.
Validates manuscript backups, CSV/JSON/JSONL raw evidence schema,
evaluation metrics, BibTeX literature citations, and LaTeX paper source.
"""

import os
import re
import csv
import json
import hashlib
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple
from .assertion_framework import get_workspace_root


class ArtifactValidator:
    """Opaque-box validator for file artifacts, schemas, checksums, and manuscripts."""

    def __init__(self, workspace_root: Optional[Path] = None):
        self.workspace_root = workspace_root or get_workspace_root()

    @staticmethod
    def sha256_file(path: Path | str) -> str:
        """Compute hex SHA-256 digest of a file."""
        p = Path(path)
        h = hashlib.sha256()
        with open(p, "rb") as f:
            while chunk := f.read(65536):
                h.update(chunk)
        return h.hexdigest().lower()

    def verify_backup_file(self, original_rel: str, backup_rel: str) -> bool:
        """Verify backup file exists and matches original bit-for-bit."""
        orig = self.workspace_root / original_rel
        back = self.workspace_root / backup_rel
        if not orig.is_file() or not back.is_file():
            return False
        return self.sha256_file(orig) == self.sha256_file(back)

    @staticmethod
    def validate_csv_headers(path: Path | str, required_headers: List[str]) -> Tuple[bool, List[str]]:
        """Verify CSV file contains required column headers."""
        p = Path(path)
        if not p.is_file():
            return False, []
        with open(p, "r", encoding="utf-8", errors="ignore") as f:
            reader = csv.reader(f)
            headers = next(reader, [])
        cleaned = [h.strip() for h in headers]
        missing = [rh for rh in required_headers if rh not in cleaned]
        return len(missing) == 0, missing

    @staticmethod
    def validate_json_schema(path: Path | str, required_keys: List[str]) -> Tuple[bool, List[str]]:
        """Verify JSON file contains required top-level keys."""
        p = Path(path)
        if not p.is_file():
            return False, required_keys
        with open(p, "r", encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, dict):
            return False, ["(root is not a dict)"]
        missing = [k for k in required_keys if k not in data]
        return len(missing) == 0, missing

    @staticmethod
    def validate_jsonl_records(path: Path | str, required_keys: List[str]) -> Tuple[bool, int]:
        """Verify each line in JSONL is valid JSON and contains required keys."""
        p = Path(path)
        if not p.is_file():
            return False, 0
        valid_count = 0
        with open(p, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                record = json.loads(line)
                if not isinstance(record, dict):
                    return False, valid_count
                for rk in required_keys:
                    if rk not in record:
                        return False, valid_count
                valid_count += 1
        return True, valid_count

    @staticmethod
    def validate_confusion_matrix(tp: int, fp: int, tn: int, fn: int) -> Dict[str, float]:
        """Compute standard evaluation metrics from confusion matrix components."""
        total = tp + fp + tn + fn
        precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
        recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0
        specificity = tn / (tn + fp) if (tn + fp) > 0 else 0.0
        f1 = (2 * precision * recall) / (precision + recall) if (precision + recall) > 0 else 0.0
        balanced_acc = (recall + specificity) / 2.0
        fpr = fp / (fp + tn) if (fp + tn) > 0 else 0.0
        fnr = fn / (fn + tp) if (fn + tp) > 0 else 0.0

        return {
            "total": total,
            "precision": round(precision, 4),
            "recall": round(recall, 4),
            "specificity": round(specificity, 4),
            "f1": round(f1, 4),
            "balanced_acc": round(balanced_acc, 4),
            "fpr": round(fpr, 4),
            "fnr": round(fnr, 4),
        }

    def validate_bibtex_dois(self, bib_path: Path | str) -> Dict[str, Any]:
        """Extract and check DOIs and publication years from a BibTeX file."""
        p = Path(bib_path)
        if not p.is_file():
            return {"entry_count": 0, "dois": [], "years": [], "invalid_dois": []}

        content = p.read_text(encoding="utf-8", errors="ignore")
        entries = re.findall(r"@\w+\s*\{([^,]+),", content)
        doi_matches = re.findall(r"doi\s*=\s*[\"{]([^\n\"}]+)[\"}]", content, re.IGNORECASE)
        year_matches = re.findall(r"year\s*=\s*[\"{](\d{4})[\"}]", content, re.IGNORECASE)

        doi_pattern = re.compile(r"^10\.\d{4,9}/[-._;()/:A-Za-z0-9]+$")
        invalid_dois = [d.strip() for d in doi_matches if not doi_pattern.match(d.strip())]

        return {
            "entry_count": len(entries),
            "dois": [d.strip() for d in doi_matches],
            "years": [int(y) for y in year_matches],
            "invalid_dois": invalid_dois,
        }

    def inspect_manuscript_latex(self, tex_path: Path | str) -> Dict[str, Any]:
        """Inspect LaTeX manuscript for key author, ORCID, and section requirements."""
        p = Path(tex_path)
        if not p.is_file():
            return {"exists": False}

        content = p.read_text(encoding="utf-8", errors="ignore")
        has_author = bool(re.search(r"Duc\s+Hoang\s+Nguyen", content, re.IGNORECASE)) or "Nguyen Duc Hoang" in content
        has_email = "duchoang.nguyen103@gmail.com" in content
        found_orcids = re.findall(r"\b\d{4}-\d{4}-\d{4}-\d{3}[\dX]\b", content)
        mandated_orcid = "0009-0006-9780-8146"
        has_orcid = mandated_orcid in found_orcids or mandated_orcid in content
        is_ieeetran = "IEEEtran" in content
        sections = re.findall(r"\\section\{([^}]+)\}", content)
        rqs = re.findall(r"RQ\d+", content)

        return {
            "exists": True,
            "has_author": has_author,
            "has_email": has_email,
            "has_orcid": has_orcid,
            "mandated_orcid": mandated_orcid,
            "found_orcids": found_orcids,
            "is_ieeetran": is_ieeetran,
            "sections": sections,
            "rq_count": len(set(rqs)),
            "affiliation_fpt": "FPT University" in content,
            "size_bytes": len(content.encode("utf-8")),
        }

    def validate_sessions_csv(
        self,
        path: Path | str,
        min_rows: int = 100,
        required_columns: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        """Validate experimental sessions.csv headers, row count, and data integrity."""
        p = Path(path)
        if not p.is_file():
            return {"valid": False, "exists": False, "row_count": 0, "errors": [f"File not found: {p}"]}

        req = required_columns or ["session_id", "device_id", "door_open_sec", "weight_delta_g", "rfid_ok", "stay_min"]
        errors = []
        rows = []
        with open(p, "r", encoding="utf-8", errors="ignore") as f:
            reader = csv.DictReader(f)
            headers = reader.fieldnames or []
            missing = [c for c in req if c not in headers]
            if missing:
                errors.append(f"Missing required headers: {missing}")
            for r in reader:
                rows.append(r)

        if len(rows) < min_rows:
            errors.append(f"Row count {len(rows)} < minimum {min_rows}")

        # Check session_id uniqueness
        session_ids = [r.get("session_id") for r in rows if "session_id" in r]
        if len(session_ids) != len(set(session_ids)):
            errors.append("Duplicate session_id values found in sessions.csv")

        return {
            "valid": len(errors) == 0,
            "exists": True,
            "row_count": len(rows),
            "headers": headers,
            "errors": errors,
        }

    def validate_ground_truth_labels_csv(
        self,
        path: Path | str,
        min_rows: int = 100,
        min_per_category: int = 20,
    ) -> Dict[str, Any]:
        """Validate ground_truth_labels.csv stratification across the 5 mandated categories."""
        p = Path(path)
        if not p.is_file():
            return {"valid": False, "exists": False, "total": 0, "errors": [f"File not found: {p}"]}

        mandated_categories = {
            "NORMAL_AUTHORIZED",
            "UNAUTHORIZED_CREDENTIAL",
            "FORCED_DOOR_OPEN",
            "LOAD_OR_TAMPER_ANOMALY",
            "SENSOR_FAULT",
        }
        counts = {c: 0 for c in mandated_categories}
        errors = []
        total = 0
        with open(p, "r", encoding="utf-8", errors="ignore") as f:
            reader = csv.DictReader(f)
            headers = reader.fieldnames or []
            cat_col = "category" if "category" in headers else "label"
            for idx, r in enumerate(reader, start=1):
                total += 1
                cat = r.get(cat_col, "").strip()
                if cat in counts:
                    counts[cat] += 1
                else:
                    errors.append(f"Row {idx}: unknown category {cat}")

        if total < min_rows:
            errors.append(f"Total labels {total} < minimum {min_rows}")

        under_quota = {cat: cnt for cat, cnt in counts.items() if cnt < min_per_category}
        if under_quota:
            for cat, cnt in under_quota.items():
                errors.append(f"Category {cat} count {cnt} < minimum quota {min_per_category}")

        return {
            "valid": len(errors) == 0,
            "exists": True,
            "total": total,
            "category_counts": counts,
            "under_quota": under_quota,
            "errors": errors,
        }

    def validate_execution_summary_json(self, path: Path | str, min_total: int = 100) -> Dict[str, Any]:
        """Validate execution_summary.json schema and arithmetic consistency."""
        p = Path(path)
        if not p.is_file():
            return {"valid": False, "exists": False, "errors": [f"File not found: {p}"]}
        try:
            with open(p, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception as e:
            return {"valid": False, "exists": True, "errors": [f"Invalid JSON: {e}"]}

        errors = []
        for k in ["total", "passed", "failed", "blocked"]:
            if k not in data:
                errors.append(f"Missing required summary key: {k}")

        if not errors:
            total = data["total"]
            p_c, f_c, b_c = data["passed"], data["failed"], data["blocked"]
            if total < min_total:
                errors.append(f"Total {total} < required minimum {min_total}")
            if p_c + f_c + b_c != total:
                errors.append(f"Summary count mismatch: passed({p_c}) + failed({f_c}) + blocked({b_c}) != total({total})")

        return {
            "valid": len(errors) == 0,
            "exists": True,
            "summary": data if not errors else {},
            "errors": errors,
        }

    def validate_metrics_summary_json(
        self,
        path: Path | str,
        required_campaigns: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        """Validate metrics_summary.json contains valid evaluation results for campaigns E1-E7."""
        p = Path(path)
        if not p.is_file():
            return {"valid": False, "exists": False, "errors": [f"File not found: {p}"]}
        try:
            with open(p, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception as e:
            return {"valid": False, "exists": True, "errors": [f"Invalid JSON: {e}"]}

        campaigns = required_campaigns or [
            "E1_Auth", "E2_Rules", "E3_Detection", "E4_Network",
            "E5_Audit", "E6_Consistency", "E7_Scalability"
        ]
        errors = []
        campaign_statuses = {}
        for c in campaigns:
            c_data = None
            for k, val in data.items():
                if k.lower() == c.lower() or k.lower().startswith(c[:2].lower()):
                    c_data = val
                    break
            if c_data is None:
                errors.append(f"Missing campaign results: {c}")
            elif isinstance(c_data, dict):
                st = c_data.get("status")
                campaign_statuses[c] = st
                if st not in ("PASS", "FAIL", "BLOCKED"):
                    errors.append(f"Campaign {c} invalid status: {st}")
            else:
                errors.append(f"Campaign {c} entry must be a dictionary")

        return {
            "valid": len(errors) == 0,
            "exists": True,
            "campaign_statuses": campaign_statuses,
            "errors": errors,
        }

    def validate_scopus_venues(
        self,
        path: Path | str,
        min_candidates: int = 15,
        primary_quota: int = 3,
        backup_quota: int = 3,
    ) -> Dict[str, Any]:
        """Validate conference venue candidate count and recommendations."""
        p = Path(path)
        if not p.is_file():
            return {"valid": False, "exists": False, "errors": [f"File not found: {p}"]}
        try:
            with open(p, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception as e:
            return {"valid": False, "exists": True, "errors": [f"Invalid JSON: {e}"]}

        venues = data if isinstance(data, list) else data.get("venues", [])
        errors = []
        if len(venues) < min_candidates:
            errors.append(f"Candidate venues {len(venues)} < minimum {min_candidates}")

        primaries = [v for v in venues if v.get("type") == "PRIMARY"]
        backups = [v for v in venues if v.get("type") == "BACKUP"]

        if len(primaries) != primary_quota:
            errors.append(f"Primary venues count {len(primaries)} != mandated {primary_quota}")
        if len(backups) != backup_quota:
            errors.append(f"Backup venues count {len(backups)} != mandated {backup_quota}")

        for v in primaries + backups:
            if not v.get("scopus_indexed"):
                errors.append(f"Recommended venue {v.get('name')} is not marked scopus_indexed")

        return {
            "valid": len(errors) == 0,
            "exists": True,
            "total_candidates": len(venues),
            "primary_venues": [v.get("name") for v in primaries],
            "backup_venues": [v.get("name") for v in backups],
            "errors": errors,
        }

    @staticmethod
    def calculate_wilson_ci(k: int, n: int, confidence: float = 0.95) -> Tuple[float, float]:
        """Calculate Wilson score interval for a binomial proportion."""
        import math
        if n == 0:
            return 0.0, 0.0
        # z for 95% confidence is ~1.96
        z = 1.959963984540054
        p_hat = k / n
        denominator = 1.0 + z * z / n
        centre = (p_hat + z * z / (2.0 * n)) / denominator
        spread = (z / denominator) * math.sqrt((p_hat * (1.0 - p_hat) / n) + (z * z / (4.0 * n * n)))
        lower = max(0.0, centre - spread)
        upper = min(1.0, centre + spread)
        return round(lower, 4), round(upper, 4)
