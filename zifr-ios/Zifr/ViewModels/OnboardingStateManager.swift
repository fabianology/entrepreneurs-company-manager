import Foundation
import SwiftUI
import Observation

enum OnboardingStep: String, Codable {
    // Real first-run onboarding
    case notStarted
    case needsEntity
    case needsBank
    case needsReview
    case needsNotes
    case needsCommandCenterQuickAdd
    case needsCommandCenterFinancialsHeader
    case needsCommandCenterFinancialsAccounts
    case needsCommandCenterFinancialsReport
    case needsCommandCenterSubscriptions
    case needsCommandCenterDocuments
    case needsAssistant
    case completed
    case skipped

    // Tutorial walkthrough steps
    case tutorialEntityCard
    case tutorialQuickActions
    case tutorialSearch
    case tutorialAssistant
    case tutorialFinancial
    case tutorialSubscriptions
    case tutorialSwipeHint
    case tutorialDone
}

@Observable
final class OnboardingStateManager {
    var currentStep: OnboardingStep {
        didSet {
            UserDefaults.standard.set(currentStep.rawValue, forKey: "onboardingStep")
        }
    }

    /// True once the tutorial has been started at least once — used to show the
    /// blurred dummy card after tutorial completion instead of the un-blurred one.
    var tutorialHasBeenRun: Bool {
        didSet {
            UserDefaults.standard.set(tutorialHasBeenRun, forKey: "tutorialHasBeenRun")
        }
    }

    // MARK: - Real Onboarding Spotlights

    var isSpotlightingEntity: Bool {
        currentStep == .needsEntity
    }

    var isSpotlightingBank: Bool {
        currentStep == .needsBank
    }

    var isSpotlightingReview: Bool {
        currentStep == .needsReview
    }

    var isSpotlightingNotes: Bool {
        currentStep == .needsNotes
    }

    var isSpotlightingCommandCenterQuickAdd: Bool {
        currentStep == .needsCommandCenterQuickAdd
    }

    var isSpotlightingCommandCenterFinancialsHeader: Bool {
        currentStep == .needsCommandCenterFinancialsHeader
    }

    var isSpotlightingCommandCenterFinancialsAccounts: Bool {
        currentStep == .needsCommandCenterFinancialsAccounts
    }

    var isSpotlightingCommandCenterFinancialsReport: Bool {
        currentStep == .needsCommandCenterFinancialsReport
    }

    var isSpotlightingCommandCenterFinancials: Bool {
        currentStep == .needsCommandCenterFinancialsHeader || currentStep == .needsCommandCenterFinancialsAccounts || currentStep == .needsCommandCenterFinancialsReport
    }

    var isSpotlightingCommandCenterSubscriptions: Bool {
        currentStep == .needsCommandCenterSubscriptions
    }

    var isSpotlightingCommandCenterDocuments: Bool {
        currentStep == .needsCommandCenterDocuments
    }

    var isSpotlightingAssistant: Bool {
        currentStep == .needsAssistant
    }

    // MARK: - Tutorial Mode

    var isTutorialActive: Bool {
        switch currentStep {
        case .tutorialEntityCard, .tutorialQuickActions, .tutorialSearch,
             .tutorialAssistant, .tutorialFinancial, .tutorialSubscriptions,
             .tutorialSwipeHint:
            return true
        default:
            return false
        }
    }

    var isSpotlightingTutorialEntity: Bool      { currentStep == .tutorialEntityCard }
    var isSpotlightingTutorialQuickActions: Bool { currentStep == .tutorialQuickActions }
    var isSpotlightingTutorialSearch: Bool       { currentStep == .tutorialSearch }
    var isSpotlightingTutorialAssistant: Bool    { currentStep == .tutorialAssistant }
    var isSpotlightingTutorialFinancial: Bool    { currentStep == .tutorialFinancial }
    var isSpotlightingTutorialSubs: Bool         { currentStep == .tutorialSubscriptions }
    var isSpotlightingTutorialSwipe: Bool        { currentStep == .tutorialSwipeHint }
    var isTutorialDone: Bool                     { currentStep == .tutorialDone }

    /// Step index (1-based) and total for the progress indicator
    var tutorialStepIndex: Int {
        switch currentStep {
        case .tutorialEntityCard:     return 1
        case .tutorialQuickActions:   return 2
        case .tutorialSearch:         return 3
        case .tutorialAssistant:      return 4
        case .tutorialFinancial:      return 5
        case .tutorialSubscriptions:  return 6
        case .tutorialSwipeHint:      return 7
        case .tutorialDone:           return 8
        default:                      return 0
        }
    }

    let tutorialTotalSteps = 8

    // MARK: - Init

    init() {
        if let savedStr = UserDefaults.standard.string(forKey: "onboardingStep"),
           let saved = OnboardingStep(rawValue: savedStr) {
            self.currentStep = saved
        } else {
            self.currentStep = .notStarted
        }
        self.tutorialHasBeenRun = UserDefaults.standard.bool(forKey: "tutorialHasBeenRun")
    }

    // MARK: - Real Onboarding

    func evaluateState(appState: AppState) {
        let companiesCount = appState.companies.count
        let institutionsCount = appState.institutions.count
        let subscriptionsCount = appState.subscriptions.count

        // If tutorial is mid-flow, don't interrupt
        if isTutorialActive && currentStep != .tutorialDone { return }

        // If stuck on the completion screen (app killed/relaunched), treat as skipped
        if currentStep == .tutorialDone {
            currentStep = .skipped
        }

        // If they have NO data, force onboarding to start unless explicitly skipped/completed
        if companiesCount == 0 && currentStep != .skipped && currentStep != .completed {
            currentStep = .needsEntity
            return
        }

        if currentStep == .completed || currentStep == .skipped {
            return
        }

        if companiesCount == 0 {
            currentStep = .needsEntity
        } else if institutionsCount == 0 {
            currentStep = .needsBank
        } else if currentStep == .needsEntity || currentStep == .needsBank || currentStep == .notStarted {
            currentStep = .needsReview
        }
        // If currentStep is already .needsReview, .needsNotes, .needsCommandCenter*, or .needsAssistant, leave it alone.
    }

    func skipOnboarding() {
        if currentStep == .needsBank || currentStep == .needsEntity {
            currentStep = .needsReview
        } else {
            currentStep = .completed
        }
    }

    func completeOnboarding() {
        switch currentStep {
        case .needsEntity:
            currentStep = .needsBank
        case .needsBank:
            currentStep = .needsReview
        case .needsReview:
            currentStep = .needsNotes
        case .needsNotes:
            currentStep = .needsCommandCenterQuickAdd
        case .needsCommandCenterQuickAdd:
            currentStep = .needsCommandCenterFinancialsHeader
        case .needsCommandCenterFinancialsHeader:
            currentStep = .needsCommandCenterFinancialsAccounts
        case .needsCommandCenterFinancialsAccounts:
            currentStep = .needsCommandCenterFinancialsReport
        case .needsCommandCenterFinancialsReport:
            currentStep = .needsCommandCenterSubscriptions
        case .needsCommandCenterSubscriptions:
            currentStep = .needsCommandCenterDocuments
        case .needsCommandCenterDocuments:
            currentStep = .completed
        case .needsAssistant:
            currentStep = .completed
        default:
            currentStep = .completed
        }
    }

    // MARK: - Tutorial Navigation

    func startTutorial() {
        tutorialHasBeenRun = true
        currentStep = .tutorialEntityCard
    }

    func tutorialNext() {
        switch currentStep {
        case .tutorialEntityCard:     currentStep = .tutorialQuickActions
        case .tutorialQuickActions:   currentStep = .tutorialSearch
        case .tutorialSearch:         currentStep = .tutorialAssistant
        case .tutorialAssistant:      currentStep = .tutorialFinancial
        case .tutorialFinancial:      currentStep = .tutorialSubscriptions
        case .tutorialSubscriptions:  currentStep = .tutorialSwipeHint
        case .tutorialSwipeHint:      currentStep = .tutorialDone
        case .tutorialDone:           currentStep = .skipped
        default: break
        }
    }

    func tutorialBack() {
        switch currentStep {
        case .tutorialQuickActions:   currentStep = .tutorialEntityCard
        case .tutorialSearch:         currentStep = .tutorialQuickActions
        case .tutorialAssistant:      currentStep = .tutorialSearch
        case .tutorialFinancial:      currentStep = .tutorialAssistant
        case .tutorialSubscriptions:  currentStep = .tutorialFinancial
        case .tutorialSwipeHint:      currentStep = .tutorialSubscriptions
        case .tutorialDone:           currentStep = .tutorialSwipeHint
        default: break
        }
    }

    func exitTutorial() {
        currentStep = .skipped
    }
}

import AVFoundation

@Observable
class SpeechManager: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechManager()
    private let synthesizer = AVSpeechSynthesizer()

    override private init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session for speech: \(error)")
        }
    }

    func speak(text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        }
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
