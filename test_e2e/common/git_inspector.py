"""
Git Inspector Utility for SmartLocker E2E Testing.
Inspects git branches, worktrees, commit provenance (da95f43 vs 1cc154a),
and verifies research branch isolation (research/multisensor-simulation).
"""

import subprocess
from pathlib import Path
from typing import Any, Dict, List, Optional
from .assertion_framework import get_workspace_root


class GitInspector:
    """Helper to query repository git state and historical commit provenance."""

    def __init__(self, workspace_root: Optional[Path] = None):
        self.workspace_root = workspace_root or get_workspace_root()

    def _run_git(self, *args: str, timeout: float = 5.0) -> subprocess.CompletedProcess:
        cmd = ["git"] + list(args)
        return subprocess.run(
            cmd,
            cwd=str(self.workspace_root),
            capture_output=True,
            text=True,
            timeout=timeout,
        )

    def is_git_repository(self) -> bool:
        """Verify the working directory is inside a valid git repository."""
        res = self._run_git("rev-parse", "--is-inside-work-tree")
        return res.returncode == 0 and res.stdout.strip() == "true"

    def get_current_branch(self) -> str:
        """Get the currently checked out branch name."""
        res = self._run_git("rev-parse", "--abbrev-ref", "HEAD")
        return res.stdout.strip() if res.returncode == 0 else ""

    def list_branches(self) -> List[str]:
        """List all local and remote branches."""
        res = self._run_git("branch", "-a")
        if res.returncode != 0:
            return []
        branches = []
        for line in res.stdout.splitlines():
            line = line.strip().lstrip("*").strip()
            if line:
                branches.append(line)
        return branches

    def branch_exists(self, branch_name: str) -> bool:
        """Check if branch exists locally or remotely."""
        res = self._run_git("show-ref", "--verify", f"refs/heads/{branch_name}")
        if res.returncode == 0:
            return True
        res_rem = self._run_git("show-ref", f"refs/remotes/origin/{branch_name}")
        return res_rem.returncode == 0

    def get_head_commit_hash(self) -> str:
        """Get full 40-character SHA of HEAD."""
        res = self._run_git("rev-parse", "HEAD")
        return res.stdout.strip() if res.returncode == 0 else ""

    def get_commit_info(self, ref: str) -> Optional[Dict[str, str]]:
        """Get commit metadata: sha, author, date, message."""
        res = self._run_git("log", "-1", "--pretty=format:%H|%an|%ad|%s", ref)
        if res.returncode != 0 or not res.stdout.strip():
            return None
        parts = res.stdout.strip().split("|", 3)
        return {
            "sha": parts[0] if len(parts) > 0 else "",
            "author": parts[1] if len(parts) > 1 else "",
            "date": parts[2] if len(parts) > 2 else "",
            "message": parts[3] if len(parts) > 3 else "",
        }

    def get_commit_files_changed(self, ref: str) -> List[str]:
        """Get list of files modified in a given commit."""
        res = self._run_git("show", "--name-only", "--pretty=format:", ref)
        if res.returncode != 0:
            return []
        return [line.strip() for line in res.stdout.splitlines() if line.strip()]

    def get_latest_commit_before(self, date_cutoff: str) -> Optional[str]:
        """Find commit SHA that existed before a given date (e.g. '2026-10-31 00:00:00+07:00')."""
        res = self._run_git("log", f"--before={date_cutoff}", "-n", "1", "--pretty=format:%H")
        return res.stdout.strip() if res.returncode == 0 and res.stdout.strip() else None

    def verify_october_30_provenance(self) -> Dict[str, Any]:
        """
        Formally verify the provenance discrepancy:
        On 30 Oct 2026, the latest commit was da95f43.
        Commit 1cc154a was created on 15 Nov 2026 and only modified README.md.
        """
        oct30_commit = self.get_latest_commit_before("2026-10-31 00:00:00+07:00")
        info_1cc = self.get_commit_info("1cc154a")
        files_1cc = self.get_commit_files_changed("1cc154a") if info_1cc else []

        return {
            "oct30_commit_sha": oct30_commit,
            "oct30_matches_da95f43": (oct30_commit or "").startswith("da95f43"),
            "commit_1cc154a_exists": bool(info_1cc),
            "commit_1cc154a_date": info_1cc.get("date") if info_1cc else "",
            "commit_1cc154a_files": files_1cc,
            "commit_1cc154a_only_readme": files_1cc == ["README.md"],
        }
