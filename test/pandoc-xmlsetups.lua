local context = context
local xml = xml

local orderedListDepth = 0
local orderedListStyles = { "n", "a", "r", "g" }

function xml.functions.startOrderedList(ol)
  local numberconversion = "arabicnumerals"
  local numberstopper = "."
  local at = ol.at
  local start = at.start and tonumber(at.start) or 1
  local number_style = at["number-style"]
  local number_delim = at["number-delim"]
  -- number style
  if number_style == "DefaultStyle" then
    numberconversion = orderedListStyles[(orderedListDepth) % 4 + 1]
  elseif number_style == "Example" then
    numberconversion = "n"
  elseif number_style == "Decimal" then
    numberconversion = "n"
  elseif number_style == "LowerRoman" then
    numberconversion = "r"
  elseif number_style == "UpperRoman" then
    numberconversion = "R"
  elseif number_style == "LowerAlpha" then
    numberconversion = "a"
  elseif number_style == "UpperAlpha" then
    numberconversion = "A"
  end
  -- number delimiter
  if number_delim == "DefaultDelim" then
    numberstopper = ""
  elseif number_delim == "Period" then
    numberstopper = "."
  elseif number_delim == "OneParen" then
    numberstopper = ")"
  elseif number_delim == "TwoParens" then
    numberstopper = "))"
  end
  context.startitemize(
    { numberconversion },
    {
      start = start,
      numberstopper = numberstopper
    }
  )
  orderedListDepth = orderedListDepth + 1
end

function xml.functions.stopOrderedList(ol)
  orderedListDepth = orderedListDepth - 1
  context.stopitemize()
end

