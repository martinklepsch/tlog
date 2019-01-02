-- https://github.com/kikito/ansicolors.lua
-- https://github.com/luafun/luafun
local date = require "date"
local db = require "db"
local M = require "moses"
local driver = require "luasql.sqlite3"

local inspect = require "inspect"
function p(d)
   print(inspect(d))
end

function sheet(m)
   return m.sheet
end

function add_minutes (x)
   local end_date = x["end"] or date(true)
   x.diff = date.diff(end_date, x.start)
   x.minutes = x.diff:spanminutes()
   return x
end

-- https://github.com/Yonaba/Moses/blob/master/doc/tutorial.md
function sum_minutes (entries)
   local function get_min (e) return e.minutes end
   return M.sum(M.map(entries, get_min))
end

function group_by_sheet (entries)
   return M.groupBy(entries, function(x) return x.sheet end)
end

function fmt_duration (minutes)
   local hours = math.floor(minutes / 60)
   return hours
end

function duration (entries)
   if entries then
      local with_minutes = M.map(entries, add_minutes)
      local total_minutes = M.sum(M.map(with_minutes, function(e) return e.minutes end))

      local hours = math.floor(total_minutes / 60)
      local minutes = math.floor(total_minutes % 60)
      return hours .. ":" .. minutes .. "h"
   else
      return "00:00h"
   end
end

-- function sheet_list ()
--    local by_sheet = group_by_sheet(M.map(db.get_entries(), add_minutes))
--    local metadata = db.get_meta()
--    local function is_current_or_last (sheet)
--       return metadata.current_sheet == sheet or metadata.last_sheet == sheet
--    end
--    local remaining_sheets = M.reject(M.unique(M.map(db.get_entries(), sheet)), is_current_or_last)

--    if metadata.current_sheet then
--       print("* "..metadata.current_sheet.." "..duration(by_sheet[metadata.current_sheet]))
--    end
--    if metadata.last_sheet then
--       print("- "..metadata.last_sheet.." "..duration(by_sheet[metadata.last_sheet]))
--    end
--    M.each(remaining_sheets, function(x) print("  " .. x .. " " .. duration(by_sheet[x])) end)
-- end

function sheet_display (sheet_name)
   M.map(db.get_entries(), add_minutes)
   local by_sheet = group_by_sheet(M.map(db.get_entries(), add_minutes))
   local sheet = sheet_name or db.get_meta().current_sheet
   print("Timesheet: "..sheet)
   M.each(by_sheet[sheet] or {},
          function (e)
             local d = date(e.start)
             local end_date = e["end"] or date(true)
             print(d:fmt("%a %b %d, %Y") .. "   " .. d:fmt("%H:%M") .. " - " .. date(end_date):fmt("%H:%M")
                      .. "   " .. duration({e}) .. "   (" .. e.id .. ")")
   end)
   print("Total: "..duration(by_sheet[sheet]))
end

-- function kill (id)

-- local cmds = {
--    backend = function() os.execute("sqlite3 " .. tt_file) end,
--    display = sheet_display,
--    kill = nil,
--    ["in"] = nil,
--    out = nil,
--    sheet = sheets
-- }

-- local shortcuts = {
--    i = "in",
--    o = "out",
--    d = "display",
--    b = "backend",
--    s = "sheet"
-- }

-- function main()
--    local args = parser:parse()
--    args.cmd = shortcuts[args.cmd] or args.cmd

--    if cmds[args.cmd] then
--       if args.cmd == "display" then
--          cmds[args.cmd](args.sheet)
--       elseif args.cmd == "sheet" then
--          cmds[args.cmd](args.sheet)
--       else
--          cmds[args.cmd]()
--       end
--    else
--       print("Not yet implemented")
--    end
-- end

-- main()

return {
   -- main = main,
   sheet_display = sheet_display,
   add_minutes = add_minutes,
   duration = duration
}
