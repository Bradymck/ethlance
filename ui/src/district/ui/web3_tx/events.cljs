(ns district.ui.web3-tx.events
  (:require
   [re-frame.core :as re]))

;; Register the missing set-gas-price event handler
(re-frame/reg-event-db
 ::set-gas-price
 (fn [db [_ gas-price]]
   (js/console.log "Setting gas price to:" gas-price)
   (assoc-in db [:district.ui.web3-tx :gas-price] gas-price)))
