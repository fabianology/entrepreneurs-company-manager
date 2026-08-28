import SwiftUI
import SwiftData

// MARK: - Edit Loan Sheet
struct EditLoanSheet: View {
    @State var loan: Loan
    @Bindable var vm: AppViewModel
    let isNew: Bool
    let institutions: [Institution]
    let cards: [FinancialCard]
    var isInstitutionContext: Bool = false
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var showShareSheet = false
    
    private var isViewer: Bool {
        let share = appState.resourceShares.first(where: { $0.resourceId == loan.id || $0.resourceId == loan.companyId })
        return share?.role == "Viewer"
    }
    
    private var isConnectedToInstitution: Bool {
        if isInstitutionContext { return true }
        guard let lender = loan.lender?.trimmingCharacters(in: .whitespaces).lowercased(), !lender.isEmpty else { return false }
        return institutions.contains { ($0.name ?? "").trimmingCharacters(in: .whitespaces).lowercased() == lender }
    }
    
    struct Snapshot: Equatable {
        var name, lender, borrower, term, role, status, interestType, scheduleFrequency, notes: String
        var principalAmount, remainingBalance, monthlyPayment, interestRate: Double
        var termYears, termMonths: Int
        var startDate: Date
        var maturityDate, paidOffDate: Date?
    }
    @State private var snapshot: Snapshot?
    @State private var showAmortizationTable = false
    @State private var isAutoUpdating = false
    @State private var showTermPicker = false
    @State private var showPaymentHUD = false
    @State private var paymentDraft = LoanPayment(id: UUID(), userId: UUID(), loanId: UUID(), date: Date(), amount: 0.0)
    @State private var editingPaymentId: String? = nil

    private var currentSnapshot: Snapshot {
        Snapshot(
            name: loan.name ?? "",
            lender: loan.lender ?? "",
            borrower: loan.borrower ?? "",
            term: loan.term,
            role: loan.role,
            status: loan.status,
            interestType: loan.interestType,
            scheduleFrequency: loan.scheduleFrequency,
            notes: loan.notes ?? "",
            principalAmount: loan.principalAmount,
            remainingBalance: loan.remainingBalance,
            monthlyPayment: loan.monthlyPayment,
            interestRate: loan.interestRate,
            termYears: loan.termYears,
            termMonths: loan.termMonths,
            startDate: loan.startDate,
            maturityDate: loan.maturityDate,
            paidOffDate: loan.paidOffDate
        )
    }

    private var isDirty: Bool {
        guard let snap = snapshot else { return isNew && !loan.name.trimmingCharacters(in: .whitespaces).isEmpty }
        return snap != currentSnapshot
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    SharedItemOverrideBanner(resourceId: loan.id, defaultCompanyId: loan.companyId)

                    if !isNew {
                        ResourceConnectionsSection(
                            reference: ResourceReference(kind: .loan, resourceId: loan.id)
                        )
                    }
                    
                    Group {
                        loanSummarySection()
                        
                        // ── Green Add Payment Button (Standalone Loans Only) ──
                        if !isConnectedToInstitution {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                editingPaymentId = nil
                                paymentDraft = LoanPayment(id: UUID(), userId: loan.userId, loanId: loan.id, date: Date(), amount: 0, source: "")
                                showPaymentHUD = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                    Text("Add Payment")
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#166A4E"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PremiumButtonStyle())
                        }
                        
                        loanPrincipalSection()
                        
                        LoanPaymentsLedgerView(
                            loan: $loan,
                            editingPaymentId: $editingPaymentId,
                            paymentDraft: $paymentDraft,
                            showPaymentHUD: $showPaymentHUD
                        )

                        // MARK: - Actions Card
                        if !isNew {
                            ZifrSheetCard(title: "ACTIONS", icon: "slider.horizontal.3") {
                                VStack(spacing: 12) {
                                    // Share Loan
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        showShareSheet = true
                                    } label: {
                                        VStack(spacing: 4) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "person.crop.circle.badge.plus")
                                                Text("Share Loan")
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
                                    Text("Delete \((loan.name ?? "").isEmpty ? "Loan" : loan.name)")
                                    Spacer()
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.red)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .confirmationDialog("Delete Loan?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                                Button("Delete Loan", role: .destructive) {
                                    vm.deleteLoan(loan, appState: appState)
                                    dismiss()
                                }
                                Button("Cancel", role: .cancel) {}
                            }
                        }
                    } // Close Group
                    .disabled(isViewer)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(hex: "#1C1C1E"))
            .onAppear {
                if loan.role.isEmpty || loan.role == "Bank Loan" || loan.role == "I'm Lending" || loan.role == "Lender" {
                    loan.role = "Borrower"
                }
                if (isNew && loan.remainingBalance == 0 && loan.principalAmount > 0) || (loan.remainingBalance == 0 && !(loan.payments ?? []).isEmpty) {
                    loan.recalculateBalance()
                }
                snapshot = currentSnapshot
            }
            .navigationTitle(isNew ? "New Loan" : loan.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(isNew ? "New Loan" : loan.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "#C1AA78"))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isNew { 
                            vm.deleteLoan(loan, appState: appState) 
                        } else if let snap = snapshot {
                            loan.name = snap.name
                            loan.lender = snap.lender
                            loan.borrower = snap.borrower
                            loan.role = snap.role
                            loan.status = snap.status
                            loan.interestType = snap.interestType
                            loan.scheduleFrequency = snap.scheduleFrequency
                            loan.principalAmount = snap.principalAmount
                            loan.remainingBalance = snap.remainingBalance
                            loan.monthlyPayment = snap.monthlyPayment
                            loan.interestRate = snap.interestRate
                            loan.termYears = snap.termYears
                            loan.termMonths = snap.termMonths
                            loan.startDate = snap.startDate
                            loan.maturityDate = snap.maturityDate
                            loan.paidOffDate = snap.paidOffDate
                            loan.notes = snap.notes
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !isViewer {
                        Button("Save") {
                            vm.saveLoan(loan, appState: appState)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .tint(isDirty ? .green : nil)
                    }
                }
            }
            .interactiveDismissDisabled(isNew)
            .sheet(isPresented: $showShareSheet) {
                ShareEntitySheet(resourceId: loan.id, resourceType: "loan", resourceTitle: loan.name.isEmpty ? "Loan" : loan.name)
            }
            .sheet(isPresented: $showTermPicker) {
                NavigationStack {
                    HStack(spacing: 0) {
                        Picker("Years", selection: $loan.termYears) {
                            ForEach(0...30, id: \.self) { year in
                                let yStr = year == 1 ? "Year" : "Years"
                                Text("\(year) \(yStr)").tag(year)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .onChange(of: loan.termYears) { _, _ in updateMaturityDate() }
                        
                        Picker("Months", selection: $loan.termMonths) {
                            ForEach(0...11, id: \.self) { month in
                                let s = month == 1 ? "Month" : "Months"
                                Text("\(month) \(s)").tag(month)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .onChange(of: loan.termMonths) { _, _ in updateMaturityDate() }
                    }
                    .navigationTitle("Loan Term")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showTermPicker = false }
                        }
                    }
                }
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showPaymentHUD) {
                LoanPaymentHUD(
                    draft: $paymentDraft,
                    isNew: editingPaymentId == nil,
                    institutions: institutions,
                    cards: cards,
                    onSave: {
                        var idToFind: UUID? = nil
                        if let eId = editingPaymentId { idToFind = UUID(uuidString: eId) }
                        if let pId = idToFind, let idx = loan.payments?.firstIndex(where: { $0.id == pId }) {
                            loan.payments?[idx].date = paymentDraft.date
                            loan.payments?[idx].amount = paymentDraft.amount
                            loan.payments?[idx].source = paymentDraft.source
                        } else {
                            if loan.payments == nil { loan.payments = [] }
                            loan.payments?.append(paymentDraft)
                        }
                        loan.recalculateBalance()
                        showPaymentHUD = false
                        editingPaymentId = nil
                    },
                    onCancel: {
                        showPaymentHUD = false
                        editingPaymentId = nil
                    }
                )
                .presentationDetents([.fraction(0.70), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
            .onChange(of: loan.principalAmount) { _, _ in
                loan.recalculateBalance()
            }
            .onChange(of: loan.interestRate) { _, _ in
                loan.recalculateBalance()
            }
            .onChange(of: loan.interestType) { _, _ in
                loan.recalculateBalance()
            }
        }
    }

    private func loanPicker(label: String, sel: Binding<String>, opts: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
                .textCase(.uppercase)
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

    private func datePicker(label: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
                .textCase(.uppercase)
            
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
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
                .textCase(.uppercase)
            HStack(spacing: 4) {
                if loan.interestType == "Fixed" {
                    Text("$")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                DoubleField(placeholder: loan.interestType == "Fixed" ? "0" : "0.00", value: value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                if loan.interestType != "Fixed" {
                    Text("%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .background(Color(hex: "#2C2C2E"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }

    private func moneyField(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
                .textCase(.uppercase)
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

    @ViewBuilder
    private func loanSummarySection() -> some View {
        let amort = loan.amortization
        ZifrSheetCard(title: "LOAN SUMMARY", icon: "chart.pie.fill") {
            VStack(alignment: .leading, spacing: 16) {
                // ── HEADER: Hero Identity & Key Balance ───────────────
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Loan Name
                        Text((loan.name ?? "").isEmpty ? "Loan" : loan.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        // Counterparty (Borrower)
                        let borrowerName = (loan.borrower ?? "").isEmpty ? (loan.lender ?? "") : (loan.borrower ?? "")
                        let counterparty = borrowerName.isEmpty ? "—" : borrowerName
                        HStack(spacing: 4) {
                            Text("BORROWER")
                                .zifrLabel()
                                .foregroundStyle(Color(hex: "#C1AA78"))
                            
                            Text(counterparty)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.75))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer(minLength: 12)
                    
                    // Right: Prominent Balance Display with LOAN AMOUNT & numerical value
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(loan.remainingBalance.currencyString)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(hex: "#C1AA78"))
                            .monospacedDigit()
                        
                        HStack(spacing: 4) {
                            Text("LOAN AMOUNT")
                                .zifrLabel()
                            Text(amort.totalPrincipal.currencyString)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.75))
                        }
                    }
                }

                // ── PROGRESS TELEMETRY: Status Bar & Payoff % ──────────
                VStack(spacing: 6) {
                    // Payoff Track: App Background Green (#166A4E) & Luminous Solid Gold (#C1AA78)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track (App background green #166A4E)
                            Capsule()
                                .fill(Color(hex: "#166A4E"))
                            
                            // Fill (Solid Gold)
                            Capsule()
                                .fill(Color(hex: "#C1AA78"))
                                .frame(width: max(0, min(geo.size.width, geo.size.width * loan.progressPercent)))
                        }
                    }
                    .frame(height: 7)

                    // Micro-Telemetry Labels
                    HStack {
                        Spacer()
                        let pctText = String(format: "%.0f%% PAID OFF", loan.progressPercent * 100)
                        Text(pctText)
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(Color(hex: "#C1AA78"))
                    }
                }

                // ── TELEMETRY COCKPIT: Recessed Data Pod ───────────────
                HStack(spacing: 0) {
                    let rateStr = loan.interestType == "Fixed" ? "\(loan.interestRate.currencyString)" : String(format: loan.interestRate.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f%%" : "%.2f%%", loan.interestRate)
                    summaryPodItem(label: "RATE", value: rateStr)
                    
                    summaryPodDivider
                    
                    let freqLabel = loan.scheduleFrequency == "Weekly" ? "WK PMT" : (loan.scheduleFrequency == "Yearly" ? "YR PMT" : (loan.scheduleFrequency == "N/A" ? "PMT" : "MO PMT"))
                    let pmtVal = loan.scheduleFrequency == "N/A" ? "N/A" : amort.monthlyPayment.currencyString
                    summaryPodItem(label: freqLabel, value: pmtVal)
                    
                    summaryPodDivider
                    
                    summaryPodItem(label: "INTEREST", value: amort.totalInterest.currencyString)
                    
                    summaryPodDivider
                    
                    summaryPodItem(label: "TOTAL COST", value: amort.totalCost.currencyString)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .background(Color.black.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
                )

                // ── FOOTER: Timeline Strip ─────────────────────────────
                HStack {
                    HStack(spacing: 4) {
                        Text("START").zifrLabel()
                        Text(loan.startDate.numericDisplay)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("MATURITY").zifrLabel()
                        Text(loan.maturityDate?.numericDisplay ?? "—")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(.horizontal, 4)

                // ── AMORTIZATION SCHEDULE (Expandable) ─────────────────
                if !amort.schedule.isEmpty {
                    VStack(spacing: 12) {
                        Divider().background(Color.white.opacity(0.05))
                            .padding(.vertical, 2)
                            
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showAmortizationTable.toggle()
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text(showAmortizationTable ? "Hide Schedule" : "Amortization Schedule")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.6))
                                    .textCase(.uppercase)
                                    .tracking(1.5)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.6))
                                    .rotationEffect(.degrees(showAmortizationTable ? 180 : 0))
                                Spacer()
                            }
                            .frame(height: 36)
                            .background(Color.white.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        
                        if showAmortizationTable {
                            VStack(spacing: 0) {
                                HStack {
                                    Text(loan.scheduleFrequency == "Weekly" ? "WK" : (loan.scheduleFrequency == "Yearly" ? "YR" : "MO"))
                                        .frame(width: 30, alignment: .leading)
                                    Text("PMT")
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    Text("PRIN")
                                        .foregroundStyle(Color.white.opacity(0.5))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    Text("INT")
                                        .foregroundStyle(Color.zifrBG)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    Text("BAL")
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.4))
                                .textCase(.uppercase)
                                .tracking(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(hex: "#1C1C1E"))
                                
                                Divider().background(Color.white.opacity(0.05))
                                
                                ScrollView {
                                    VStack(spacing: 0) {
                                        ForEach(amort.schedule) { row in
                                            HStack {
                                                Text("\(row.month)")
                                                    .foregroundStyle(Color.white.opacity(0.5))
                                                    .frame(width: 30, alignment: .leading)
                                                Text("$\(Int(round(row.payment)))")
                                                    .foregroundStyle(Color.white.opacity(0.9))
                                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                                Text("$\(Int(round(row.principal)))")
                                                    .foregroundStyle(Color.white.opacity(0.7))
                                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                                Text("$\(Int(round(row.interest)))")
                                                    .foregroundStyle(Color.zifrBG)
                                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                                Text("$\(Int(round(row.balance)))")
                                                    .foregroundStyle(Color.white)
                                                    .fontWeight(.bold)
                                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                            }
                                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            
                                            if row.month != amort.schedule.last?.month {
                                                Divider().background(Color.white.opacity(0.03))
                                            }
                                        }
                                    }
                                }
                                .frame(maxHeight: 250)
                                .background(Color.black.opacity(0.2))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.03), lineWidth: 1))
                        }
                    }
                }
            }
        }
    }

    private func summaryPodItem(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .tracking(1)
                .foregroundStyle(Color.white.opacity(0.35))
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var summaryPodDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(width: 1, height: 22)
    }

    @ViewBuilder
    private func loanPrincipalSection() -> some View {
        ZifrSheetCard(title: "LOAN DETAILS", icon: "doc.text") {
            VStack(spacing: 14) {
                // Row 1: BORROWER & LENDER
                HStack(spacing: 12) {
                    ZifrField(
                        label: "BORROWER", 
                        placeholder: "e.g. Acme Corp", 
                        text: Binding(get: { loan.borrower ?? "" }, set: { loan.borrower = $0 })
                    )
                    ZifrField(
                        label: "LENDER", 
                        placeholder: "e.g. Chase", 
                        text: Binding(get: { loan.lender ?? "" }, set: { loan.lender = $0 })
                    )
                }
                
                // Row 2: LOAN AMOUNT & LOAN NAME
                HStack(spacing: 12) {
                    moneyField(label: "LOAN AMOUNT", value: $loan.principalAmount)
                        .frame(maxWidth: .infinity)
                    
                    ZifrField(
                        label: "LOAN NAME", 
                        placeholder: "e.g. Bridge Loan", 
                        text: Binding(get: { loan.name }, set: { loan.name = $0 })
                    )
                    .frame(maxWidth: .infinity)
                }
                
                // Row 3: INTEREST TYPE & LOAN TERM
                HStack(spacing: 12) {
                    loanPicker(label: "INTEREST TYPE", sel: $loan.interestType, opts: Loan.interestTypes)
                        .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LOAN TERM")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.45))
                            .textCase(.uppercase)
                        Button {
                            showTermPicker = true
                        } label: {
                            HStack {
                                let yStr = loan.termYears == 1 ? "Yr" : "Yrs"
                                let mStr = loan.termMonths == 1 ? "Mo" : "Mos"
                                Text("\(loan.termYears) \(yStr), \(loan.termMonths) \(mStr)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 44)
                            .background(Color(hex: "#2C2C2E"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Row 4: APR / FIXED FEE & PAYMENT FREQUENCY
                HStack(spacing: 12) {
                    aprField(label: loan.interestType == "Fixed" ? "FIXED FEE" : "YR APR", value: $loan.interestRate)
                    loanPicker(label: "PAYMENT FREQUENCY", sel: $loan.scheduleFrequency, opts: Loan.frequencies)
                }
                
                HStack(spacing: 12) {
                    datePicker(label: "START DATE", selection: $loan.startDate)
                        .onChange(of: loan.startDate) { _, _ in updateMaturityDate() }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MATURITY")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.45))
                        
                        if let selection = Binding($loan.maturityDate) {
                            DatePicker("", selection: selection, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 44)
                                .onChange(of: loan.maturityDate) { _, _ in updateTerm() }
                        } else {
                            Button {
                                loan.maturityDate = Date()
                            } label: {
                                Text("Set Date")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.zifrGold)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("LOAN NOTES")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.45))
                    
                    TextField("Add notes...", text: Binding(
                        get: {
                            (loan.notes ?? "").replacingOccurrences(of: "\\[Borrower: [^\\]]+\\]\\n?", with: "", options: .regularExpression)
                        },
                        set: { newNotes in
                            let bTag = loan.borrower.map { "[Borrower: \($0)]\n" } ?? ""
                            loan.notes = bTag + newNotes
                        }
                    ), axis: .vertical)
                        .lineLimit(3...6)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(Color(hex: "#2C2C2E"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                }
                .padding(.top, 2)
            }
        }
    }

        
    private func updateMaturityDate() {
        if isAutoUpdating { return }
        var dateComponent = DateComponents()
        dateComponent.year = loan.termYears
        dateComponent.month = loan.termMonths
        if let newDate = Calendar.current.date(byAdding: dateComponent, to: loan.startDate) {
            if let current = loan.maturityDate, Calendar.current.isDate(current, inSameDayAs: newDate) { return }
            isAutoUpdating = true
            loan.maturityDate = newDate
            DispatchQueue.main.async { isAutoUpdating = false }
        }
    }

    private func updateTerm() {
        if isAutoUpdating { return }
        guard let maturity = loan.maturityDate else { return }
        let components = Calendar.current.dateComponents([.year, .month], from: loan.startDate, to: maturity)
        let y = min(max(components.year ?? 0, 0), 30)
        let m = min(max(components.month ?? 0, 0), 11)
        if loan.termYears == y && loan.termMonths == m { return }
        
        isAutoUpdating = true
        loan.termYears = y
        loan.termMonths = m
        DispatchQueue.main.async { isAutoUpdating = false }
    }
}
