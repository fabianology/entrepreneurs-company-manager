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
    
    struct Snapshot: Equatable {
        var name, lender, term, role, status, interestType, scheduleFrequency, notes: String
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
                    
                    Group {
                        loanSummarySection()
                        
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
                    draft: paymentDraft,
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
        }
    }

    private func loanPicker(label: String, sel: Binding<String>, opts: [String]) -> some View {
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

    @ViewBuilder
    private func loanSummarySection() -> some View {
        let amort = loan.amortization
        ZifrSheetCard(title: "LOAN SUMMARY", icon: "chart.pie.fill") {
            VStack(spacing: 16) {
                // Header Stats
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text((loan.name ?? "").isEmpty ? "Loan" : loan.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text((loan.lender ?? "").isEmpty ? "Lender Unknown" : (loan.lender ?? ""))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(loan.principalAmount.currencyString)
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.white)
                        Text("PRINCIPAL")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
                
                // Progress Bar
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color(hex: "#545454"))
                                .frame(width: geo.size.width * (amort.principalPct / 100))
                            Rectangle()
                                .fill(Color(hex: "#742C2D"))
                        }
                    }
                    .frame(height: 8)
                    .clipShape(Capsule())
                    .background(Color.white.opacity(0.05))
                }
                
                // Stats Grid
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        summaryStatColumn(label: "INTEREST", value: amort.totalInterest.currencyString, width: geo.size.width / 3)
                        summaryStatColumn(label: "TOTAL COST", value: amort.totalCost.currencyString, width: geo.size.width / 3)
                        summaryStatColumn(label: "MO. PAYMENT", value: amort.monthlyPayment.currencyString, width: geo.size.width / 3)
                    }
                }
                .frame(height: 40)
                
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
                                        .foregroundStyle(Color(hex: "#742C2D"))
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
                                                    .foregroundStyle(Color(hex: "#742C2D"))
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

    private func summaryStatColumn(label: String, value: String, width: CGFloat) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .tracking(1)
                .foregroundStyle(Color.white.opacity(0.4))
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: width)
    }

    @ViewBuilder
    private func loanRoleSection() -> some View {
        if !isInstitutionContext {
            CustomSegmentedControl(options: Loan.roles, selection: $loan.role)
            .frame(height: 44)
            .disabled(!isNew)
        }
    }

    @ViewBuilder
    private func loanPrincipalSection() -> some View {
        ZifrSheetCard(title: "LOAN DETAILS", icon: "doc.text") {
            VStack(spacing: 14) {
                if !isInstitutionContext {
                    loanRoleSection()
                        .padding(.bottom, 2)
                }

                HStack(spacing: 12) {
                    ZifrField(
                        label: (!isInstitutionContext && loan.role == "I'm Lending") ? "LENT TO" : "LENDER", 
                        placeholder: (!isInstitutionContext && loan.role == "I'm Lending") ? "e.g. Acme Corp" : "e.g. Chase", 
                        text: Binding(get: { loan.lender ?? "" }, set: { loan.lender = $0 })
                    )
                    ZifrField(
                        label: (!isInstitutionContext && loan.role == "I'm Lending") ? "LOAN NAME" : "LOAN ID", 
                        placeholder: (!isInstitutionContext && loan.role == "I'm Lending") ? "e.g. Bridge Loan" : "e.g. Series A", 
                        text: Binding(get: { loan.name ?? "" }, set: { loan.name = $0 })
                    )
                }
                
                HStack(spacing: 12) {
                    moneyField(label: "PRINCIPAL", value: $loan.principalAmount)
                        .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LOAN TERM")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.45))
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
                
                if loan.role == "I'm Lending" {
                    HStack(spacing: 12) {
                        loanPicker(label: "INTEREST TYPE", sel: $loan.interestType, opts: Loan.interestTypes)
                    }
                }
                
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
                    
                    TextField("Add notes...", text: Binding(get: { loan.notes ?? "" }, set: { loan.notes = $0 }), axis: .vertical)
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
