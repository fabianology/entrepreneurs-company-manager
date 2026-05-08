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
