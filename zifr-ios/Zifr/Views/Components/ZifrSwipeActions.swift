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
            : min(actionWidth, max(-actionWidth, rawOffset))

        return ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: "#315B50"))
                .opacity(visibleOffset > 0 ? 1 : 0)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: "#7A2E2E"))
                .opacity(visibleOffset < 0 ? 1 : 0)

            HStack(spacing: 0) {
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
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

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
                }
                .buttonStyle(.plain)
            }
            .opacity(abs(visibleOffset) > 1 ? 1 : 0)
            .allowsHitTesting(abs(visibleOffset) >= actionWidth - 1)
            .accessibilityHidden(abs(visibleOffset) <= 1)
            
            content
                .offset(x: visibleOffset)
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.width
                        }
                        .onEnded { value in
                            let projectedOffset = offset + value.predictedEndTranslation.width
                            let completedOffset = offset + value.translation.width

                            if completedOffset <= -fullSwipeThreshold {
                                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                                withAnimation(.easeIn(duration: 0.16)) {
                                    offset = -fullSwipeExitOffset
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                    onDelete()
                                }
                                return
                            }

                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                if offset < 0 {
                                    offset = value.translation.width > revealThreshold / 2 ? 0 : -actionWidth
                                } else if offset > 0 {
                                    offset = value.translation.width < -revealThreshold / 2 ? 0 : actionWidth
                                } else if projectedOffset < -revealThreshold {
                                    offset = -actionWidth
                                } else if projectedOffset > revealThreshold {
                                    offset = actionWidth
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
