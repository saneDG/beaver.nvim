<div align="center">

# Beaver
##### **Beaver.nvim** is a Neovim plugin for inspecting and previewing log files.

[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)
[![Neovim](https://img.shields.io/badge/Neovim%200.8+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)

# 🦫

</div>


Beaver provides an efficient way to view logs directly within Neovim, making it easier to monitor and troubleshoot your application's behavior without leaving the editor.

## Features
- Fast and easy log file inspection
- Watches file change and updates log buffer automatically
- Browse and preview logs within neovim

## Installation

You can install **Beaver.nvim** with the following plugin managers:

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

Add this line to your lazy setup:

```lua
{
    'saneDG/beaver.nvim',
    opts = {}
}
```

## Usage

To start using Beaver.nvim, simply open a log file in Neovim and run the following command:

```
:Beaver
```

This will activate Beaver in the current buffer, allowing you to preview and inspect the log file seamlessly.

**Beaver.nvim** can automatically watch for changes in log files, making it ideal for monitoring logs in real-time. This feature allows you to keep an eye on new log entries as they appear, without manually refreshing the file.

With Beaver activated, the line your cursor is on the log file buffer is printed on preview split to right. The content on the left split is formatted and syntax highlighted (Only JSON is supported).

## Log file

Intented use of Beaver is to watch file changes, and print single log entries on preview split. You should some other tool to print your logs to the log file before so you can use Beaver to preview logs live.

For example you can use [tee](https://www.gnu.org/software/coreutils/manual/html_node/tee-invocation.html) to append log stream stdout to local file
```
your-log-command | tee logfile.log
```

Depending on the case you might want to use [pipe](https://www.gnu.org/software/bash/manual/html_node/Pipelines.html) to manipulate the incoming logs somehow. This is outside of the scope of this plugin tho.
```
your-log-stream | remove-debug-logs | tee logfile.log
```

To test Beaver with dummy data
```
while true; do echo '{"timestamp": "'$(date +%FT%T)'", "level": "WARN", "module": "AuthService", "message": "Session timeout warning issued for user: john_doe."}'; sleep 1; done | tee logfile.log;
```

## TODO
- [ ] Start/Stop file watch command
- [ ] Fix preview if content is not valid json
- [ ] Keymaps:
    - [ ] Toggle preview
    - [ ] Toggle file watch
- [ ] Somehow handle conflicts when log file is being edited while file watcher is on

???
- [ ] Allow passing log sream script within the editor
- [ ] Log timestamps

## Contributing

Feel free to open issues or submit pull requests to improve Beaver.nvim.
