import Foundation

/// Everything user-facing that changes per app. Compiled into both the app and the widget,
/// so keep it free of UIKit/SwiftUI imports.
enum AppConfig {
    // MARK: Identity
    static let appName = "Backflow Log"
    static let bundleID = "com.example.backflow-log"
    static let appGroupID = "group.com.example.backflow-log"
    /// Your App Store ID once the app is live. The Rate button stays hidden while it is empty.
    static let appStoreID = ""

    // MARK: Sync
    static let iCloudSyncEnabled = false

    // MARK: StoreKit
    static let productPrefix = bundleID.replacingOccurrences(of: "-", with: "")
    static let annualProductID = "\(productPrefix).pro.annual"
    static let lifetimeProductID = "\(productPrefix).pro.lifetime"

    // MARK: Links
    static let supportEmail = "support@somexai.com"
    static let privacyPolicyURL = URL(string: "https://somexai.com/privacy/backflow-log/")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    // MARK: Copy
    static let entryNoun = "Test"
    static let entryNounPlural = "Tests"
    static let exportFileStem = "backflow"

    /// The boundary. The tester passes or fails the assembly; the app records and prints it.
    static let disclaimer = """
    You take the readings and you decide whether the assembly passed. Backflow Log records what \
    you entered, compares it against the minimums you set in Settings, and prints a report. \
    It is not an approved form for any water purveyor, it does not file anything on your behalf, \
    and it does not replace your certification or your jurisdiction's own paperwork.
    """

    static let onboarding: [OnboardingPage] = [
        OnboardingPage(symbol: "list.clipboard.fill", title: "The route, not a spreadsheet",
                       body: "Every assembly you look after, sorted by what is overdue and what is due next. Plan a month in one screen."),
        OnboardingPage(symbol: "gauge.with.needle", title: "The form on the truck",
                       body: "The right boxes for an RP, a DC or a PVB, with your own minimums flagged while you are still on site."),
        OnboardingPage(symbol: "doc.text.fill", title: "A report to send",
                       body: "A PDF per test with the assembly, the readings, the repairs and your certification number. Email it from the driveway."),
    ]

    static let paywallSymbol = "gauge.with.needle"
    static let paywallHeadline = "Unlock Backflow Log"
    static let paywallBenefits = [
        "Unlimited customers, sites and assemblies",
        "The route, sorted by what is overdue and due next",
        "Test forms shaped to each assembly type",
        "A report PDF per test, plus CSVs for your records",
        "No account, no per-test fee, nothing leaves your phone",
    ]

    // MARK: How-to guide
    static let howToIntro = "Four steps from install to a report you can send from the driveway."
    static let howTo: [HowToStep] = [
        HowToStep(symbol: "person.text.rectangle", title: "Put your details in",
                  body: "Tap the gear on the Route screen, then You and your gauge. Your name, certification number, gauge serial and its calibration date print on every report.",
                  tip: "The app warns you when the gauge calibration has run out, because that voids the tests taken with it."),
        HowToStep(symbol: "building.2", title: "Add a customer and a site",
                  body: "On the Customers tab tap +, add the customer, then a site with its address. A customer can have as many sites as you look after.",
                  tip: "Access notes are worth filling in. Where the key is kept saves the second trip."),
        HowToStep(symbol: "gauge.with.needle", title: "Add the assembly",
                  body: "Inside a site tap Add assembly. Pick the type, then the serial, make, model, size and exactly where it sits on the property.",
                  tip: "Set how often it needs testing. Most are annual; some high hazard assemblies are more often."),
        HowToStep(symbol: "square.and.pencil", title: "Run a test",
                  body: "From the Route screen tap the assembly, then Start Test. The form shows only the boxes that assembly's report needs. Enter the readings, mark it passed or failed, and save.",
                  tip: "A reading under your configured minimum is flagged on the spot, while you are still standing at the valve."),
        HowToStep(symbol: "square.and.arrow.up", title: "Send the report",
                  body: "Every saved test has a Report button. Share the PDF to email, Files or a printer, then send it to the water purveyor the way they ask for it."),
        HowToStep(symbol: "rectangle.on.rectangle", title: "Add the widget",
                  body: "Long-press your Home Screen, tap +, search \"Backflow Log\", and add the widget to see what is overdue."),
    ]

    /// Display prices used only by DEBUG screenshot runs (`-mockPrices`).
    static let mockPrices = (annual: "$29.99", lifetime: "$69.99")

    // MARK: Behaviour
    static let reviewAfterSuccesses = 5
}

struct HowToStep: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
    var tip: String? = nil
}

struct OnboardingPage: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
}
