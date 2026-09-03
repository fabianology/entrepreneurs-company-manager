import SwiftUI
import CloudKit
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    let company: Company

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowPublic, .allowPrivate, .allowReadOnly, .allowReadWrite]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let parent: CloudSharingView
        init(_ parent: CloudSharingView) { self.parent = parent }

        func itemTitle(for c: UICloudSharingController) -> String? {
            return parent.company.name
        }

        func cloudSharingController(_ c: UICloudSharingController, failedToSaveShareWithError error: Error) {
            AppDiagnostics.failure("sharing", "cloudkit_save_share", error: error)
        }

        func cloudSharingControllerDidSaveShare(_ c: UICloudSharingController) {
            AppDiagnostics.event("sharing", "cloudkit_save_share", status: "success")
        }

        func cloudSharingControllerDidStopSharing(_ c: UICloudSharingController) {
            AppDiagnostics.event("sharing", "cloudkit_stop_share", status: "success")
        }
    }
}
