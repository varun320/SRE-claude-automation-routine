# lib/ — placeholder for future pullers + generators

**Status:** EMPTY. This directory is intentionally a placeholder. The runbook above is a PLAN, not an implementation.

When we move from plan to code, the file layout mirrors the GHL `~/.claude/runbooks/ghl-deep-audit-workflow/lib/` set 1:1, so anyone familiar with the GHL pipeline finds the same shape here.

---

## Planned layout (build manifest)

```
lib/
├── run_audit.py                       # one-command orchestrator (mirrors GHL run_audit.py)
├── _common.py                         # shared HTTP wrapper, retry, MS Graph version map
├── pull_tenant.py                     # stage 1
├── pull_mail.py                       # stage 2A
├── pull_calendar.py                   # stage 2B
├── pull_contacts.py                   # stage 2C
├── pull_sharepoint.py                 # stage 3
├── pull_onedrive.py                   # stage 4
├── pull_teams.py                      # stage 5
├── pull_planner_todo.py               # stage 6
├── pull_onenote.py                    # stage 7
├── pull_mail_delta.py                 # incremental refresh (post-initial)
├── pull_calendar_delta.py             # incremental
├── pull_sharepoint_delta.py           # incremental
├── pull_onedrive_delta.py             # incremental
├── synth_customer_360.py              # stage 8
├── synth_sales_pipeline.py            # stage 9 (incl. AR aging)
├── ocr_documents.py                   # stage 9 opt-in PDF/XLSX text extraction
├── build_ms365_account_overview.py    # stage 10 dashboard
├── build_ms365_customer_360.py        # stage 10 dashboard
├── build_ms365_sales_pipeline.py      # stage 10 dashboard
├── build_ms365_communications_heatmap.py
├── build_ms365_document_library.py
├── build_ms365_time_allocation.py
├── build_ms365_cleanup_report.py
└── build_subhub_index.py              # sub-hub index.html
```

---

## Shared `_common.py` contract

Same shape as GHL's request helper:

```python
def _req(method: str, path: str, params: dict | None, version: str, token: str,
         body: dict | None = None) -> dict:
    """
    GET/PUT/POST against Microsoft Graph with:
      - User-Agent forced to a browser string (avoids Cloudflare 1010)
      - Authorization: Bearer <token>
      - Version header per endpoint family (v1.0 vs beta)
      - 1.5s × attempt backoff for 429/5xx, max 3 retries
    Returns parsed JSON or {"_error": "..."} on permanent failure.
    """
```

The MCP server abstracts the actual HTTP. The pullers call MCP tools (`mcp__ms365__*`) rather than raw HTTP. `_common.py` mostly handles:
- Pagination (`@odata.nextLink`) loops
- Delta-token persistence
- Per-tool concurrency limits
- Error classification (transient vs permanent)
- Standardized output JSON shape

---

## `run_audit.py` contract

One-command orchestrator, mirrors GHL:

```bash
python3 lib/run_audit.py \
  --client-slug sre \
  --tenant-config client-config.yaml \
  --audit-dir ~/ms365-audits/sre-2026-05-22 \
  --skip pull_onenote   # comma-separated stages to skip
```

Stage order baked in:
1. `pull_tenant`
2. `pull_mail` (parallel with cal/contacts)
3. `pull_calendar` (parallel)
4. `pull_contacts` (parallel)
5. `pull_sharepoint`
6. `pull_onedrive`
7. `pull_teams`
8. `pull_planner_todo`
9. `pull_onenote`
10. `synth_customer_360`
11. `synth_sales_pipeline`
12. All `build_*` generators
13. `build_subhub_index`

Each stage is independently re-runnable with `--skip <other-stages>`.

---

## Build order (incremental, mirrors the 8-week plan)

| Week | New files in lib/ |
|---|---|
| 1 | `_common.py`, `run_audit.py`, `pull_tenant.py` |
| 2 | `pull_mail.py`, `pull_calendar.py` |
| 3 | `pull_sharepoint.py`, `synth_customer_360.py`, `build_ms365_customer_360.py`, `build_ms365_account_overview.py`, `build_subhub_index.py` |
| 4 | `synth_sales_pipeline.py`, `build_ms365_sales_pipeline.py`, `ocr_documents.py` |
| 5 | `pull_onedrive.py`, `pull_teams.py`, `build_ms365_document_library.py` |
| 6 | `pull_planner_todo.py`, `pull_onenote.py`, `pull_contacts.py` |
| 7 | `build_ms365_communications_heatmap.py`, `build_ms365_time_allocation.py`, `build_ms365_cleanup_report.py`, all `pull_*_delta.py` |
| 8 | Polish, retry, documentation |

---

## Where this code does NOT belong

- Routines (`routines/tier*/`) — they CONSUME audit output, they don't re-pull
- Skills (`~/.claude/skills/`) — they wrap audit-derived data into reusable units, no Graph calls
- Sub-runbooks (`runbook/<other>.md`) — they document processes; this `lib/` is the actual code

---

## Implementation status

⬜ Nothing here yet. All files listed above are TODO.

When implementation starts, replace this README with one matching the GHL `lib/` actual file list + per-file responsibilities, so newcomers can navigate the code without reading every file.
