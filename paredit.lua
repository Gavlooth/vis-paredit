-- load standard vis module,  providing parts of the Lua API

require('vis')

lisp_file_types ={"clj", "cljs" , "lisp", "cljx", "cljc", "edn"}

function paredit_remove_filetype (x)
  for k,v in pairs(lisp_file_types)do
    if v == x  then
      lisp_file_types[k]=nil
    end
  end
end

function paredit_add_filetype (x)
  if type(x) == "string" then
    table.insert(lisp_file_types, x)
  end
end

local lexers = vis.lexers
local l = require('lexer')
local match = lpeg.match
local P, R, S = lpeg.P, lpeg.R, lpeg.S
local char_sexp_literals = P{"\\" * S('(){}[]"') }
local char_literals = P{"\\" * (l.graph -  S("n\"\\"))}
local str_pattern = ('"' *  ( ( P("\\\"") +    (1 -  S('"'))))^0 * '"')
local strings_and_chars = str_pattern + char_sexp_literals
local lisp_word = (((l.graph -  S("(){}[]\"\\")) + char_literals))^1

function find_first (p)
 local I = lpeg.Cp ()
  return lpeg.P{ I * p * I + 1 * lpeg.V(1) }
end

function is_lisp_file ()
  local ex = vis.win.file.name
  if ex~=nil then
    local matcher = lpeg.P(lisp_file_types[1]) * P(-1)
    for i = 2, #lisp_file_types do
      matcher = matcher + lpeg.P(lisp_file_types[i] ) * P(-1)
    end
    return match(find_first (matcher), ex)
  else return nil
  end
end


local simple_sexp = P{("(" * ((1 - S("(){}[]\"")) + strings_and_chars + lpeg.V(1))^0 * ")") +
("[" * ((1 - S("(){}[]\"")) + strings_and_chars + lpeg.V(1))^0 * "]") +
("{" * ((1 - S("(){}[]\"")) + strings_and_chars  + lpeg.V(1))^0 * "}")}


local complete_balanced_sexp =   P{("(" * ((1 - S("(){}[]\"")) + strings_and_chars + lpeg.V(1))^0 * ")") +
("[" * ((1 - S("(){}[]\"")) + strings_and_chars + lpeg.V(1))^0 * "]") +
("{" * ((1 - S("(){}[]\"")) + strings_and_chars  + lpeg.V(1))^0 * "}") +
(((l.graph -  S("(){}[]\"\\")) + char_literals))^1+ str_pattern^1  }


local empty_sexp = P{( "(" *  S(" \n")^0  * ")") +
( "[" *  S(" \n")^0  * "]") + ( "{" *  S(" \n")^0  * "}")}

local match_sexp = {["("] = ")",
[")"] = "(",
["["] = "]",
["]"] = "[",
["{"] = "}",
["}"] = "{",
["\""]="\"" }


function print_two (a,b)
  print ("  " .. tostring (a) .. "--" .. tostring(b))
end


function prinf (a,b,c)
 vis:info("  " .. tostring(a) .. " " .. tostring (b) .. " " .. tostring (c) )
end


function prinmsg (a,b,c)
 vis:message("  " .. tostring(a) .. " " .. tostring (b) .. " " .. tostring (c) )
end



function trim_space_around (pos)
  local file = vis.win.file
  local text = file:content(0,  vis.win.file.size)
  if  match ( S('\r\n\f\t ')^1, file:content(pos,  1)) and pos > 0 then
    local _ , start_pos = match (last_occurance(l.graph),vis.win.file:content(0, pos )  )
    local end_pos, _ = match(next_occurance(l.graph),file:content(pos + 1, file.size -pos -1 ) )
    file:delete(start_pos, end_pos + pos - start_pos   )
    vis.win.selection.pos = start_pos -1
  end
  return pos
end



function is_sexp (start, finish)
local text = vis.win.file:content(start ,  finish - start)
return  match(complete_balanced_sexp , text)
end


function is_sexp_empty ()

end

function match_next_sexp (pos)   local Range = {}
  local I = lpeg.Cp()
  local text = vis.win.file:content(pos + 1,vis.win.file.size)
  local start, finish = match(S(" \n")^0 * I  * complete_balanced_sexp * I, text  )
  if start ~= nil then
    Range.start , Range.finish = pos + start, pos + finish
  end
  return Range
end

function match_next_simple_sexp (pos)
  local Range = {}
  local I = lpeg.Cp()
  local text = vis.win.file:content(pos + 1,vis.win.file.size)
  local start, finish = match(S(" \n")^0 * I  * simple_sexp * I, text  )
  if start ~= nil then
    Range.start , Range.finish = pos + start, pos + finish
  end
  return Range
end


function last_occurance (p)
  local I = lpeg.Cp ()
  return lpeg.P{(I * p * I * lpeg.S(" \n")^0 * lpeg.P(-1)) + 1 * lpeg.V(1)}
end




function next_occurance (p)
  local I = lpeg.Cp ()
  return lpeg.P{(I * p * I + 1 * lpeg.V(1))}
end

function match_previus_sexp (pos)
  local text_trimmed =  vis.win.file:content(0,pos)
  return match(last_occurance(complete_balanced_sexp), text_trimmed)
end


function match_previus_lisp_word (pos)
  local text_trimmed =  vis.win.file:content(0,pos)
  return match(last_occurance(lisp_word), text_trimmed)
end


function blink_error()
end


function move_sexp (current_pos, target_pos)
  local file, cursor_char = vis.win.file, vis.win.file:content(current_pos,1)
  if target_pos == nil then
    blink_error()
  elseif match_sexp[cursor_char] == nil then
    blink_error(lexers.STYLE_INFO)
  elseif match_sexp[cursor_char] ~= nil then
    if current_pos > target_pos then
      file:delete(current_pos, 1)
      vis.win.selection.pos = current_pos
      file:insert(target_pos,  cursor_char)
      vis.win.selection.pos = target_pos
    elseif current_pos < target_pos then
      file:delete(current_pos, 1)
      vis.win.selection.pos =current_pos
      file:insert(target_pos - 1,  cursor_char)
      vis.win.selection.pos = target_pos - 1
    --  vis.win.selection.pos = target_pos - 1
    end
  end
end

function balance_sexp (key)
  if key == '(' then
    return function (_) vis:insert('()') return 0 end
  elseif key == '[' then
    return function (_) vis:insert('[]') return 0 end
  elseif key == '{' then
    return function (_) vis:insert('{}') return 0 end
  elseif key == '"' then
    return function (_) vis:insert('""') return 0 end
  end
end



function search_top_sexp (start_pos, pos, text)
  local start, finish = match (lpeg.P{ lpeg.Cp() * simple_sexp * lpeg.Cp() + 1 * lpeg.V(1) } , text, start_pos + 1)
  if finish ~= nil then
    if finish >= pos and start <= pos then
      return start - 1, finish
    else
      return search_top_sexp (finish, pos , text)
    end
  else  return -1
  end
end


function lowest_level_sexp (pos)
  local text = vis.win.file:content(0, vis.win.file.size)
  local enclosing_sexp_start ,  enclosing_sexp_end =  0, vis.win.file.size
  function travers_sexp (start_pos, pos, text)
    local start, finish = match (lpeg.P{ lpeg.Cp() * simple_sexp * lpeg.Cp() + 1 * lpeg.V(1) } , text, start_pos + 1)
    if finish ~= nil then
      if  start > pos and finish > pos then
        return -1
      elseif start <= pos and finish > pos then
        enclosing_sexp_start, enclosing_sexp_end  = start , finish
        travers_sexp (start + 1 , pos , text)
      elseif finish < pos then
        travers_sexp (start + 1 , pos , text)
      end
    else  return -1
    end
  end
  travers_sexp(0,pos, text)
  return enclosing_sexp_start - 1, enclosing_sexp_end -1
end


function slurp_sexp_forward ()
  local file, pos = vis.win.file,  vis.win.selection.pos
  local start, finish  = lowest_level_sexp(pos)
  local cursor_char = vis.win.file:content(pos,1)
  if  match( S(')]}'), cursor_char)~= nil then
    local sexp_pos = match_next_sexp(pos)
    move_sexp(pos, sexp_pos.finish)
  else
    if   match(empty_sexp, file:content(start  , finish - start )) ~= nil then
      vis.win.selection.pos = finish - 1
      slurp_sexp_forward ()
    end
  end
end

function slurp_sexp_backwards ()
  local file, pos = vis.win.file,  vis.win.selection.pos
  local start_2, finish_2  = lowest_level_sexp(pos)
  local cursor_char = vis.win.file:content(pos,1)
  if match(   S('([{'),  cursor_char)~= nil then
    local start, finish = match_previus_sexp(pos)
    if start == nil then
      move_sexp(pos,nil)
    else
      move_sexp(pos,start - 1)
    end
  else
  if start_2 > -1 and  match(empty_sexp, file:content(start_2, finish_2- start_2)) ~= nil then
    prinf(3)
      vis.win.selection.pos = start_2
      slurp_sexp_backwards ()
    end
  end
end


--function slurp_sexp_forward ()
--  local file, pos = vis.win.file,  vis.win.selection.pos
--  local start, finish  = lowest_level_sexp(pos)
--  local this_sexp = file:content(start  , finish - start )
--  local cursor_char = vis.win.file:content(pos,1)
--  if match_sexp[cursor_char] == "(" then
--    local sexp_pos = match_next_sexp(pos)
--    move_sexp(pos, sexp_pos.finish)
--  else
--    if  match(empty_sexp, this_sexp) ~= nil then
--      vis.win.selection.pos = finish - 1
--      slurp_sexp_forward ()
--    end
--  end
--end

function test_me ()
  local  pos =  vis.win.selection.pos
  local a,b =   lowest_level_sexp(pos)
   print("----" .. vis.win.file:content(a, b - a).. "....")
end


function top_sexp_at_cursor ()
  local  pos =  vis.win.selection.pos
  local text = vis.win.file:content(0,  vis.win.file.size)
  return  search_top_sexp (0, pos, text)
end


function slice_sexp ( )
  local  pos =  vis.win.selection.pos
  local file = vis.win.file
  local text = vis.win.file:content(0,  vis.win.file.size)
  left , right = lowest_level_sexp (pos + 1 )
  if left ~= nil then
    file:delete(left, 1)
    file:insert(left,  " ")
    file:delete(right - 1, 1)
    file:insert(right - 1,  " ")
    vis.win.selection.pos = pos
  end
end

function make_sexp_wraper (x)
  function wrap_sexp ()
    local  pos =  vis.win.selection.pos
    local file = vis.win.file
    local text = vis.win.file:content(0,  vis.win.file.size)
    left , right = lowest_level_sexp (pos + 1 )
    if left ~= nil then
      file:insert(left,  x )
      file:insert(right - 1, match_sexp[x])
      vis.win.selection.pos = pos
    end
  end
  return wrap_sexp
end


function split_sexp ( )
  local pos =  vis.win.selection.pos
  local file = vis.win.file
  local pos =  vis.win.selection.pos
  file:insert(pos  , " ")
  file:delete(pos, 1  )
  vis.win.selection.pos = pos
  trim_space_around (vis.win.selection.pos)
  pos =  vis.win.selection.pos
  local text = file:content(0,  vis.win.file.size)
  local left , right = lowest_level_sexp (pos + 1 )
  local cursor_char = vis.win.file:content(pos,  1)
  local split_pos = match_previus_lisp_word(pos + 1)

  if left ~= -1 then
    local s_type = vis.win.file:content(left ,  1)

   if match(S('\r\n\f\t ')^1, cursor_char) then
      file:insert(pos   ,  match_sexp[s_type] )
      file:insert(pos + 2 , s_type )
      vis.win.selection.pos = pos+2
    elseif left == pos then
      file:insert(pos, s_type )
      file:insert(pos , match_sexp[s_type] )
      vis.win.selection.pos = pos +2
     -- prinf ("1")
    elseif  right == pos + 1 then
      vis.win.selection.pos = pos
      file:insert(pos   ,  match_sexp[s_type] )
      vis.win.selection.pos = pos
      file:insert(pos + 1,  s_type )
      vis.win.selection.pos = pos + 1
    -- prinf ("3")
    else
      local _ , new_pos = match (last_occurance(l.graph),vis.win.file:content(0,  split_pos - 1)  )
      file:insert(new_pos - 1 ,  match_sexp[s_type] )
      file:insert(split_pos, s_type )
     vis.win.selection.pos = 1 + trim_space_around (new_pos )
      -- prinf ("4")
    end
  end
end


vis.events.subscribe(vis.events.WIN_OPEN, function()
  vis:map(vis.modes.INSERT, "(", balance_sexp("(") )
  vis:map(vis.modes.INSERT, "[", balance_sexp("[") )
  vis:map(vis.modes.INSERT, "{", balance_sexp("{") )
  vis:map(vis.modes.INSERT, '"', balance_sexp('"') )
  if is_lisp_file() ~= nil then
   vis:map(vis.modes.NORMAL,  '<Space>l', slurp_sexp_forward)
   vis:map(vis.modes.NORMAL,  '<Space>h',  slurp_sexp_backwards  )
   vis:map(vis.modes.NORMAL,  '<Space>b', slice_sexp)
   vis:map(vis.modes.NORMAL,  '<Space>(', make_sexp_wraper("("))
   vis:map(vis.modes.NORMAL,  '<Space>o', split_sexp)
 end
end)

