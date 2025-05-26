(ns ethlance.ui.event.sign-in
  (:refer-clojure :exclude [resolve])
  (:require
    [district.ui.graphql.events :as gql-events]
    [district.ui.logging.events :as logging.events]
    [district.ui.web3-accounts.queries :as account-queries]
    [district.ui.web3.queries :as web3-queries]
    [re-frame.core :as re]))

;; Add a flag to prevent multiple concurrent sign-in attempts
(def ^:private signing-in-progress? (atom false))

(re/reg-event-fx
  :user/sign-in
  ;; Event FX Handler. Perform a sign in with the active ethereum account.
  ;;
  ;; # Notes
  ;;
  ;; - This will attempt to 'sign' the `data-str` using the given active
  ;; account. If the signed message is valid, the active ethereum account
  ;; will be signed in by providing the session with a JWT Token.
  (fn [{:keys [db]} _]
    ;; Check if already signed in or if signing is in progress
    (if (or @signing-in-progress? (get-in db [:active-session :jwt]))
      (do
        (.log js/console "Sign-in skipped - already signed in or in progress.")
        {})
      (let [active-account (account-queries/active-account db)]
        (if-not active-account
          (do
            (.log js/console "No active account found, can't sign in.")
            {:dispatch [::logging.events/error "No active Ethereum account found. Please connect your wallet."]}) 
          (let [data-str " Sign in to Ethlance! "]
            (.log js/console "Starting sign-in process with account:" active-account)
            (reset! signing-in-progress? true)
            {:web3/personal-sign
             {:web3 (web3-queries/web3 db)
              :data-str data-str
              :from active-account
              :on-success [:user/-authenticate {:data-str data-str}]
              :on-error [::sign-in-error]}})))))

(re/reg-event-fx
  ::sign-in-error
  (fn [_ [_ error]]
    (.log js/console "Sign-in error:" (or error "Unknown error"))
    (reset! signing-in-progress? false)
    {:dispatch [::logging.events/error (str "Error signing with Ethereum account: " (or error "Unknown error"))]}))

(re/reg-event-fx
  :user/sign-out
  ;; TODO Remove JWT server-side
  [(re/inject-cofx :store)]
  (fn [{:keys [db store]}]
    (.log js/console "Signing out user")
    (reset! signing-in-progress? false)
    {:db (dissoc db :active-session)
     :store (dissoc store :active-session)
     :dispatch [:district.ui.graphql.events/set-authorization-token nil]}))

(re/reg-event-fx
  ::store-active-session
  (fn [cofx [_ event-data]]
    (.log js/console "Storing active session:" (clj->js event-data))
    (reset! signing-in-progress? false)
    (let [jwt (get-in event-data [:sign-in :jwt])
          user-id (get-in event-data [:sign-in :user/id])]
      (if (and jwt user-id)
        (-> cofx
            (assoc-in ,,, [:db :active-session] {:jwt jwt :user/id user-id})
            (assoc ,,, :store {:jwt jwt :user/id user-id})
            (assoc ,,, :fx [[:dispatch [:district.ui.graphql.events/set-authorization-token jwt]]]))
        (do
          (.log js/console "Warning: Received incomplete session data")
          (-> cofx
              (assoc-in [:db :active-session] nil)
              (assoc :fx [[:dispatch [::logging.events/error "Failed to receive proper authentication data"]]]))))))

;; Intermediates
(re/reg-event-fx
  ;; Event FX Handler. Authenticate the sign in for the given active account.
  :user/-authenticate
  (fn [_ [_ {:keys [data-str]} data-signature]]
    (.log js/console "Authentication with signature complete, submitting to backend...")
    {:dispatch [::gql-events/mutation
                {:queries [[:sign-in {:data-signature data-signature
                                      :data data-str}
                            [:jwt :user/id]]]
                 :on-success [::store-active-session]
                 :on-error [::auth-error]}]}))

(re/reg-event-fx
  ::auth-error
  (fn [_ [_ error]]
    (.log js/console "Authentication error:" (clj->js error))
    (reset! signing-in-progress? false)
    {:dispatch [::logging.events/error "Failed to authenticate with server. Please try again later."]}))

(comment
  (re/dispatch [:user/sign-in]))
