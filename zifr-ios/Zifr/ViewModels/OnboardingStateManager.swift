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
    // Dashboard segment (steps 1–4)
    case tutorialEntityCard
    case tutorialQuickActions
    case tutorialSearch
    case tutorialAssistant
    // Command Center segment (steps 5–10)
    case tutorialCommandCenter
    case tutorialCommandQuickAdd
    case tutorialCommandFinancials
    case tutorialCommandSubscriptions
    case tutorialCommandDocuments
    case tutorialCommandTabBar
    // Financial segment (steps 11–14)
    case tutorialFinancialPage
    case tutorialFinancialWallet
    case tutorialFinancialCardTap
    case tutorialFinancialSwipe
    // Final dashboard steps (15–16)
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
             .tutorialAssistant,
             .tutorialCommandCenter, .tutorialCommandQuickAdd, .tutorialCommandFinancials,
             .tutorialCommandSubscriptions, .tutorialCommandDocuments, .tutorialCommandTabBar,
             .tutorialFinancialPage, .tutorialFinancialWallet, .tutorialFinancialCardTap:
            return true
        default:
            return false
        }
    }

    // Dashboard steps
    var isSpotlightingTutorialEntity: Bool      { currentStep == .tutorialEntityCard }
    var isSpotlightingTutorialQuickActions: Bool { currentStep == .tutorialQuickActions }
    var isSpotlightingTutorialSearch: Bool       { currentStep == .tutorialSearch }
    var isSpotlightingTutorialAssistant: Bool    { currentStep == .tutorialAssistant }
    var isSpotlightingTutorialSwipe: Bool        { currentStep == .tutorialSwipeHint }

    // Command Center steps
    var isSpotlightingTutorialCommandCenter: Bool       { currentStep == .tutorialCommandCenter }
    var isSpotlightingTutorialCommandQuickAdd: Bool     { currentStep == .tutorialCommandQuickAdd }
    var isSpotlightingTutorialCommandFinancials: Bool   { currentStep == .tutorialCommandFinancials }
    var isSpotlightingTutorialCommandSubs: Bool         { currentStep == .tutorialCommandSubscriptions }
    var isSpotlightingTutorialCommandDocs: Bool         { currentStep == .tutorialCommandDocuments }
    var isSpotlightingTutorialCommandTabBar: Bool       { currentStep == .tutorialCommandTabBar }

    // Financial page steps
    var isSpotlightingTutorialFinancialPage: Bool     { currentStep == .tutorialFinancialPage }
    var isSpotlightingTutorialFinancialWallet: Bool   { currentStep == .tutorialFinancialWallet }
    var isSpotlightingTutorialFinancialCardTap: Bool  { currentStep == .tutorialFinancialCardTap }
    var isSpotlightingTutorialFinancialSwipe: Bool    { currentStep == .tutorialFinancialSwipe }

    /// True when ANY financial tutorial step is active (used to show dummy wallet)
    var isInFinancialTutorial: Bool {
        currentStep == .tutorialCommandTabBar ||
        currentStep == .tutorialFinancialPage ||
        currentStep == .tutorialFinancialWallet ||
        currentStep == .tutorialFinancialCardTap ||
        currentStep == .tutorialFinancialSwipe
    }

    /// True when ANY command center tutorial step is active
    var isInCommandCenterTutorial: Bool {
        currentStep == .tutorialCommandCenter ||
        currentStep == .tutorialCommandQuickAdd ||
        currentStep == .tutorialCommandFinancials ||
        currentStep == .tutorialCommandSubscriptions ||
        currentStep == .tutorialCommandDocuments
    }

    var isTutorialDone: Bool                     { currentStep == .tutorialDone }

    /// Step index (1-based) and total for the progress indicator
    var tutorialStepIndex: Int {
        switch currentStep {
        case .tutorialEntityCard:             return 1
        case .tutorialQuickActions:           return 2
        case .tutorialSearch:                 return 3
        case .tutorialAssistant:              return 4
        case .tutorialCommandCenter:          return 5
        case .tutorialCommandQuickAdd:        return 6
        case .tutorialCommandFinancials:      return 7
        case .tutorialCommandSubscriptions:   return 8
        case .tutorialCommandDocuments:       return 9
        case .tutorialCommandTabBar:          return 10
        case .tutorialFinancialPage:          return 11
        case .tutorialFinancialWallet:        return 12
        case .tutorialFinancialCardTap:       return 13
        default:                              return 0
        }
    }

    /// Segment label shown in the progress pill alongside the step counter
    var tutorialSegmentLabel: String {
        switch currentStep {
        case .tutorialEntityCard, .tutorialQuickActions,
             .tutorialSearch, .tutorialAssistant:
            return "DASHBOARD"
        case .tutorialCommandCenter, .tutorialCommandQuickAdd,
             .tutorialCommandFinancials, .tutorialCommandSubscriptions,
             .tutorialCommandDocuments:
            return "COMMAND CENTER"
        case .tutorialCommandTabBar,
             .tutorialFinancialPage, .tutorialFinancialWallet,
             .tutorialFinancialCardTap:
            return "FINANCIALS"
        default:
            return ""
        }
    }

    var tutorialTotalSteps = 13

    // MARK: - Shared Tutorial Frame Storage
    // These bypass PreferenceKey propagation (which fails inside LazyVStack).
    // FinancialView writes directly; CompanyDetailView reads for spotlight positioning.
    var tutorialFinancialWalletFrame: CGRect = .zero
    var tutorialFinancialInstitutionFrame: CGRect = .zero

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
        // Dashboard segment
        case .tutorialEntityCard:          currentStep = .tutorialQuickActions
        case .tutorialQuickActions:        currentStep = .tutorialSearch
        case .tutorialSearch:              currentStep = .tutorialAssistant
        case .tutorialAssistant:           currentStep = .tutorialCommandCenter
        // Command Center segment
        case .tutorialCommandCenter:       currentStep = .tutorialCommandQuickAdd
        case .tutorialCommandQuickAdd:     currentStep = .tutorialCommandFinancials
        case .tutorialCommandFinancials:   currentStep = .tutorialCommandSubscriptions
        case .tutorialCommandSubscriptions: currentStep = .tutorialCommandDocuments
        case .tutorialCommandDocuments:    currentStep = .tutorialCommandTabBar
        // Financial segment (step 10 = tabBar, shown on financial page)
        case .tutorialCommandTabBar:       currentStep = .tutorialFinancialPage
        case .tutorialFinancialPage:       currentStep = .tutorialFinancialWallet
        case .tutorialFinancialWallet:     currentStep = .tutorialFinancialCardTap
        case .tutorialFinancialCardTap:    currentStep = .tutorialDone  // last step — show completion overlay
        case .tutorialDone:                currentStep = .skipped
        default: break
        }
    }

    func tutorialBack() {
        switch currentStep {
        // Dashboard segment
        case .tutorialQuickActions:        currentStep = .tutorialEntityCard
        case .tutorialSearch:              currentStep = .tutorialQuickActions
        case .tutorialAssistant:           currentStep = .tutorialSearch
        // Command Center segment
        case .tutorialCommandCenter:       currentStep = .tutorialAssistant
        case .tutorialCommandQuickAdd:     currentStep = .tutorialCommandCenter
        case .tutorialCommandFinancials:   currentStep = .tutorialCommandQuickAdd
        case .tutorialCommandSubscriptions: currentStep = .tutorialCommandFinancials
        case .tutorialCommandDocuments:    currentStep = .tutorialCommandSubscriptions
        case .tutorialCommandTabBar:       currentStep = .tutorialCommandDocuments
        // Financial segment
        case .tutorialFinancialPage:       currentStep = .tutorialCommandTabBar
        case .tutorialFinancialWallet:     currentStep = .tutorialFinancialPage
        case .tutorialFinancialCardTap:    currentStep = .tutorialFinancialWallet
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
