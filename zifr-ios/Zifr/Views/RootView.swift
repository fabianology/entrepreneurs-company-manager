import SwiftUI

struct RootView: View {
    @State private var vm = AppViewModel()

    var body: some View {
        DashboardView(vm: vm)
            .tint(.white)
    }
}
