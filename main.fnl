#!/usr/bin/env fennel

(local inspect (require "fennelview"))
(fn p [d] (-> d (inspect) (print)))

(local date (require "deps.date"))
(local db (require "plaindb"))
(local humantime (require "humantime"))
(local M (require "deps.moses"))
;; TODO open bug that those are not equivalent
;; parser:option "-f" "--from"
;; parser:option "-f --from"
;; with the first option the option is registered as `f` not `from`
(local argparse (require "deps.argparse"))

(local parser (argparse {:name "tt"
                         :description "A small, fast time tracking utility backed by SQLite."}))

(: (: parser :option "--db") :args 1)

(: parser :command_target "command")
(: parser :command "backend")
(: parser :command "status")
(-> (: parser :command "in")
    (: :option "--at"))
(-> (: parser :command "out")
    (: :option "--at"))
(-> (: parser :command "kill")
    (: :option "-i --id"))
(-> (: parser :command "sheet")
    (: :argument "sheet_name" "The sheet to switch to")
    (: :args "?"))
(-> (: parser :command "display")
    (: :argument "sheet" "The sheet to switch to")
    (: :args "?"))

(local g {}) ; A container for global state

(local util {})
(lambda util.group_by_sheet [entries]
  (M.groupBy entries (fn [e] (. e :sheet))))

(lambda util.add_minutes [entry]
  (let [end (or (. entry :end) (date false))]
    (tset entry :diff (date.diff end (. entry :start)))
    (tset entry :minutes (: entry.diff :spanminutes))
    entry))

(fn util.duration [entries]
  (if (< 0 (M.count entries))
      (let [w_minutes (M.map entries util.add_minutes)
            total_minutes (M.sum (M.map w_minutes (fn [e] (. e :minutes))))
            hours (math.floor (/ total_minutes 60))
            minutes (math.floor (% total_minutes 60))]
        (string.format "%02d:%02d" hours minutes))
      "00:00"))

(lambda util.confirm [question]
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

(lambda sheet_list [entries meta]
  (let [by_sheet (util.group_by_sheet (M.map entries util.add_minutes))
        is_current_or_last? (fn is_current_or_last [sheet]
                              (or (= (. meta :current_sheet) sheet)
                                  (= (. meta :last_sheet) sheet)))
        remaining_sheets (-> (M.map entries (fn [e] (. e :sheet)))
                             (M.reject is_current_or_last?)
                             (M.unique))]
    (when (. meta :current_sheet)
      (print (.. "* " (. meta :current_sheet) " " (util.duration (. by_sheet (. meta :current_sheet))))))
    (when (. meta :last_sheet)
      (print (.. "- " (. meta :last_sheet) " " (util.duration (. by_sheet (. meta :last_sheet))))))
    (M.each remaining_sheets (fn [s] (print (.. "  " s " " (util.duration (. by_sheet s))))))))

(fn sheets [entries meta sheet_name]
  (if (= sheet_name "-")
      (do (print (.. "Switching to sheet " (. meta :last_sheet)))
          (db.switch_sheet g.db_conn (. meta :last_sheet)))

      sheet_name
      (do (print (.. "Switching to sheet " sheet_name))
          (db.switch_sheet g.db_conn sheet_name))

      (sheet_list entries meta)))

(lambda clock_in [entries meta ts]
  (let [[running] (M.reject entries (fn [e] (. e :end)))]
    (if (= 0 (M.count running))
        (do
          (print (.. "Starting new entry in " (. meta :current_sheet)))
          (db.clock_in g.db_conn (. meta :current_sheet) ts))
        (do (print "Running entry, please sign out first")
            (p (. running 1))))))

(lambda status_display [entries]
  (let [[running] (M.reject entries (fn [e] (. e :end)))]
    (if (= 0 (M.count running))
        (print "off")
        (print (.. (. running :sheet) " " (util.duration [running]))))))

(fn sheet_display [entries meta sheet_name]
  (let [by_sheet (util.group_by_sheet (M.map entries util.add_minutes))
        sheet    (or sheet_name (. meta :current_sheet))]
    (print (.. "Timesheet: " sheet))
    (M.each (or (. by_sheet sheet) [])
            (fn [entry]
              (let [start (date (. entry :start))
                    end   (date (or (. entry :end) false))]
                (print (.. (: start :fmt "%a %b %d, %Y") "   " (: start :fmt "%H:%M") " - " (: end :fmt "%H:%M")
                           "   " (util.duration [entry])
                           "  (" (. entry :start_line) ", " (or (. entry :end_line) "") ")"
                           (if (. entry :end) "" "  <-- RUNNING"))))))
    (print (.. "Total: " (util.duration (. by_sheet sheet))))))

(lambda clock_out [entries ts]
  (let [[e] (M.reject entries (fn [e] (. e :end)))]
    (if e
        (do (db.clock_out g.db_conn (. e :sheet) (or ts (date false)))
            (print (.. "Clocked out of " (. e :sheet))))
        (print "No running entry"))))

(lambda kill [entries id]
  (let [[entry] (M.filter entries (fn [e] (= (. e :id) id)))]
    (when (util.confirm (string.format "Delete entry with ID %s from sheet '%s'?" id (. entry :sheet)))
      (db.kill g.db_conn id))))

(local shortcuts
       {:i "in"
        :o "out"
        :d "display"
        :b "backend"
        :s "sheet"})

(fn main []
  (local args (: parser :parse))
  (let [db_file (or (. args :db)
                    (os.getenv "FENNEL_TT_FILE"))]
    (tset g :db_conn db_file))
  (let [entries (db.get_entries g.db_conn)
        meta    (db.get_meta g.db_conn)
        ts      (when (. args :at)
                  (humantime.from_human_desc (. args :at)))]
    (if (. args :backend)
        (os.execute (.. "$EDITOR " (. g :db_conn)))

        (. args :status)
        (status_display entries)

        (. args :display)
        (sheet_display entries meta (. args :sheet))

        (. args :sheet)
        (sheets entries meta (. args :sheet_name))

        (. args :kill)
        (kill (tonumber (. args :id)))

        (. args :in)
        (clock_in entries meta (or ts (date false)))

        (. args :out)
        (clock_out entries (or ts (date false)))

        ;; else
        (print "Not yet implemented"))))

(main)
