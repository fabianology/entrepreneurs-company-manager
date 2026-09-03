import SwiftUI
import SwiftData

// MARK: - Edit Card Sheet
struct EditCardSheet: View {
    @State var card: FinancialCard
    @Bindable var vm: AppViewModel
    let institutions: [Institution]
    let cards: [FinancialCard]
    let isNew: Bool
    var isInstitutionContext: Bool = false
    var customTitle: String? = nil
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var showShareSheet = false
    @State private var showDeleteInstitutionConfirm = false
    @State private var institutionToDelete: Institution? = nil
    @State private var showCardScanner = false
    
    private var subscriptions: [Subscription] { appState.subscriptions }
    
    private var isViewer: Bool {
        let share = appState.resourceShares.first(where: { $0.resourceId == card.id || $0.resourceId == card.companyId })
        return share?.role == "Viewer"
    }
    
    @State private var showFinancials = false
    @State private var showPaymentPicker = false
    @State private var isNewInstitution: Bool = false
    @State private var showTransactions = false
    
    // Institution Draft
    @State private var instWebsite: String = ""
    @State private var instLogin: String = ""
    @State private var instPass: String = ""
    @State private var instEmail: String = ""
    @State private var instTwoFactor: String = ""
    @State private var showInstPassword = false
    @State private var isEditingInstitution = false

    private var allLogins: [String] {
        let subLogins = subscriptions.map { $0.loginId }
        let instUsers = institutions.map { $0.username }
        let instEmails = institutions.map { $0.email }
        return (subLogins + instUsers + instEmails).compactMap { $0 }.filter { !$0.isEmpty }
    }
    private var autoPayBinding: Binding<Bool> {
        Binding(
            get: { card.autopay == "Yes" },
            set: { card.autopay = $0 ? "Yes" : "No" }
        )
    }
    
    private let ordinalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .ordinal
        return f
    }()

    private func ordinal(_ n: Int) -> String {
        ordinalFormatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private var paidOnBinding: Binding<Int> {
        Binding(
            get: { Int(card.paidOn ?? "") ?? 1 },
            set: { card.paidOn = "\($0)" }
        )
    }
    
    struct Snapshot: Equatable {
        var name, login, password, last4, network, type, autopay, cardHolder, cardHolderType, expiry, notes: String
        var balance, limit, moPayment, apr, promoApr: Double
        var promoEnds: Date
    }
    @State private var snapshot: Snapshot?

    private var currentSnapshot: Snapshot {
        Snapshot(name: card.name ?? "", login: card.login ?? "", password: card.password ?? "", last4: card.last4 ?? "", network: card.network ?? "", type: card.type ?? "", autopay: card.autopay, cardHolder: card.cardHolder ?? "", cardHolderType: card.cardHolderType ?? "", expiry: card.expiry ?? "", notes: card.notes ?? "", balance: card.balance, limit: card.limit, moPayment: card.moPayment, apr: card.apr, promoApr: card.promoApr, promoEnds: card.promoEnds ?? Date())
    }

    private var isDirty: Bool {
        guard let snap = snapshot else { return isNew && !card.name.trimmingCharacters(in: .whitespaces).isEmpty }
        return snap != currentSnapshot
    }

    private var institutionName: String {
        (card.institutionName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !institutionName.isEmpty
    }

    private func suggestedInstitutionWebsite(for name: String) -> String {
        let normalizedName = name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
            .lowercased()

        guard !normalizedName.isEmpty else { return "" }

        let knownDomains: [String: String] = [
            "ally": "ally.com",
            "allybank": "ally.com",
            "amex": "americanexpress.com",
            "americanexpress": "americanexpress.com",
            "apple": "apple.com",
            "applecard": "apple.com",
            "bankofamerica": "bankofamerica.com",
            "barclays": "barclays.com",
            "capitalone": "capitalone.com",
            "charlesschwab": "schwab.com",
            "chase": "chase.com",
            "chasebank": "chase.com",
            "citi": "citi.com",
            "citibank": "citi.com",
            "citizens": "citizensbank.com",
            "citizensbank": "citizensbank.com",
            "discover": "discover.com",
            "fidelity": "fidelity.com",
            "fidelityinvestments": "fidelity.com",
            "fifththird": "53.com",
            "fifththirdbank": "53.com",
            "goldmansachs": "goldmansachs.com",
            "jpmorgan": "jpmorgan.com",
            "jpmorganchase": "chase.com",
            "marcus": "marcus.com",
            "navyfederal": "navyfederal.org",
            "navyfederalcreditunion": "navyfederal.org",
            "paypal": "paypal.com",
            "pnc": "pnc.com",
            "pncbank": "pnc.com",
            "regions": "regions.com",
            "regionsbank": "regions.com",
            "sofi": "sofi.com",
            "synchrony": "synchrony.com",
            "synchronybank": "synchrony.com",
            "td": "td.com",
            "tdbank": "tdbank.com",
            "truist": "truist.com",
            "usaa": "usaa.com",
            "usbank": "usbank.com",
            "vanguard": "vanguard.com",
            "venmo": "venmo.com",
            "wellsfargo": "wellsfargo.com"
        ]

        if let knownDomain = knownDomains[normalizedName] {
            return knownDomain
        }

        let genericSuffixes = [
            "federalcreditunion",
            "creditunion",
            "financialservices",
            "financial",
            "nationalbank",
            "bankandtrust",
            "banktrust",
            "bank"
        ]

        let simplifiedName = genericSuffixes.reduce(normalizedName) { result, suffix in
            guard result.hasSuffix(suffix), result.count > suffix.count else { return result }
            return String(result.dropLast(suffix.count))
        }

        if let knownDomain = knownDomains[simplifiedName] {
            return knownDomain
        }

        return "\(simplifiedName).com"
    }

    @ViewBuilder private var institutionDetailsSection: some View {
        if isNewInstitution {
            VStack(alignment: .leading, spacing: 8) {
                ZifrField(
                    label: "INSTITUTION NAME",
                    placeholder: "e.g. Chase Bank",
                    text: Binding(
                        get: { card.institutionName ?? "" },
                        set: { newName in
                            card.institutionName = newName
                            instWebsite = suggestedInstitutionWebsite(for: newName)
                        }
                    )
                )
                
                let matches = institutions.filter { ($0.name ?? "").lowercased().contains((card.institutionName ?? "").lowercased()) && ($0.name ?? "").lowercased() != (card.institutionName ?? "").lowercased() }
                
                if !matches.isEmpty && !(card.institutionName ?? "").isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(matches.prefix(3)) { inst in
                                Button {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                        isNewInstitution = false
                                        card.institutionName = inst.name
                                        instWebsite = inst.loginUrl ?? ""
                                        instLogin = inst.username ?? ""
                                        instPass = inst.password ?? ""
                                        instEmail = inst.email ?? ""
                                        instTwoFactor = inst.twoFactor ?? ""
                                        isEditingInstitution = false
                                    }
                                } label: {
                                    Text("Switch to \(inst.name)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.green)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.green.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    @ViewBuilder private var institutionSelectorRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FINANCIAL INSTITUTION")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Color.white.opacity(0.5))
            
            VStack(spacing: 0) {
                if !institutions.isEmpty {
                    CustomSegmentedControl(
                        options: ["Select Existing", "Create New"],
                        selection: Binding(
                            get: { isNewInstitution ? "Create New" : "Select Existing" },
                            set: { isNewInstitution = $0 == "Create New" }
                        )
                    )
                    .padding(.bottom, 12)
                }
                
                if !isNewInstitution && !institutions.isEmpty {
                    Menu {
                        ForEach(institutions) { inst in
                            Button(inst.name.isEmpty ? "Unnamed" : inst.name) {
                                card.institutionName = inst.name
                                instWebsite = inst.loginUrl ?? ""
                                instLogin = inst.username ?? ""
                                instPass = inst.password ?? ""
                                instEmail = inst.email ?? ""
                                instTwoFactor = inst.twoFactor ?? ""
                                isEditingInstitution = false
                            }
                        }
                    } label: {
                        HStack {
                            Text((card.institutionName ?? "").isEmpty ? "Select Institution..." : (card.institutionName ?? ""))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle((card.institutionName ?? "").isEmpty ? Color.white.opacity(0.4) : .white)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.bottom, 16)
                }
                
                if isNewInstitution || !(card.institutionName ?? "").isEmpty {
                    institutionDetailsSection
                }

            }
        }
    }

    @ViewBuilder private var row1: some View {
        HStack(spacing: 12) {
            ZifrField(label: "CARD NICKNAME", placeholder: "e.g. Sapphire", text: Binding(get: { card.name ?? "" }, set: { card.name = $0 }))
            ZifrField(label: "NAME ON CARD", placeholder: "Jane Doe", text: Binding(get: { card.cardHolder ?? "" }, set: { card.cardHolder = $0 }), textContentType: .name)
        }
    }

    @ViewBuilder private var row2: some View {
        Group {
            VStack(alignment: .leading, spacing: 10) {
                ZifrField(
                    label: "CARD NUMBER",
                    placeholder: "0000 0000 0000 0000",
                    text: Binding(get: { card.cardNumber ?? "" }, set: { card.cardNumber = $0 }),
                    keyboardType: .numberPad,
                    trailingSystemImage: "camera.fill",
                    trailingIconColor: .zifrBG,
                    onTrailingTap: {
                        showCardScanner = true
                    }
                )
                .onChange(of: card.cardNumber) { old, new in
                    let newStr = new ?? ""
                    let filtered = newStr.filter { $0.isNumber }
                    if (card.cardNumber ?? "") != filtered { card.cardNumber = filtered }
                    
                    if let first = filtered.first {
                        if first == "4" { card.network = "Visa" }
                        else if first == "5" { card.network = "Mastercard" }
                        else if first == "3" { card.network = "Amex" }
                        else if first == "6" { card.network = "Discover" }
                    }
                    
                    let maxLen = card.network == "Amex" ? 5 : 4
                    if filtered.count >= maxLen {
                        card.last4 = String(filtered.suffix(maxLen))
                    } else {
                        card.last4 = filtered
                    }
                }
                
                if hasLinkedAccount {
                    linkedToRow
                }
            }
            .padding(.vertical, 4)
            
            HStack(spacing: 12) {
                cardPicker(label: "TYPE", sel: Binding(get: { card.type }, set: { card.type = $0 }), opts: FinancialCard.types)
                cardPicker(label: "NETWORK", sel: Binding(get: { card.network }, set: { card.network = $0 }), opts: FinancialCard.networks)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder private var credentialRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZifrField(
                    label: "LOGIN ID",
                    placeholder: "username or email",
                    text: Binding(get: { card.login ?? "" }, set: { card.login = $0 }),
                    textContentType: .username
                )
                ZifrField(
                    label: "PASSWORD",
                    placeholder: SecurityService.isLockedValue(card.password) ? SecurityService.lockedValueLabel : "••••••••",
                    text: Binding(get: { SecurityService.editableValue(card.password) }, set: { card.password = $0 }),
                    isSecure: true,
                    textContentType: .password
                )
            }
            if SecurityService.isLockedValue(card.password) {
                HStack {
                    Label("Password locked; replace it or preserve it unchanged.", systemImage: "lock.trianglebadge.exclamationmark")
                    Spacer()
                    Button("Clear", role: .destructive) { card.password = nil }
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.orange.opacity(0.8))
            }
        }
    }

    @ViewBuilder private var row3: some View {
        GeometryReader { geo in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AUTOPAY")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.45))
                    HStack {
                        Text(autoPayBinding.wrappedValue ? "Enabled" : "Disabled")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.white)
                        Spacer()
                        Toggle("", isOn: autoPayBinding).toggleStyle(PremiumToggleStyle())
                            .labelsHidden()
                            .tint(.green)
                            .scaleEffect(0.8)
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(hex: "#2C2C2E"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                }
                .frame(width: (geo.size.width - 12) * 0.6)

                VStack(alignment: .leading, spacing: 4) {
                    Text("PAID ON")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.45))
                    HStack {
                        Picker("", selection: paidOnBinding) {
                            ForEach(1...31, id: \.self) { day in
                                Text(ordinal(day)).tag(day)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .tint(.white)
                        Spacer()
                    }
                    .padding(.leading, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 44)
                    .background(Color(hex: "#2C2C2E"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .frame(width: (geo.size.width - 12) * 0.4)
            }
        }
        .frame(height: 64)
    }

    @ViewBuilder private var row4: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PAID FROM")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
            
            Button {
                showPaymentPicker = true
            } label: {
                HStack {
                    Text((card.paidFrom ?? "").isEmpty ? "None" : paidFromWithInstitution)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle((card.paidFrom ?? "").isEmpty ? Color.white.opacity(0.4) : .white)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color(hex: "#2C2C2E"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder private var row5: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ROLE")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.45))
                VStack(spacing: 0) {
                    Spacer()
                    CustomSegmentedControl(
                        options: ["Mine", "Assigned"],
                        selection: Binding(get: { card.cardHolderType ?? "Mine" }, set: { card.cardHolderType = $0 })
                    )
                    .labelsHidden()
                    Spacer()
                }
                .frame(height: 44)
            }
            
            ZifrField(label: "EXPIRES", placeholder: "MM/YY", text: Binding(get: { card.expiry ?? "" }, set: { card.expiry = $0 }), keyboardType: .numberPad)
                .onChange(of: card.expiry) { old, new in
                    var filtered = (new ?? "").filter { $0.isNumber }
                    if (old ?? "").count == 3 && (old ?? "").hasSuffix("/") && (new ?? "").count == 2 {
                        filtered = String(filtered.prefix(1))
                    }
                    if filtered.count > 2 {
                        filtered.insert("/", at: filtered.index(filtered.startIndex, offsetBy: 2))
                    }
                    if filtered.count > 5 {
                        filtered = String(filtered.prefix(5))
                    }
                    if (card.expiry ?? "") != filtered { card.expiry = filtered }
                }
        }
    }

    private var paysForServices: [(name: String, cost: Double)] {
        let cardName = card.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cardName.isEmpty else { return [] }
        var results: [(name: String, cost: Double)] = []
        for sub in subscriptions {
            if (sub.paymentMethod ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == cardName {
                results.append((name: sub.name.isEmpty ? "Unnamed Service" : sub.name, cost: sub.cost))
            }
            for subSvc in sub.subServices {
                if (subSvc.paymentMethod ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == cardName {
                    results.append((name: subSvc.name.isEmpty ? "Unnamed Sub-service" : subSvc.name, cost: subSvc.cost))
                }
            }
        }
        return results
    }

    @ViewBuilder private var paysForRow: some View {
        let services = paysForServices
        VStack(alignment: .leading, spacing: 12) {
            Text("PAYS FOR")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
                .padding(.leading, 6)
            
            if services.isEmpty {
                Text("No linked services")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(Color(hex: "#2C2C2E"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
            } else {
                ForEach(Array(services.enumerated()), id: \.offset) { index, svc in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(svc.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.zifrGreen)
                                    .frame(width: 6, height: 6)
                                
                                Text("|")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.white.opacity(0.2))
                                
                                Text("Paid with \(card.name)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.6))
                            }
                        }
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("$\(String(format: "%.0f", svc.cost))")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("/mo")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#2C2C2E"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.05), lineWidth: 1))
                }
            }
        }
    }

    private var hasLinkedAccount: Bool {
        let cardIdString = card.id.uuidString
        return appState.institutions.contains { inst in
            inst.accounts.contains { acc in
                acc.linkedCardId == cardIdString
            }
        }
    }

    private var linkedAccountText: String {
        let cardIdString = card.id.uuidString
        for inst in appState.institutions {
            for acc in inst.accounts {
                if let linkedId = acc.linkedCardId, linkedId == cardIdString {
                    return acc.name.isEmpty ? acc.type : acc.name
                }
            }
        }
        return ""
    }

    @ViewBuilder private var linkedToRow: some View {
        let linkedText = linkedAccountText
        HStack(alignment: .top, spacing: 6) {
            Text("LINKED TO:")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: "#C1AA78"))
                .textCase(.uppercase)
                .layoutPriority(1)
            
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: "link")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.zifrGreen)
                
                Text(linkedText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#7D7D7D"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    SharedItemOverrideBanner(resourceId: card.id, defaultCompanyId: card.companyId)

                    if !isNew {
                        ResourceConnectionsSection(
                            reference: ResourceReference(kind: .card, resourceId: card.id)
                        )
                    }

                    Group {
                        if !isInstitutionContext {
                            ZifrSheetCard(title: "FINANCIAL INSTITUTION", icon: "building.columns") {
                                institutionSelectorRow
                            }
                        }

                        // MARK: - Card Details Card
                        ZifrSheetCard(title: "CARD DETAILS", icon: "creditcard") {
                            VStack(spacing: 16) {
                                row1
                                credentialRow
                                row2
                                if card.type.lowercased() != "debit" {
                                    row3
                                    row4
                                }
                                row5
                                paysForRow
                                
                                Button(action: {
                                    showTransactions = true
                                }) {
                                    HStack {
                                        Text("TRANSACTIONS")
                                            .font(.system(size: 14, weight: .bold))
                                            .tracking(0.5)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Image(systemName: "receipt")
                                            .foregroundStyle(Color.white.opacity(0.4))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color(hex: "#2C2C2E"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                                }
                                .buttonStyle(PremiumButtonStyle())
                                .padding(.top, 4)
                            }
                        }

                        // MARK: - Financial Details Card
                        ZifrSheetCard(title: "FINANCIALS", icon: "chart.line.uptrend.xyaxis") {
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    moneyField(label: "BALANCE", value: Binding(get: { card.balance }, set: { card.balance = $0 }))
                                    if card.type == "Credit" {
                                        moneyField(label: "CREDIT LIMIT", value: Binding(get: { card.limit }, set: { card.limit = $0 }))
                                    } else {
                                        Color.clear.frame(maxWidth: .infinity)
                                    }
                                }

                                HStack(spacing: 12) {
                                    moneyField(label: "MO. PAYMENT", value: Binding(get: { card.moPayment }, set: { card.moPayment = $0 }))
                                    Color.clear.frame(maxWidth: .infinity)
                                }

                                if card.type == "Credit" {
                                    HStack(spacing: 12) {
                                        aprField(label: "APR%", value: $card.apr)
                                            .frame(maxWidth: .infinity)
                                        
                                        aprField(label: "PROMO APR%", value: $card.promoApr)
                                            .frame(maxWidth: .infinity)
                                        
                                        datePicker(label: "ENDS", selection: Binding(get: { card.promoEnds ?? Date() }, set: { card.promoEnds = $0 }))
                                    }
                                }
                            }
                        }

                        // MARK: - Notes Card
                        ZifrSheetCard(title: "NOTES", icon: "note.text") {
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("Add notes...", text: Binding(get: { card.notes ?? "" }, set: { card.notes = $0 }), axis: .vertical)
                                    .lineLimit(3...6)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                                    .padding(14)
                                    .background(Color(hex: "#2C2C2E"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                            }
                        }

                        // MARK: - Actions Card
                        if !isNew {
                            ZifrSheetCard(title: "ACTIONS", icon: "slider.horizontal.3") {
                                VStack(spacing: 12) {
                                    // Share Card
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        showShareSheet = true
                                    } label: {
                                        VStack(spacing: 4) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "person.crop.circle.badge.plus")
                                                Text("Share Card")
                                            }
                                            .font(.system(size: 13, weight: .semibold))
                                            Text("Generate a share link for collaborators")
                                                .font(.system(size: 10, weight: .regular))
                                                .foregroundStyle(Color.white.opacity(0.6))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(MiloomSecondaryButtonStyle())
                                }
                            }

                            // ── Unencapsulated Bottom Delete Button ─────
                            Button(role: .destructive) {
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                showDeleteConfirm = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Image(systemName: "trash")
                                    Text("Delete \(card.name.isEmpty ? "Card" : card.name)")
                                    Spacer()
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.red)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .confirmationDialog("Delete Card?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                                Button("Delete Card", role: .destructive) {
                                    let instNameStr = card.institutionName ?? ""
                                    vm.deleteCard(card, appState: appState)
                                    
                                    let remainingCards = cards.filter { ($0.institutionName ?? "").lowercased() == instNameStr.lowercased() && $0.id != card.id }
                                    if let orphanedInst = institutions.first(where: { $0.name.lowercased() == instNameStr.lowercased() }) {
                                        if remainingCards.isEmpty && orphanedInst.accounts.isEmpty {
                                            institutionToDelete = orphanedInst
                                            
                                            // Slight delay so the first sheet closes cleanly before showing second
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                showDeleteInstitutionConfirm = true
                                            }
                                        } else {
                                            dismiss()
                                        }
                                    } else {
                                        dismiss()
                                    }
                                }
                                Button("Cancel", role: .cancel) {}
                            }
                            .alert("Delete Empty Institution?", isPresented: $showDeleteInstitutionConfirm) {
                                Button("Yes, Delete", role: .destructive) {
                                    if let inst = institutionToDelete {
                                        vm.deleteInstitution(inst, appState: appState)
                                    }
                                    dismiss()
                                }
                                Button("No, Keep Institution", role: .cancel) {
                                    dismiss()
                                }
                            } message: {
                                Text("This was the last item for \(institutionToDelete?.name ?? "this institution"). Do you want to delete the institution profile too?")
                            }
                        }
                    } // End Group
                    .disabled(isViewer)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(hex: "#1C1C1E"))
            .sheet(isPresented: $showCardScanner) {
                CardScannerView { result in
                    if let number = result.cardNumber {
                        card.cardNumber = number
                        let filtered = number.filter { $0.isNumber }
                        if let first = filtered.first {
                            if first == "4" { card.network = "Visa" }
                            else if first == "5" { card.network = "Mastercard" }
                            else if first == "3" { card.network = "Amex" }
                            else if first == "6" { card.network = "Discover" }
                        }
                        let maxLen = card.network == "Amex" ? 5 : 4
                        if filtered.count >= maxLen {
                            card.last4 = String(filtered.suffix(maxLen))
                        } else {
                            card.last4 = filtered
                        }
                    }
                    if let expiry = result.expiry {
                        card.expiry = expiry
                    }
                    if let holder = result.cardHolder {
                        card.cardHolder = holder
                    }
                    if let net = result.network {
                        card.network = net
                    }
                }
            }
            .sheet(isPresented: $showTransactions) {
                TransactionFeedView(
                                    accountId: card.plaidAccountId ?? card.id.uuidString,
                                    cardId: card.id,
                                    cardName: card.name,
                                    companyId: card.companyId,
                                    vm: vm
                                )
            }
            .onAppear {
                if isNew {
                    isNewInstitution = institutions.isEmpty
                } else {
                    isNewInstitution = (card.institutionName ?? "").isEmpty || !institutions.contains(where: { $0.name.lowercased() == (card.institutionName ?? "").lowercased() })
                }
                if snapshot == nil { snapshot = currentSnapshot }
            }
            .navigationTitle(customTitle ?? (isNew ? "New Card" : card.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(customTitle ?? (isNew ? "New Card" : card.name))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "#C1AA78"))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isNew { 
                            vm.deleteCard(card, appState: appState) 
                        } else if let snap = snapshot {
                            card.name = snap.name
                            card.login = snap.login
                            card.password = snap.password
                            card.last4 = snap.last4
                            card.network = snap.network
                            card.type = snap.type
                            card.autopay = snap.autopay
                            card.cardHolder = snap.cardHolder
                            card.cardHolderType = snap.cardHolderType
                            card.expiry = snap.expiry
                            card.notes = snap.notes
                            card.balance = snap.balance
                            card.limit = snap.limit
                            card.moPayment = snap.moPayment
                            card.apr = snap.apr
                            card.promoApr = snap.promoApr
                            card.promoEnds = snap.promoEnds
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !isViewer {
                        Button("Save") {
                            card.institutionName = institutionName
                            saveInstitutionData()
                            vm.saveCard(card, appState: appState)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .tint(canSave && isDirty ? .green : nil)
                        .disabled(!canSave)
                    }
                }
            }
            .interactiveDismissDisabled(isNew)
            .sheet(isPresented: $showShareSheet) {
                ShareEntitySheet(resourceId: card.id, resourceType: "card", resourceTitle: card.name.isEmpty ? "Card" : card.name)
            }
            .sheet(isPresented: $showPaymentPicker) {
                NavigationStack {
                    PaymentMethodPickerView(
                        currentMethod: card.paidFrom ?? "",
                        companyId: card.companyId,
                        institutions: institutions,
                        cards: cards
                    ) { _, name in
                        card.paidFrom = name
                    }
                }
            }
        }
    }

    private func datePicker(label: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 44)
        }
    }

    private func aprField(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            HStack(spacing: 4) {
                DoubleField(placeholder: "0.00", value: value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .background(Color(hex: "#2C2C2E"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }

    private func cardPicker(label: String, sel: Binding<String>, opts: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            HStack {
                Picker("", selection: sel) {
                    ForEach(opts, id: \.self) { t in
                        Text(t).tag(t)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(.white)
                
                Spacer()
            }
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .background(Color(hex: "#2C2C2E"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func saveInstitutionData() {
        guard !institutionName.isEmpty else { return }

        if isNewInstitution {
            var newInst = vm.addInstitution(appState: appState, userId: card.userId, companyId: card.companyId)
            newInst.name = institutionName
            newInst.loginUrl = instWebsite
            newInst.username = instLogin
            newInst.password = instPass
            newInst.email = instEmail
            newInst.twoFactor = instTwoFactor
            vm.saveInstitution(newInst, appState: appState)
        } else {
            let instName = institutionName.lowercased()
            if !instName.isEmpty {
                if var existing = institutions.first(where: { $0.name.lowercased() == instName }) {
                    if !instWebsite.isEmpty { existing.loginUrl = instWebsite }
                    if !instLogin.isEmpty { existing.username = instLogin }
                    if !instPass.isEmpty { existing.password = instPass }
                    if !instEmail.isEmpty { existing.email = instEmail }
                    if !instTwoFactor.isEmpty { existing.twoFactor = instTwoFactor }
                    vm.saveInstitution(existing, appState: appState)
                }
            }
        }
    }

    private func moneyField(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.5))
            HStack(spacing: 4) {
                Text("$")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                DoubleField(placeholder: "0.00", value: value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .background(Color(hex: "#2C2C2E"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }

    private var paidFromWithInstitution: String {
        guard let paidFrom = card.paidFrom, !paidFrom.isEmpty else { return "" }
        let normalizedPaidFrom = paidFrom.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Search in cards
        for c in appState.cards {
            if c.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedPaidFrom {
                let instName = (c.institutionName ?? "").isEmpty ? "" : c.institutionName!
                if !instName.isEmpty {
                    return "\(instName) · \(paidFrom)"
                }
            }
        }
        
        // 2. Search in institutions accounts
        for inst in appState.institutions {
            for acc in inst.accounts {
                let accName = acc.name.isEmpty ? acc.type : acc.name
                if accName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedPaidFrom {
                    let instName = inst.name.isEmpty ? "" : inst.name
                    if !instName.isEmpty {
                        return "\(instName) · \(paidFrom)"
                    }
                }
            }
        }
        return paidFrom
    }
}
