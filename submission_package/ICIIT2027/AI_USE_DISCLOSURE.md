# AI-use disclosure (draft for author review)

From `docs/paper/REVISION2_LOG.md`, section 6. Items marked AUTHOR_CONFIRM are not verified.

| Stage | Tool | Evidence | Status |
|---|---|---|---|
| Writing and editing, LaTeX checking, diagrams of Fig. 1–9 | Claude (Anthropic) | previous Acknowledgment text | AUTHOR_CONFIRM scope |
| Code: `experiments/*.py`, audit reports | AI coding agents | git history 15–16 Nov 2026 | AUTHOR_CONFIRM which tool |
| Evidence harness and logs of 30 Oct 2026 (operators named "agent paper-editor-4", "agent reviewer-4", "agent retrain", "agent screens") | AI agents | log headers | AUTHOR_CONFIRM |
| Revision 2: audit, analysis scripts, revision log | Claude Code (Anthropic) | REVISION2_LOG.md | confirmed |
| Simulator v2 parameter proposal (P3, table 1.3) | Claude Code (Anthropic) | "Simulator v2 rationale" in the log | drafted by Claude Code; the author reviewed and approved each value (2026-11-17 00:01 +0700) |
| Simulator v2 implementation, live run, analysis; manuscript update (session A/B) | Claude Code (Anthropic) | REVISION2_LOG.md | confirmed |

Text now in the Acknowledgment of the manuscript:

> The authors used the AI assistant Claude (Anthropic) to edit the English text, check the LaTeX source and draw
> Fig. 1 to Fig. 9, and AI coding agents including Claude Code (Anthropic) to write parts of the simulation, evaluation
> and audit scripts, execute the scripted runs under the authors' supervision and draft the parameter proposal of the
> second simulator, each value of which the authors approved. The authors designed the system, reviewed every script
> and result, and take full responsibility for the content of this paper. The AI tools are not authors.

The ACM policy page (https://www.acm.org/publications/policy-on-authorship) returned HTTP 403 to automated access, and
the ICIIT pages state no AI policy. Check the policy by hand.
