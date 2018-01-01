-- load standard vis module,  providing parts of the Lua API
require('vis')
local l = require('lexer')
local match = lpeg.match
local P, R, S = lpeg.P, lpeg.R, lpeg.S

local char_sexp_literals = P{"\\" * S('(){}[]"') }
local char_literals = P{"\\" * (l.graph -  S("n\"\\"))}

local str_pattern = ('"' *  ( ( P("\\\"") +    (1 -  S('"'))))^0 * '"')
local strings_and_chars = str_pattern + char_sexp_literals

complete_balanced_sexp =   P{("(" * ((1 - S("(){}[]\"")) + strings_and_chars + lpeg.V(1))^0 * ")") +
                             ("[" * ((1 - S("(){}[]\"")) + strings_and_chars + lpeg.V(1))^0 * "]") +
                             ("{" * ((1 - S("(){}[]\"")) + strings_and_chars  + lpeg.V(1))^0 * "}") +
                             (((l.graph -  S("(){}[]\"\\")) + char_literals))^1+ str_pattern^1  }

 match_sexp = {["("] = ")",
               [")"] = "(",
               ["["] = "]",
               ["]"] = "[",
               ["{"] = "}",
               ["}"] = "{",
               ["\""]="\"" }


--This function returns a patternt that skips as many characters
--in order to find the given patternt
function search_patern (p)
  local I = lpeg.Cp()
  return (1 - lpeg.P(p))^0 * I * p * I
end
function print_two (a,b)
 print ("  " .. tostring (a) .. "--" .. tostring(b))
end

function match_next_sexp (pos) --pos + 1 ?
 local Range = {}
 local I = lpeg.Cp()
 local text = vis.win.file:content(pos + 1,vis.win.file.size)
 local start, finish = match(S(" \n")^0 * I  * complete_balanced_sexp * I, text  )
 if start ~= nil then
 Range.start , Range.finish = pos + start, pos + finish
 end
 -- print_two(Range.start,Range.finish)
 return Range
end



function match_next_sexp_two(pos) --pos + 1 ?
 local Range = {}
 local I = lpeg.Cp()
 local text = vis.win.file:content(pos + 1,vis.win.file.size)
 local start, finish = match(S(" \n")^0 * I  * complete_balanced_sexp * I, text  )
 if start ~= nil then
 Range.start , Range.finish = pos + start, pos + finish
 end
 -- print_two(Range.start,Range.finish)
 return Range
end

function match_previus_sexp (starting_pos, pos, previus_sexp_pos)
  local sexp_pos = match_next_sexp (starting_pos)
    if sexp_pos.finish == nil then
      return match_previus_sexp (starting_pos + 1, pos,  previus_sexp_pos)
    elseif  sexp_pos.finish < pos then
      return  match_previus_sexp(sexp_pos.finish -1, pos, sexp_pos  )
    else
      return previus_sexp_pos
  end
end



function match_previus_sexp_two (starting_pos, pos, previus_sexp_pos)
  local sexp_pos = match_next_sexp (starting_pos)
    if  sexp_pos.finish < pos then
      return  match_previus_sexp_two(sexp_pos.finish, pos, sexp_pos  )
    else
      return previus_sexp_pos
  end
end

function move_sexp (current_pos, target_pos)
  local file, cursor_char = vis.win.file, vis.win.file:content(current_pos,1)
  if  match_sexp[cursor_char] ~= nil then
    file:insert(target_pos,  cursor_char)
    if current_pos > target_pos then
      file:delete(current_pos + 1, 1)
      vis.win.selection.pos = target_pos
    elseif current_pos < target_pos then
      file:delete(current_pos, 1)
      vis.win.selection.pos = target_pos - 1
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

function slurp_sexp_forward ()
 local file, pos = vis.win.file,  vis.win.selection.pos
 local sexp_pos = match_next_sexp(pos)
move_sexp(pos, sexp_pos.finish)
end

function slurp_sexp_backwards ()
 local file, pos = vis.win.file,  vis.win.selection.pos
 local sexp_range = match_previus_sexp(0, pos +  1)

 move_sexp(pos, sexp_range.start)
end


 vis:map(vis.modes.NORMAL,  '<Space>h', slurp_sexp_backwards)
   vis.events.subscribe(vis.events.INIT, function()
   vis:map(vis.modes.INSERT, "(", balance_sexp("(") )
   vis:map(vis.modes.INSERT, "[", balance_sexp("[") )
   vis:map(vis.modes.INSERT, "{", balance_sexp("{") )
   vis:map(vis.modes.INSERT, '"', balance_sexp('"') )
   vis:map(vis.modes.NORMAL,  '<Space>l', slurp_sexp_forward)
   vis:map(vis.modes.NORMAL,  '<Space>h',  slurp_sexp_backwards  )
 end)


