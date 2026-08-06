import SwiftUI

// TutorialSheetView has been replaced by the spotlight-based tutorial walkthrough.
// The new entry points are:
//   - OnboardingStateManager.startTutorial()  — starts step 1 on the Dashboard
//   - OnboardingStateManager.skipOnboarding() — same as above, called when user skips real onboarding
//
// This file is kept to avoid Xcode project reference errors.
// It can be safely removed from the project target in Xcode.
@available(*, deprecated, renamed: "TutorialSpotlightOverlayView")
struct TutorialSheetView: View {
    var body: some View { EmptyView() }
}
