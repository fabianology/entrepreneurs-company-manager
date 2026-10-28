import SwiftUI
import Charts

/// Positive magnitudes only enter a sector chart. Signed source values remain
/// visible in its legend; a credit or refund must never become a debt wedge.
struct DuoReportSlice: Identifiable {
    let id: String
    let title: String
    let value: Double
    let color: Color

    var magnitude: Double { value.isFinite ? max(0, value) : 0 }
}

enum DuoReportSeries {
    static func selectedID(at angle: Double?, in slices: [DuoReportSlice]) -> String? {
        guard let angle, angle.isFinite, angle >= 0 else { return nil }
        var end = 0.0
        for slice in slices where slice.magnitude > 0 {
            end += slice.magnitude
            if angle < end { return slice.id }
        }
        return nil
    }
}

enum DuoHologram {
    static let cyan = Color(hex: "#89EEE3")
    static let coral = Color(hex: "#FFB3A3")

    static func amount(_ value: Double, currency: String = "USD") -> String {
        value.formatted(.currency(code: currency))
    }
}

/// A bounded chart, rather than an always-running particle/animation layer.
/// The legend provides the same selection without relying on chart gestures or color.
struct DuoHolographicBreakdown: View {
    let title: String
    let slices: [DuoReportSlice]
    var currency = "USD"
    @Binding var selection: String?
    @State private var angle: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selected: DuoReportSlice? { slices.first { $0.id == selection } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.system(.caption, design: .monospaced).weight(.bold))
                .tracking(1.3).foregroundStyle(Color.zifrGold)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 24) { chart; legend.frame(minWidth: 160) }
                VStack(spacing: 16) { chart; legend }
            }
            if let selected {
                HStack {
                    Text(selected.title).foregroundStyle(selected.color)
                    Spacer(minLength: 8)
                    Text(DuoHologram.amount(selected.value, currency: currency)).foregroundStyle(.white)
                }
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) { Rectangle().fill(DuoHologram.cyan.opacity(0.22)).frame(height: 0.5) }
        .onChange(of: angle) { _, value in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                selection = DuoReportSeries.selectedID(at: value, in: slices)
            }
        }
        .onChange(of: slices.map(\.id)) { _, ids in
            if let selection, !ids.contains(selection) { self.selection = nil }
        }
    }

    private var chart: some View {
        ZStack {
            if slices.contains(where: { $0.magnitude > 0 }) {
                Chart(slices) { slice in
                    SectorMark(angle: .value(slice.title, slice.magnitude),
                               innerRadius: .ratio(0.76), angularInset: 3)
                        .foregroundStyle(slice.color.opacity(selection == nil || selection == slice.id ? 0.85 : 0.25))
                        .cornerRadius(3)
                        .accessibilityLabel(slice.title)
                        .accessibilityValue(DuoHologram.amount(slice.value, currency: currency))
                }
                .chartAngleSelection(value: $angle)
                .shadow(color: DuoHologram.cyan.opacity(0.15), radius: 9)
                .accessibilityLabel(title)
            } else {
                Circle().stroke(DuoHologram.cyan.opacity(0.25), style: StrokeStyle(lineWidth: 2, dash: [3, 7]))
                Text(slices.contains { $0.value.isFinite && $0.value != 0 } ? "No positive values" : "No data yet")
                    .font(.caption).foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(width: 146, height: 146)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(slices) { slice in
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        selection = selection == slice.id ? nil : slice.id
                    }
                } label: {
                    HStack(spacing: 10) {
                        Capsule().fill(slice.color).frame(width: 3, height: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(slice.title).font(.caption).foregroundStyle(.white.opacity(0.8))
                            Text(DuoHologram.amount(slice.value, currency: currency))
                                .font(.system(.headline, design: .rounded)).monospacedDigit()
                                .foregroundStyle(slice.color)
                        }
                        Spacer(minLength: 0)
                        if selection == slice.id {
                            Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(slice.color)
                        }
                    }
                    .padding(.vertical, 8).frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == slice.id ? .isSelected : [])
            }
        }
    }
}

struct DuoHolographicFinancialSummary: View {
    let debt: Double
    let cardDebt: Double
    let availableCredit: Double
    let monthlyServices: Double
    @State private var selected: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TOTAL DEBT").font(.system(.caption, design: .monospaced).weight(.bold))
                .tracking(1.4).foregroundStyle(.white.opacity(0.75))
            Text(DuoHologram.amount(debt))
                .font(.system(size: 34, weight: .semibold, design: .rounded)).monospacedDigit()
                .foregroundStyle(Color.zifrGold)
                .shadow(color: Color.zifrGold.opacity(0.22), radius: 8)
                .minimumScaleFactor(0.6).lineLimit(1)
            DuoHolographicBreakdown(title: "DEBT & AVAILABLE CREDIT", slices: [
                .init(id: "cards", title: "Credit card balance", value: cardDebt, color: DuoHologram.coral),
                .init(id: "loans", title: "Loan balance", value: debt - cardDebt, color: .zifrGold),
                .init(id: "available", title: "Available credit", value: availableCredit, color: DuoHologram.cyan)
            ], selection: $selected)
            HStack {
                Text("Monthly services").foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(DuoHologram.amount(monthlyServices)).foregroundStyle(DuoHologram.cyan).monospacedDigit()
            }
            .font(.subheadline.weight(.medium)).padding(.vertical, 12)
        }
    }
}

struct DuoHolographicSubscriptionSummary: View {
    let summary: SubscriptionReceiptSummary
    @State private var selectedCurrency: String?
    @State private var selectedType: String?
    @State private var annual = false
    private var currency: String {
        selectedCurrency.flatMap { summary.currencies.contains($0) ? $0 : nil } ?? summary.currencies.first ?? "USD"
    }
    private var charges: [SubscriptionReceiptSummary.Charge] {
        summary.charges.filter { $0.currency == currency }
    }
    private var shownCharges: [SubscriptionReceiptSummary.Charge] {
        charges.filter { selectedType == nil || $0.serviceType.rawValue == selectedType }
    }
    private func periodAmount(_ charge: SubscriptionReceiptSummary.Charge) -> Double {
        annual ? charge.annualAmount : charge.annualAmount / 12
    }
    private var slices: [DuoReportSlice] {
        var subscriptionAmount = 0.0
        var billAmount = 0.0
        for charge in charges {
            if charge.serviceType == .bill { billAmount += periodAmount(charge) }
            else { subscriptionAmount += periodAmount(charge) }
        }
        return [
            DuoReportSlice(id: RecurringServiceType.subscription.rawValue, title: "Subscriptions",
                           value: subscriptionAmount, color: DuoHologram.cyan),
            DuoReportSlice(id: RecurringServiceType.bill.rawValue, title: "Bills",
                           value: billAmount, color: DuoHologram.coral)
        ]
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            periodControls
            total
            DuoHolographicBreakdown(title: "RECURRING CHARGES", slices: slices,
                                     currency: currency, selection: $selectedType)
            chargeDetails
        }
    }

    private var periodControls: some View {
        HStack {
            Picker("Report period", selection: $annual) {
                Text("Monthly").tag(false)
                Text("Annual").tag(true)
            }.pickerStyle(.segmented).frame(maxWidth: 240)
            Spacer(minLength: 8)
            Menu(currency) {
                ForEach(summary.currencies, id: \.self) { code in
                    Button(code) { selectedCurrency = code; selectedType = nil }
                }
            }
            .font(.subheadline.weight(.semibold)).foregroundStyle(Color.zifrGold)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Report currency, \(currency)")
        }
    }

    private var total: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(annual ? "ANNUAL EQUIVALENT" : "MONTHLY EQUIVALENT")
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .tracking(1.3).foregroundStyle(.white.opacity(0.75))
            Text(DuoHologram.amount(charges.reduce(0) { $0 + periodAmount($1) }, currency: currency))
                .font(.system(size: 34, weight: .semibold, design: .rounded)).monospacedDigit()
                .foregroundStyle(Color.zifrGold).shadow(color: Color.zifrGold.opacity(0.22), radius: 8)
                .minimumScaleFactor(0.6).lineLimit(1)
        }
    }

    @ViewBuilder
    private var chargeDetails: some View {
        if charges.isEmpty {
            Text("No active paid services.").font(.subheadline).foregroundStyle(.white.opacity(0.8))
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(shownCharges) { charge in chargeRow(charge) }
            }
        }
    }

    private func chargeRow(_ charge: SubscriptionReceiptSummary.Charge) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(charge.name).foregroundStyle(.white)
                Spacer(minLength: 12)
                Text(DuoHologram.amount(charge.amount, currency: currency))
                    .foregroundStyle(DuoHologram.cyan).monospacedDigit()
            }.font(.subheadline.weight(.medium))
            Text("\(charge.cycle == .monthly ? "Monthly" : "Yearly") · \(charge.source.label)")
                .font(.caption).foregroundStyle(.white.opacity(0.75))
        }
        .padding(.vertical, 10).accessibilityElement(children: .combine)
    }
}


/// A stationary edge divider opens an ninety-percent-width drawer.
struct DuoBinderDrawerFrames: Equatable {
    let sheet: CGRect
    let tab: CGRect
    let travel: CGFloat

    static func resolve(size: CGSize, progress: CGFloat, tabIndex: Int) -> Self {
        let width = max(0, size.width), height = max(0, size.height)
        let tabWidth = min(56, width)
        let travel = width * 0.9
        let fraction = progress.isFinite ? min(1, max(0, progress)) : 0
        let x = fraction * travel
        let top = min(16, height)
        let gap = min(12, max(0, height - top) / 6)
        let tabHeight = min(144, max(0, height - top - gap * 2) / 3)
        let y = top + CGFloat(min(2, max(0, tabIndex))) * (tabHeight + gap)
        return Self(sheet: CGRect(x: x - travel, y: 0, width: travel, height: height),
                    tab: CGRect(x: 0, y: y, width: tabWidth, height: tabHeight), travel: travel)
    }
}

private struct DuoBinderDividerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cut = min(12, min(rect.width, rect.height) / 3)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + cut),
                          control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - cut, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// One persistent divider is the pull handle during both tap and drag gestures.
struct MiloomDuoFilingTab: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: (CGFloat, CGFloat) -> Void

    var body: some View {
        Button(action: action) {
            GeometryReader { geometry in
                Label(title, systemImage: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(width: max(0, geometry.size.height - 20), height: 24)
                    .rotationEffect(.degrees(-90))
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .foregroundStyle(isSelected ? Color.zifrGold : .white.opacity(0.85))
            .background { tabGlass }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { onDragChanged($0.translation.width) }
            .onEnded { onDragEnded($0.translation.width, $0.predictedEndTranslation.width) })
        .accessibilityLabel(isSelected ? "Close \(title)" : "\(title) divider")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "Tap again or drag left to close the file" : "Tap or pull right to open the file")
    }

    @ViewBuilder private var tabGlass: some View {
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(.clear.interactive(), in: DuoBinderDividerShape())
        } else {
            DuoBinderDividerShape().fill(.ultraThinMaterial)
        }
    }
}

/// A square leading edge makes the sheet emerge from the phone's left side.
/// The title stays in the inset card; a vertical pull handle sits on the glass.
struct MiloomDuoPortraitSheet<Content: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var dragOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(.headline, design: .monospaced).weight(.bold))
                .foregroundStyle(Color.zifrGold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($titleFocused)
            content().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(hex: "#0D4635"), in: RoundedRectangle(cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.leading, 20)
        // Preserve the previous 44-point control row plus its 4-point top inset.
        .padding([.top, .trailing, .bottom], 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { clearGlass }
        .overlay(alignment: .trailing) {
            Button(action: onClose) {
                Capsule().fill(.white.opacity(0.6)).frame(width: 4, height: 36)
                    .frame(width: 44, height: 80).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 2)
            .accessibilityLabel("Close \(title)")
            .accessibilityHint("Drag left or double tap to close the report")
            .simultaneousGesture(DragGesture(minimumDistance: 10, coordinateSpace: .global)
                .onChanged { dragOffset = min(0, $0.translation.width) }
                .onEnded { value in
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.32)) { dragOffset = 0 }
                    if value.translation.width < -40 || value.predictedEndTranslation.width < -100 { onClose() }
                })
        }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .offset(x: dragOffset)
        .accessibilityAction(.escape, onClose)
        .onAppear { titleFocused = true }
    }

    @ViewBuilder private var clearGlass: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                           bottomTrailingRadius: 28, topTrailingRadius: 28)
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(.clear, in: shape)
        } else {
            shape.fill(.ultraThinMaterial)
        }
    }
}


/// Seed the choice from the sheet item itself, rather than a separate state
/// write that can be captured before SwiftUI presents the first sheet frame.
struct MiloomDuoReportSelection<Financial: View, Subscriptions: View>: View {
    @State private var showsSubscriptions: Bool
    let financial: () -> Financial
    let subscriptions: () -> Subscriptions

    init(initiallyShowsSubscriptions: Bool,
         @ViewBuilder financial: @escaping () -> Financial,
         @ViewBuilder subscriptions: @escaping () -> Subscriptions) {
        _showsSubscriptions = State(initialValue: initiallyShowsSubscriptions)
        self.financial = financial
        self.subscriptions = subscriptions
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Report", selection: $showsSubscriptions) {
                Text("Financial").tag(false)
                Text("Subscriptions").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(16)
            if showsSubscriptions { subscriptions() } else { financial() }
        }
    }
}
