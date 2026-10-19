# Backflow Log

A route and test report tool for certified backflow prevention assembly testers. It organizes customers, sites and assemblies, builds a route from due dates, and prints a test report per assembly.

One of a set of niche iPhone apps built from a shared SwiftUI template. It was never released on the App Store; the code is here for anyone to use. The template is [somexai-ios-template](https://github.com/victorboba/somexai-ios-template) and the collection is [somexai-ios-apps](https://github.com/victorboba/somexai-ios-apps).

## What it does

- **Route**: every assembly sorted by urgency, grouped by month. Never-tested sits above overdue, because that is work nobody has scheduled.
- **Customer, site, assembly**: a three-level hierarchy with the route built on top of it.
- **Type-shaped forms**: an RP asks for two checks and a relief valve, a DC for two checks, a PVB for an air inlet and a check. `AssemblyType.fields` drives the form so nothing irrelevant appears.
- **Flagging on the spot**: a reading below the tester's own minimum turns red while the tester is still at the valve, and the footer lists boxes still empty.
- **Repairs**: one switch adds a second set of readings, and both print with what was done in between.
- **Report PDF** per test with the nameplate, every reading beside the minimum it was judged against, and the tester's certification and gauge details.
- **Gauge calibration**: tracked and warned about.
- A Home Screen widget showing what is overdue, a Siri App Shortcut ("Open the route"), CSVs for tests and the route, and a How do I use guide.

## The boundary

The tester passes or fails the assembly; the app never does. Readings are compared against minimums the tester enters in Settings and anything short is flagged, but the result recorded on the report is the tester's own entry. The app is not an approved form for any water purveyor and files nothing. `AppConfig.disclaimer` appears on Route, on the test form, in Settings and at the foot of every report.

## Privacy

All data stays on the device in SwiftData. There is no account, no analytics and no network code, and `AppConfig.iCloudSyncEnabled` is `false`. CSV and PDF export happen only when you choose to share a file.

## Build and run

Requirements: Xcode 26 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), and iOS 17+.

```bash
xcodegen generate
open BackflowLog.xcodeproj
```

Pick the `BackflowLog` scheme and an iPhone simulator, then Run.

Tests:

```bash
xcodebuild -scheme BackflowLog -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' test
```

Paywall: the app has a hard paywall (annual subscription or lifetime purchase). Running from Xcode uses the bundled `Products.storekit` file, so purchases are simulated and free. Debug builds can also skip it with the `-unlock` launch argument or the Debug switch in Settings. Debug builds also accept the launch arguments `-sampleData`, `-resetData`, `-skipOnboarding`, `-mockPrices` and `-uiTesting`.

To run on your own device or ship it: set your team in `project.yml` (`DEVELOPMENT_TEAM`), change the `com.example` bundle ID prefix in `project.yml`, both `.entitlements` files and `Products.storekit`, and update `supportEmail`, `privacyPolicyURL` and `appStoreID` in `Shared/AppConfig.swift`.

## Project layout

- `BackflowLog/App/`: app entry point and the root view that gates onboarding, paywall and the app.
- `BackflowLog/Core/`: StoreKit entitlement, CSV and PDF export, App Intents, review prompt, widget sync, debug flags and sample data.
- `BackflowLog/Features/`: the screens, including onboarding, paywall, settings and the How do I use guide.
- `BackflowLog/Models/`: the SwiftData models and the calculation code. Models are `Assembly` and `BackflowTest`; route logic lives in `RouteMath`.
- `BackflowLog/StoreKit/Products.storekit`: local StoreKit configuration.
- `BackflowLogWidget/`: the Home Screen widget, fed by a snapshot in the App Group.
- `BackflowLogTests/` and `BackflowLogUITests/`: unit and UI tests.
- `Shared/AppConfig.swift`: everything that changes per app (name, copy, onboarding, paywall benefits, How-to steps, disclaimer, product IDs, links).
- `scripts/`: icon and screenshot helpers. `docs/` has notes on capabilities such as iCloud and App Groups.

## Technical notes

- Readings are stored as a string such as `"checkOne:5.2|relief:2.6"`, which handles a variable field set per assembly type with no join table and stays CloudKit-safe.
- Every test snapshots the assembly nameplate, site and customer, so replacing a unit never rewrites a report already written against the old one.
- An assembly with no tests has no due date rather than a guessed one, so the route never shows fictional work.
- `RouteMath` has no SwiftData dependency and is unit-tested directly.

## License

MIT. See [LICENSE](LICENSE).
