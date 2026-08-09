import SwiftUI

struct InstitutionHeightKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct StackedInstitutionDeckView: View {
    let institutions: [Institution]
    let cards: [FinancialCard]
    let loans: [Loan]
    @Bindable var vm: AppViewModel
    let onEditInst: (Institution) -> Void
    let onEditCard: (FinancialCard) -> Void
    let onEditLoan: (Loan) -> Void
    
    @State private var expandedInstId: UUID? = nil
    @State private var poppedCardId: String? = nil
    @State private var pullingUpCardId: String? = nil
    @State private var zIndexCardId: String? = nil
    @State private var institutionHeights: [UUID: CGFloat] = [:]

    // Drag tracking for subscription-style pull animation
    @State private var draggingCardId: UUID? = nil
    @State private var dragOffset: CGFloat = 0
    
    // Collapsed header height — matches subscription card overlap
    private let collapsedHeight: CGFloat = 68
    
    private var totalStackHeight: CGFloat {
        guard !institutions.isEmpty else { return 0 }
        let lastIndex = institutions.count - 1
        let lastInst = institutions[lastIndex]
        let isExpanded = expandedInstId == lastInst.id
        let isBottomMostDefault = expandedInstId == nil
        
        let lastHeight: CGFloat
        if isExpanded || isBottomMostDefault {
            let instCards = cards.filter { ($0.institutionName ?? "").lowercased() == lastInst.name.lowercased() }
            let showPhysicalCards = isExpanded
            let cardPeekHeight: CGFloat = (!showPhysicalCards || instCards.isEmpty) ? 0 : (20.0 + CGFloat(instCards.count - 1) * 40.0 + 16.0)
            lastHeight = (institutionHeights[lastInst.id] ?? collapsedHeight) + cardPeekHeight + 16.0
        } else {
            lastHeight = collapsedHeight
        }
        
        return calculateYOffset(for: lastIndex) + lastHeight
    }

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(Array(institutions.enumerated()), id: \.element.id) { index, inst in
                institutionSlice(index: index, inst: inst)
            }
        }
        .frame(height: totalStackHeight, alignment: .top)
        .padding(.bottom, 120)
        .onPreferenceChange(InstitutionHeightKey.self) { value in
            institutionHeights.merge(value, uniquingKeysWith: { $1 })
        }
    }
    
    // MARK: - Per-Institution Slice
    
    @ViewBuilder
    private func institutionSlice(index: Int, inst: Institution) -> some View {
        let isExpanded = expandedInstId == inst.id
        let isBottomMostDefault = (expandedInstId == nil) && (index == institutions.count - 1)
        let showFullCard = isExpanded || isBottomMostDefault
        let showPhysicalCards = isExpanded
        
        let instCards = cards.filter { ($0.institutionName ?? "").lowercased() == inst.name.lowercased() }
        let instLoans = loans.filter { ($0.lender ?? "").lowercased() == inst.name.lowercased() }
        let yOffset = calculateYOffset(for: index)
        let cardPeekHeight: CGFloat = (!showPhysicalCards || instCards.isEmpty) ? 0 : (20.0 + CGFloat(instCards.count - 1) * 40.0 + 16.0)
        
        ZStack(alignment: .top) {
            if showFullCard {
                expandedInstitution(inst: inst, index: index, instCards: instCards, instLoans: instLoans, cardPeekHeight: cardPeekHeight, showPhysicalCards: showPhysicalCards)
                    .transition(.opacity)
            } else {
                collapsedInstitutionHeader(inst: inst, index: index, instCards: instCards, instLoans: instLoans, isLast: index == institutions.count - 1)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.top, cardPeekHeight)
        .offset(y: yOffset)
        .zIndex(isExpanded ? 100 : Double(index))
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: expandedInstId)
    }
    
    // MARK: - Y-Offset Calculation (including drag offset)
    
    private func calculateYOffset(for index: Int) -> CGFloat {
        var offset: CGFloat = 0
        for i in 0..<index {
            let inst = institutions[i]
            if expandedInstId == inst.id {
                let instCards = cards.filter { ($0.institutionName ?? "").lowercased() == inst.name.lowercased() }
                let cardPeekHeight: CGFloat = instCards.isEmpty ? 0 : (20.0 + CGFloat(instCards.count - 1) * 40.0 + 16.0)
                offset += (institutionHeights[inst.id] ?? collapsedHeight) + cardPeekHeight + 8.0
            } else {
                offset += collapsedHeight
            }
        }

        // Apply live drag offset: cards below move down, dragged card moves with resistance
        if let dragId = draggingCardId,
           let dragIndex = institutions.firstIndex(where: { $0.id == dragId }) {
            if index > dragIndex {
                offset += max(0, dragOffset)
            } else if index == dragIndex {
                offset += dragOffset * 0.3
            }
        }

        return offset
    }

    // MARK: - Drag Gesture Handlers

    private func handleDragChange(value: DragGesture.Value, inst: Institution) {
        draggingCardId = inst.id
        dragOffset = value.translation.height
    }

    private func handleDragEnd(value: DragGesture.Value, index: Int, inst: Institution) {
        let dx = value.translation.width
        let dy = value.translation.height
        let distance = hypot(dx, dy)
        let velocity = value.predictedEndTranslation.height - value.translation.height

        // If distance < 8pt, treated as tap -> handled by .onTapGesture
        if distance < 8 {
            dragOffset = 0
            draggingCardId = nil
            return
        }

        let threshold: CGFloat = 35
        let velocityThreshold: CGFloat = 120

        withAnimation(.spring(response: 0.45, dampingFraction: 0.82, blendDuration: 0)) {
            if dy > 0 && (dy > threshold || velocity > velocityThreshold) {
                // Drag down -> expand card
                if expandedInstId != inst.id {
                    expandedInstId = inst.id
                    poppedCardId = nil
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            } else if dy < 0 && (dy < -threshold || velocity < -velocityThreshold) {
                // Drag up -> collapse card
                if expandedInstId == inst.id {
                    expandedInstId = nil
                    poppedCardId = nil
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } else if index > 0 {
                    let aboveInst = institutions[index - 1]
                    if expandedInstId == aboveInst.id {
                        expandedInstId = nil
                        poppedCardId = nil
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }
            }

            dragOffset = 0
            draggingCardId = nil
        }
    }
    
    // MARK: - Collapsed Header (matches original InstitutionCardView header exactly)
    
    @ViewBuilder
    private func collapsedInstitutionHeader(inst: Institution, index: Int, instCards: [FinancialCard], instLoans: [Loan], isLast: Bool) -> some View {
        let healthColor = institutionHealthColor(inst)
        
        let cardShape = UnevenRoundedRectangle(
            topLeadingRadius: 24,
            bottomLeadingRadius: isLast ? 24 : 0,
            bottomTrailingRadius: isLast ? 24 : 0,
            topTrailingRadius: 24
        )

        return HStack(alignment: .center, spacing: 16) {
            // Logo
            if let loginUrl = inst.loginUrl, !loginUrl.isEmpty {
                FaviconImage(website: loginUrl, size: 40)
                    .frame(width: 56, height: 56)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 56, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    Image(systemName: "building.columns")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.8))
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                // Name with health dot
                Text(inst.name.isEmpty ? "Bank" : inst.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                
                // Counts with pipe separators — exact match
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("\(inst.accounts.count)").foregroundStyle(.white)
                        Text("Accounts").foregroundStyle(Color(hex: "#C1AA78"))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .tracking(0.3)
                    
                    Text("|").font(.system(size: 10)).foregroundStyle(Color.white.opacity(0.2))
                    
                    HStack(spacing: 4) {
                        Text("\(instCards.count)").foregroundStyle(.white)
                        Text("Cards").foregroundStyle(Color(hex: "#C1AA78"))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .tracking(0.3)
                    
                    Text("|").font(.system(size: 10)).foregroundStyle(Color.white.opacity(0.2))
                    
                    HStack(spacing: 4) {
                        Text("\(instLoans.count)").foregroundStyle(.white)
                        Text("Loans").foregroundStyle(Color(hex: "#C1AA78"))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .tracking(0.3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .frame(height: collapsedHeight, alignment: .center)
        .frame(maxWidth: .infinity)
        .frame(height: isLast ? collapsedHeight : collapsedHeight + 80, alignment: .top)
        .background(
            cardShape
                .fill(Color.black.opacity(0.70))
        )
        .clipShape(cardShape)
        .overlay(
            cardShape
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "#3A2D6E"),
                            Color(hex: "#16161E").opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                expandedInstId = inst.id
                poppedCardId = nil
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    handleDragChange(value: value, inst: inst)
                }
                .onEnded { value in
                    handleDragEnd(value: value, index: index, inst: inst)
                }
        )
    }
    
    // MARK: - Expanded Institution
    
    @ViewBuilder
    private func expandedInstitution(inst: Institution, index: Int, instCards: [FinancialCard], instLoans: [Loan], cardPeekHeight: CGFloat, showPhysicalCards: Bool) -> some View {
        // Credit cards fan out above
        if showPhysicalCards {
            cardFanOut(instCards: instCards)
        }
        
        // Full InstitutionCardView
        InstitutionCardView(
            institution: inst,
            totalMonthlyPayment: instLoans.reduce(0) { $0 + $1.monthlyPayment },
            cardCount: instCards.count,
            loanCount: instLoans.count,
            loans: instLoans,
            vm: vm,
            onEdit: { onEditInst(inst) },
            onEditLoan: { onEditLoan($0) }
        )
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: InstitutionHeightKey.self, value: [inst.id: geo.size.height])
            }
        )
        .overlay(alignment: .top) {
            // Drag overlay over top header area for pull expand/collapse
            Color.clear
                .frame(height: collapsedHeight)
                .contentShape(Rectangle())
                .onTapGesture {
                    if expandedInstId == inst.id {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onEditInst(inst)
                    } else {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            expandedInstId = inst.id
                            poppedCardId = nil
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { value in
                            handleDragChange(value: value, inst: inst)
                        }
                        .onEnded { value in
                            handleDragEnd(value: value, index: index, inst: inst)
                        }
                )
        }
        .zIndex(10)
    }
    
    // MARK: - Card Fan-Out
    
    @ViewBuilder
    private func cardFanOut(instCards: [FinancialCard]) -> some View {
        let foremostPeekOffset: CGFloat = 20
        let stackedPeekOffset: CGFloat = 40
        let cardH: CGFloat = 110
        let fullCardH: CGFloat = 210
        
        if !instCards.isEmpty {
            ForEach(Array(instCards.enumerated()), id: \.element.id) { index, card in
                cardFanItem(card: card, index: index, totalCards: instCards.count,
                           foremostPeekOffset: foremostPeekOffset, stackedPeekOffset: stackedPeekOffset,
                           cardH: cardH, fullCardH: fullCardH)
            }
        }
    }
    
    @ViewBuilder
    private func cardFanItem(card: FinancialCard, index: Int, totalCards: Int,
                             foremostPeekOffset: CGFloat, stackedPeekOffset: CGFloat,
                             cardH: CGFloat, fullCardH: CGFloat) -> some View {
        let isPopped = poppedCardId == card.id.uuidString
        let isPulling = pullingUpCardId == card.id.uuidString
        let isFront = zIndexCardId == card.id.uuidString
        
        let yOffset = isPopped ? 16.0 : (isPulling ? -140.0 : -(foremostPeekOffset + CGFloat(index) * stackedPeekOffset))
        let scale = (isPopped || isPulling) ? 1.02 : max(0.88, 1.0 - CGFloat(index) * 0.03)
        let rotationAngle: Double = isPopped ? 0 : (isPulling ? -1.0 : -4 - Double(index) * 1.5)
        let shadowRadius: CGFloat = (isPopped || isPulling) ? 20 : 4
        let shadowOpacity: Double = (isPopped || isPulling) ? 0.5 : 0.15
        let zIndex = (isPopped || isFront) ? 25.0 : Double(totalCards - index)
        
        FinancialCardVisual(card: card, isPopped: isPopped)
            .id(card.id)
            .frame(height: isPopped ? fullCardH : cardH)
            .scaleEffect(scale, anchor: .bottom)
            .rotation3DEffect(
                .degrees(rotationAngle),
                axis: (x: 1, y: 0, z: 0),
                anchor: .bottom,
                perspective: 0.3
            )
            .offset(y: yOffset)
            .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, y: isPopped ? 12 : 2)
            .zIndex(zIndex)
            .transition(.asymmetric(
                insertion: AnyTransition.offset(y: 80)
                    .combined(with: .scale(scale: 0.9))
                    .combined(with: .opacity)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.07)),
                removal: AnyTransition.offset(y: 80)
                    .combined(with: .scale(scale: 0.9))
                    .combined(with: .opacity)
                    .animation(.spring(response: 0.4, dampingFraction: 0.9))
            ))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: poppedCardId)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: pullingUpCardId)
            .onTapGesture {
                togglePop(for: card.id.uuidString)
            }
            .onLongPressGesture {
                onEditCard(card)
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 10)
                    .onEnded { value in
                        if isPopped && value.translation.height < -10 {
                            togglePop(for: card.id.uuidString)
                        }
                    },
                including: isPopped ? .gesture : .none
            )
    }
    
    // MARK: - Helpers
    
    private func institutionHealthColor(_ inst: Institution) -> Color {
        if inst.isDisconnected { return .red }
        if inst.accounts.contains(where: { $0.status != "Active" }) { return .orange }
        return .zifrGreen
    }
    
    private func togglePop(for cardId: String) {
        if poppedCardId == cardId {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                pullingUpCardId = cardId
                poppedCardId = nil
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if pullingUpCardId == cardId {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        pullingUpCardId = nil
                        zIndexCardId = nil
                    }
                }
            }
        } else {
            let oldPoppedId = poppedCardId
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            
            if let oldId = oldPoppedId {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    pullingUpCardId = cardId
                    poppedCardId = nil
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    if pullingUpCardId == cardId {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            poppedCardId = cardId
                            zIndexCardId = cardId
                            pullingUpCardId = nil
                        }
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    if zIndexCardId == oldId {
                        zIndexCardId = nil
                    }
                }
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    pullingUpCardId = cardId
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    if pullingUpCardId == cardId {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            poppedCardId = cardId
                            zIndexCardId = cardId
                            pullingUpCardId = nil
                        }
                    }
                }
            }
        }
    }
}
