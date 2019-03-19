(local M (require "deps.moses"))
(local date (require "deps.date"))

;; (local f "logs.time")

;; always store timezones as UTC(?)
;; pro: timezone independence
;; con: raw editing is harder

;; sheet project
;; in project ts
;; note project some note
;; out project ts

(local db {})

(fn local_now []
  (date false))

(lambda append [filename line]
  (let [h (assert (io.open filename "a"))]
    (: h :write line "\n")
    (: h :close)))

;; file = io.open("test.lua", "r")

;; -- prints the first line of the file
;; print(file:read())

(lambda read_file [filename]
  (var arr [])
  (var done? false)
  (let [h (assert (io.open filename "r"))]
    (while (not done?)
      (local l (: h :read))
      (if (= l nil)
          (set done? true)
          (when (and (not (= 0 (string.len l)))
                     (not (= 35 (string.byte l 1)))) ; byte of # for comments
            (table.insert arr l)))))
  arr)

(lambda tokenize_line [line]
  ;; (print line)
  (let [line-contents []]
    ;; todo `note` handling
    (each [s (string.gmatch line "[^%s]+")]
      (table.insert line-contents s))
    line-contents))

(lambda db.get_data [f]
  (M.reduce (M.map (read_file f) tokenize_line)
            (fn [acc [cmd sheet xs]]
              (let [line      (+ 1 (. acc :line_count))
                    running   (. acc :running)
                    entries   (. acc :entries)
                    for_sheet (. running sheet)]
                (tset acc :line_count line)
                (if
                 (and (= "in" cmd) for_sheet) (print "Corrupted")
                 (and (= "out" cmd) (not for_sheet)) (print "Corrupted")

                 (= "in" cmd)  (tset running sheet {:id line
                                                    :sheet sheet
                                                    :start_line line
                                                    :start xs})
                 (= "out" cmd) (do (tset running sheet nil)
                                   (tset for_sheet :end xs)
                                   (tset for_sheet :end_line line)
                                   (table.insert entries for_sheet))

                 (= "sheet" cmd) (do (when (not (= sheet (. acc :current_sheet)))
                                       (tset acc :previous_sheet (. acc :current_sheet)))
                                     (tset acc :current_sheet sheet))

                 (do (print "Unrecognized line" cmd sheet xs)
                     (os.exit 1))))
              acc)
            {:line_count 0
             :current_sheet nil
             :previous_sheet nil
             :running {}
             :entries []}))

(lambda db.get_entries [f]
  (let [data (db.get_data f)
        completed (. data :entries)]
    (each [k v (pairs (. data :running))]
      (table.insert completed v))
    completed))

(lambda db.get_meta [f]
  (let [data (db.get_data f)]
    {:current_sheet (. data :current_sheet)
     :last_sheet (. data :previous_sheet)})) ; fixme

(lambda db.switch_sheet [f sheet]
  (append f (string.format "sheet %s" sheet)))

(lambda db.clock_in [f sheet ts]
  (append f (string.format "in %s %s" sheet (: ts :fmt "${iso}"))))

(lambda db.clock_out [f sheet ts]
  (append f (string.format "out %s %s" sheet (: ts :fmt "${iso}"))))

(lambda db.kill [f id]
  (print "not implemented"))

db
