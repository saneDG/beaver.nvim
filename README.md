<div align="center">

# 🦫 Beaver
**Beaver.nvim** is a Neovim plugin for watching log files

</div>

https://github.com/user-attachments/assets/921427f0-1b27-4a01-a5e5-f5e28c0c7e40

## Before you install

There are dedicated GUI and terminal tools for this same purpose.

For me, the main issue with other log tools was that you need to learn new workflow and keymaps. The main goal behind this plugin is to be able to view log files in Neovim therefore being able to use same motions and functionalities that Neovim provides. One of the biggest hitch with other tools was not being able to copy content from log files.

If you don't have specific need to view logs in Neovim, I recommend to check those other tools out. I've listed some of them at the bottom of this README.

That being said, if you decide to try the plugin, leave some feedback and share your experience!

## Features
- Fast and easy log file inspection
- Watches file change and updates log buffer automatically
- Browse and preview logs within neovim

## Installation

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

The line your cursor is on, is displayed on the preview split. The content on the preview buffer is formatted and highlighted (Only JSON is supported).

## Log file

Intented use of Beaver is to watch file changes and display log entry on preview split. You should some other tool to print your logs to the file you would like to watch with Beaver.

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

## TODO
- [ ] Start/Stop file watch command
- [x] Fix preview if content is not valid json
- [ ] Use better formatter
- [ ] Keymaps:
    - [ ] Toggle preview
    - [ ] Toggle file watch
- [ ] Somehow handle conflicts when log file is being edited while file watcher is on

???
- [ ] Allow passing log sream script within the editor
- [ ] Log timestamps

## Contributing

Feel free to open issues or submit pull requests to improve Beaver.nvim.

## Other terminal log tools (not neovim plugins)
- [toolong](https://github.com/Textualize/toolong)
- [lnav](https://lnav.org/)
