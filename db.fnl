(local tt_file "/Users/martinklepsch/Documents/Timetracking/testing.sqlite.db")

(local driver (require "luasql.sqlite3"))
(local M (require "moses"))

(local env (driver.sqlite3))
(local db (: env :connect tt_file))

(fn read_cursor [sql_cursor]
  (var arr [])
  (var done? true)
  (while done?
    (local r (: sql_cursor :fetch {} "a"))
    (if (= r nil)
        (set done? false)
        (table.insert arr r)))
  arr)

(fn get_entries []
  (read_cursor (: db :execute "SELECT * FROM entries")))

(fn get_meta []
  (let [c (read_cursor (: db :execute "SELECT * FROM meta"))]
    (M.reduce c (fn [acc x] (tset acc (. x :key) (. x :value)) acc) {})))

(lambda switch_sheet [new_sheet]
  (let [current (-> (: db :execute "SELECT value FROM meta WHERE key = 'current_sheet'")
                    (read_cursor)
                    (. 1 :value))]
    (: db :execute (string.format "UPDATE meta SET value = '%s' where key = 'current_sheet'" new_sheet))
    (: db :execute (string.format "UPDATE meta SET value = '%s' where key = 'last_sheet'" current))))

(fn running_entries []
  (read_cursor (: db :execute "SELECT * FROM entries WHERE end IS NULL")))

(lambda clock_in [sheet note]
  (: db :execute (string.format "insert into entries (note, start, sheet) VALUES ('%s', datetime(), '%s')"
                                note sheet)))

(lambda clock_out [id end]
  (: db :execute (string.format "UPDATE entries SET end = '%s' WHERE id = %s" end id)))

(lambda kill [id]
  (: db :execute (.. "DELETE FROM entries WHERE id = " id)))

{
  :get_meta get_meta
  :get_entries get_entries
  :switch_sheet switch_sheet
  :running_entries running_entries
  :clock_in clock_in
  :clock_out clock_out
  :tt_file tt_file
  :kill kill
}
