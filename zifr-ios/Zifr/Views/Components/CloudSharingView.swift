import SwiftUI
import CloudKit
import SwiftData

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
            print("Failed to save share: \(error)")
        }

        func cloudSharingControllerDidSaveShare(_ c: UICloudSharingController) {
            print("Share saved successfully")
        }

        func cloudSharingControllerDidStopSharing(_ c: UICloudSharingController) {
            print("Stopped sharing")
        }
    }
}
