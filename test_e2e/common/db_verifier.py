"""
Database Verifier Utility for SmartLocker E2E Testing.
Validates SQL migrations (01_schema.sql through 05_auto_checkin.sql),
verifies schema definitions for tables, procedures, and safety guards (SL_* convention).
"""

import os
import re
import subprocess
from pathlib import Path
from typing import Dict, List, Optional, Set
from .assertion_framework import get_workspace_root


class DatabaseVerifier:
    """Utility for static SQL inspection and live database checks."""

    def __init__(self, workspace_root: Optional[Path] = None):
        self.workspace_root = workspace_root or get_workspace_root()
        self.sql_dir = self.workspace_root / "sql"

    def get_build_order_files(self) -> List[Path]:
        """Return SQL migration files in prescribed execution order."""
        build_order_txt = self.sql_dir / "build-order.txt"
        if build_order_txt.is_file():
            with open(build_order_txt, "r", encoding="utf-8") as f:
                lines = [line.strip() for line in f if line.strip() and not line.startswith("#")]
            files = [self.sql_dir / name for name in lines]
            return [p for p in files if p.is_file()]

        # Fallback to standard numbered files
        numbered = sorted(self.sql_dir.glob("0[1-5]_*.sql"))
        return numbered

    def read_all_migration_sql(self) -> str:
        """Combine all migrations in build order into a single text block."""
        texts = []
        for path in self.get_build_order_files():
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                texts.append(f.read())
        return "\n".join(texts)

    def is_table_declared(self, table_name: str) -> bool:
        """Check if table DDL `CREATE TABLE <table_name>` exists in migrations."""
        sql = self.read_all_migration_sql()
        pattern = rf"CREATE\s+TABLE\s+(?:dbo\.)?\[?{re.escape(table_name)}\]?"
        return bool(re.search(pattern, sql, re.IGNORECASE))

    def get_declared_tables(self) -> Set[str]:
        """Extract all table names created across migration scripts."""
        sql = self.read_all_migration_sql()
        pattern = r"CREATE\s+TABLE\s+(?:dbo\.)?\[?([A-Za-z0-9_]+)\]?"
        matches = re.findall(pattern, sql, re.IGNORECASE)
        return {m for m in matches}

    def is_procedure_declared(self, proc_name: str) -> bool:
        """Check if stored procedure DDL exists in migrations."""
        sql = self.read_all_migration_sql()
        pattern = rf"CREATE\s+PROCEDURE\s+(?:dbo\.)?\[?{re.escape(proc_name)}\]?"
        return bool(re.search(pattern, sql, re.IGNORECASE))

    def get_table_columns(self, table_name: str) -> List[str]:
        """Extract column names defined in CREATE TABLE block for table_name."""
        sql = self.read_all_migration_sql()
        pattern = rf"CREATE\s+TABLE\s+(?:dbo\.)?\[?{re.escape(table_name)}\]?\s*\((.*?)\s*\);"
        match = re.search(pattern, sql, re.IGNORECASE | re.DOTALL)
        if not match:
            return []
        block = match.group(1)
        columns = []
        for line in block.splitlines():
            line = re.sub(r"--.*$", "", line).strip().rstrip(",")
            if not line or line.upper().startswith(("PRIMARY", "FOREIGN", "CONSTRAINT", "INDEX", "UNIQUE", "CHECK")):
                continue
            col_match = re.match(r"^\[?([A-Za-z0-9_]+)\]?\s+[A-Za-z]", line)
            if col_match:
                columns.append(col_match.group(1))
        return columns

    @staticmethod
    def is_safe_test_db(db_name: str) -> bool:
        """
        Verify database safety guard: name MUST match ^SL_[A-Za-z0-9_]+$
        and must NOT be the production database PRJ301_LOCKER.
        """
        if db_name == "PRJ301_LOCKER":
            return False
        return bool(re.match(r"^SL_[A-Za-z0-9_]+$", db_name))

    def check_safety_guards_in_repo(self) -> Dict[str, bool]:
        """Verify that repository scripts contain active test database guards."""
        results = {}
        # 1. scripts/test.sh check
        test_sh = self.workspace_root / "scripts" / "test.sh"
        if test_sh.is_file():
            content = test_sh.read_text(encoding="utf-8", errors="ignore")
            results["scripts/test.sh"] = "SL_*" in content and "exit 2" in content
        else:
            results["scripts/test.sh"] = False

        # 2. test/test/AuditFloodDatabaseIntegrationTest.java check
        audit_test = self.workspace_root / "test" / "test" / "AuditFloodDatabaseIntegrationTest.java"
        if audit_test.is_file():
            content = audit_test.read_text(encoding="utf-8", errors="ignore")
            results["AuditFloodDatabaseIntegrationTest"] = 'startsWith("SL_")' in content or 'SL_' in content
        else:
            results["AuditFloodDatabaseIntegrationTest"] = False

        return results

    def query_live_db(self, query: str, db_name: str = "SL_SIM") -> Optional[str]:
        """Optionally execute a query against local SQL Server using sqlcmd."""
        if not self.is_safe_test_db(db_name):
            raise ValueError(f"Unsafe database name rejected by safety guard: {db_name}")

        cmd = [
            "sqlcmd",
            "-S", "localhost",
            "-U", "sa",
            "-P", "12345",
            "-d", db_name,
            "-h", "-1",
            "-W",
            "-Q", query,
        ]
        try:
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
            if res.returncode == 0:
                return res.stdout.strip()
            return None
        except Exception:
            return None
