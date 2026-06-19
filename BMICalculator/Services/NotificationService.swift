//
//  NotificationService.swift
//  BMICalculator
//
//  Local weigh-in reminders, designed from the notification/retention research:
//
//  • CADENCE: weekly is the DEFAULT (sits safely below opt-out thresholds);
//    the person can choose daily / 3×-week / weekly / off. Never auto-escalate.
//  • OPT-IN: authorization is requested only AFTER a value moment (first saved
//    result), behind an in-app soft-ask — never cold on launch. iOS gives one
//    shot at the native dialog, so the UI must prime first; this service just
//    fires `requestAuthorization()` when the user taps the soft-ask CTA.
//  • COPY: personalized, ≤~12 words, one emoji max, and NUMBER-FREE — it
//    celebrates checking in, never the weight/BMI value (a stigmatizing metric).
//  • FRICTION: notifications deep-link to a pre-filled new entry and expose a
//    one-tap "Log now" action (category registered at launch).
//  • GUARDRAILS: reschedule after each log so a just-logged user isn't pinged;
//    suppress duplicates; keep the channel free of upsell.
//
//  Local-first: everything is scheduled and delivered on-device, no server.
//

import Foundation
import UserNotifications

@MainActor
@Observable
public final class NotificationService {

    // MARK: Cadence

    public enum ReminderCadence: String, CaseIterable, Identifiable, Sendable {
        case off, weekly, threeTimesWeek, daily
        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .off:            return "Off"
            case .weekly:         return "Weekly"
            case .threeTimesWeek: return "3× a week"
            case .daily:          return "Daily"
            }
        }

        public var subtitle: String {
            switch self {
            case .off:            return "No reminders"
            case .weekly:         return "Recommended — a gentle nudge"
            case .threeTimesWeek: return "Mon · Wed · Fri"
            case .daily:          return "For an active goal"
            }
        }
    }

    // MARK: Identifiers

    // `nonisolated` so the nonisolated `NotificationDelegate` (and other off-actor
    // callers) can read these compile-time string constants.
    nonisolated public static let reminderIDPrefix = "com.bmi.notifications.weighIn"
    /// Back-compat identifier for the single weekly request.
    nonisolated public static let weeklyReminderID = "\(reminderIDPrefix).weekly.0"
    nonisolated public static let categoryID = "WEIGH_IN_REMINDER"
    nonisolated public static let logActionID = "LOG_NOW"
    nonisolated public static let snoozeActionID = "SNOOZE"
    /// Deep link the tap / "Log now" action routes to (register `bmicalculator` URL scheme).
    nonisolated public static let deepLink = "bmicalculator://new-entry"

    // MARK: Observable state

    public private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    public private(set) var isReminderScheduled = false
    /// User-selected cadence (weekly default). Persisted by the caller via @AppStorage.
    public var cadence: ReminderCadence = .weekly

    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    // MARK: Launch setup

    /// Registers the "Log now" / "Snooze" actions. Call once at launch. The app's
    /// `UNUserNotificationCenterDelegate` handles the responses (route `deepLink`,
    /// reschedule on snooze).
    public func registerCategories() {
        let log = UNNotificationAction(identifier: Self.logActionID,
                                       title: "Log now",
                                       options: [.foreground])
        let snooze = UNNotificationAction(identifier: Self.snoozeActionID,
                                          title: "Remind me later",
                                          options: [])
        let category = UNNotificationCategory(identifier: Self.categoryID,
                                              actions: [log, snooze],
                                              intentIdentifiers: [],
                                              options: [])
        center.setNotificationCategories([category])
    }

    // MARK: Authorization

    public func refreshStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        await refreshScheduledState()
    }

    /// Fire the native permission dialog. Call ONLY from a soft-ask CTA, never cold.
    @discardableResult
    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
            return granted
        } catch {
            await refreshStatus()
            return false
        }
    }

    /// Quiet, prompt-free authorization (delivers to Notification Center). A
    /// low-friction fallback if the person declines the soft-ask.
    @discardableResult
    public func requestProvisionalAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge, .provisional])
            await refreshStatus()
            return granted
        } catch {
            await refreshStatus()
            return false
        }
    }

    // MARK: Scheduling

    /// Schedule reminders at the chosen cadence and a consistent morning time.
    /// - Parameters:
    ///   - weekday: 1 = Sun … 7 = Sat (default Monday). Ignored for `.daily`.
    ///   - hour/minute: consistent cue time (default 9:00am — habit research favors a fixed cue).
    ///   - userName: optional first name for personalization (4× reaction-rate lift).
    @discardableResult
    public func schedule(cadence: ReminderCadence,
                         weekday: Int = 2,
                         hour: Int = 9,
                         minute: Int = 0,
                         userName: String? = nil) async -> Bool {
        self.cadence = cadence
        cancelAll()
        guard cadence != .off else { return true }

        await refreshStatus()
        if authorizationStatus == .notDetermined { _ = await requestAuthorization() }
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            return false
        }

        var allOK = true
        for (index, comps) in Self.triggerComponents(for: cadence, weekday: weekday, hour: hour, minute: minute).enumerated() {
            let request = UNNotificationRequest(
                identifier: "\(Self.reminderIDPrefix).\(cadence.rawValue).\(index)",
                content: Self.makeContent(userName: userName),
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            )
            do { try await center.add(request) } catch { allOK = false }
        }
        await refreshScheduledState()
        return allOK && isReminderScheduled
    }

    /// Back-compat convenience (existing Settings/Onboarding callers). `lastBMI`
    /// is intentionally unused — copy never references the number.
    @discardableResult
    public func scheduleWeeklyReminder(weekday: Int = 2,
                                       hour: Int = 9,
                                       minute: Int = 0,
                                       lastBMI: Double? = nil,
                                       userName: String? = nil) async -> Bool {
        await schedule(cadence: .weekly, weekday: weekday, hour: hour, minute: minute, userName: userName)
    }

    /// GUARDRAIL: call after each saved entry so the next reminder is a fresh full
    /// period out — a person who just logged shouldn't be pinged immediately.
    public func rescheduleAfterLog(weekday: Int = 2, hour: Int = 9, minute: Int = 0, userName: String? = nil) async {
        guard cadence != .off else { return }
        _ = await schedule(cadence: cadence, weekday: weekday, hour: hour, minute: minute, userName: userName)
    }

    public func cancelWeeklyReminder() { cancelAll() }

    public func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: Self.allRequestIDs)
        isReminderScheduled = false
    }

    private static var allRequestIDs: [String] {
        ReminderCadence.allCases.flatMap { cadence in
            (0..<3).map { "\(reminderIDPrefix).\(cadence.rawValue).\($0)" }
        } + [weeklyReminderID]
    }

    private func refreshScheduledState() async {
        let pending = await center.pendingNotificationRequests()
        isReminderScheduled = pending.contains { $0.identifier.hasPrefix(Self.reminderIDPrefix) }
    }

    // MARK: Triggers

    private static func triggerComponents(for cadence: ReminderCadence, weekday: Int, hour: Int, minute: Int) -> [DateComponents] {
        func at(weekday: Int?) -> DateComponents {
            var c = DateComponents(); c.weekday = weekday; c.hour = hour; c.minute = minute; return c
        }
        switch cadence {
        case .off:            return []
        case .daily:          return [at(weekday: nil)]                 // repeats daily
        case .weekly:         return [at(weekday: weekday)]             // repeats weekly
        case .threeTimesWeek: return [at(weekday: 2), at(weekday: 4), at(weekday: 6)] // Mon/Wed/Fri
        }
    }

    // MARK: Copy (non-shaming, personalized, number-free)

    private static func makeContent(userName: String?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Check-in time"
        content.body = reminderBody(userName: userName)
        content.sound = .default
        content.interruptionLevel = .active
        content.categoryIdentifier = categoryID
        content.userInfo = ["link": deepLink]
        return content
    }

    /// The scheduled weigh-in reminder body. Celebrates the act, never the number.
    static func reminderBody(userName: String?) -> String {
        if let name = userName, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Time for your check-in, \(name). However the week went, showing up is the win. 🌱"
        }
        return "Time for your check-in. However the week went, showing up is the win. 🌱"
    }

    /// Reusable copy for other notification moments the app may add. All are
    /// number-free, person-first, and non-punitive — `{name}` is replaced by the
    /// caller (or dropped). Provided so the whole notification voice stays consistent.
    public enum Copy {
        public static let standardWeekly = "Ready for your check-in? It takes 10 seconds. ☀️"
        public static let gentleNumberFree = "Time for your weigh-in. However the week went, showing up is the win."
        public static let returnAfterLapse = "We've kept everything just as you left it. Whenever you're ready, your chart is here. 🌱"
        public static let milestoneGentle = "That's a month of checking in. Proud of the consistency. 💙"
        // ❌ Never: "You gained weight — log now", "Don't break your streak!", "Don't give up on your goals."
    }
}
