(local tt_file "/Users/martinklepsch/Documents/Timetracking/testing.sqlite.db")

(local driver (require "luasql.sqlite3"))
(local M (require "moses"))

(local env (driver.sqlite3))
(local conn (: env :connect tt_file))

(fn read_cursor [sql_cursor]
  (var arr [])
  (var done? true)
  (while done?
    (local r (: sql_cursor :fetch {} "a"))
    (if (= r nil)
        (set done? false)
        (table.insert arr r)))
  arr)

(local db {})

(fn db.get_entries []
  (read_cursor (: conn :execute "SELECT * FROM entries")))

(fn db.get_meta []
  (let [c (read_cursor (: conn :execute "SELECT * FROM meta"))]
    (M.reduce c (fn [acc x] (tset acc (. x :key) (. x :value)) acc) {})))

(lambda db.switch_sheet [new_sheet]
  (let [current (-> (: conn :execute "SELECT value FROM meta WHERE key = 'current_sheet'")
                    (read_cursor)
                    (. 1 :value))]
    (: conn :execute (string.format "UPDATE meta SET value = '%s' where key = 'current_sheet'" new_sheet))
    (: conn :execute (string.format "UPDATE meta SET value = '%s' where key = 'last_sheet'" current))))

(fn db.running_entries []
  (read_cursor (: conn :execute "SELECT * FROM entries WHERE end IS NULL")))

(lambda db.clock_in [sheet note]
  (: conn :execute (string.format "insert into entries (note, start, sheet) VALUES ('%s', datetime(), '%s')"
                                note sheet)))

(lambda db.clock_out [id end]
  (: conn :execute (string.format "UPDATE entries SET end = '%s' WHERE id = %s" end id)))

(lambda db.kill [id]
  (: conn :execute (.. "DELETE FROM entries WHERE id = " id)))

db
