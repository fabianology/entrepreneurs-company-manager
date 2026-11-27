import SwiftUI

struct StackedInstitutionDeckView: View {
    let institutions: [Institution]
    let cards: [FinancialCard]
    let loans: [Loan]
    @Environment(AppState.self) private var appState
    @Bindable var vm: AppViewModel
    var editableInstitutionIDs: Set<UUID> = []
    var editableCardIDs: Set<UUID> = []
    var editableLoanIDs: Set<UUID> = []
    var canAccessCredentials: Bool = true
    var fitsCompactWidth = false
    let onEditInst: (Institution) -> Void
    let onEditCard: (FinancialCard) -> Void
    let onEditLoan: (Loan) -> Void
    
    @State private var expandedInstId: UUID? = nil
    @State private var poppedCardId: String? = nil
    @State private var pullingUpCardId: String? = nil
    @State private var zIndexCardId: String? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Drag tracking for subscription-style pull animation
    @State private var draggingCardId: UUID? = nil
    @State private var dragOffset: CGFloat = 0
    
    private let dragCommitDistance: CGFloat = 24
    private let projectedDragCommitDistance: CGFloat = 64
    private let maximumDragPreview: CGFloat = 28
    
    private var relationships: InstitutionRelationships {
        InstitutionRelationships(institutions: institutions, cards: cards, loans: loans,
            connections: appState.resourceConnections, companyOverrides: appState.localCompanyOverrides)
    }

    private func associatedCards(for institution: Institution) -> [FinancialCard] {
        let resolved = relationships
        return cards.filter { resolved.banks(for: .card, id: $0.id).contains(institution.id) }
    }

    private func associatedLoans(for institution: Institution) -> [Loan] {
        let resolved = relationships
        return loans.filter { resolved.banks(for: .loan, id: $0.id).contains(institution.id) }
    }

    var body: some View {
        let expandedIndex = institutions.firstIndex { $0.id == expandedInstId }
        let walletCount = expandedIndex.map { associatedCards(for: institutions[$0]).count } ?? 0
        let walletHeight: CGFloat = walletCount > 0 ? 36 + CGFloat(walletCount - 1) * 40 : 0

        VStack(spacing: 0) {
            ForEach(Array(institutions.enumerated()), id: \.element.id) { index, inst in
                institutionSlice(index: index, inst: inst,
                                 peekHeight: index == expandedIndex ? walletHeight : 0,
                                 nextPeekHeight: index + 1 == expandedIndex ? walletHeight : 0)
            }
        }
        .padding(.bottom, 20)
        .onAppear {
            setSingleInstitutionDefaultIfNeeded()
        }
        .onChange(of: institutions.map(\.id)) { previousInstitutionIds, institutionIds in
            if institutionIds.count == 1 {
                if expandedInstId != institutionIds[0] {
                    setExpandedInstitutionWithoutAnimation(institutionIds[0])
                }
            } else if institutionIds.count > previousInstitutionIds.count {
                poppedCardId = nil
                setExpandedInstitutionWithoutAnimation(nil)
            } else if let expandedInstId, !institutionIds.contains(expandedInstId) {
                self.expandedInstId = nil
            }
        }
    }

    private func setSingleInstitutionDefaultIfNeeded() {
        guard institutions.count == 1, expandedInstId == nil else { return }
        setExpandedInstitutionWithoutAnimation(institutions[0].id)
    }

    private func setExpandedInstitutionWithoutAnimation(_ institutionId: UUID?) {
        var transaction = SwiftUI.Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            expandedInstId = institutionId
        }
    }
    
    // MARK: - Per-Institution Slice
    
    @ViewBuilder
    private func institutionSlice(index: Int, inst: Institution, peekHeight: CGFloat, nextPeekHeight: CGFloat) -> some View {
        let isExpanded = expandedInstId == inst.id
        let isBottomMostDefault = (expandedInstId == nil) && (index == institutions.count - 1)
        let showFullCard = isExpanded || isBottomMostDefault
        let isLast = index == institutions.count - 1
        let instCards = associatedCards(for: inst)
        let instLoans = associatedLoans(for: inst)
        // Carry the preceding face behind the whole wallet slot and the following rounded corners.
        let underlap: CGFloat = !showFullCard && !isLast ? nextPeekHeight + 24 : 0

        ZStack(alignment: .top) {
            if isExpanded {
                cardFanOut(instCards: instCards)
            }
            InstitutionCardView(
                institution: inst,
                totalMonthlyPayment: instLoans.reduce(0) { $0 + $1.monthlyPayment },
                cardCount: instCards.count, loanCount: instLoans.count, loans: instLoans,
                vm: vm, onEdit: { onEditInst(inst) }, onEditLoan: { onEditLoan($0) },
                canEdit: editableInstitutionIDs.contains(inst.id), editableLoanIDs: editableLoanIDs,
                canAccessCredentials: canAccessCredentials, fitsCompactWidth: fitsCompactWidth,
                showsBody: showFullCard, underlap: underlap,
                isExpanded: isExpanded,
                onCollapse: {
                    withAnimation(reduceMotion ? nil : .cardDeckReveal) {
                        expandedInstId = isExpanded ? nil : inst.id
                        poppedCardId = nil
                    }
                },
                onDragChanged: { handleDragChange(value: $0, inst: inst) },
                onDragEnded: { handleDragEnd(value: $0, index: index, inst: inst) }
            )
            .layoutPriority(1)
            .zIndex(10)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.top, peekHeight)
        .padding(.bottom, isExpanded && !isLast ? 8 : 0)
        .offset(y: dragPreviewOffset(for: index))
        .zIndex(isExpanded && zIndexCardId != nil ? Double(institutions.count) : Double(index))
    }

    private func dragPreviewOffset(for index: Int) -> CGFloat {
        guard let draggingCardId, let dragged = institutions.firstIndex(where: { $0.id == draggingCardId })
        else { return 0 }
        if index == dragged { return dragOffset * 0.3 }
        return index > dragged ? max(0, dragOffset) : 0
    }

    // MARK: - Drag Gesture Handlers

    private func handleDragChange(value: DragGesture.Value, inst: Institution) {
        guard abs(value.translation.height) > abs(value.translation.width) else { return }
        draggingCardId = inst.id
        dragOffset = limitedDragPreview(for: value.translation.height)
    }

    private func handleDragEnd(value: DragGesture.Value, index: Int, inst: Institution) {
        let dx = value.translation.width
        let dy = value.translation.height
        let distance = hypot(dx, dy)
        let projectedDy = value.predictedEndTranslation.height

        // If distance < 8pt, treated as tap -> handled by .onTapGesture
        if distance < 8 {
            dragOffset = 0
            draggingCardId = nil
            return
        }

        guard abs(dy) > abs(dx) else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                dragOffset = 0
                draggingCardId = nil
            }
            return
        }

        withAnimation(reduceMotion ? nil : .cardDeckReveal) {
            if dy > 0 && (dy > dragCommitDistance || projectedDy > projectedDragCommitDistance) {
                // Drag down -> expand card
                if expandedInstId != inst.id {
                    expandedInstId = inst.id
                    poppedCardId = nil
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            } else if dy < 0 && (dy < -dragCommitDistance || projectedDy < -projectedDragCommitDistance) {
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

    /// Gives the deck a short, rubber-banded preview without allowing the
    /// user's finger to pull an unlimited amount of empty space into the stack.
    private func limitedDragPreview(for translation: CGFloat) -> CGFloat {
        let direction: CGFloat = translation < 0 ? -1 : 1
        let magnitude = abs(translation)
        let resistedMagnitude = maximumDragPreview * (1 - exp(-magnitude / 28))
        return direction * min(resistedMagnitude, maximumDragPreview)
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
        let scale = (isPopped || isPulling) ? 1.0 : max(0.88, 1.0 - CGFloat(index) * 0.03)
        let rotationAngle: Double = isPopped ? 0 : (isPulling ? -1.0 : -4 - Double(index) * 1.5)
        let shadowRadius: CGFloat = (isPopped || isPulling) ? 20 : 4
        let shadowOpacity: Double = (isPopped || isPulling) ? 0.5 : 0.15
        let zIndex = (isPopped || isFront) ? 25.0 : Double(totalCards - index)
        
        FinancialCardVisual(card: card, isPopped: isPopped, canAccessCredentials: canAccessCredentials)
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
            .transition(.offset(y: 20).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: poppedCardId)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: pullingUpCardId)
            .onTapGesture {
                togglePop(for: card.id.uuidString)
            }
            .onLongPressGesture {
                if editableCardIDs.contains(card.id) { onEditCard(card) }
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
