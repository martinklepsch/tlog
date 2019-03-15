(local date (require "deps.date")) ;http://tieske.github.io/date/#date

(local api {})

(lambda api.from_human_desc [s]
  (let [;; s "10:14 yesterday"
        ;; s "10 min ago"
        ;; s "10:14"
        parsed {:min-ago (string.match s "(%d+)%s*min ago")
                :in-min  (string.match s "in (%d+)%s*min")

                :hours-ago (or (string.match s "(%d+)%s*hours ago")
                               (string.match s "(%d+)%s*hr ago"))

                :time (let [(hr min) (string.match s "(%d+):(%d+)$")]
                        (when (and hr min)
                          [hr min]))

                :time-yesterday (let [(hr min) (string.match s "(%d+):(%d+) yesterday")]
                                  (when (and hr min)
                                    [hr min]))}
        now (date false)]
    (if
     (. parsed :time)
     (let [[hr min] (. parsed :time)]
       (: now :sethours hr min 0))

     (. parsed :time-yesterday)
     (let [[hr min] (. parsed :time-yesterday)]
       (: now :adddays -1)
       (: now :sethours hr min 0))

     (. parsed :min-ago)
     (let [min-ago (. parsed :min-ago)]
       (: now :addminutes (.. "-" min-ago)))

     (. parsed :in-min)
     (let [in-min (. parsed :in-min)]
       (: now :addminutes in-min))

     (. parsed :hours-ago)
     (let [hr-ago (. parsed :hours-ago)]
       (: now :addhours (.. "-" hr-ago))))
    ;; (: now :fmt "${iso}")
    now))

api
