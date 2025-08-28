(ns ethlance.ui.patches.ethgasstation-override
  (:require
    [re-frame.core :as re-frame]
    [district.ui.web3-tx.events :as tx-events]))

;; Override the ethgasstation API with local hardcoded values
(re-frame/reg-event-fx
  ::override-ethgasstation
  (fn [{:keys [db]} _]
    (let [fallback-gas-prices {:average 50 :fast 70 :fastest 90}]
      {:db (assoc-in db [:district.ui.web3-tx :gas-prices] fallback-gas-prices)
       :dispatch [::tx-events/set-gas-price (:average fallback-gas-prices)]})))

;; Auto-initialize on load
(re-frame/dispatch-sync [::override-ethgasstation])
