-- https://github.com/kikito/ansicolors.lua
-- https://github.com/luafun/luafun
local inspect = require "inspect"
local date = require "date"
local M = require "moses"
local argparse = require "argparse"
local driver = require "luasql.sqlite3"

function p(d)
   print(inspect(d))
end

local tt_file = "/Users/martinklepsch/Documents/Timetracking/testing.sqlite.db"
local env = driver.sqlite3()
local db = env:connect(tt_file)

local parser = argparse() {
   name = "tt",
   description = "A small, fast time tracking utility backed by SQLite."
}

parser:argument("cmd", "The subcommand to invoke (in, out, sheet)"):args(1)
parser:argument("sheet", "sheet to use"):args("?")

function read_cursor(sql_cursor)
   local arr = {}
   local i = 1
   while true do
      local r = sql_cursor:fetch({}, "a")
      if r == nil then break end
      arr[i] = r
      i = i + 1
   end
   return arr
end

function get_entries()
   return read_cursor(db:execute("SELECT * FROM entries"))
end

function meta_reduce(acc, x)
   acc[x.key] = x.value
   return acc
end

function get_meta()
   return M.reduce(read_cursor(db:execute("SELECT * FROM meta")), meta_reduce, {})
end

function sheet(m)
   return m.sheet
end

function add_minutes (x)
   x.diff = date.diff(x["end"], x.start)
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
   local with_minutes = M.map(entries, add_minutes)
   local total_minutes = M.sum(M.map(with_minutes, function(e) return e.minutes end))

   local hours = math.floor(total_minutes / 60)
   local minutes = math.floor(total_minutes % 60)
   return hours .. ":" .. minutes .. "h"
end

function sheet_list ()
   local by_sheet = group_by_sheet(M.map(get_entries(), add_minutes))
   local metadata = get_meta()
   local function is_current_or_last (sheet)
      return metadata.current_sheet == sheet or metadata.last_sheet == sheet
   end
   local remaining_sheets = M.reject(M.unique(M.map(get_entries(), sheet)), is_current_or_last)

   if metadata.current_sheet then
      print("* "..metadata.current_sheet.." "..duration(by_sheet[metadata.current_sheet]))
   end
   if metadata.last_sheet then
      print("- "..metadata.last_sheet.." "..duration(by_sheet[metadata.last_sheet]))
   end
   M.each(remaining_sheets, function(x) print("  " .. x .. " " .. duration(by_sheet[x])) end)
end

function sheet_display (sheet_name)
   local by_sheet = group_by_sheet(M.map(get_entries(), add_minutes))
   local sheet = sheet_name or get_meta().current_sheet
   print("Timesheet: "..sheet)
   M.each(by_sheet[sheet],
          function (e)
             local d = date(e.start)
             print(d:fmt("%a %b %d, %Y") .. "   " .. d:fmt("%H:%M") .. " - " .. date(e["end"]):fmt("%H:%M")
                      .. "   " .. duration({e}) .. "   (" .. e.id .. ")")
   end)
   print("Total: "..duration(by_sheet[sheet]))
end

local cmds = {
   backend = function() os.execute("sqlite3 " .. tt_file) end,
   display = sheet_display,
   kill = nil,
   ["in"] = nil,
   out = nil,
   sheet = sheet_list
}

local shortcuts = {
   i = "in",
   o = "out",
   d = "display",
   b = "backend",
   s = "sheet"
}

function main()
   local args = parser:parse()
   args.cmd = shortcuts[args.cmd] or args.cmd

   if cmds[args.cmd] then
      if args.cmd == "display" then
         cmds[args.cmd](args.sheet)
      else
         cmds[args.cmd]()
      end
   else
      print("Not yet implemented")
   end
end

main()
