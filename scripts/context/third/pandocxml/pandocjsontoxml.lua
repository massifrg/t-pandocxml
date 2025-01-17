local helpinfo    = [[
<?xml version="1.0"?>
<application>
<metadata>
<entry name="name">pandocjsontoxml</entry>
<entry name="detail">Pandoc JSON to XML converter</entry>
<entry name="version">0.10</entry>
</metadata>
<examples>
  <category>
   <title>Examples</title>
   <subcategory>
    <example><command>mtxrun --script pandocjsontoxml file.json</command></example>
    <example><command>mtxrun --script pandocjsontoxml file.json file.xml</command></example>
   </subcategory>
  </category>
 </examples>
</application>
]]

local application = logs.application {
  name     = "pandocjsontoxml",
  banner   = "Pandoc JSON to XML converter",
  helpinfo = helpinfo,
}

local report      = application.report

scripts           = scripts or {}

require("t-pandocxml")

local thirddata = thirddata or { pandocxml = {} }
local pandocxml = thirddata.pandocxml
local convertPandocJsonFile = pandocxml.convertPandocJsonFile

local function do_conversion(json_file, xml_file)
  if convertPandocJsonFile then
    convertPandocJsonFile(json_file, xml_file)
  end
end

local arg_files = environment.files

if #arg_files == 1 or #arg_files == 2 then
  do_conversion(arg_files[1], arg_files[2])
else
  application.help()
end
