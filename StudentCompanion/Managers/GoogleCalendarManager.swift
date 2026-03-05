import SwiftUI
import GoogleSignIn // This is for Google Sign-In
import GoogleAPIClientForREST_Calendar // This is for Google Calendar API (assuming GoogleAPIClientForREST_Calendar product was added)
import GoogleAPIClientForRESTCore // Core for the Google API client library

// Define the necessary scopes for Google Calendar API
private let scopes = [
    "https://www.googleapis.com/auth/calendar.readonly", // View calendars and events
    "https://www.googleapis.com/auth/calendar.events"    // Manage events (create, edit, delete)
]

class GoogleCalendarManager: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var userProfile: GIDProfileData?
    @Published var error: Error? // General errors for sign-in, calendar list
    @Published var fetchedCalendars: [GTLRCalendar_CalendarListEntry] = []
    @Published var isLoadingCalendars: Bool = false

    @Published var fetchedEventsByCalendar: [String: [GTLRCalendar_Event]] = [:]
    @Published var isLoadingEvents: Bool = false
    @Published var eventFetchError: Error? = nil

    @Published var selectedCalendarIDs: Set<String> {
        didSet {
            saveSelectedCalendarIDs()
             ("Selected calendar IDs changed: \(selectedCalendarIDs)")
            if isSignedIn {
                syncEventsForSelectedCalendars()
            }
        }
    }

    private let selectedCalendarIDsKey = "googleCalendarSelectedIDs"

    // Make sure GTLRCalendarService is the correct type from the imported module
    private let calendarService = GTLRCalendarService()

    init() {
        self.selectedCalendarIDs = Self.loadSelectedCalendarIDs(from: UserDefaults.standard, key: selectedCalendarIDsKey)

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: "802192919415-cnjmfbihba29nb3m23hb1gslqcf974f2.apps.googleusercontent.com")
        
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let error {
                self.error = error
                self.isSignedIn = false
                return
            }
            if let user {
                self.userProfile = user.profile
                self.calendarService.authorizer = user.fetcherAuthorizer
                self.isSignedIn = true
                self.loadCalendarList { success in
                    if success && !self.selectedCalendarIDs.isEmpty {
                        self.syncEventsForSelectedCalendars()
                    }
                }
            } else {
                self.isSignedIn = false
            }
        }
    }

    func signIn(presentingViewController: UIViewController) {
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController, hint: nil, additionalScopes: scopes) { signInResult, error in
            if let error {
                self.error = error
                self.isSignedIn = false
                 ("Sign-in error: \(error.localizedDescription)")
                return
            }
            
            guard let signInResult else {
                self.error = NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown sign-in error: signInResult is nil"])
                self.isSignedIn = false
                return
            }
            
            let user = signInResult.user

            self.userProfile = user.profile
            self.calendarService.authorizer = user.fetcherAuthorizer
            self.isSignedIn = true
            self.error = nil // Clear general errors
             ("Successfully signed in as \(user.profile?.name ?? "Unknown User")")
            
            self.loadCalendarList { success in
                if success && !self.selectedCalendarIDs.isEmpty {
                    self.syncEventsForSelectedCalendars()
                } else if success && self.selectedCalendarIDs.isEmpty {
                    // No calendars pre-selected, or list is empty. Do nothing for events yet.
                     ("Calendar list loaded, no calendars were pre-selected or found for event sync.")
                }
            }
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        self.userProfile = nil
        self.calendarService.authorizer = nil
        self.isSignedIn = false
        self.fetchedCalendars = []
        // self.selectedCalendarIDs = [] // Keep persisted selection or clear? Let's keep for now.
        
        self.fetchedEventsByCalendar = [:]
        self.isLoadingEvents = false
        self.eventFetchError = nil
        
         ("Successfully signed out")
    }

    func loadCalendarList(completion: ((_ success: Bool) -> Void)? = nil) {
        guard isSignedIn, calendarService.authorizer != nil else {
            self.error = NSError(domain: "GoogleCalendarManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not signed in or authorizer missing for calendar list fetch"])
            self.fetchedCalendars = []
            completion?(false)
            return
        }
        
        self.isLoadingCalendars = true
        self.error = nil // Clear previous errors

        let query = GTLRCalendarQuery_CalendarListList.query()
        query.showHidden = true // You might want to make this configurable later

        calendarService.executeQuery(query) { (ticket: GTLRServiceTicket, result: Any?, error: Error?) in
            DispatchQueue.main.async { // Ensure UI updates are on the main thread
                self.isLoadingCalendars = false
                if let error {
                    self.error = error
                    self.fetchedCalendars = []
                     ("Error fetching calendar list: \(error.localizedDescription)")
                    completion?(false)
                    return
                }
                
                if let calendarList = result as? GTLRCalendar_CalendarList, let items = calendarList.items {
                    self.fetchedCalendars = items
                     ("Successfully fetched \(items.count) calendars.")
                    completion?(true)
                } else {
                    self.error = NSError(domain: "GoogleCalendarManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse calendar list or no items found"])
                    self.fetchedCalendars = []
                     ("Failed to parse calendar list or no items found.")
                    completion?(false)
                }
            }
        }
    }

    func fetchEvents(forCalendarId calendarId: String = "primary", completion: @escaping (Result<[GTLRCalendar_Event], Error>) -> Void) {
        guard isSignedIn, calendarService.authorizer != nil else {
            completion(.failure(NSError(domain: "GoogleCalendarManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not signed in or authorizer missing"])))
            return
        }

        let query = GTLRCalendarQuery_EventsList.query(withCalendarId: calendarId)
        query.timeMin = GTLRDateTime(date: Date())
        query.singleEvents = true
        query.orderBy = kGTLRCalendarOrderByStartTime

        calendarService.executeQuery(query) { (ticket: GTLRServiceTicket, result: Any?, error: Error?) in
            if let error {
                completion(.failure(error))
                return
            }

            if let events = result as? GTLRCalendar_Events, let items = events.items {
                completion(.success(items))
            } else {
                completion(.failure(NSError(domain: "GoogleCalendarManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse events or no items found"])))
            }
        }
    }

    func syncEventsForSelectedCalendars() {
        guard isSignedIn else {
             ("Cannot sync events, user not signed in.")
            return
        }

        guard !selectedCalendarIDs.isEmpty else {
             ("No calendars selected for event sync.")
            // Clear any previously fetched events if no calendars are selected anymore
            DispatchQueue.main.async {
                 self.fetchedEventsByCalendar = [:]
                 self.eventFetchError = nil
                 self.isLoadingEvents = false
            }
            return
        }

         ("Starting event sync for calendars: \(selectedCalendarIDs)")
        DispatchQueue.main.async {
            self.isLoadingEvents = true
            self.eventFetchError = nil // Clear previous event errors
            // self.fetchedEventsByCalendar = [:] // Decide if we append or replace. For a full sync, replace.
        }

        let group = DispatchGroup()
        var newFetchedEvents: [String: [GTLRCalendar_Event]] = [:]
        var firstErrorEncountered: Error? = nil

        for calendarId in selectedCalendarIDs {
            group.enter()
            fetchEvents(forCalendarId: calendarId) { result in
                switch result {
                case .success(let events):
                    // Since access to newFetchedEvents is inside multiple completion handlers,
                    // ensure thread safety if necessary, though DispatchGroup should handle completions sequentially enough.
                    // For simplicity, direct assignment here. If issues, use a serial queue for writes.
                    newFetchedEvents[calendarId] = events
                     ("Fetched \(events.count) events for calendar ID: \(calendarId)")
                case .failure(let error):
                     ("Error fetching events for calendar ID \(calendarId): \(error.localizedDescription)")
                    if firstErrorEncountered == nil {
                        firstErrorEncountered = error
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.isLoadingEvents = false
            self.fetchedEventsByCalendar = newFetchedEvents // Update with all fetched events
            if let error = firstErrorEncountered {
                self.eventFetchError = error
                 ("Event sync completed with error(s). First error: \(error.localizedDescription)")
            } else {
                self.eventFetchError = nil
                 ("Event sync completed successfully for all selected calendars.")
                // For debugging,   a summary
                for (calId, events) in self.fetchedEventsByCalendar {
                     ("Calendar: \(self.fetchedCalendars.first(where: {$0.identifier == calId})?.summary ?? calId), Events: \(events.count)")
                }
            }
            // Send notification to EventViewModel to process the fetched events
            NotificationCenter.default.post(name: .googleCalendarEventsFetched, object: nil)
        }
    }

    // TODO: Implement create, update, delete event functions

    private func saveSelectedCalendarIDs() {
        let idsArray = Array(selectedCalendarIDs)
        UserDefaults.standard.set(idsArray, forKey: selectedCalendarIDsKey)
    }

    private static func loadSelectedCalendarIDs(from defaults: UserDefaults, key: String) -> Set<String> {
        guard let idsArray = defaults.array(forKey: key) as? [String] else {
            return []
        }
        return Set(idsArray)
    }
}

// Helper to get the top view controller for presenting Google Sign-In
extension UIApplication {
    class func getTopViewController(base: UIViewController? = nil) -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows
            .filter({$0.isKeyWindow}).first
        
        var currentBase = base ?? keyWindow?.rootViewController

        if let nav = currentBase as? UINavigationController {
            currentBase = nav.visibleViewController
        }
        if let tab = currentBase as? UITabBarController {
            if let selected = tab.selectedViewController {
                currentBase = selected
            }
        }
        while let presented = currentBase?.presentedViewController {
            currentBase = presented
        }
        return currentBase
    }
}
