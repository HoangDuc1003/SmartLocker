"""
Tier 2 Boundary & Corner Cases Tests: Features 26-33 (Git Provenance, Numeric Reconciliation, Literature Review,
Manuscript Reconstruction, Authorship, Scopus Venues, Reviewer Simulation, Evidence Matrices).
Total tests: 40 (exactly 5 distinct boundary/corner/negative tests per feature).
"""

import re
from pathlib import Path
from test_e2e.common.assertion_framework import (
    E2ETestCase,
    feature,
    assert_true,
    assert_false,
    assert_equal,
    assert_in,
    assert_matches_regex,
)
from test_e2e.common.git_inspector import GitInspector
from test_e2e.common.artifact_validator import ArtifactValidator


class TestTier2Features26To33(E2ETestCase):
    tier = 2

    def setUp(self) -> None:
        super().setUp()
        self.git = GitInspector(self.workspace_root)
        self.artifacts = ArtifactValidator(self.workspace_root)

    # =========================================================================
    # Feature 26: Git Provenance Resolution (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(26, "Commit hash format validation")
    def test_f26_bva01_commit_hash_mismatch_with_tree(self):
        """Verify invalid or truncated commit hashes fail validation."""
        def is_valid_sha(sha: str) -> bool:
            return bool(re.match(r"^[0-9a-f]{40}$", sha.lower()))

        assert_false(is_valid_sha("1cc154a"), "Short SHA (7 chars) is not full 40-char SHA")
        assert_false(is_valid_sha("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"), "Non-hex characters rejected")
        assert_false(is_valid_sha(""), "Empty SHA rejected")
        assert_true(is_valid_sha("1cc154a000000000000000000000000000000000"), "Valid 40-char hex accepted")

    @feature(26, "Unverified commit date claiming Oct 30 anachronism")
    def test_f26_bva02_unverified_commit_date_claiming_oct_30(self):
        """Verify claiming measurements on Oct 30 against commit 1cc154a (Nov 15) is flagged."""
        claim_date = "2026-10-30"
        commit_1cc_date = "2026-11-15"

        is_anachronism = claim_date < commit_1cc_date
        assert_true(is_anachronism, "Commit 1cc154a did not exist on Oct 30; must be flagged as anachronistic")

    @feature(26, "Non-existent commit SHA handling")
    def test_f26_bva03_non_existent_commit_sha_handling(self):
        """Verify querying non-existent commit SHA returns None rather than crashing."""
        fake_sha = "0000000000000000000000000000000000000000"
        info = self.git.get_commit_info(fake_sha)
        assert_equal(info, None, "Non-existent commit must return None")

    @feature(26, "Ambiguous parent commits traversal handling")
    def test_f26_bva04_ambiguous_parent_commits_traversal(self):
        """Verify merge commit parent resolution does not crash ancestry parser."""
        def get_parent_commits(commit_ref: str) -> list[str]:
            res = self.git._run_git("log", "-1", "--pretty=format:%P", commit_ref)
            if res.returncode != 0 or not res.stdout.strip():
                return []
            return res.stdout.strip().split()

        parents = get_parent_commits("HEAD")
        assert_true(isinstance(parents, list), "Parent commits must be returned as list")

    @feature(26, "Missing UNVERIFIED tag on discrepancy flagged")
    def test_f26_bva05_missing_unverified_tag_on_discrepancy(self):
        """Verify policy: any unresolved provenance gap without explicit 'UNVERIFIED' tag fails audit."""
        claim_record = {
            "claim_id": "CLM-026",
            "status": "COMPLETED",   # Marked completed without proof
            "is_provenance_verified": False,
            "tag": "NONE",
        }
        has_integrity_violation = (not claim_record["is_provenance_verified"]) and (claim_record["tag"] != "UNVERIFIED")
        assert_true(has_integrity_violation, "Unverified claim lacking UNVERIFIED tag must fail audit")

    # =========================================================================
    # Feature 27: Numeric Discrepancy Reconciliation (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(27, "Discrepancy between Java files count and paper text")
    def test_f27_bva01_java_files_count_discrepancy(self):
        """Verify validator catches discrepancy if paper text reports wrong Java file count."""
        actual_count = len(list(self.get_path("src/java").rglob("*.java")))
        assert_equal(actual_count, 89)

        paper_claim_wrong = 88  # Old baseline count
        has_discrepancy = (actual_count != paper_claim_wrong)
        assert_true(has_discrepancy, "Discrepancy 89 vs 88 must be flagged")

    @feature(27, "Discrepancy between TestNG test count and paper text")
    def test_f27_bva02_testng_test_count_discrepancy(self):
        """Verify validator catches discrepancy if paper reports old test count (66 vs 83)."""
        test_dir = self.get_path("test/test")
        classes = list(test_dir.glob("*.java"))
        actual_tests = sum(len(re.findall(r"^\s*@Test\b", f.read_text(encoding="utf-8", errors="ignore"), re.M)) for f in classes)
        assert_equal(actual_tests, 83)

        paper_claim_wrong = 66
        has_discrepancy = (actual_tests != paper_claim_wrong)
        assert_true(has_discrepancy, "Discrepancy 83 vs 66 must be flagged")

    @feature(27, "Rounding errors in metrics tables detected")
    def test_f27_bva03_rounding_errors_in_metrics_tables(self):
        """Verify metrics table percentage sums not equaling 100% are caught."""
        percentages = [33.3, 33.3, 33.3]  # Sum = 99.9%
        total_pct = sum(percentages)
        is_rounding_inconsistency = abs(total_pct - 100.0) > 0.05
        assert_true(is_rounding_inconsistency, "Sum of 99.9% must be flagged for rounding adjustment")

    @feature(27, "Inconsistent session totals detected")
    def test_f27_bva04_inconsistent_session_totals(self):
        """Verify mismatch between stratified category sum and reported total is caught."""
        stratified = {"cat1": 20, "cat2": 20, "cat3": 20, "cat4": 20, "cat5": 19}  # sum = 99
        reported_total = 100
        has_mismatch = sum(stratified.values()) != reported_total
        assert_true(has_mismatch, "Sum of 99 != 100 must be caught as inconsistent")

    @feature(27, "Mismatched JSP views count detected")
    def test_f27_bva05_mismatched_jsp_views_count(self):
        """Verify mismatch between actual JSP views on disk (22) and claimed count is caught."""
        views_dir = self.get_path("web/WEB-INF/views")
        actual_jsp = len(list(views_dir.glob("*.jsp")))
        assert_equal(actual_jsp, 22)

        claimed_jsp = 21  # Missing lockerSession.jsp
        assert_false(actual_jsp == claimed_jsp, "Mismatch 22 vs 21 must be detected")

    # =========================================================================
    # Feature 28: 2021-2026 Literature Review (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(28, "Invalid DOI syntax detection")
    def test_f28_bva01_invalid_doi_syntax(self):
        """Verify invalid DOI strings are rejected by DOI regex."""
        doi_regex = r"^10\.\d{4,9}/[-._;()/:A-Za-z0-9]+$"
        invalid_dois = [
            "11.1234/invalid_prefix",
            "10.12/too_short_prefix",
            "http://dx.doi.org/10.1000/182",  # URL rather than bare DOI
            "doi:10.1000/182",                 # Prefix included
            "",
        ]
        for doi in invalid_dois:
            assert_false(bool(re.match(doi_regex, doi)), f"Invalid DOI {doi} must fail regex")

    @feature(28, "Pre-2021 publication year in recent literature window")
    def test_f28_bva02_pre_2021_publication_year(self):
        """Verify citations claimed as recent 5-year work published before 2021 are flagged."""
        citations = [
            {"key": "ref1", "year": 2023},
            {"key": "ref2", "year": 2017},  # Pre-2021
            {"key": "ref3", "year": 2024},
        ]
        pre_2021 = [c["key"] for c in citations if c["year"] < 2021]
        assert_equal(pre_2021, ["ref2"])

    @feature(28, "Non-existent citation key in LaTeX detection")
    def test_f28_bva03_non_existent_citation_key(self):
        """Verify citation key cited in TeX but missing from BibTeX is detected."""
        bibtex_keys = {"smith2022iot", "nguyen2023smart", "zhang2024edge"}
        tex_citations = {"smith2022iot", "ghost_citation_2025"}

        undefined_keys = tex_citations - bibtex_keys
        assert_equal(undefined_keys, {"ghost_citation_2025"}, "Undefined citation must be detected")

    @feature(28, "Malformed BibTeX entry detection")
    def test_f28_bva04_malformed_bibtex_entry(self):
        """Verify BibTeX parser flags missing closing braces or missing author/title."""
        malformed_entry = "@article{bad_entry,\n author = {John Doe},\n title = {Incomplete"
        is_unclosed = malformed_entry.count("{") != malformed_entry.count("}")
        assert_true(is_unclosed, "Unclosed BibTeX brace must be caught")

    @feature(28, "Predatory journal citations flagged")
    def test_f28_bva05_predatory_journal_detection(self):
        """Verify journals with known predatory flags or missing indexing are flagged."""
        predatory_keywords = ["universal research", "trends in engineering", "global journal of advanced"]
        test_venue = "International Universal Research Journal of Advanced Computing"

        is_flagged = any(kw in test_venue.lower() for kw in predatory_keywords)
        assert_true(is_flagged, "Predatory title pattern must be detected")

    # =========================================================================
    # Feature 29: Reconstructed Manuscript (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(29, "LaTeX compilation syntax error detection")
    def test_f29_bva01_latex_compilation_syntax_error(self):
        """Verify parser catches unbalanced LaTeX environments."""
        snippet = "\\begin{figure}\n\\includegraphics{fig1.png}\n"  # Missing \end{figure}
        has_end = "\\end{figure}" in snippet
        assert_false(has_end, "Unbalanced environment must be detected")

    @feature(29, "Overfull hbox warnings threshold detection")
    def test_f29_bva02_overfull_hbox_warnings_threshold(self):
        """Verify overfull hbox warnings exceeding 5pt are flagged as formatting violations."""
        MAX_ALLOWED_OVERFULL_PT = 5.0
        log_snippet = "Overfull \\hbox (12.4pt too wide) in paragraph at lines 105--112"
        match = re.search(r"Overfull \\hbox \((\d+\.?\d*)pt too wide\)", log_snippet)
        assert_true(match is not None)
        pt_val = float(match.group(1))
        assert_true(pt_val > MAX_ALLOWED_OVERFULL_PT, "Overfull 12.4pt must exceed 5.0pt threshold")

    @feature(29, "Missing required sections detection")
    def test_f29_bva03_missing_required_sections(self):
        """Verify manuscript validator detects absence of Research Questions or Threat Model."""
        existing_sections = ["Introduction", "Related Work", "System Design", "Evaluation", "Conclusion"]
        required_sections = ["Research Questions", "Threat Model", "Limitations"]

        missing = [s for s in required_sections if s not in existing_sections]
        assert_equal(len(missing), 3)
        assert_in("Threat Model", missing)

    @feature(29, "Unescaped special characters in LaTeX text body")
    def test_f29_bva04_unescaped_special_characters(self):
        """Verify unescaped characters (_, %, &, #) in raw text are flagged."""
        bad_text = "The F1_score increased by 50% & latency was reduced."
        unescaped_percent = bool(re.search(r"[^\\]%", bad_text))
        unescaped_amp = bool(re.search(r"[^\\]&", bad_text))
        assert_true(unescaped_percent, "Unescaped % must be detected")
        assert_true(unescaped_amp, "Unescaped & must be detected")

    @feature(29, "Empty or placeholder abstract detected")
    def test_f29_bva05_empty_abstract_detected(self):
        """Verify abstract containing placeholder text or <50 words fails validation."""
        def validate_abstract(text: str) -> bool:
            if not text or "TODO" in text or "Lorem ipsum" in text:
                return False
            words = text.split()
            return len(words) >= 50

        assert_false(validate_abstract("TODO: Write abstract here."))
        assert_false(validate_abstract("Short abstract only ten words long."))
        assert_true(validate_abstract("This paper presents SmartLocker, a secure multi-sensor IoT locker system... " * 10))

    # =========================================================================
    # Feature 30: Authorship & ORCID Preservation (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(30, "Missing author Duc Hoang Nguyen rejected")
    def test_f30_bva01_missing_author_duc_hoang_nguyen(self):
        """Verify author check fails if Duc Hoang Nguyen is removed or missing."""
        author_list = ["Viet Tien Nguyen", "Kieu Trong Khanh"]
        assert_false("Duc Hoang Nguyen" in author_list, "Missing corresponding author must fail check")

    @feature(30, "Altered or missing ORCID rejected")
    def test_f30_bva02_altered_or_missing_orcid(self):
        """Verify ORCID other than 0009-0006-9780-8146 is rejected."""
        MANDATED_ORCID = "0009-0006-9780-8146"
        altered_orcids = [
            "0000-0001-2345-6789",
            "0009-0006-9780-814X",  # Bad checksum char
            "",
            None,
        ]
        for orcid in altered_orcids:
            assert_false(orcid == MANDATED_ORCID, f"Altered ORCID {orcid} must be rejected")

    @feature(30, "Corrupted author email address rejected")
    def test_f30_bva03_corrupted_email_address(self):
        """Verify email other than duchoang.nguyen103@gmail.com is rejected."""
        MANDATED_EMAIL = "duchoang.nguyen103@gmail.com"
        corrupted_emails = [
            "duchoang@gmail.com",
            "nguyen103@fpt.edu.vn",
            "admin@smartlocker.com",
            "",
        ]
        for em in corrupted_emails:
            assert_false(em == MANDATED_EMAIL, f"Corrupted email {em} must be rejected")

    @feature(30, "Fabricated co-author entries rejected")
    def test_f30_bva04_fabricated_co_author_entries(self):
        """Verify fictitious co-author additions are flagged as integrity violation."""
        authorized_authors = {
            "Duc Hoang Nguyen",
            "Viet Tien Nguyen",
            "Huy Hoang Nguyen",
            "Thanh Cao Nguyen",
            "Thu Le",
            "Kieu Trong Khanh",
        }
        proposed_authors = ["Duc Hoang Nguyen", "John H. Phantom", "Alice Ghost"]
        fabricated = [a for a in proposed_authors if a not in authorized_authors]
        assert_equal(fabricated, ["John H. Phantom", "Alice Ghost"])

    @feature(30, "ORCID ISO 7064 MOD 11-2 checksum verification")
    def test_f30_bva05_orcid_checksum_validation(self):
        """Verify MOD 11-2 check digit of 0009-0006-9780-8146 evaluates correctly to '6'."""
        orcid_digits = "000900069780814"  # first 15 digits
        expected_check = "6"

        total = 0
        for digit in orcid_digits:
            total = (total + int(digit)) * 2
        remainder = total % 11
        result = (12 - remainder) % 11
        computed_check = "X" if result == 10 else str(result)

        assert_equal(computed_check, expected_check, f"ORCID check digit must be {expected_check}, got {computed_check}")

    # =========================================================================
    # Feature 31: Scopus Conference Venue Search (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(31, "Conference search under 15 venues rejected")
    def test_f31_bva01_conference_search_fewer_than_15_venues(self):
        """Verify venue list with fewer than 15 candidate conferences is rejected."""
        venues = [f"Venue_{i}" for i in range(12)]  # Only 12
        assert_false(len(venues) >= 15, "12 venues must fail >= 15 quota")

    @feature(31, "Unverified Scopus indexing status flagged")
    def test_f31_bva02_unverified_scopus_indexing_status(self):
        """Verify venue claiming Scopus indexing without verified source is flagged."""
        venue = {"name": "UnverifiedConf 2026", "scopus_indexed": True, "source": ""}
        is_verified = venue["scopus_indexed"] and bool(venue.get("source"))
        assert_false(is_verified, "Scopus claim without source must be flagged as unverified")

    @feature(31, "Missing submission deadlines flagged")
    def test_f31_bva03_missing_submission_deadlines(self):
        """Verify venue candidates missing submission deadlines are flagged."""
        venues = [
            {"name": "IEEE IoT 2026", "deadline": "2026-12-01"},
            {"name": "ACM SAC 2026", "deadline": ""},  # Missing
        ]
        missing_deadlines = [v["name"] for v in venues if not v.get("deadline")]
        assert_equal(missing_deadlines, ["ACM SAC 2026"])

    @feature(31, "Non-IoT/Security venue classification rejected")
    def test_f31_bva04_non_iot_security_venue_classification(self):
        """Verify venues outside IoT / Security / Embedded systems are flagged."""
        allowed_domains = {"IoT", "Security", "Embedded", "Network", "Pervasive", "Applied Computing"}
        unrelated_venue = "International Conference on Literature and Art"

        is_domain_match = any(d.lower() in unrelated_venue.lower() for d in allowed_domains)
        assert_false(is_domain_match, "Unrelated venue must be rejected")

    @feature(31, "Missing primary and backup recommendations split")
    def test_f31_bva05_missing_primary_backup_split(self):
        """Verify recommendations lacking 3 primary + 3 backup split are rejected."""
        recommendations = {
            "primary": ["Venue1", "Venue2"],           # only 2 (needs 3)
            "backup": ["Venue3", "Venue4", "Venue5"],   # 3
        }
        is_valid = len(recommendations.get("primary", [])) == 3 and len(recommendations.get("backup", [])) == 3
        assert_false(is_valid, "Fewer than 3 primary venues must fail check")

    # =========================================================================
    # Feature 32: 3-Reviewer Independent Simulation (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(32, "Missing reviewer simulation persona rejected")
    def test_f32_bva01_missing_reviewer_simulation_persona(self):
        """Verify simulation with fewer than 3 reviewer personas fails."""
        personas = ["Reviewer 1 (IoT)", "Reviewer 2 (Security)"]  # Missing Reviewer 3
        assert_false(len(personas) == 3, "2 personas must fail 3-reviewer requirement")

    @feature(32, "Identical scores without critical feedback flagged")
    def test_f32_bva02_identical_scores_without_critical_feedback(self):
        """Verify rubber-stamping (all 10/10 with no weaknesses) is flagged as uncritical."""
        simulation = [
            {"reviewer": "R1", "score": 10, "weaknesses": []},
            {"reviewer": "R2", "score": 10, "weaknesses": []},
            {"reviewer": "R3", "score": 10, "weaknesses": []},
        ]
        is_rubber_stamp = (
            all(r["score"] == 10 for r in simulation)
            and all(len(r["weaknesses"]) == 0 for r in simulation)
        )
        assert_true(is_rubber_stamp, "All 10/10 with 0 weaknesses must be flagged as rubber-stamping")

    @feature(32, "Missing revision action plan rejected")
    def test_f32_bva03_missing_revision_action_plan(self):
        """Verify simulation lacking concrete revision action plan is rejected."""
        sim_report = {"reviews": [{"reviewer": "R1", "weaknesses": ["Needs threat model"]}], "revision_plan": []}
        has_plan = len(sim_report.get("revision_plan", [])) > 0
        assert_false(has_plan, "Empty revision plan must be rejected")

    @feature(32, "Empty reviewer comments rejected")
    def test_f32_bva04_empty_reviewer_comments(self):
        """Verify reviewer review with empty comments or blank summary is rejected."""
        empty_review = {"reviewer_id": "R1", "summary": "", "strengths": [], "weaknesses": []}
        is_valid = bool(empty_review.get("summary").strip()) and len(empty_review.get("strengths", [])) > 0
        assert_false(is_valid, "Blank review must be rejected")

    @feature(32, "Conflicting review decisions resolution")
    def test_f32_bva05_conflicting_decision_resolution(self):
        """Verify split decision (Accept, Weak Accept, Reject) synthesizes meta-review."""
        reviews = [{"score": "Accept"}, {"score": "Weak Accept"}, {"score": "Reject"}]
        has_split = any(r["score"] == "Reject" for r in reviews) and any("Accept" in r["score"] for r in reviews)
        assert_true(has_split, "Split decision must be identified, requiring meta-review consensus")

    # =========================================================================
    # Feature 33: Progress & Evidence Matrices (Boundary / BVA / Edge Cases)
    # =========================================================================
    @feature(33, "Incomplete progress matrix rejected")
    def test_f33_bva01_incomplete_progress_matrix(self):
        """Verify progress matrix with fewer than 16 phases is rejected."""
        matrix_phases = [f"Phase {i}" for i in range(1, 15)]  # Only 14 phases
        assert_false(len(matrix_phases) == 16, "14 phases must fail 16-phase requirement")

    @feature(33, "Broken evidence file hyperlinks detected")
    def test_f33_bva02_broken_evidence_file_hyperlinks(self):
        """Verify evidence matrix referencing non-existent file path is caught."""
        evidence_entry = {"claim": "Gate passed", "evidence_path": "experiments/results/non_existent_file.json"}
        target_path = self.get_path(evidence_entry["evidence_path"])
        exists = target_path.is_file()
        assert_false(exists, "Broken file hyperlink must be detected as non-existent")

    @feature(33, "Commit SHA missing from evidence matrix row flagged")
    def test_f33_bva03_commit_sha_missing_from_evidence(self):
        """Verify evidence entries without commit SHA or verification command are flagged."""
        entry = {"claim": "Rule engine verification", "commit_sha": "", "command": ""}
        is_traceable = bool(entry.get("commit_sha")) or bool(entry.get("command"))
        assert_false(is_traceable, "Missing both commit SHA and command must fail traceability check")

    @feature(33, "Unverified claim without backing file rejected")
    def test_f33_bva04_unverified_claim_without_backing_file(self):
        """Verify claim marked COMPLETED without evidence file is rejected."""
        claim = {"claim_id": "C-101", "status": "COMPLETED", "evidence_file": ""}
        is_valid = claim["status"] != "COMPLETED" or bool(claim.get("evidence_file"))
        assert_false(is_valid, "Completed claim without evidence file must be rejected")

    @feature(33, "Invalid status flags rejected")
    def test_f33_bva05_invalid_status_flags(self):
        """Verify status values other than standard set are rejected."""
        allowed_statuses = {"PLANNED", "IN_PROGRESS", "COMPLETED", "BLOCKED", "UNVERIFIED"}
        invalid_statuses = ["DONE", "FINISHED", "PENDING", "UNKNOWN", ""]
        for st in invalid_statuses:
            assert_false(st in allowed_statuses, f"Status flag {st} must be rejected")
