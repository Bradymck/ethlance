(ns ethlance.ui.patches.ethgasstation-fallback
  (:require
   [re-frame.core :as re-frame]
   [district.ui.web3-tx.events :as tx-events]))

;; Register an event interceptor to handle ethgasstation errors
(re-frame/reg-event-fx
 ::handle-ethgasstation-fallback
 (fn [{:keys [db]} _]
   ;; Use hardcoded gas prices as fallback
   (let [fallback-gas-prices {:average 50 :fast 70 :fastest 90}]
     {:db (assoc-in db [:district.ui.web3-tx :gas-prices] fallback-gas-prices)
      :dispatch [::tx-events/set-gas-price (:average fallback-gas-prices)]})))

;; Register an initialization event
(re-frame/dispatch [::handle-ethgasstation-fallback])
