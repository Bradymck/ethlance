(ns ethlance.ui.patches.http-effects-patch
  (:require
   [re-frame.core :as re-frame]
   [day8.re-frame.http-fx :as http-fx]
   [ajax.core :as ajax]))

;; Override the standard HTTP effects to block ethgasstation.info requests
(defn- block-ethgasstation? [request]
  (let [uri (or (:uri request) "")]
    (boolean (re-find #"ethgasstation\.info" uri))))

;; Intercept HTTP effect requests
(re-frame/reg-fx
 :http-xhrio
 (fn [request]
   (if (map? request)
     ;; Single request
     (if (block-ethgasstation? request)
       (js/console.log "Blocked HTTP request to ethgasstation.info")
       (http-fx/http-effect request))
     
     ;; Sequence of requests
     (doseq [r request]
       (if (block-ethgasstation? r)
         (js/console.log "Blocked HTTP request to ethgasstation.info")
         (http-fx/http-effect r))))))

(js/console.log "HTTP effects patched to block ethgasstation.info requests")
