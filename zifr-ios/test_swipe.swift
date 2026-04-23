import SwiftUI

struct TestSwipe: View {
    var body: some View {
        ScrollView {
            VStack {
                Text("Header")
                List {
                    ForEach(0..<5) { i in
                        Text("Item \(i)")
                            .swipeActions {
                                Button("Delete") {}
                            }
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: 200)
            }
        }
    }
}
