(local driver (require "luasql.sqlite3"))
(local M (require "moses"))

(local env (driver.sqlite3))

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
(tset db :tt_file "/Users/martinklepsch/Documents/Timetracking/testing.sqlite.db")

(lambda db.connect [file]
  (: env :connect file))

(lambda db.get_entries [conn]
  (read_cursor (: conn :execute "SELECT * FROM entries")))

(lambda db.get_meta [conn]
  (let [c (read_cursor (: conn :execute "SELECT * FROM meta"))]
    (M.reduce c (fn [acc x] (tset acc (. x :key) (. x :value)) acc) {})))

(lambda db.switch_sheet [conn new_sheet]
  (let [current (-> (: conn :execute "SELECT value FROM meta WHERE key = 'current_sheet'")
                    (read_cursor)
                    (. 1 :value))]
    (: conn :execute (string.format "UPDATE meta SET value = '%s' where key = 'current_sheet'" new_sheet))
    (: conn :execute (string.format "UPDATE meta SET value = '%s' where key = 'last_sheet'" current))))

;; (fn db.running_entries []
;;   (read_cursor (: conn :execute "SELECT * FROM entries WHERE end IS NULL")))

(lambda db.clock_in [conn sheet note]
  (: conn :execute (string.format "insert into entries (note, start, sheet) VALUES ('%s', datetime(), '%s')"
                                note sheet)))

(lambda db.clock_out [conn id end]
  (: conn :execute (string.format "UPDATE entries SET end = '%s' WHERE id = %s" end id)))

(lambda db.kill [conn id]
  (: conn :execute (.. "DELETE FROM entries WHERE id = " id)))

db
