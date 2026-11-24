import SwiftUI

// MARK: - Custom Swipe to Delete for ScrollView
struct ZifrSwipeToDeleteModifier: ViewModifier {
    let action: () -> Void
    @State private var offset: CGFloat = 0
    
    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            Color.red
                .overlay(alignment: .trailing) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                        .padding(.trailing, 20)
                }
            
            content
                .background(Color(hex: "#2C2C2E"))
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width < 0 {
                                offset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring()) {
                                if value.translation.width < -80 {
                                    action()
                                    offset = 0
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .clipped()
    }
}

// MARK: - Custom Swipe Actions for ScrollView
struct ZifrSwipeActionsModifier: ViewModifier {
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var offset: CGFloat = 0
    
    func body(content: Content) -> some View {
        ZStack {
            // Edit Background (Leading)
            Color.blue
                .overlay(alignment: .leading) {
                    Image(systemName: "pencil")
                        .foregroundColor(.white)
                        .padding(.leading, 20)
                }
                .opacity(offset > 0 ? 1 : 0)
            
            // Delete Background (Trailing)
            Color.red
                .overlay(alignment: .trailing) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                        .padding(.trailing, 20)
                }
                .opacity(offset < 0 ? 1 : 0)
            
            content
                .background(Color(hex: "#2C2C2E"))
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = value.translation.width
                        }
                        .onEnded { value in
                            withAnimation(.spring()) {
                                if value.translation.width < -80 {
                                    onDelete()
                                    offset = 0
                                } else if value.translation.width > 80 {
                                    onEdit()
                                    offset = 0
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .clipped()
    }
}

// MARK: - Message Swipe Actions (Unread / Delete)
struct ZifrMessageSwipeModifier: ViewModifier {
    let onReadToggle: () -> Void
    let onDelete: () -> Void
    let isRead: Bool
    var markReadOnly = false

    private var canSwipeToRead: Bool { !markReadOnly || !isRead }
    @State private var offset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    private let actionWidth: CGFloat = 104
    private let revealThreshold: CGFloat = 52
    private let fullSwipeThreshold: CGFloat = 220
    private let fullSwipeExitOffset: CGFloat = 420
    
    func body(content: Content) -> some View {
        let rawOffset = offset + dragOffset
        let visibleOffset = rawOffset < -actionWidth
            ? max(-fullSwipeExitOffset, rawOffset)
            : min(canSwipeToRead ? actionWidth : 0, max(-actionWidth, rawOffset))

        return ZStack {
            Color.clear
                .overlay(alignment: .leading) {
                    Color(hex: "#315B50").frame(width: max(0, visibleOffset))
                }
                .overlay(alignment: .trailing) {
                    Color(hex: "#7A2E2E").frame(width: max(0, -visibleOffset))
                }
                .allowsHitTesting(false)

            if markReadOnly {
                content
                    .offset(x: visibleOffset)
                    .simultaneousGesture(swipe)
            } else {
                content
                    .offset(x: visibleOffset)
                    .gesture(swipe)
            }
        }
        .overlay(alignment: .leading) {
            if visibleOffset > 0 {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        offset = 0
                    }
                    onReadToggle()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: isRead ? "envelope.badge" : "envelope.open")
                            .font(.system(size: 17, weight: .bold))
                        Text(isRead ? "UNREAD" : "READ")
                            .font(.system(size: 9, weight: .black))
                            .tracking(0.8)
                    }
                    .foregroundStyle(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .mask(alignment: .leading) { Rectangle().frame(width: visibleOffset) }
                .allowsHitTesting(visibleOffset >= actionWidth - 1)
                .accessibilityHidden(visibleOffset < actionWidth - 1)
            }
        }
        .overlay(alignment: .trailing) {
            if visibleOffset < 0 {
                Button {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        offset = 0
                    }
                    onDelete()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 17, weight: .bold))
                        Text("DELETE")
                            .font(.system(size: 9, weight: .black))
                            .tracking(0.8)
                    }
                    .foregroundStyle(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .mask(alignment: .trailing) { Rectangle().frame(width: -visibleOffset) }
                .allowsHitTesting(visibleOffset <= -actionWidth + 1)
                .accessibilityHidden(visibleOffset > -actionWidth + 1)
            }
        }
        .clipShape(.rect(cornerRadius: markReadOnly ? 0 : 24))
        .onChange(of: isRead) { _, read in
            if markReadOnly && read && offset > 0 { offset = 0 }
        }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: markReadOnly ? 22 : 10)
            .updating($dragOffset) { value, state, _ in
                guard isHorizontal(value) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard isHorizontal(value) else { return }
                let projectedOffset = offset + value.predictedEndTranslation.width
                let completedOffset = offset + value.translation.width

                if completedOffset <= -fullSwipeThreshold {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    if markReadOnly {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { offset = 0 }
                        onDelete()
                    } else {
                        withAnimation(.easeIn(duration: 0.16)) { offset = -fullSwipeExitOffset }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { onDelete() }
                    }
                    return
                }

                if markReadOnly && canSwipeToRead && completedOffset >= fullSwipeThreshold {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { offset = 0 }
                    onReadToggle()
                    return
                }

                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    if offset < 0 {
                        offset = value.translation.width > revealThreshold / 2 ? 0 : -actionWidth
                    } else if offset > 0 {
                        offset = value.translation.width < -revealThreshold / 2 ? 0 : actionWidth
                    } else if projectedOffset < -revealThreshold {
                        offset = -actionWidth
                    } else if canSwipeToRead && projectedOffset > revealThreshold {
                        offset = actionWidth
                    } else {
                        offset = 0
                    }
                }
            }
    }

    private func isHorizontal(_ value: DragGesture.Value) -> Bool {
        !markReadOnly || abs(value.translation.width) > abs(value.translation.height) * 1.3
    }

}
