import Foundation
import SwiftUI
import Observation

enum OnboardingStep: String, Codable {
    case notStarted
    case completed
    case skipped

    case needsEntity, needsBank, needsReview, needsNotes
    case needsCommandCenterQuickAdd, needsCommandCenterFinancialsHeader, needsCommandCenterFinancialsAccounts, needsCommandCenterFinancialsReport
    case needsCommandCenterSubscriptions, needsCommandCenterDocuments, needsAssistant
    
    // Tutorial walkthrough steps
    case tutorialEntityCard
    case tutorialQuickActions
    case tutorialSearch
    case tutorialAssistant
    case tutorialCommandCenter
    case tutorialCommandQuickAdd
    case tutorialCommandFinancials
    case tutorialCommandSubscriptions
    case tutorialCommandDocuments
    case tutorialCommandTabBar
    case tutorialFinancialPage
    case tutorialFinancialWallet
    case tutorialFinancialCardTap
    case tutorialFinancialSwipe
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

    var tutorialHasBeenRun: Bool {
        didSet {
            UserDefaults.standard.set(tutorialHasBeenRun, forKey: "tutorialHasBeenRun")
        }
    }

    // MARK: - JIT Contextual Tooltip Flags
    var hasShownFinancialTooltip: Bool {
        get { UserDefaults.standard.bool(forKey: "hasShownFinancialTooltip") }
        set { UserDefaults.standard.set(newValue, forKey: "hasShownFinancialTooltip") }
    }

    var hasShownAssistantTooltip: Bool {
        get { UserDefaults.standard.bool(forKey: "hasShownAssistantTooltip") }
        set { UserDefaults.standard.set(newValue, forKey: "hasShownAssistantTooltip") }
    }

    var hasShownDashboardTooltip: Bool {
        get { UserDefaults.standard.bool(forKey: "hasShownDashboardTooltip") }
        set { UserDefaults.standard.set(newValue, forKey: "hasShownDashboardTooltip") }
    }

    // MARK: - Onboarding Spotlights
    var isSpotlightingEntity: Bool { false }
    var isSpotlightingBank: Bool { false }
    var isSpotlightingReview: Bool { false }
    var isSpotlightingNotes: Bool { false }
    var isSpotlightingCommandCenterQuickAdd: Bool { false }
    var isSpotlightingCommandCenterFinancialsHeader: Bool { false }
    var isSpotlightingCommandCenterFinancialsAccounts: Bool { false }
    var isSpotlightingCommandCenterFinancialsReport: Bool { false }
    var isSpotlightingCommandCenterFinancials: Bool { false }
    var isSpotlightingCommandCenterSubscriptions: Bool { false }
    var isSpotlightingCommandCenterDocuments: Bool { false }
    var isSpotlightingAssistant: Bool { false }

    // MARK: - Tutorial Mode (Restored)
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
    
    var isSpotlightingTutorialEntity: Bool      { currentStep == .tutorialEntityCard }
    var isSpotlightingTutorialQuickActions: Bool { currentStep == .tutorialQuickActions }
    var isSpotlightingTutorialSearch: Bool       { currentStep == .tutorialSearch }
    var isSpotlightingTutorialAssistant: Bool    { currentStep == .tutorialAssistant }
    var isSpotlightingTutorialSwipe: Bool        { currentStep == .tutorialSwipeHint }

    var isSpotlightingTutorialCommandCenter: Bool       { currentStep == .tutorialCommandCenter }
    var isSpotlightingTutorialCommandQuickAdd: Bool     { currentStep == .tutorialCommandQuickAdd }
    var isSpotlightingTutorialCommandFinancials: Bool   { currentStep == .tutorialCommandFinancials }
    var isSpotlightingTutorialCommandSubs: Bool         { currentStep == .tutorialCommandSubscriptions }
    var isSpotlightingTutorialCommandDocs: Bool         { currentStep == .tutorialCommandDocuments }
    var isSpotlightingTutorialCommandTabBar: Bool       { currentStep == .tutorialCommandTabBar }

    var isSpotlightingTutorialFinancialPage: Bool     { currentStep == .tutorialFinancialPage }
    var isSpotlightingTutorialFinancialWallet: Bool   { currentStep == .tutorialFinancialWallet }
    var isSpotlightingTutorialFinancialCardTap: Bool  { currentStep == .tutorialFinancialCardTap }
    var isSpotlightingTutorialFinancialSwipe: Bool    { currentStep == .tutorialFinancialSwipe }

    var isInFinancialTutorial: Bool {
        currentStep == .tutorialCommandTabBar ||
        currentStep == .tutorialFinancialPage ||
        currentStep == .tutorialFinancialWallet ||
        currentStep == .tutorialFinancialCardTap ||
        currentStep == .tutorialFinancialSwipe
    }

    var isInCommandCenterTutorial: Bool {
        currentStep == .tutorialCommandCenter ||
        currentStep == .tutorialCommandQuickAdd ||
        currentStep == .tutorialCommandFinancials ||
        currentStep == .tutorialCommandSubscriptions ||
        currentStep == .tutorialCommandDocuments
    }

    var isTutorialDone: Bool { currentStep == .tutorialDone }

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

    var tutorialFinancialWalletFrame: CGRect = .zero
    var tutorialFinancialInstitutionFrame: CGRect = .zero

    // MARK: - Init
    init() {
        if let savedStr = UserDefaults.standard.string(forKey: "onboardingStep"),
           let saved = OnboardingStep(rawValue: savedStr) {
            self.currentStep = saved
        } else {
            self.currentStep = .skipped
        }
        self.tutorialHasBeenRun = UserDefaults.standard.bool(forKey: "tutorialHasBeenRun")
    }

    // MARK: - Real Onboarding Evaluator
    func evaluateState(appState: AppState) {
        if isTutorialActive && currentStep != .tutorialDone { return }
        if currentStep == .tutorialDone {
            currentStep = .skipped
        }
        if currentStep != .completed && currentStep != .skipped {
            currentStep = .skipped
        }
    }

    func skipOnboarding() {
        currentStep = .skipped
    }

    func completeOnboarding() {
        currentStep = .completed
    }

    // MARK: - Tutorial Navigation
    func startTutorial() {
        tutorialHasBeenRun = true
        currentStep = .tutorialEntityCard
    }
    
    func startTutorial(appState: AppState, userId: UUID) {
        tutorialHasBeenRun = true
        currentStep = .tutorialEntityCard
    }

    func tutorialNext() {
        switch currentStep {
        case .tutorialEntityCard:          currentStep = .tutorialQuickActions
        case .tutorialQuickActions:        currentStep = .tutorialSearch
        case .tutorialSearch:              currentStep = .tutorialAssistant
        case .tutorialAssistant:           currentStep = .tutorialCommandCenter
        case .tutorialCommandCenter:       currentStep = .tutorialCommandQuickAdd
        case .tutorialCommandQuickAdd:     currentStep = .tutorialCommandFinancials
        case .tutorialCommandFinancials:   currentStep = .tutorialCommandSubscriptions
        case .tutorialCommandSubscriptions: currentStep = .tutorialCommandDocuments
        case .tutorialCommandDocuments:    currentStep = .tutorialCommandTabBar
        case .tutorialCommandTabBar:       currentStep = .tutorialFinancialPage
        case .tutorialFinancialPage:       currentStep = .tutorialFinancialWallet
        case .tutorialFinancialWallet:     currentStep = .tutorialFinancialCardTap
        case .tutorialFinancialCardTap:    currentStep = .tutorialDone
        case .tutorialDone:                currentStep = .skipped
        default: break
        }
    }

    func tutorialBack() {
        switch currentStep {
        case .tutorialQuickActions:        currentStep = .tutorialEntityCard
        case .tutorialSearch:              currentStep = .tutorialQuickActions
        case .tutorialAssistant:           currentStep = .tutorialSearch
        case .tutorialCommandCenter:       currentStep = .tutorialAssistant
        case .tutorialCommandQuickAdd:     currentStep = .tutorialCommandCenter
        case .tutorialCommandFinancials:   currentStep = .tutorialCommandQuickAdd
        case .tutorialCommandSubscriptions: currentStep = .tutorialCommandFinancials
        case .tutorialCommandDocuments:    currentStep = .tutorialCommandSubscriptions
        case .tutorialCommandTabBar:       currentStep = .tutorialCommandDocuments
        case .tutorialFinancialPage:       currentStep = .tutorialCommandTabBar
        case .tutorialFinancialWallet:     currentStep = .tutorialFinancialPage
        case .tutorialFinancialCardTap:    currentStep = .tutorialFinancialWallet
        default: break
        }
    }

    func exitTutorial(appState: AppState) {
        currentStep = .skipped
    }
}

// Keep SpeechManager
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
