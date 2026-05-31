local source = debug.getinfo(1, "S").source
source = source:gsub("^@", "")

local script_dir = source:match("^(.*)/[^/]+$")
package.path = script_dir .. "/?.lua;" .. package.path

local utils = require('utils')
local root_dir = "." --os.getenv("QUARTO_PROJECT_ROOT")
-- local logging = require('logging')

local function create_template(doc)

  -- Extract and label questions
  local extracted = utils.extract_questions(doc)
  
  -- Remove any HTML tags (e.g., <kbd>, <br>) 
  local extracted = utils.remove_html(extracted)
  
  -- Optionally, remove any markdown formatting
  -- (e.g. `1 + 1` becomes just 1 + 1 and *hello* becomes just hello)
  local preserve_md = doc.meta.format["lts-html"]["preserve-md"]
  if preserve_md == nil or not preserve_md then
    extracted = utils.remove_md(extracted)
  end
  
  -- Optionally, remove code chunk options
  local preserve_chunk_opts= doc.meta.format["lts-html"]["preserve_chunk_opts"]
  if preserve_chunk_opts == nil or not preserve_chunk_opts then
    extracted = utils.remove_chunk_opts(extracted)
  end
  
  -- Write YAML header meta data into a raw markdown block.
  -- This seems to be the best way to get the YAML into the output following the traditional order
  -- e.g. title, author, etc.
  local ordered_keys = {"title", "format"}
  
  local new_meta = pandoc.Meta(doc.meta)
  new_meta.format = "html"
  local header = utils.create_yaml_header(new_meta, ordered_keys)
  table.insert(extracted, 1, header)

  -- Convert back to markdown  
  local markdown = pandoc.write(
    pandoc.Pandoc(extracted),
    "markdown-smart",
    { wrap_text = "wrap-none" }
  )

  -- Restore Quarto code chunk syntax
  local restored = utils.md_to_quarto_chunk(markdown)
  
  return restored
  
end

local function create_solutions(doc)
  
  -- Extract and label solutions
  local extracted = utils.extract_solutions(doc)
  -- Optionally, remove code chunk options
  local echo = doc.meta.format["lts-html"]["echo-solutions"]
  if preserve_chunk_opts == nil or not preserve_chunk_opts then
    extracted = utils.remove_echo(extracted)
  end
  
  -- Write YAML header meta data into a raw markdown block.
  -- This seems to be the best way to get the YAML into the output following the traditional order
  -- e.g. title, author, etc.
  local ordered_keys = {"title", "format", "execute"}
  local new_meta = pandoc.Meta(doc.meta)
  new_meta["execute"] = {echo = false}
  new_meta["format"] = "html"
  local header = utils.create_yaml_header(new_meta, ordered_keys)
  table.insert(extracted, 1, header)

  -- Convert back to markdown  
  local markdown = pandoc.write(
    pandoc.Pandoc(extracted, doc.meta),
    "markdown-smart",
    { wrap_text = "wrap-none" }
  )

  -- Restore Quarto code chunk syntax
  local restored = utils.md_to_quarto_chunk(markdown)
  
  return restored

end

local qmd_files = utils.find_qmd_files(root_dir)

for _, path in ipairs(qmd_files) do

  local raw = utils.read_file(path)

  -- Convert R code chunks to pandoc code block format
  local normalized = utils.quarto_to_md_chunk(raw)

  -- Parse into AST, and don't use smart quotes!
  local ok, doc = pcall(function()
    return pandoc.read(normalized, "markdown-smart")
  end)
  
  if not ok then
    print(" Failed to parse" .. path)
    goto continue
  end

  if ok and utils.is_lts_format(doc.meta) then
    
    print(" Creating template and solutions from ".. path)
    
    local template_md = create_template(doc)
    utils.write_file(path:gsub("%.qmd$", "_template.qmd"), template_md)
    
    local solutions_md = create_solutions(doc)
    utils.write_file(path:gsub("%.qmd$", "_solutions.qmd"), solutions_md)
  else
    print(" Skipping " .. path .. " (not lts-html)")
  end
  
  ::continue::
end  