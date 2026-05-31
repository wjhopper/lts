local utils = {}

utils.read_file = function(path)
  local f = assert(io.open(path, "r"))
  local text = f:read("*all")
  f:close()
  return text
end

utils.write_file = function(path, text)
  local f = assert(io.open(path, "w"))
  f:write(text)
  f:close()
end

utils.file_exists = function(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

-- Searches recursively for files with .qmd extension
utils.find_qmd_files = function(root)

  local files = {}

  local cmd

  if package.config:sub(1,1) == "\\" then
    -- Windows
    cmd = 'dir "' .. root .. '" /s /b *.qmd'
  else
    -- Unix/macOS/Linux
    cmd = 'find "' .. root .. '" -type f -name "*.qmd"'
  end

  local pipe = io.popen(cmd)

  for line in pipe:lines() do
    table.insert(files, line)
  end

  pipe:close()

  return files
end

-- Check whether document uses lts-html format
utils.is_lts_format = function(meta)
  
  local format = meta.format
  
  if not format then
    return false
  end

  -- Checks for nested yaml e.g.
  -- format:
  --   lts-html:
  --     toc: true

  if format["lts-html"] ~= nil then
    return true
  end

  -- Checks for plain yaml form e.g.
  -- format: lts-html
  format_string = pandoc.utils.stringify(format)

  return format_string:match("lts%-html") ~= nil

end

-- Convert quarto code chunk syntax into general markdown code blocks
utils.quarto_to_md_chunk = function(text)

  -- Converts from code chunks formatted like:
  -- ```{r echo=FALSE}
  -- to markdown code blocks formatted like:
  -- ```r echo=FALSE
  return text:gsub(
    "```%s*{%s*([%w%+%-%_]+)%s*([^}]*)}",
    "```%1%2"
  )

end

utils.md_to_quarto_chunk = function(text)

  -- Converts from markdown code blocks formatted like:
  -- ```r echo=FALSE
  -- to code chunks formatted like:
  -- ```{r echo=FALSE}
  return text:gsub(
    "```[ \t\r]*([%w%+%-%_]+)([^\n]*)",
    "```{%1%2}"
  )
end

local function render_meta_value(key, value)

  -- Create a temporary Meta object containing only one key
  local meta = pandoc.Meta({
    [key] = value
  })

  -- Ask pandoc's markdown writer to serialize it
  local rendered = pandoc.write(
    pandoc.Pandoc({}, meta),
    "markdown-smart",
    {
      template = "$titleblock$"
    }
  )

  -- Remove surrounding --- YAML fences if present
  rendered = rendered:gsub("^%-%-%-\n", "")
  rendered = rendered:gsub("\n%-%-%-\n?$", "")

  return rendered
end

-- Needed because the normal technique for writing meta data into file (by passing it to
-- pandoc.write) always writes YAML keys in an alphabetical order
-- and we don't want execute, knitr, keys coming before title or format!
-- it's just not natual for a Quarto doc

utils.create_yaml_header = function(meta, allowed_keys)

  local header = {}
  
  table.insert(header, "---")

  for _, key in ipairs(allowed_keys) do

    local value = meta[key]

    if value then
      table.insert(header, render_meta_value(key, value))
    end
  
  end

  table.insert(header, "---")

  local yaml = table.concat(header, "\n")

  return pandoc.RawBlock("markdown", yaml)

end

utils.extract_questions = function(doc)

  local question_blocks = {}
  local q_num = 0

  local function collect(el)

    if el.classes:includes("question") then

      q_num = q_num + 1

      table.insert(
        question_blocks,
        pandoc.Header(
          2,
          { pandoc.Str("Question " .. q_num) }
        )
      )

      for _, block in ipairs(el.content) do
        table.insert(question_blocks, block)
      end
    end

    return nil
  end

  pandoc.walk_block(
    pandoc.Div(doc.blocks),
    {
      Div = collect
    }
  )

  return question_blocks

end

utils.remove_html = function(blocks)
  
  local function strip_html_tags(s)
    return s:gsub("<[^>]+>", "")
  end
  
  local function clean_element(el)
    if el.t == "RawInline" and el.format == "html" then
      return {} -- remove
    end
  
    if el.t == "RawBlock" and el.format == "html" then
      return {} -- remove
    end
    
    if el.t == "Str" then
      el.text = strip_html_tags(el.text)
      return el
    end
  end
  
  local function clean_code(el)
    return {el.text}
  end
  
  return pandoc.walk_block(
    pandoc.Div(blocks),
    {
      RawInline = clean_element,
      RawBlock  = clean_element,
      Str       = clean_element
    }
  ).content

end

utils.remove_md = function(blocks)
  
  local function flatten_para(el)
    
    local plain = pandoc.write(
      pandoc.Pandoc({ el }),
      "plain-smart",
      { wrap_text = "wrap-none" }
    )
    
    plain = plain:gsub("%s+$", "")

    local x = pandoc.RawInline('markdown', plain)
    return x
    
  end
  
  return pandoc.walk_block(
    pandoc.Div(blocks), 
    {
      Para = flatten_para,
      BulletList = flatten_para
    }
  ).content

end

utils.remove_chunk_opts = function(blocks)
  
  return pandoc.walk_block(
    pandoc.Div(blocks), 
    {
    CodeBlock = function(el)
      -- Regex should match this format
      -- #| echo: fenced
      el.text = el.text:gsub("^#|%s+%a+:%s+%a+\n", "")
      return el
    end
    }
  ).content

end

utils.extract_solutions = function(doc)

  question_blocks = {}
  local q_num = 0

  local function collect(el)

    if el.classes:includes("solution") then

      q_num = q_num + 1
      question_header = { pandoc.Str("Question " .. q_num) } 
      table.insert(el.content, 1, pandoc.Header(2, question_header) )

      el.classes = {"question"}
      table.insert(question_blocks, el)
      return el
    
    end

    return nil
  end

  pandoc.walk_block(
    pandoc.Div(doc.blocks),
    {
      Div = collect
    }
  )

  return question_blocks

end

utils.remove_echo  = function(blocks)
  
  return pandoc.walk_block(
    pandoc.Div(blocks), 
    {
    CodeBlock = function(el)
      -- Regex should match this format
      -- #| echo: fenced
      el.text = el.text:gsub("^#|%s+echo:%s+%a+\n", "")
      return el
    end
    }
  ).content

end


return utils