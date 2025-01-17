# Typeset Pandoc JSON files with ConTeXt

This is a module for [ConTeXt](https://wiki.contextgarden.net)
to typeset Pandoc JSON files directly with ConTeXt.

This is how it works:

- JSON documents are converted on the fly (in memory) to XML,
  as if they were parsed XML files, which means that a lua table
  is created, representing the document object model (DOM);

- as with other XML-native documents, you define xmlsetups in ConTeXt
  to associate typesetting templates (xmlsetups) to XML elements;
  the association is made through XPath-like (lpath) or CSS selectors.

## Convert Pandoc JSON files to XML

The first, simple, step you can make is to convert a Pandoc JSON file
to its XML equivalent.

Just type (you need ConTeXt to be installed on your system):

```sh
mtxrun --script pandocjsontoxml.lua mydoc.json mydoc.xml
```

where `mydoc.json` is your JSON document, and `mydoc.xml` is its translation to XML.

That way you can also check how a Pandoc document is translated into XML.

If you specify only the source file,

```sh
mtxrun --script pandocjsontoxml.lua mydoc.json
```

you'll see the XML in the standard output.

## Typeset Pandoc JSON files with ConTeXt XML setups

(TODO; for now you can look at `.tex` files in the `test` directory).

Examples:

```sh
context test1
context pandoc-testsuite
```

Both import some simple xmlsetups from `pandoc-xmlsetups.tex`.

### How Pandoc items are encoded in XML

Most of Pandoc items are JSON-encoded with a `t` (type) and a `c` (content) fields.

The most natural way to make a conversion to XML is using the `t` (type) field
as the name of an element tag.

So `Para` items become `<Para>...</Para>` elements, `Emph` inlines become `<Emph>...</Emph>`
elements, and so on.

This is the skeleton of the XML version of a JSON document:

```xml
<Pandoc api-version="1,23,1">
<meta>
...
</meta>
<blocks>
...
</blocks>
</Pandoc>
```

So the JSON outer keys, `pandoc-api-version`, `meta` and `blocks`, become, respectively,
an attribute of the root element and its two children elements.

For elements, I kept the capitalization of Pandoc types (`meta` and `blocks` are exceptions,
but they are not Pandoc items).

Lowercase tags are used also for items that don't have an explicit name in Pandoc, like list items (`<item>`), the lines of a `LineBlock` (`<line>`), or the terms (`<term>`) and definitions (`<def>`) of `DefinitionList`.
The citations in a `<Cite>` inline element become `<Citation>` elements.

For attributes, I preferred a lowercase version (kebab-case when attributes are multi-word).
So,

- `Quoted(SingleQuote)` becomes `<Quoted quote-type="SingleQuote">...</Quoted>`

- `Math(DisplayMath)` becomes `<Math math-type="DisplayMath">...</Math>`

- `RawInline` becomes `<RawInline format="...">...</RawInline>`

Items with an `Attr` behave like this:

- the identifier goes into the `id` attribute

- classes are encoded the same way as HTML, their values are joined with spaces
  and put in the `class` attribute

- other attributes are mapped on XML attributes with the _same_ name (no prefix
  like `data-` in HTML)

You should not have `id` and `class` attributes in `Attr`; in the unfortunate case
you have, they are ignored, because identifier and classes take precedence.

## Typesetting Pandoc documents directly with ConTeXt vs converting them to ConTeXt with Pandoc

Pandoc can already export documents as ConTeXt `.tex` files.
It may also call ConTeXt to typeset them as PDF files.

So why typesetting Pandoc (JSON) documents directly with ConTeXt?

Because the standard Pandoc conversion to ConTeXt format can lose much of
the information that can be carried by a Pandoc document.

You may use filters to retain some of that information and use it
by injecting `RawBlock` or `RawInline` elements of "context" format.

In particular, I'm using some conventions to provide indices and different
kinds of notes (not only footnotes), that are not supported by Pandoc,
and its `Writer` of the ConTeXt format.

You can also try to parse the native or JSON Pandoc formats directly in
ConTeXt; it's possible, because ConTeXt has Lua libraries to parse JSON
or even the native format (through LPEGs).
But you must transform the parsed information into ConTeXt macro calls.

I already did some typesetting XML with ConTeXt, and Pandoc internal format
can be converted to XML in quite a natural way (see above), so I prefer 
transforming the JSON files into XML, and then use ConTeXt's macros
designed for XML typesetting.

Moreover, the conversion from JSON to XML can be done on the fly in
memory by ConTeXt.

## The structure and formats of Pandoc documents

Pandoc always converts input files into an internal format,
before writing the document in the desired output format.

That internal format stores the maximum of information that can
pass through Pandoc, and it is storable as a file in two formats:

- native: a textual format that represents a document in the way
          you would instantiate it through Haskell constructors;
          it's fairly human-readable;

- json:   a JSON representation of the document, where nearly every
          textual item has a "t" (type) field and a "c" field (content);
          it's really granular and rather unreadable, despite being
          a textual format.

The internal model is tree-like, and a transformation of it into XML
is pretty straightforward (see above).

## Further use in pundok-editor

Synctex information can be injected in the lua table of the
XML representation of a Pandoc JSON document;
that information can be later used by a PDF reader to open the
source file at the position corresponding to the point clicked
in the PDF preview.

In particular, the PDF reader should make
[pundok-editor](https://github.com/massifrg/pundok-editor), an editor
for Pandoc JSON files, open the right JSON file at the start of the
paragraph clicked on the PDF preview.

## Retrieving source files coordinates for synctex (not yet implemented)

The documents in pundok-editor can be spread in a tree of JSON source files.

`Div` elements with an `include-doc` class and a few other attributes are
used as references for the sub-documents to be included as a replacement
of their placeholder contents.

The inclusion and assembling of sub-documents is done with pandoc and
a filter: [pandoc-include-doc](https://github.com/massifrg/pandoc-include-doc).

Tracing those `Div` elements and counting the `Para` elements, it should be possible
to populate the `cf` and `cl` fields of XML elements in the XML lua table in ConTeXt.

The `cl` line is meant for the line in a text source file, in this case I would use
it as a counter of `Para`, paragraph elements in Pandoc, which is the textual element
that is most similar to a line in a plain text document.

Feeding back those coordinates (source file + paragraph counter), the editor should
be able to open the right file, and then count paragraphs to put the cursor at the
start of the desired one.

As a refinement, the count should be extended to other paragraph-like blocks
in Pandoc: the ones that contain a list of
[Inlines](https://hackage.haskell.org/package/pandoc-types-1.23.1/docs/Text-Pandoc-Definition.html#t:Inline),
like `Header`, `Plain`, every line in `LineBlock`, every term of a `DefinitionList`
(see [Pandoc model](https://hackage.haskell.org/package/pandoc-types-1.23.1/docs/Text-Pandoc-Definition.html)).
