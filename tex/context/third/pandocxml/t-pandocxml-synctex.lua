local xml = xml
local hasclass = xml.functions.hasclass
local table_insert = table.insert
local table_remove = table.remove

local INCLUDE_DOC_CLASS = "include-doc"
local INCLUDED_CLASS = "included"
local INCLUDE_SRC_ATTR = "include-src"
local TAG_DEF_LIST_TERM = 'term'
local TAG_LINEBLOCK_LINE = 'line'
local TAG_CAPTION_SHORT = 'ShortCaption'

local log_report = logs.reporter('t-pandoc-synctex')

---@class SynctexState
---@field cf string
---@field cl integer

---@alias SynctexStack SynctexState[]

---Fill the `cf` and `cl` fields of a lua table representing
---the XML DOM of a Pandoc document
---@param el table
---@param _stack SynctexStack
local function addSynctexFields(el, _stack)
  local tg = el.tg
  if tg == 'meta' then
    return
  end
  local stack = _stack or {
    {
      cf = el.cf or "",
      cl = 0
    }
  }
  local state = stack[#stack]
  local childrenInSubdoc = false
  if tg == 'Para'
      or tg == 'Header'
      or tg == 'Plain'
      or tg == TAG_LINEBLOCK_LINE
      or tg == TAG_DEF_LIST_TERM
      or tg == TAG_CAPTION_SHORT then
    state.cl = state.cl + 1
    -- log_report('line ' .. tostring(state.cl) .. ' at ' .. tg .. ', file=' .. state.cf)
  elseif tg == 'Div' then
    local included = el.at[INCLUDE_SRC_ATTR]
    local has_include_doc_class = hasclass(el, "class", INCLUDE_DOC_CLASS)
    if not has_include_doc_class and included then
      log_report('Div with "' .. INCLUDE_SRC_ATTR .. '" attribute, but without "' .. INCLUDE_DOC_CLASS .. '" class')
    end
    if has_include_doc_class and not included then
      log_report('Div with "' .. INCLUDE_DOC_CLASS .. '" class, but without "' .. INCLUDE_SRC_ATTR .. '" attribute')
    end
    if not hasclass(el, "class", INCLUDED_CLASS) then
      log_report('Div with "' .. INCLUDE_SRC_ATTR .. '" attribute, but the inclusion of file "'
        .. included .. '" looks unsuccessful, because there\' no "' .. INCLUDED_CLASS .. '" class')
    end
    if included then
      table_insert(stack, { cf = included, cl = 0 })
      childrenInSubdoc = true
    end
  end
  -- never cl=0 even when state.cl == 0
  el.cl = state.cl > 0 and state.cl or 1
  el.cf = state.cf
  -- DEBUG
  -- local indent = ""
  -- for j = 1, #stack do
  --   indent = indent .. "  "
  -- end
  -- log_report(indent .. tg .. ": " .. el.cf .. ", line " .. tostring(el.cl))
  --- END DEBUG
  local dt = el.dt
  if type(dt) == 'table' then
    local child
    for i = 1, #dt do
      child = dt[i]
      if type(child) == 'table' then
        addSynctexFields(child, stack)
      end
    end
    if childrenInSubdoc then
      table_remove(stack)
    end
  end
end

xml.functions.addSynctexFields = addSynctexFields
