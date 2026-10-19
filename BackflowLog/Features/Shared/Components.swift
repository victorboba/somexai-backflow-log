import SwiftUI

struct MaxContentWidth: ViewModifier {
    var width: CGFloat
    func body(content: Content) -> some View {
        content.frame(maxWidth: width).frame(maxWidth: .infinity)
    }
}

extension View {
    func maxContentWidth(_ width: CGFloat = 640) -> some View { modifier(MaxContentWidth(width: width)) }
}

extension RouteMath.DueStatus {
    var tint: Color {
        switch self {
        case .overdue: return .red
        case .dueSoon: return .orange
        case .scheduled: return .green
        case .neverTested: return .purple
        }
    }
}

struct Panel<Content: View>: View {
    var title: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// One stop on the route: who, where, which assembly, and when it is due.
struct RouteRow: View {
    let entry: RouteMath.RouteEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.status.symbol)
                .font(.title3)
                .foregroundStyle(entry.status.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.customerName).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(entry.siteName) · \(entry.assemblyName)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Text(entry.location).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(dueText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(entry.status.tint)
                    .multilineTextAlignment(.trailing)
                if let due = entry.dueDate {
                    Text(Formatters.short.string(from: due))
                        .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var dueText: String {
        guard let days = entry.daysUntilDue else { return "Never tested" }
        return Formatters.due(days).prefix(1).uppercased() + Formatters.due(days).dropFirst()
    }
}

/// One gauge reading on the test form, with its minimum shown and a flag when it falls short.
struct ReadingField_View: View {
    let field: ReadingField
    let minimum: Double
    @Binding var text: String
    @FocusState.Binding var keypadUp: Bool

    private var value: Double? { Double(text.replacingOccurrences(of: ",", with: ".")) }
    private var isShort: Bool { value.map { $0 < minimum } ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(field.name).font(.subheadline)
                Spacer()
                TextField("0.0", text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .frame(width: 82)
                    .focused($keypadUp)
                Text(field.unit).font(.subheadline).foregroundStyle(.secondary)
            }
            if isShort {
                Label("Below your minimum of \(Formatters.psi(minimum)) \(field.unit)",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            } else if value != nil {
                Label("Minimum \(Formatters.psi(minimum)) \(field.unit)", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }
}

struct StatBlock: View {
    let value: String
    let label: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.weight(.bold)).monospacedDigit().foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// One past test in a history list.
struct TestRow: View {
    let test: BackflowTest

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: test.passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                .foregroundStyle(test.passed ? Color.green : Color.red)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(test.customerName) · \(test.assemblyName)")
                    .font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(Formatters.short.string(from: test.date))
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .contentShape(Rectangle())
    }

    private var detail: String {
        var parts = [test.reason.name]
        if test.hasRepair { parts.append("repaired") }
        if !test.siteName.isEmpty { parts.append(test.siteName) }
        return parts.joined(separator: " · ")
    }
}
