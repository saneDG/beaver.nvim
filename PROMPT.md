# PROMPT.md — beaver.nvim Build Session

## Project Goal

Extend beaver.nvim into a full-featured Neovim log inspection tool with:
- Smooth UX for both static and live-streaming local log files
- Visual indicators for unread new logs (gutter marks + virt_lines divider)
- Pause/resume watching, preview split toggle — all via buffer-local keymaps
- Live log streaming from remote sources via `:Beaver [url]`, with named
  adapters for generic HTTP, Loki, Papertrail, Datadog, and AWS CloudWatch
- Zero required config for basic use; credentials via env vars for remote adapters

## Non-Goals

- No console URL reverse-engineering (e.g. pasting a CloudWatch browser URL
  and having it auto-parse — users provide API URLs or use aws:// scheme)
- No hosted service, no external binary to install
- No WebSocket streaming (Loki tail WS endpoint not supported; polling only)
- No UI beyond what Neovim builtins provide (no floating windows, no TUI)
- The mock log server lives in a separate repository (linked from README);
  it is a shell script, not part of this plugin

## Future Feature Ideas

- Add a clean visual indicator when unread logs exist below the visible window.
  Prefer a subtle bottom-of-buffer down arrow or similarly minimal UI over a
  distracting popup.
- Replace `:Beaver --mock` with a dedicated `:BeaverMockStart` command.

## Existing Repo — Inspect These First

Before writing any code, read:
  lua/beaver.lua          — entire current implementation (~82 lines)
  plugin/beaver.lua       — currently just: print("🦫")
  README.md               — existing docs, install snippet, TODO list

Key facts about the current state:
- M.setup() takes no arguments; all logic is inside the :Beaver command handler
- Watch_file is an accidental global (missing `local`) — must be fixed
- No keymaps exist anywhere; all interaction is via :Beaver command
- format_json uses naive gsub — breaks on strings containing { } ,
- No idempotency guard: calling :Beaver twice creates duplicate watchers
- plugin/beaver.lua does not call setup(); lazy.nvim does it via opts = {}
- The preview buffer is listed=true — should be false (it is scratch, not real)
- No cleanup on buffer delete; watcher runs forever

## Proposed Architecture

Refactor the single flat file into modules:

  lua/beaver/
    init.lua              -- M.setup(opts), :Beaver command, public API
    config.lua            -- defaults table, M.resolve(user_opts)
    watcher.lua           -- fs_event watching, pause/resume, keymaps
    marks.lua             -- extmark namespace, gutter signs, virt_lines divider
    preview.lua           -- split window open/toggle, format_json (fixed)
    poll.lua              -- HTTP polling loop, adapter dispatch, scratch buffer
    adapters/
      generic.lua         -- plain NDJSON GET via curl
      loki.lua            -- Loki query_range adapter
      papertrail.lua      -- Papertrail search.json adapter
      datadog.lua         -- Datadog v2 logs/events/search adapter
      cloudwatch.lua      -- shells out to `aws` CLI

  plugin/beaver.lua       -- replace print("🦫") with require('beaver').setup()

### Config defaults (config.lua)

  {
    keymaps = {
      pause          = "<leader>bp",  -- buffer-local: pause/resume watcher
      toggle_preview = "<leader>bv",  -- buffer-local: show/hide preview split
      clear_marks    = "<leader>bc",  -- buffer-local: clear divider + gutter signs
    },
    allow_editing    = false,         -- false = set nomodifiable on log buffer
    sign_text        = "▎",          -- gutter character for new lines (1-2 chars)
    sign_hl_group    = "DiffAdd",
    divider_hl_group = "Comment",
    poll_interval_ms = 5000,
  }

### State model

All runtime state lives in a module-level table keyed by bufnr:
  state[bufnr] = {
    watching, fs_event_handle, poll_timer,
    log_win, preview_win, preview_buf,
    baseline_count, new_line_start, divider_id, last_reloaded_count,
    cursor,   -- adapter-specific pagination cursor (poll mode only)
  }

### Marks / new-log indicator behaviour

- On each file reload (on_reload from nvim_buf_attach) or poll tick:
  - Count new lines vs baseline_count
  - Place a virt_lines extmark above the first new line:
      ─── 4 unread logs ─── Press <leader>bc to clear ───
  - Place sign_text = "▎" + DiffAdd highlight on every new line in gutter
  - Update divider text on subsequent batches (don't move the anchor)
- Marks are cleared ONLY by <leader>bc (explicit keymap). No auto-clear.
- nvim_buf_attach on_reload is used to detect checktime reloads.
  All marks are wiped on reload and re-applied from scratch (same pattern
  as gitsigns.nvim). Requires Neovim >= 0.9 for sign_text in extmarks.

### URL mode adapter contract

Each adapter exports:
  adapter.fetch(url, cursor, cfg, callback)
  -- callback(err_string_or_nil, lines_string_array, new_cursor)

Adapter detection order in poll.lua:
  1. BEAVER_ADAPTER env var (explicit override)
  2. URL scheme / hostname sniffing:
       aws://            → cloudwatch
       logs.*.amazonaws.com → cloudwatch
       grafana.net / :3100 / loki in hostname → loki
       papertrailapp.com → papertrail
       datadoghq.*       → datadog
       anything else     → generic

### Env vars per adapter

  generic:     none required
  loki:        BEAVER_LOKI_USER, BEAVER_LOKI_PASSWORD, BEAVER_LOKI_ORG_ID (all optional)
  papertrail:  BEAVER_PAPERTRAIL_TOKEN (required)
  datadog:     BEAVER_DATADOG_API_KEY (required), BEAVER_DATADOG_APP_KEY (required)
               BEAVER_DATADOG_SITE (optional, default: datadoghq.com)
               BEAVER_DATADOG_QUERY (optional, default: *)
  cloudwatch:  BEAVER_AWS_REGION (optional), BEAVER_CLOUDWATCH_LOG_GROUP (required
               if not parseable from aws:// URL), BEAVER_CLOUDWATCH_FILTER (optional)
               Standard AWS env vars (AWS_PROFILE, AWS_DEFAULT_REGION) are respected.

## Milestone 1 — Everything in Scope

All of the following is in scope for this single build session:

1. Module refactor (init, config, watcher, marks, preview, poll, adapters)
2. Fix Watch_file global leak
3. Idempotency guard on :Beaver
4. nomodifiable on log buffer (allow_editing = false default)
5. Auto-pause watcher on BufModifiedSet with notify
6. Pause/resume keymap (<leader>bp), buffer-local
7. Preview split toggle keymap (<leader>bv), buffer-local
8. Clear marks keymap (<leader>bc), buffer-local
9. Gutter sign marks (▎, DiffAdd) on new lines after each reload
10. virt_lines divider above first new line with unread count + clear hint
11. Marks cleared only by <leader>bc — no auto-clear
12. BufDelete cleanup (stop watcher/timer, clear state)
13. Fix format_json (use jq if available, fallback to correct Lua formatter)
14. preview_buf listed=false (was true — wrong)
15. plugin/beaver.lua calls setup() instead of printing emoji
16. poll.lua with uv timer + vim.system curl polling
17. All five adapters (generic, loki, papertrail, datadog, cloudwatch)
18. URL stub guard for unrecognised input
19. README update: new features, env vars, adapter docs, mock server repo link

## Files Likely to Change / Be Created

  CHANGE:   plugin/beaver.lua
  CHANGE:   README.md
  DELETE:   lua/beaver.lua         (replaced by lua/beaver/ directory)
  CREATE:   lua/beaver/init.lua
  CREATE:   lua/beaver/config.lua
  CREATE:   lua/beaver/watcher.lua
  CREATE:   lua/beaver/marks.lua
  CREATE:   lua/beaver/preview.lua
  CREATE:   lua/beaver/poll.lua
  CREATE:   lua/beaver/adapters/generic.lua
  CREATE:   lua/beaver/adapters/loki.lua
  CREATE:   lua/beaver/adapters/papertrail.lua
  CREATE:   lua/beaver/adapters/datadog.lua
  CREATE:   lua/beaver/adapters/cloudwatch.lua

## Manual Verification Checklist

### File mode
- [ ] Open any .log file, run :Beaver
      → preview split opens to the right, signcolumn appears, buffer is nomodifiable
- [ ] Run :Beaver again on same buffer
      → "Already watching" notify, no second split opens
- [ ] Move cursor line by line
      → preview split updates with current line content, formatted if JSON
- [ ] Append a line externally: echo '{"msg":"test"}' >> file.log
      → ▎ appears in gutter on new line, divider virt_line appears above it
- [ ] Append more lines externally
      → divider count increments, new lines also get ▎
- [ ] Press <leader>bc
      → all marks clear, divider disappears
- [ ] Press <leader>bp
      → notify "Paused", append more lines → buffer does NOT reload, no marks
- [ ] Press <leader>bp again
      → notify "Watching resumed", append lines → marks appear again
- [ ] Press <leader>bv
      → preview split closes
- [ ] Press <leader>bv again
      → preview split reopens, CursorMoved still works
- [ ] Press i to enter insert mode
      → notify "Paused — buffer modified", watcher stops
- [ ] Press <leader>bp while buffer is modified
      → warn "Cannot resume: buffer is modified"
- [ ] Close the log buffer (:bd)
      → no errors, watcher cleaned up silently

### URL mode — generic adapter
- [ ] Start a local NDJSON server (e.g. the shell mock from the separate repo)
- [ ] :Beaver http://localhost:8080/logs
      → scratch buffer opens, lines appear every poll_interval_ms
- [ ] <leader>bc, <leader>bp, <leader>bv all work same as file mode
- [ ] Kill the server → poll error notify, plugin keeps retrying without crashing

### URL mode — error handling
- [ ] :Beaver http://localhost:9999/notrunning
      → warn notify on each failed poll, no crash
- [ ] :Beaver notaurl
      → warn "Unrecognised input", nothing else happens
- [ ] :Beaver aws://missing-group with no aws CLI installed
      → clear error notify: "aws CLI not found"
- [ ] Adapter with missing required env var (e.g. no BEAVER_PAPERTRAIL_TOKEN)
      → clear error notify naming the missing var, polling does not start

### Regression
- [ ] lazy.nvim install with opts = {} still works (no config required)
- [ ] Plugin works on a plain text log file (non-JSON lines don't crash preview)

## Risks and Open Questions

**Risk: virt_lines extmark position after checktime reload**
nvim_buf_attach on_reload fires after a full buffer reload (triggered by checktime).
All extmarks are wiped. The re-apply pattern (clear namespace, re-place all marks)
is identical to gitsigns.nvim and is confirmed safe. However: on_reload is a fast
context — all vim.api.* calls inside it must be deferred with vim.schedule().
If this is missed anywhere, Neovim will throw E5560. Be careful.

**Risk: marks.on_reload called from two paths**
In file mode it is called via nvim_buf_attach on_reload.
In poll mode it is called directly from the poll timer callback.
The function must be stateless enough to work in both contexts without
assuming how it was triggered. The baseline_count / new_line_start tracking
must be accurate in both paths.

**Risk: CloudWatch console URL parsing is brittle**
The console URL is double-URL-encoded. Only attempt parsing if the URL
contains the known path fragment `log-group/`. If parsing fails, fall back
to requiring BEAVER_CLOUDWATCH_LOG_GROUP env var and notify the user.

**Risk: Loki nanosecond timestamps**
Loki uses nanoseconds, not milliseconds. os.time() returns seconds.
Correct conversion: tostring(os.time()) .. '000000000' (append 9 zeros).
A mistake here produces no results silently (time window in the far past).

**Risk: Datadog requires two separate keys**
If only one of DD_API_KEY / DD_APP_KEY is set, the API returns 403 with no
useful body. The adapter must check for both before making any request and
emit a specific error naming which key is missing.

**Open question: poll mode line deduplication**
For generic adapter, the server may return the full log on every poll
(stateless endpoint). The generic adapter currently returns all lines and
relies on the caller to not re-append. This needs a strategy: either track
a line-count cursor client-side, or require the server to support a ?since=
param. For the milestone, assume the generic adapter server is stateful
(returns only new lines per request). Document this assumption in adapter.

**Open question: format_json fallback quality**
If jq is not installed, the Lua fallback formatter using vim.json.encode
produces compact single-line JSON. This is correct but hard to read.
A recursive Lua pretty-printer is the right solution but adds complexity.
Decision: implement the recursive printer; it is ~30 lines and eliminates
the gsub bug entirely.
