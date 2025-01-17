---@class CtxXmlNode
---@field tg string The node's name (element name or "@rt@" for root, "@pi@" for processing instruction, etc.).
---@field at table<string,string> The element's attributes.
---@field cf string The current source file for synctex.
---@field cl integer The current line in the source file, for synctex.
---@field ni integer The current index among siblings, as children of the parent node.
---@field ns string The node's namespace.
---@field rn string "???".
---@field dt CtxXmlContent[] The node's children.
---@field __p__? CtxXmlElement|CtxXmlDocument The node's parent.

---@class CtxXmlElement : CtxXmlNode

---@alias CtxXmlContent string | CtxXmlElement xml content.

---@class CtxXmlDocument : CtxXmlNode
---@field tg "@rt@" It's always "@rt@".
---@field ri integer "???"
---@field settings CtxXmlDocSettings Settings.
---@field special boolean "???".
---@field statistics CtxXmlDocStatistics Statistics.
---@field cf? string The current source file for synctex.
---@field cl? integer The current line in the source file, for synctex.
---@field ni? integer The current index among siblings, as children of the parent node.
---@field rn? string "???".

---@class CtxXmlDocSettings
---@field linenumbers boolean "???".
---@field resolve_predefined_entities boolean "???".
---@field utfize_entities boolean "???".

---@class CtxXmlDocStatistics
---@field entities CtxXmlDocEntities "???".

---@class CtxXmlDocEntities
---@field decimals table "???".
---@field hexadecimals table "???".
---@field intermediates table "???".
---@field names table "???".

---@class SynctexCoords
---@field cf string The current filename.
---@field cl integer The current line.

---@class CtxXmlSettings
---@field parent table
---@field name string
---@field linenumbers boolean
---@field strip_cm_and_dt boolean
---@field utfize_entities boolean
---@field resolve_entities boolean
---@field resolve_predefined_entities boolean
---@field unify_predefined_entities boolean
---@field text_cleanup boolean
---@field entities CtxXmlEntities
---@field currentresource string
---@field preprocessor function
---@field parent_root table
---@field error_handler any
---@field no_root boolean

---@class CtxXmlEntities
---@field decimals table
---@field hexadecimals table
---@field intermediates table
---@field names table<string,string> Name to content translation of entities.

---@class CtxXmlState
---@field linenumbers boolean Track line numbers.
---@field stack table
---@field level integer Depth.
---@field top table
---@field at table Attributes.
---@field mt metatable Metatable.
---@field dt CtxXmlContent[] Children.
---@field nt integer
---@field xmlns table Namespaces
---@field errorstr? string Error message in case of errors.
---@field strip? boolean Strip cm and dt.
---@field utfize? boolean Make entities UTF.
---@field resolve? boolean Resolve entities.
---@field resolve_predefined? boolean Resolve predefined entities.
---@field unify_predefined? boolean Unify predefined entities.
---@field cleanup? boolean Text cleanup.
---@field entities CtxXmlEntities Entities.
---@field currentfilename string Current file name or resource.
---@field currentline integer Current line.
---@field parameters table
---@field reported_at_errors table
---@field dcache table
---@field hcache table
---@field acache table
