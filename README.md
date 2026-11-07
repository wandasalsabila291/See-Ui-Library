# See Library

See Library is a client-side UI library for Roblox. It provides draggable and resizable windows, searchable tabs, themes, notifications, and a built-in settings tab.

## Installation

1. Create a ModuleScript named `SeeLibrary` in `ReplicatedStorage`.
2. Paste the contents of [SeeLibrary.luau](SeeLibrary.luau) into the ModuleScript.
3. Add a LocalScript to `StarterPlayer > StarterPlayerScripts` and paste the example below. Press **Play** in Studio.

## Quick start

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SeeLibrary = require(ReplicatedStorage:WaitForChild("SeeLibrary"))

local library = SeeLibrary.new()
local window = library:CreateWindow({
    Title = "Example",
    Theme = "Purple",
})

local tab = window:CreateTab({ Title = "Home" })
tab:CreateButton({
    Title = "Show notification",
    Callback = function()
        window:Notify({
            Title = "See Library",
            Description = "Your window is ready.",
        })
    end,
})
```

Press **Right Shift** to show or hide the window. Set `Settings = false` in the window options to disable the built-in settings tab.

## Components

Tabs support sections, separator lines, paragraphs, toggles, checkboxes, buttons, sliders, dropdowns, text boxes, keybinds, and color pickers.

## Optional features

- **Lucide icons** work in Studio when `ReplicatedStorage` contains a `Lucide` ModuleScript exposing `GetAsset`. You can also provide a compatible module through `SeeLibrary.SetIconModule(module)`.
- **File-based settings** require the host to provide `writefile`, `readfile`, and `isfile`. The UI can run in Studio without those functions.
