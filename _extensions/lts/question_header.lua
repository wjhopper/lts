local question_num = 0

function Div(div)
  
  if div.classes:includes("question") then

    if div.classes:includes("solution") then
    
      div.classes = div.classes:filter(function(class)
        return class ~= "solution" and class ~= "proof"
      end)
  
    end
    
    question_num = question_num + 1
    local heading = pandoc.Header(2, { pandoc.Str("Question " .. question_num) } )
    table.insert(div.content, 1, heading)

    return div
    
  end
  
end