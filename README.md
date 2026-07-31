<div align="center">

# 🦫 Beaver
**Beaver.nvim** is a Neovim plugin for watching log files

</div>

https://github.com/user-attachments/assets/921427f0-1b27-4a01-a5e5-f5e28c0c7e40

## Before you install

There are dedicated GUI and terminal tools for this same purpose.

For me, the main issue with other log tools was that you need to learn new workflow and keymaps. For example, with other tools I was not able to yank content from log files or navigate logs with Vim motions. The main goal behind this plugin is to be able to view log files in Neovim, therefore being able to use same motions and functionalities that Neovim provide.

If you don't have specific need to view logs in Neovim, I recommend to check those other tools out. I've listed some of them at the bottom of this README.

That being said, if you decide to try the plugin, leave some feedback and share your experience!

## Features
- Watch local log files and reload them automatically
- Preview and pretty-print JSON log entries in a right split
- Mark unread lines with gutter signs and a virtual divider
- Pause and resume local file watching or remote polling
- Poll HTTP log sources without leaving Neovim
- Built-in adapters for generic HTTP, Loki, Papertrail, Datadog, and AWS CloudWatch

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

Add this to your lazy setup:

```lua
{
  'saneDG/beaver.nvim',
  opts = {
    allow_editing = false,
    sign_text = "▎",
    sign_hl_group = "BeaverSign",
    divider_hl_group = "BeaverDivider",
    scroll_hl_group = "BeaverScroll",
    poll_interval_ms = 5000,
    mock_interval_ms = 500,
    keymaps = {
      pause = "<leader>Lp",
      toggle_preview = "<leader>Lv",
      clear_marks = "<leader>Lc",
    },
  },
}
```

## Usage

Open a local log file and start watching it:

```vim
:Beaver
```

Poll a remote log source:

```vim
:Beaver https://example.com/logs
```

Start a mock feed that appends logs to the current local file:

```vim
:BeaverMockStart
```

Stop the mock feed:

```vim
:BeaverMockStop
```

The line under the cursor is shown in the preview split. JSON entries are
pretty-printed; plain text entries are left unchanged.

### Keymaps

The mappings are buffer-local and become active after Beaver starts.

| Keymap | Action |
| --- | --- |
| `<leader>Lp` | Pause or resume watching/polling |
| `<leader>Lv` | Toggle the preview split |
| `<leader>Lc` | Clear unread marks |

## Configuration

All options are shown in the lazy.nvim example above. Pass only the values you
want to override through `opts`.

## Adapters

### Generic HTTP

Uses `curl` to fetch newline-delimited JSON or plain-text logs. No environment
variables are required. Generic endpoints are expected to return their full log
history; Beaver uses a client-side line-count cursor to append only new lines.

### Loki

Calls the Loki `query_range` API. `BEAVER_LOKI_USER` and
`BEAVER_LOKI_PASSWORD` optionally enable basic authentication, and
`BEAVER_LOKI_ORG_ID` optionally sets the tenant header.

### Papertrail

Uses the Papertrail events search API. `BEAVER_PAPERTRAIL_TOKEN` is required.

### Datadog

Uses the Datadog v2 logs search API. `BEAVER_DATADOG_API_KEY` and
`BEAVER_DATADOG_APP_KEY` are required. `BEAVER_DATADOG_SITE` optionally changes
the site from `datadoghq.com`, and `BEAVER_DATADOG_QUERY` optionally changes the
query from `*`.

### AWS CloudWatch

Runs `aws logs filter-log-events`, so the AWS CLI must be installed.
`BEAVER_CLOUDWATCH_LOG_GROUP` is required unless the group is supplied through
an `aws://<log-group>` URL. `BEAVER_AWS_REGION` or `AWS_DEFAULT_REGION` may set
the region, and `BEAVER_CLOUDWATCH_FILTER` may set a filter pattern.

Set `BEAVER_ADAPTER` to `generic`, `loki`, `papertrail`, `datadog`, or
`cloudwatch` to override automatic adapter detection.

## Log file

Intended use of Beaver is to watch file changes and display log entry on preview split. You should use some other tool to print your logs to the file you would like to watch with Beaver.

For example you can use [tee](https://www.gnu.org/software/coreutils/manual/html_node/tee-invocation.html) to append log stream stdout to local file
```
your-log-command | tee logfile.log
```

Depending on the case you might want to use [pipe](https://www.gnu.org/software/bash/manual/html_node/Pipelines.html) to manipulate the incoming log stream
```
your-log-stream | remove-debug-logs | tee logfile.log
```

To test Beaver with dummy data
```
while true; do echo '{"timestamp": "'$(date +%FT%T)'", "level": "WARN", "module": "AuthService", "message": "Session timeout warning issued for user: john_doe."}'; sleep 1; done | tee logfile.log;
```

## Contributing

Feel free to open issues or submit pull requests to improve Beaver.nvim.

## Other terminal log tools (not Neovim plugins)
- [toolong](https://github.com/Textualize/toolong)
- [lnav](https://lnav.org/)
