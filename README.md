# Beaver.nvim 🦫

**Beaver.nvim** is a Neovim plugin for inspecting and previewing log files. This plugin provides an efficient way to view logs directly within Neovim, making it easier to monitor and troubleshoot your application's behavior without leaving the editor.

## Features
- Fast and easy log file inspection
- Command-based interface for quick access
- Smooth scrolling and navigation through large log files

## Installation

You can install **Beaver.nvim** with the following plugin managers:

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

Add this line to your lazy setup:

```lua
{
    'saneDG/beaver.nvim'
}
```

## Usage

To start using Beaver.nvim, simply open a log file in Neovim and run the following command:

```
:Beaver
```

This will activate Beaver in the current buffer, allowing you to preview and inspect the log file seamlessly.

## Watching Log File Changes

**Beaver.nvim** can automatically watch for changes in log files, making it ideal for monitoring logs in real-time. This feature allows you to keep an eye on new log entries as they appear, without manually refreshing the file.

To start watching a log file for changes, open the log file in Neovim and run:

```
:Beaver
```

With Beaver active, the log file view will update automatically whenever new entries are added, so you always have the latest information at a glance.

## Contributing

Feel free to open issues or submit pull requests to improve Beaver.nvim.
