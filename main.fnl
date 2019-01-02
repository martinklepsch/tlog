(local inspect (require "inspect"))
(fn p [d] (-> d (inspect) (print)))

(local tt (require "tt"))
(local date (require "date"))
(local db (require "db"))
(local M (require "moses"))
;; TODO open bug that those are not equivalent
;; parser:option "-f" "--from"
;; parser:option "-f --from"
;; with the first option the option is registered as `f` not `from`
(local argparse (require "argparse"))

(local parser (argparse {:name "tt"
                         :description "A small, fast time tracking utility backed by SQLite."}))

(: parser :command_target "command")
(: parser :command "backend")
(: parser :command "in")
(: parser :command "out")
(-> (: parser :command "kill")
    (: :option "-i --id"))
(-> (: parser :command "sheets")
    (: :argument "sheet" "The sheet to switch to")
    (: :args "?"))
(-> (: parser :command "display")
    (: :argument "sheet" "The sheet to switch to")
    (: :args "?"))

(fn group_by_sheet [entries]
  (M.groupBy entries (fn [e] (. e :sheet))))

(fn sheet_list []
  (let [entries  (db.get_entries)
        meta     (db.get_meta)
        by_sheet (group_by_sheet (M.map entries tt.add_minutes))
        is_current_or_last? (fn is_current_or_last [sheet]
                              (or (= (. meta :current_sheet) sheet)
                                  (= (. meta :last_sheet) sheet)))
        remaining_sheets (-> (M.map entries (fn [e] (. e :sheet)))
                             (M.reject is_current_or_last?)
                             (M.unique))]
    (when (. meta :current_sheet)
      (print (.. "* " (. meta :current_sheet) " " (tt.duration (. by_sheet (. meta :current_sheet))))))
    (when (. meta :last_sheet)
      (print (.. "* " (. meta :last_sheet) " " (tt.duration (. by_sheet (. meta :last_sheet))))))
    (M.each remaining_sheets (fn [s] (print (.. "  " s " " (tt.duration (. by_sheet s))))))))

(fn sheets [sheet_name]
  (if sheet_name
      (do (print (.. "Switching to sheet " sheet_name))
          (db.switch_sheet sheet_name))
      (sheet_list)))

(fn clock_in []
  (let [running  (db.running_entries)
        meta     (db.get_meta)]
    (if (= 0 (M.count running))
        (do
          (print (.. "Starting new entry in " (. meta :current_sheet)))
          (p (db.clock_in (. meta :current_sheet) "my note")))
        (do (print "Running entry, please sign out first")
            (p (. running 1))))))

(fn clock_out []
  (let [[e] (db.running_entries)]
    (if e
        (do (db.clock_out (. e :id) (date true))
            (print (.. "Clocked out of " (. e :sheet))))
        (print "No running entry"))))

(fn confirm [question]
  (var answer nil)
  (while (not (or (= answer false)
                  (= answer true)))
    (io.write (.. question " (y/n) "))
    (io.flush)
    (let [r (io.read)]
      (if (= r "y")
          (set answer true)
          (= r "n")
          (set answer false))))
  answer)

(fn kill [id]
  (let [[entry] (M.filter (db.get_entries)
                          (fn [e] (= (. e :id) id)))]
    (when (confirm (string.format "Delete entry with ID %s from sheet '%s'?" id (. entry :sheet)))
      (db.kill id))))

(local shortcuts
       {:i "in"
        :o "out"
        :d "display"
        :b "backend"
        :s "sheet"})

(fn main []
  (local args (: parser :parse))
  (tset args :cmd (or (. shortcuts (. args :command))
                      (. args :command)))
  (if (. args :backend)
      (os.execute (.. "sqlite3 " (. db :tt_file)))

      (. args :display)
      (tt.sheet_display (. args :sheet))

      (. args :sheets)
      (sheets (. args :sheet))

      (. args :kill)
      (kill (tonumber (. args :id)))

      (. args :in)
      (clock_in)

      (. args :out)
      (clock_out)

      ;; else
      (print "Not yet implemented")))

(main)
