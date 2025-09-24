---@diagnostic disable-next-line: lowercase-global
if not modules then modules = {} end
modules['t-pandocxml'] = {
  version   = "2025.09.21",
  comment   = "Conversion of Pandoc JSON files to XML",
  author    = "M. Farinella",
  copyright = "M. Farinella",
  email     = "massifrg@gmail.com",
  license   = "Public Domain"
}

---@diagnostic disable-next-line: lowercase-global
thirddata = thirddata or {}

-- load types' annotations
---@module "luals-pandoc-json-annotations"
---@module "luals-context-xml-annotations"

local string_match = string.match
local string_gsub = string.gsub
local table_concat = table.concat
local table_insert = table.insert
local table_remove = table.remove
local sortedpairs = table.sortedpairs
local table_serialize = table.serialize
local json = utilities.json
local context = context
local lxml = lxml
local xml = xml
local interfaces = interfaces
local environment = environment
local is_mtxrun_script = interfaces and true or false

local log_report = logs.reporter('json2xml')
local log
if is_mtxrun_script then
  log = function(msg)
    log_report(msg)
  end
else
  log = function(msg)
    io.stderr:write(msg .. "\n")
  end
end

local DEFAULT_API_VERSION = { 1, 23 }

local INCLUDE_SRC_ATTR = "include-src"
local INCLUDE_DOC_CLASS = "include-doc"
local INCLUDED_CLASS = "included"

local NEWLINE = "\n"

local TAG_PANDOC = 'Pandoc'
local TAG_META = 'meta'
local TAG_META_MAP_ENTRY = 'entry'
local ATTR_META_MAP_TEXT = 'text'
local TAG_BLOCKS = 'blocks'
local TAG_LIST_ITEM = 'item'
local TAG_DEF_LIST_TERM = 'term'
local TAG_DEF_LIST_DEF = 'def'
local TAG_LINEBLOCK_LINE = 'line'
local TAG_CAPTION = 'Caption'
local TAG_CAPTION_SHORT = 'ShortCaption'
local TAG_TABLE_HEAD = "TableHead"
local TAG_TABLE_BODY = "TableBody"
local TAG_TABLE_BODY_HEADER = "header"
local TAG_TABLE_BODY_BODY = "body"
local TAG_TABLE_FOOT = "TableFoot"
local TAG_TABLE_COLSPECS = 'colspecs'
local TAG_TABLE_COLSPEC = 'ColSpec'
local ATTR_COL_WIDTH = 'col-width'
local COL_WIDTH_DEFAULT_VALUE = '0' -- was "ColWidthDefault"
local TAG_TABLE_HEADER_ROW = 'Row'
local TAG_TABLE_ROW = 'Row'
local TAG_TABLE_HEADER_CELL = 'Cell'
local TAG_TABLE_CELL = 'Cell'
local ATTR_API_VERSION = 'api-version'
-- local ATTR_TABLE_BODY_HEAD_ROWS = 'head-rows'
local ATTR_TABLE_BODY_HEAD_COLS = 'row-head-columns' -- was "head-columns"
local ATTR_TABLE_CELL_ALIGN = 'alignment'            -- was "align"
local ATTR_TABLE_CELL_COLSPAN = 'col-span'           -- was "colspan"
local ATTR_TABLE_CELL_ROWSPAN = 'row-span'           -- was "rowspan"
local TAG_CITATION = 'Citation'
local TAG_CITATIONS = 'citations'
local ATTR_CITATION_ID = 'id'
local TAG_CITATION_PREFIX = 'prefix'
local TAG_CITATION_SUFFIX = 'suffix'
local ATTR_CITATION_MODE = 'mode'
local ATTR_CITATION_NOTE_NUM = 'note-num'
local ATTR_CITATION_HASH = 'hash'

---Return the inner filename.
---@param state PandocJsonParseState
---@return string
local function currentFilename(state)
  return state.filenames[#state.filenames]
end

---Return the inner filename.
---@param state PandocJsonParseState
---@return integer
local function currentLine(state)
  return state.counters[#state.counters]
end

---Return a parser state with line counter incremented.
---@param state PandocJsonParseState
---@return PandocJsonParseState
local function incrementLine(state)
  local lastIndex = #state.counters
  if not state.inMeta then
    state.counters[lastIndex] = state.counters[lastIndex] + 1
  end
  return state
end

---Return a parser state with the `inMeta` field set to the value passed as 2nd argument.
---@param state PandocJsonParseState
---@return PandocJsonParseState
local function setInMeta(state, in_meta)
  state.inMeta = in_meta
  return state
end

---Return a parser state with a document added to the filenames stack.
---@param state PandocJsonParseState
---@param filename string
---@return PandocJsonParseState
local function enterSubDocument(state, filename)
  table_insert(state.filenames, filename)
  table_insert(state.counters, 1)
  log('Entering subdocument "' .. filename .. '", depth ' .. #state.filenames)
  return state
end

---Return a parser state with the inner document removed from the filenames stack.
---@param state PandocJsonParseState
---@return PandocJsonParseState
local function exitSubDocument(state)
  log('Exiting subdocument "' .. state.filenames[#state.filenames] .. '", depth ' .. #state.filenames)
  table_remove(state.filenames, #state.filenames)
  table_remove(state.counters, #state.counters)
  return state
end

---Create an XML element as lua table.
---@param state PandocJsonParseState The current state of the parser.
---@param tag string The name of the tag.
---@param index integer The index inside the parent element.
---@return CtxXmlElement
local function createXmlElement(state, tag, index)
  local elem = {
    tg = tag,
    ni = index,
    ns = "",
    rn = "",
    at = {},
    dt = {}
  }
  if state.synctex then
    elem.cf = currentFilename(state)
    elem.cl = currentLine(state)
  end
  setmetatable(elem, state.mt)
  return elem
end

---Set the children nodes of an XML element.
---@param element CtxXmlElement
---@param children CtxXmlContent[] The element children nodes.
---@param at? table<string,string> The attributes of this element.
---@return CtxXmlElement
local function setXmlChildren(element, children, at)
  for i = 1, #children do
    local child = children[i]
    if type(child) == 'table' then
      child.__p__ = element
    end
  end
  element.dt = children or {}
  element.at = at or {}
  return element
end

---Populate the "at" table of an XML element with the attributes of a Pandoc Attr.
---@param attr PandocJsonAttr
---@return table
local function atFromAttr(attr)
  local at = {}
  local identifier, classes, attributes = attr[1], attr[2], attr[3]
  if identifier and identifier ~= '' then
    at.id = identifier
  end
  if #classes > 0 then
    at.class = table_concat(classes, " ")
  end
  for i = 1, #attributes do
    local attribute = attributes[i]
    local name, value = attribute[1], attribute[2]
    if name ~= 'id' and name ~= 'class' then
      at[name] = value
    end
  end
  return at
end

---Fix the ni field of an array of XML nodes.
---@param elems CtxXmlContent[] An array of XML nodes in a lua table.
---@param start? integer The index (the value of the ni field) of the first element.
---@return CtxXmlContent[]
local function reIndexElements(elems, start)
  local index = start or 1
  for i = 1, #elems do
    local elem = elems[i]
    if type(elem) == 'table' then
      elem.ni = index
    end
    index = index + 1
  end
  return elems
end

-- forward declarations
local metaValueToXml = function(value, state, index) end
local inlineToXml = function(inline, state, index) end
local inlinesToXml = function(inlines, state, start) return {} end
local blockToXml = function(block, state, index) end
local blocksToXml = function(blocks, state, start, separator) return {} end

---Convert a MetaMap into XML.
---@param map table<string,PandocJsonItem>
---@param state PandocJsonParseState
---@param separator? string Text separating entries (usually a newline)
---@return CtxXmlContent[]
local function metaMapEntriesToXml(map, state, separator)
  local sep = separator or NEWLINE
  local index = 1
  local entries = {} ---@type CtxXmlContent[]
  for key, value in sortedpairs(map) do
    local element = createXmlElement(state, TAG_META_MAP_ENTRY, index + 1)
    local child = metaValueToXml(value, state, 1)
    if child then
      if sep then
        table_insert(entries, sep)
        index = index + 2
      else
        index = index + 1
      end
      setXmlChildren(element, { child }, { [ATTR_META_MAP_TEXT] = key })
      table_insert(entries, element)
    end
  end
  if #entries > 0 and sep then
    table_insert(entries, sep)
  end
  return entries
end

---Convert a single MetaValue into XML.
---@param value PandocJsonItem
---@param state PandocJsonParseState
---@param index integer
---@return CtxXmlElement|nil
metaValueToXml = function(value, state, index)
  local t, c = value.t, value.c
  local element = createXmlElement(state, t, index)
  local children = {}
  local at = {}
  if t == 'MetaString' then
    children = { c }
  elseif t == 'MetaInlines' then
    children = inlinesToXml(c, state, 1)
  elseif t == 'MetaBlocks' then
    children = blocksToXml(c, state, 1)
  elseif t == 'MetaBool' then
    if c then
      at = { value = "true" }
    else
      at = { value = "false" }
    end
  elseif t == 'MetaList' then
    local lindex = 1
    for i = 1, #c do
      table_insert(children, NEWLINE)
      table_insert(children, metaValueToXml(c[i], state, lindex))
      lindex = lindex + 2
    end
    table_insert(children, NEWLINE)
  elseif t == 'MetaMap' then
    children = metaMapEntriesToXml(c, state)
  else
    log("MetaValue \"" .. t .. '" unknown')
    return nil
  end
  setXmlChildren(element, children, at)
  return element
end

---Transform an Inlines into an xml element or a string.
---@param inline PandocJsonInline An Inline in Pandoc JSON format.
---@param state PandocJsonParseState The current state of the parser.
---@param index integer The index of this inline inside its parent.
---@return CtxXmlContent|nil
inlineToXml = function(inline, state, index)
  local t, c = inline.t, inline.c
  if t == 'Str' then
    return c
  elseif t == 'Space' then
    return ' '
  end
  local element = createXmlElement(state, t, index)
  local children = {}
  local at = {}
  if t == 'Emph'
      or t == 'Underline'
      or t == 'Strong'
      or t == 'Strikeout'
      or t == 'Superscript'
      or t == 'Subscript'
      or t == 'SmallCaps' then
    children = inlinesToXml(c, state)
  elseif t == 'Span' then
    at = atFromAttr(c[1])
    children = inlinesToXml(c[2], state)
  elseif t == 'Quoted' then
    at = { ["quote-type"] = c[1].t }
    children = inlinesToXml(c[2], state)
  elseif t == 'Cite' then
    local citation_elements = {}
    local pandoc_citations = c[1]
    for i = 1, #pandoc_citations do
      local pandoc_citation = pandoc_citations[i]
      local citation = createXmlElement(state, TAG_CITATION, i)
      local citation_contents = {}
      if #pandoc_citation.citationPrefix > 0 then
        local prefix = createXmlElement(state, TAG_CITATION_PREFIX, 1)
        setXmlChildren(prefix, inlinesToXml(pandoc_citation.citationPrefix, state))
        table_insert(citation_contents, prefix)
      end
      if #pandoc_citation.citationSuffix > 0 then
        local suffix = createXmlElement(state, TAG_CITATION_SUFFIX, 2)
        setXmlChildren(suffix, inlinesToXml(pandoc_citation.citationSuffix, state))
        table_insert(citation_contents, suffix)
      end
      setXmlChildren(
        citation,
        citation_contents,
        {
          [ATTR_CITATION_ID] = pandoc_citation.citationId,
          [ATTR_CITATION_MODE] = pandoc_citation.citationMode.t,
          [ATTR_CITATION_NOTE_NUM] = tostring(pandoc_citation.citationNoteNum),
          [ATTR_CITATION_HASH] = tostring(pandoc_citation.citationHash),
        }
      )
      table_insert(citation_elements, citation)
      table_insert(citation_elements, NEWLINE)
    end
    children = inlinesToXml(c[2], state, 2)
    if #citation_elements > 0 then
      local citations = createXmlElement(state, TAG_CITATIONS, 1)
      table_insert(citation_elements, 1, NEWLINE)
      setXmlChildren(citations, citation_elements)
      table_insert(children, 1, citations)
    end
  elseif t == 'Code' then
    at = atFromAttr(c[1])
    children = { c[2] }
  elseif t == 'LineBreak' or t == 'SoftBreak' then
    -- empty elements
  elseif t == 'Math' then
    at = { ["math-type"] = c[1].t }
    children = { c[2] }
  elseif t == 'RawInline' then
    at = { format = c[1] }
    children = { c[2] }
  elseif t == 'Link' then
    at = atFromAttr(c[1])
    local target = c[3]
    at.href = target[1]
    at.title = target[2]
    children = inlinesToXml(c[2], state)
  elseif t == 'Image' then
    at = atFromAttr(c[1])
    local target = c[3]
    at.src = target[1]
    at.title = target[2]
    children = inlinesToXml(c[2], state)
  elseif t == 'Note' then
    children = blocksToXml(c, state)
  else
    log("Inline \"" .. t .. '" unknown')
    return nil
  end
  setXmlChildren(element, children, at)
  return element
end

---Transform a list of Inlines into a list of strings or xml elements.
---@param inlines PandocJsonInline[] A list of Inlines in Pandoc JSON format.
---@param state PandocJsonParseState The current state of the parser.
---@param start? integer The starting index for the first inline (nil means 1).
---@return CtxXmlContent[]
inlinesToXml = function(inlines, state, start)
  local contents = {} ---@type CtxXmlContent[]
  local index = start or 1
  local strings = {}
  local content
  for i = 1, #inlines do
    content = inlineToXml(inlines[i], state, index)
    if content then
      if (type(content) == 'string') then
        table_insert(strings, content)
      else
        if #strings > 0 then
          table_insert(contents, table_concat(strings, ''))
          strings = {}
          index = index + 1
          content.ni = index
        end
        table_insert(contents, content)
        index = index + 1
      end
    else
      log("can't decode Inline \"" .. inlines[i].t .. '"')
    end
  end
  if #strings > 0 then
    table_insert(contents, table_concat(strings, ''))
  end
  return contents
end

local function createListItems(state, pandoc_c)
  local items = {}
  for i = 1, #pandoc_c do
    table_insert(items, NEWLINE)
    local item = createXmlElement(state, TAG_LIST_ITEM, i)
    setXmlChildren(item, blocksToXml(pandoc_c[i], state))
    table_insert(items, item)
  end
  table_insert(items, NEWLINE)
  return items
end

---Create a Caption from the short and long caption JSON contents.
---@param state PandocJsonParseState
---@param short PandocJsonInline[]
---@param long PandocJsonBlock[]
---@return CtxXmlElement
local function createCaption(state, short, long)
  local short_caption = nil
  if short then
    short_caption = createXmlElement(state, TAG_CAPTION_SHORT, 1)
    local short_caption_contents = inlinesToXml(short, state)
    setXmlChildren(short_caption, short_caption_contents)
  end
  local start = 1
  if short_caption then
    start = 2
  end
  local caption = createXmlElement(state, TAG_CAPTION, 1)
  local caption_blocks = blocksToXml(long, state, start) or {}
  if short_caption then
    table_insert(caption_blocks or {}, 1, short_caption)
  end
  if #caption_blocks > 0 then
    table_insert(caption_blocks, 1, NEWLINE)
  end
  setXmlChildren(caption, reIndexElements(caption_blocks))
  return caption
end

local function createRow(state, pandoc_row, index, is_header, header_columns)
  local row_tag
  if is_header then
    row_tag = TAG_TABLE_HEADER_ROW
  else
    row_tag = TAG_TABLE_ROW
  end
  local row = createXmlElement(state, row_tag, index)
  local count_header_columns = header_columns or 0
  local pandoc_cells = pandoc_row[2]
  local cells = {}
  local cell_tag
  for i = 1, #pandoc_cells do
    if i > count_header_columns then
      cell_tag = TAG_TABLE_CELL
    else
      cell_tag = TAG_TABLE_HEADER_CELL
    end
    local cell = createXmlElement(state, cell_tag, i)
    local pandoc_cell = pandoc_cells[i]
    local cell_at = atFromAttr(pandoc_cell[1])
    cell_at[ATTR_TABLE_CELL_ALIGN] = pandoc_cell[2].t
    local rowspan = pandoc_cell[3]
    if rowspan > 1 then
      cell_at[ATTR_TABLE_CELL_ROWSPAN] = tostring(rowspan)
    end
    local colspan = pandoc_cell[4]
    if colspan > 1 then
      cell_at[ATTR_TABLE_CELL_COLSPAN] = tostring(colspan)
    end
    setXmlChildren(cell, blocksToXml(pandoc_cell[5], state), cell_at)
    table_insert(cells, NEWLINE)
    table_insert(cells, cell)
  end
  if #cells > 0 then
    table_insert(cells, NEWLINE)
  end
  setXmlChildren(row, reIndexElements(cells), atFromAttr(pandoc_row[1]))
  return row
end

---Transform a single Blocks into an xml element.
---@param block PandocJsonBlock A Block in Pandoc JSON format.
---@param state PandocJsonParseState The current state of the parser.
---@param index integer The index of this block inside its parent.
---@return CtxXmlElement|nil
blockToXml = function(block, state, index)
  local t, c = block.t, block.c
  if t == 'Para' or t == 'Plain' then
    state = incrementLine(state)
    local para_or_plain = createXmlElement(state, t, index)
    return setXmlChildren(para_or_plain, inlinesToXml(c, state))
  end
  if t == 'Header' then
    state = incrementLine(state)
    local header = createXmlElement(state, t, index)
    local at = atFromAttr(c[2])
    at.level = tostring(c[1])
    return setXmlChildren(header, inlinesToXml(c[3], state), at)
  end
  local element = createXmlElement(state, t, index)
  local at = {}
  local children = {}
  if t == 'LineBlock' then
    local lines = {}
    for i = 1, #c do
      state = incrementLine(state)
      local line = createXmlElement(state, TAG_LINEBLOCK_LINE, i)
      setXmlChildren(line, inlinesToXml(c[i], state))
      table_insert(lines, NEWLINE)
      table_insert(lines, line)
    end
    if #lines > 0 then
      table_insert(lines, NEWLINE)
    end
    children = reIndexElements(lines)
  elseif t == 'CodeBlock' then
    at = atFromAttr(c[1])
    children = { c[2] }
  elseif t == 'RawBlock' then
    at = { format = c[1] }
    children = { c[2] }
  elseif t == 'BlockQuote' then
    children = blocksToXml(c, state)
  elseif t == 'OrderedList' then
    at = {
      start = tostring(c[1][1]),
      ["number-style"] = c[1][2].t,
      ["number-delim"] = c[1][3].t
    }
    children = reIndexElements(createListItems(state, c[2]))
  elseif t == 'BulletList' then
    children = reIndexElements(createListItems(state, c))
  elseif t == 'DefinitionList' then
    local items = {}
    for i = 1, #c do
      state = incrementLine(state)
      local item = createXmlElement(state, TAG_LIST_ITEM, i)
      local term = createXmlElement(state, TAG_DEF_LIST_TERM, 1)
      setXmlChildren(term, inlinesToXml(c[i][1], state))
      local item_children = {}
      table_insert(item_children, NEWLINE)
      table_insert(item_children, term)
      local pandoc_defs = c[i][2]
      for j = 1, #pandoc_defs do
        local def = createXmlElement(state, TAG_DEF_LIST_DEF, j + 1)
        setXmlChildren(def, blocksToXml(pandoc_defs[j], state))
        table_insert(item_children, NEWLINE)
        table_insert(item_children, def)
      end
      table_insert(item_children, NEWLINE)
      setXmlChildren(item, reIndexElements(item_children))
      table_insert(items, NEWLINE)
      table_insert(items, item)
    end
    if #items > 0 then
      table_insert(items, NEWLINE)
    end
    children = reIndexElements(items)
  elseif t == 'HorizontalRule' then
    -- empty element
  elseif t == 'Table' then
    local table_items = {}
    local table_items_index = 1
    -- table attributes
    at = atFromAttr(c[1])
    -- table caption
    local caption = createCaption(state, c[2][1], c[2][2])
    table_insert(table_items, NEWLINE)
    table_insert(table_items, caption)
    -- table colspecs
    table_insert(table_items, NEWLINE)
    table_items_index = table_items_index + 1
    local colspecs_elem = createXmlElement(state, TAG_TABLE_COLSPECS, table_items_index)
    local pandoc_colspecs = c[3]
    local colspecs = {}
    for i = 1, #pandoc_colspecs do
      local colwidth = pandoc_colspecs[i][2].t
      if colwidth ~= 'ColWidthDefault' then
        colwidth = pandoc_colspecs[i][2].c
      else
        colwidth = COL_WIDTH_DEFAULT_VALUE
      end
      table_insert(colspecs, NEWLINE)
      local colspec = createXmlElement(state, TAG_TABLE_COLSPEC, i)
      setXmlChildren(colspec, {}, {
        alignment = pandoc_colspecs[i][1].t,
        [ATTR_COL_WIDTH] = tostring(colwidth)
      })
      table_insert(colspecs, colspec)
    end
    if #colspecs > 0 then
      table_insert(colspecs, NEWLINE)
    end
    setXmlChildren(colspecs_elem, reIndexElements(colspecs))
    table_insert(table_items, colspecs_elem)
    -- table head
    table_insert(table_items, NEWLINE)
    table_items_index = table_items_index + 1
    local table_head = createXmlElement(state, TAG_TABLE_HEAD, table_items_index)
    local head = c[4]
    local head_rows = {}
    local pandoc_head_rows = head[2]
    for i = 1, #pandoc_head_rows do
      table_insert(head_rows, NEWLINE)
      table_insert(head_rows, createRow(state, pandoc_head_rows[i], i, true))
    end
    if #head_rows > 0 then table_insert(head_rows, NEWLINE) end
    setXmlChildren(table_head, reIndexElements(head_rows), atFromAttr(head[1]))
    table_insert(table_items, table_head)
    -- table bodies
    local bodies = c[5]
    for b = 1, #bodies do
      table_insert(table_items, NEWLINE)
      local table_body = createXmlElement(state, TAG_TABLE_BODY, table_items_index)
      local body = bodies[b]
      table_items_index = table_items_index + 1
      local body_hrows = {}
      local body_brows = {}
      local pandoc_bheader_rows = body[3]
      for i = 1, #pandoc_bheader_rows do
        table_insert(body_hrows, NEWLINE)
        table_insert(body_hrows, createRow(state, pandoc_bheader_rows[i], i, true, body[2]))
      end
      if #body_hrows > 0 then
        table_insert(body_hrows, NEWLINE)
      end
      local pandoc_bbody_rows = body[4]
      for i = 1, #pandoc_bbody_rows do
        table_insert(body_brows, NEWLINE)
        table_insert(body_brows, createRow(state, pandoc_bbody_rows[i], i, false, body[2]))
      end
      if #body_brows > 0 then
        table_insert(body_brows, NEWLINE)
      end
      local body_header = createXmlElement(state, TAG_TABLE_BODY_HEADER, 1)
      setXmlChildren(body_header, reIndexElements(body_hrows))
      local body_body = createXmlElement(state, TAG_TABLE_BODY_BODY, 2)
      setXmlChildren(body_body, reIndexElements(body_brows))
      -- table_insert(table_items, NEWLINE)
      local body_attributes = atFromAttr(body[1])
      local body_head_cols = body[2]
      if body_head_cols > 0 then
        body_attributes[ATTR_TABLE_BODY_HEAD_COLS] = body_head_cols
      end
      setXmlChildren(table_body,
        reIndexElements({ NEWLINE, body_header, NEWLINE, body_body, NEWLINE }),
        body_attributes)
      table_insert(table_items, table_body)
    end
    -- table foot
    table_insert(table_items, NEWLINE)
    table_items_index = table_items_index + 1
    local table_foot = createXmlElement(state, TAG_TABLE_FOOT, table_items_index)
    local foot = c[6]
    local foot_rows = {}
    local pandoc_foot_rows = foot[2]
    for i = 1, #pandoc_foot_rows do
      table_insert(foot_rows, NEWLINE)
      table_insert(foot_rows, createRow(state, pandoc_foot_rows[i], i, true))
    end
    if #foot_rows > 0 then table_insert(foot_rows, NEWLINE) end
    setXmlChildren(table_foot, reIndexElements(foot_rows), atFromAttr(foot[1]))
    table_insert(table_items, table_foot)
    table_insert(table_items, NEWLINE)
    children = reIndexElements(table_items)
  elseif t == 'Figure' then
    at = atFromAttr(c[1])
    local caption = createCaption(state, c[2][1], c[2][2])
    children = blocksToXml(c[3], state) or {}
    table_insert(children, 1, caption)
    if #children > 0 then
      table_insert(children, 1, NEWLINE)
    end
    children = reIndexElements(children)
  elseif t == 'Div' then
    at = atFromAttr(c[1])
    local isInclusionDiv = false
    if at[INCLUDE_SRC_ATTR] then
      local classes = c[1][2]
      local hasIncludeDocClass, hasIncludedClass = false, false
      local clas
      for i = 1, #classes do
        clas = classes[i]
        if clas == INCLUDE_DOC_CLASS then
          hasIncludeDocClass = true
        elseif clas == INCLUDED_CLASS then
          hasIncludedClass = true
        end
      end
      isInclusionDiv = hasIncludeDocClass and hasIncludedClass
      if isInclusionDiv then
        state = enterSubDocument(state, at[INCLUDE_SRC_ATTR])
      end
    end
    children = blocksToXml(c[2], state)
    if isInclusionDiv then
      state = exitSubDocument(state)
    end
  else
    log("Block \"" .. t .. '" unknown')
    return nil
  end
  return setXmlChildren(element, children, at)
end

---Transform a list of Blocks into a list of xml elements.
---@param blocks PandocJsonBlock[] A list of Blocks in Pandoc JSON format.
---@param state PandocJsonParseState The current state of the parser.
---@param start? integer The starting index for the first block (nil means 1).
---@param separator? string A separator between blocks (default value: "\n").
---@return CtxXmlContent[]
blocksToXml = function(blocks, state, start, separator)
  local elems = {} ---@type CtxXmlContent[]
  local index = start or 1
  local sep = separator or NEWLINE
  if #blocks > 0 and sep then
    table_insert(elems, NEWLINE)
    index = index + 1
  end
  for i = 1, #blocks do
    local elem = blockToXml(blocks[i], state, index)
    if elem then
      table_insert(elems, elem)
      index = index + 1
      if sep then
        table_insert(elems, sep)
        index = index + 1
      end
    else
      log("can't decode Block \"" .. blocks[i].t .. '"')
    end
  end
  return elems
end

---Load a Pandoc document in JSON format as an XML table usable by ConTeXt XML macros.
---@param filename string The file name of the Pandoc document in JSON format.
---@param synctex? boolean Populate cf and cl synctex fields.
---@return CtxXmlDocument
local function loadPandocJsonFileAsXml(filename, synctex)
  ---@type CtxXmlDocument
  local root = xml.convert("<document></document>")

  -- initialize parser state
  ---@type PandocJsonParseState
  local state = {
    mt = getmetatable(root),
    synctex = synctex ~= false or environment.arguments.synctex,
    filenames = {},
    counters = {},
    inMeta = true -- meta is usually the first key to be parsed
  }
  -- enter main document
  state = enterSubDocument(state, filename)
  -- load pandoc JSON
  local pdoc = json.load(filename)
  if pdoc then
    -- Pandoc element
    local pandocElement = createXmlElement(state, TAG_PANDOC, 1)
    -- meta
    state = setInMeta(state, true)
    local meta = createXmlElement(state, TAG_META, 1)
    setXmlChildren(meta, metaMapEntriesToXml(pdoc.meta, state) or {})
    -- blocks
    state = setInMeta(state, false)
    local blocks = createXmlElement(state, TAG_BLOCKS, 2)
    setXmlChildren(blocks, blocksToXml(pdoc.blocks, state) or {})
    local api_version = pdoc["pandoc-api-version"] or DEFAULT_API_VERSION
    setXmlChildren(
      pandocElement,
      reIndexElements({ NEWLINE, meta, NEWLINE, blocks, NEWLINE }),
      { [ATTR_API_VERSION] = table_concat(api_version, ",") }
    )
    -- exit main document
    state = exitSubDocument(state)

    --  local root = xml.convert("<document>testa bit more</document>")
    --  xml.replace(root,"/document",xml.tostring(pandocElement))

    root.cf = filename
    root.cl = 1
    root.dt = { pandocElement }
  else
    log('file "' .. filename .. '" not loaded')
  end
  return root
end

local function processPandocJsonFileAsXml(name, filename, xmlsetup)
  local xmltable = loadPandocJsonFileAsXml(filename)
  lxml.store(name, xmltable, filename)
  context.pandocXMLprocess(xmlsetup, name)
end

if interfaces then
  interfaces.definecommand {
    name = "xmlprocesspandocjsonfile",
    arguments = {
      { "name",     "string" },
      { "filename", "string" },
      { "setup",    "string" }
    },
    macro = processPandocJsonFileAsXml
  }
end

local function save(filename, content)
  local file = io.open(filename, "w")
  if file then
    file:write(content)
    file:close()
  end
end

local function convertPandocJsonFile(json_filename, xml_filename)
  if json_filename then
    local xmltable = loadPandocJsonFileAsXml(json_filename, false)
    if xmltable then
      local xmlstring = xml.tostring(xmltable)
      if xml_filename then
        save(xml_filename, xmlstring)
      else
        print(xmlstring)
      end
    end
  end
end

---Convert a Pandoc JSON file to XML.
---@param jsonfilename string
---@param xmlfilename? string
local function convertPandocJsonFileToXmlFile(jsonfilename, xmlfilename)
  local outfilename = xmlfilename
  if not outfilename and string_match(jsonfilename, "[.]json$") then
    outfilename = string_gsub(jsonfilename, "[.]json$", ".xml")
  end
  log('converting "' .. jsonfilename .. '" to XML as "' .. outfilename .. '"')
  convertPandocJsonFile(jsonfilename, xmlfilename)
end

if interfaces then
  interfaces.definecommand {
    name = "xmlconvertpandocjsonfile",
    arguments = {
      { "option",   "list" },
      { "filename", "string" },
    },
    macro = function(filename1, filename2)
      if not context.trialtypesetting() then
        if (filename2) then
          local optional = interfaces.tolist(filename1)
          convertPandocJsonFileToXmlFile(filename2, optional[1])
        end
        convertPandocJsonFileToXmlFile(filename2)
      end
    end
  }
end

-- The following code is only to compare the xml lua tables produced
-- by pandoc JSON parsing and native ConTeXt XML parsing.

---Remove __p__ parent field from XML tree table, to be able to serialize it.
---@param t table
local function remove__p__(t)
  if type(t) == 'table' then
    t.__p__ = nil
    if (type(t.dt) == 'table') then
      local dt = t.dt
      for i = 1, #dt do
        remove__p__(dt[i])
      end
    end
  end
end

local function save_xml_tables_for_comparison()
  local JSON_FILE = 'test-pandoc-no-cite.json'
  local XML_FILE = 'test-pandoc-no-cite.xml'

  local jsondom = loadPandocJsonFileAsXml(JSON_FILE)
  -- inspect(jsondom)
  -- inspect(xml.tostring(jsondom))
  remove__p__(jsondom)
  save('xmltable-json.lua', table_serialize(jsondom, 'json'))
  save(XML_FILE, xml.tostring(jsondom))

  local xmldom = xml.load(XML_FILE)
  remove__p__(xmldom)
  -- print(table.serialize(xmldom, 'xml', true, true))
  save('xmltable-xml.lua', table_serialize(xmldom, 'xml'))
end

thirddata.pandocxml = {
  loadPandocJsonFileAsXml = loadPandocJsonFileAsXml,
  convertPandocJsonFile = convertPandocJsonFile,
  convertPandocJsonFileToXmlFile = convertPandocJsonFileToXmlFile,
}

-- save_xml_tables_for_comparison()
