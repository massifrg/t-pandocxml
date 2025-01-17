---@class PandocJsonParseState
---@field mt metatable The XML lua table metatable.
---@field synctex boolean Populate cf and cl synctex fields in elements.
---@field filenames string[] Names of the JSON source files, for synctex.
---@field counters integer[] Line number (or equivalent) of the JSON source files, for synctex.

---@class PandocJsonItem
---@field t string Type of the item.
---@field c any Content of the item.

---@class PandocJsonInline : PandocJsonItem

---@class PandocJsonBlock : PandocJsonItem

---@alias PandocJsonAttr table
