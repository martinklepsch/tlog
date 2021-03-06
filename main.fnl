#!/usr/bin/env fennel

(local inspect (require "fennelview"))
(fn p [d] (-> d (inspect) (print)))

(local date (require "deps.date"))
(local db (require "plaindb"))
(local humantime (require "humantime"))
(local M (require "deps.moses"))
(local colors (require "deps.ansicolors"))
;; TODO open bug that those are not equivalent
;; parser:option "-f" "--from"
;; parser:option "-f --from"
;; with the first option the option is registered as `f` not `from`
(local argparse (require "deps.argparse"))

(local parser (argparse {:name "t"
                         :description "A small, fast time tracking utility backed by a plaintext file."
                         :require_command false}))

(-> (: parser :option "--db")
    (: :description "Use the provided file as database (default: $TLOG_FILE)")
    (: :args 1))

(: parser :command_target "command")
(-> (: parser :command "backend")
    (: :description "Open file with $EDITOR"))
(-> (: parser :command "status")
    (: :description "Print minimal information about current session"))
(-> (: parser :command "in")
    (: :description "Start the timer in the current sheet")
    (: :option "--at")
    (: :description "A specification of time (e.g. '10min ago', '10:30 yesterday')"))
(-> (: parser :command "out")
    (: :description "Stop the currently running timer")
    (: :option "--at")
    (: :description "A specification of time (e.g. '10min ago', '10:30 yesterday')"))
(-> (: parser :command "kill")
    (: :description "NOT IMPLEMENTED")
    (: :option "-i --id"))
(-> (: parser :command "sheet")
    (: :description "Show the currently selected sheet or switch to one")
    (: :argument "sheet_name" "The sheet to switch to")
    (: :args "?"))
(-> (: parser :command "display")
    (: :description "Display a list of all entries for the current sheet")
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

(lambda util.file_exists [name]
  (match (io.open name)
    (nil msg) false
    f (do (io.close f) true)))

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

(lambda print-single-entry [entry include-date]
  (let [start (date (. entry :start))
        end   (date (or (. entry :end) false))]
    (print (colors
            (.. (if include-date
                    (: start :fmt "%a %b %d, %Y")
                    (string.format "%16s" ""))
                "   " (: start :fmt "%H:%M")
                " - " (: end :fmt "%H:%M")
                "   " (util.duration [entry])
                "  %{dim}(" (. entry :start_line) ", " (or (. entry :end_line) "") ")"
                (if (. entry :end) "" "  <-- RUNNING"))))))

(fn sheet_display [entries meta sheet_name]
  (let [by_sheet (util.group_by_sheet (M.map entries util.add_minutes))
        sheet    (or sheet_name (. meta :current_sheet))
        entries  (or (. by_sheet sheet) [])]
    (print (.. "Timesheet: " sheet))
    (-> entries
        (M.chunk (fn [entry]
                   (: (date (. entry :start)) :fmt "%Y-%m-%d")))
        (M.each (fn [days-entries]
                  (print-single-entry (M.nth days-entries 1) true)
                  (M.each (M.rest days-entries 2) (fn [e] (print-single-entry e false)))
                  (print (colors (.. "%{bright}" (string.format "%40s" (util.duration days-entries)) "%{reset}"))))))
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

(fn init_db [db_arg]
  (let [db_file (or db_arg (os.getenv "TLOG_FILE"))]
    (if (and db_file (util.file_exists db_file))
        (tset g :db_conn db_file)

        (and db_file (not (util.file_exists db_file)))
        (do (print (.. "File does not exist: '" db_file "', please create it first"))
            (os.exit 1))

        (not db_file)
        (do (print (.. "Please specify a file via --db or $TLOG_FILE"))
            (os.exit 1)))))

(fn main []
  (local args (: parser :parse))
  (init_db (. args :db))
  (if (. args :backend)
      (os.execute (.. "$EDITOR " (. g :db_conn)))

      (let [entries (db.get_entries g.db_conn)
            meta    (db.get_meta g.db_conn)
            ts      (when (. args :at)
                      (humantime.from_human_desc (. args :at)))]
        (if
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

         ;; If there are any entries
         (next entries)
         (sheet_display entries meta (. args :sheet))

         (print (.. "No data in '" g.db_conn "'"))))))

(main)
