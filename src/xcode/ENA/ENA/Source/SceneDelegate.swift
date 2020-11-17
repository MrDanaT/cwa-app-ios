// Corona-Warn-App
//
// SAP SE and all other contributors
//
// Modified by Devside SRL
//
// copyright owners license this file to you under the Apache
// License, Version 2.0 (the "License"); you may not use this
// file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import BackgroundTasks
import ExposureNotification
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate, RequiresAppDependencies {
	// MARK: Properties

	var window: UIWindow?

	private lazy var navigationController: UINavigationController = AppNavigationController()
	private lazy var coordinator = Coordinator(self, navigationController)

	var state: State = State(exposureManager: .init(), detectionMode: currentDetectionMode, risk: nil) {
		didSet {
			coordinator.updateState(
				detectionMode: state.detectionMode,
				exposureManagerState: state.exposureManager,
				risk: state.risk)
		}
	}

	private lazy var appUpdateChecker = AppUpdateCheckHelper(client: self.client, store: self.store)

	private var enStateHandler: ENStateHandler?

	// :BE: stats
	private lazy var statisticsService: BEStatisticsService = {
		return BEStatisticsService(client: self.client, store: self.store)
	}()

	// :BE: test activator
	var mobileTestIdActivator: BEMobileTestIdActivator?
	
	// MARK: UISceneDelegate

	private let riskConsumer = RiskConsumer()

	func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
		guard let windowScene = (scene as? UIWindowScene) else { return }
		let window = UIWindow(windowScene: windowScene)
		self.window = window
		
		/// this is migration code
		/// we don't want the app stuck forever in the "thank you" state
		/// if it was the case, simply reset the app
		if store.lastSuccessfulSubmitDiagnosisKeyTimestamp != nil {
			resetApplication()
		}

		#if UITESTING
		// :BE: restart from scratch at every startup
		resetApplication()
		if let isOnboarded = UserDefaults.standard.value(forKey: "isOnboarded") as? String {
			store.isOnboarded = (isOnboarded != "NO")
		}
		store.userNeedsToBeInformedAboutHowRiskDetectionWorks = false
		
		if let argIndex = ProcessInfo.processInfo.arguments.firstIndex(of: "-testResult") {
			let mobileTestId = BEMobileTestId()
			store.mobileTestId = mobileTestId
			store.registrationToken = mobileTestId.registrationToken

			let resultType = ProcessInfo.processInfo.arguments[argIndex + 1]
			switch resultType {
			case "POSITIVE":
				store.testResult = TestResult.positive
			case "NEGATIVE":
				store.testResult = TestResult.negative
			case "PENDING":
				store.testResult = TestResult.pending
			default:
				fatalError("Should never happen")
			}
			
		}
		
		// Test opening the app from the webform url
		if let argIndex = ProcessInfo.processInfo.arguments.firstIndex(of: "-openWebForm") {
			let urlString = ProcessInfo.processInfo.arguments[argIndex + 1]
			
			if let url = URL(string: urlString) {
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
					self.processURLActivity(url)
				}
			}
		}
		
		#endif

		exposureManager.resume(observer: self)

		riskConsumer.didCalculateRisk = { [weak self] risk in
			self?.state.risk = risk
		}
		riskProvider.observeRisk(riskConsumer)

		UNUserNotificationCenter.current().delegate = self

		setupUI()

		NotificationCenter.default.addObserver(self, selector: #selector(isOnboardedDidChange(_:)), name: .isOnboardedDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(backgroundRefreshStatusDidChange), name: UIApplication.backgroundRefreshStatusDidChangeNotification, object: nil)
		
		if let userActivity = connectionOptions.userActivities.first {
		  self.scene(scene, continue: userActivity)
		}
	}

	func sceneWillEnterForeground(_ scene: UIScene) {
		let detectionMode = DetectionMode.fromBackgroundStatus()
		riskProvider.configuration.detectionMode = detectionMode

		riskProvider.requestRisk(userInitiated: false)

		let state = exposureManager.preconditions()
		updateExposureState(state)
		appUpdateChecker.checkAppVersionDialog(for: window?.rootViewController)
		
		// :BE: get stats, ignore errors and result
		statisticsService.getInfectionSummary { _ in }
		
		
		// Update dynamic texts
		let dynamicTextService = BEDynamicTextService()
		let dynamicTextDownloadService = BEDynamicTextDownloadService(client: client, textService: dynamicTextService)
		
		dynamicTextDownloadService.downloadTextsIfNeeded {}
		
		let exposureSubmissionService = BEExposureSubmissionServiceImpl(diagnosiskeyRetrieval: self.exposureManager, client: self.client, store: self.store)

		// remove test result if it is too old
		exposureSubmissionService.deleteTestResultIfOutdated()
	}

	func sceneDidEnterBackground(_ scene: UIScene) {
		showPrivacyProtectionWindow()
		taskScheduler.scheduleTask()
	}

	func sceneDidBecomeActive(_: UIScene) {
		hidePrivacyProtectionWindow()
		UIApplication.shared.applicationIconBadgeNumber = 0
	}

	// MARK: Helper

	func requestUpdatedExposureState() {
		let state = exposureManager.preconditions()
		updateExposureState(state)
	}

	private func setupUI() {
		setupNavigationBarAppearance()

		if !store.isOnboarded {
			showOnboarding()
		} else {
			showHome()
		}
		UIImageView.appearance().accessibilityIgnoresInvertColors = true
		window?.rootViewController = navigationController
		window?.makeKeyAndVisible()

	}

	private func setupNavigationBarAppearance() {
		let appearance = UINavigationBar.appearance()

		appearance.tintColor = .enaColor(for: .tint)

		appearance.titleTextAttributes = [
			NSAttributedString.Key.foregroundColor: UIColor.enaColor(for: .textPrimary1)
		]

		appearance.largeTitleTextAttributes = [
			NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .largeTitle).scaledFont(size: 28, weight: .bold),
			NSAttributedString.Key.foregroundColor: UIColor.enaColor(for: .textPrimary1)
		]
	}

	private func showHome(animated _: Bool = false) {
		if exposureManager.preconditions().status == .unknown {
			exposureManager.activate { [weak self] error in
				if let error = error {
					// TODO: Error handling, if error occurs, what can we do?
					logError(message: "Cannot activate the  ENManager. The reason is \(error)")
					return
				}
				self?.presentHomeVC()
			}
		} else {
			presentHomeVC()
		}
	}

	private func presentHomeVC() {
		enStateHandler = ENStateHandler(
			initialExposureManagerState: exposureManager.preconditions(),
			delegate: self
		)

		guard let enStateHandler = self.enStateHandler else {
			fatalError("It should not happen.")
		}

		coordinator.showHome(enStateHandler: enStateHandler, state: state, statisticsService: self.statisticsService)
	}

	private func showOnboarding() {
		coordinator.showOnboarding()
	}

	@objc
	func isOnboardedDidChange(_: NSNotification) {
		store.isOnboarded ? showHome() : showOnboarding()
		
		// :BE: enable fake requests
		store.isAllowedToPerformBackgroundFakeRequests = store.isOnboarded
	}

	private var privacyProtectionWindow: UIWindow?
}

// MARK: Privacy Protection
extension SceneDelegate {
	private func showPrivacyProtectionWindow() {
		guard
			let windowScene = window?.windowScene,
			store.isOnboarded == true
			else {
				return
		}

		let privacyProtectionViewController = PrivacyProtectionViewController()
		privacyProtectionWindow = UIWindow(windowScene: windowScene)
		privacyProtectionWindow?.rootViewController = privacyProtectionViewController
		privacyProtectionWindow?.windowLevel = .alert + 1
		privacyProtectionWindow?.makeKeyAndVisible()
		privacyProtectionViewController.show()
	}

	private func hidePrivacyProtectionWindow() {
		guard let privacyProtectionViewController = privacyProtectionWindow?.rootViewController as? PrivacyProtectionViewController else {
			return
		}
		privacyProtectionViewController.hide {
			self.privacyProtectionWindow?.isHidden = true
			self.privacyProtectionWindow = nil
		}
	}
}

extension SceneDelegate: ENAExposureManagerObserver {
	func exposureManager(
		_: ENAExposureManager,
		didChangeState newState: ExposureManagerState
	) {
		// Add the new state to the history
		store.tracingStatusHistory = store.tracingStatusHistory.consumingState(newState)
		riskProvider.exposureManagerState = newState

		let message = """
		New status of EN framework:
		Authorized: \(newState.authorized)
		enabled: \(newState.enabled)
		status: \(newState.status)
		authorizationStatus: \(ENManager.authorizationStatus)
		"""
		log(message: message)

		state.exposureManager = newState
		updateExposureState(newState)
	}
}

extension SceneDelegate: CoordinatorDelegate {
	/// Resets all stores and notifies the Onboarding.
	func coordinatorUserDidRequestReset() {
		resetApplication()
	}
}

// app reset
extension SceneDelegate {
		
	func resetApplication() {
		do {
			let newKey = try KeychainHelper().generateDatabaseKey()
			store.clearAll(key: newKey)
		} catch {
			fatalError("Creating new database key failed")
		}
		UIApplication.coronaWarnDelegate().downloadedPackagesStore.reset()
		UIApplication.coronaWarnDelegate().downloadedPackagesStore.open()
		exposureManager.reset {
			self.exposureManager.resume(observer: self)
			NotificationCenter.default.post(name: .isOnboardedDidChange, object: nil)
		}
	}
}


extension SceneDelegate: UNUserNotificationCenterDelegate {
	func userNotificationCenter(_: UNUserNotificationCenter, willPresent _: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
		completionHandler([.alert, .badge, .sound])
	}

	func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
		switch response.actionIdentifier {
		case UserNotificationAction.openExposureDetectionResults.rawValue,
			 UserNotificationAction.openTestResults.rawValue:
			showHome(animated: true)
		case UserNotificationAction.ignore.rawValue,
			 UNNotificationDefaultActionIdentifier,
			 UNNotificationDismissActionIdentifier:
			break
		default: break
		}

		completionHandler()
	}
}

private extension Array where Element == URLQueryItem {
	func valueFor(queryItem named: String) -> String? {
		first(where: { $0.name == named })?.value
	}
}


extension SceneDelegate: ExposureStateUpdating {
	func updateExposureState(_ state: ExposureManagerState) {
		riskProvider.exposureManagerState = state
		riskProvider.requestRisk(userInitiated: false)
		coordinator.updateExposureState(state)
		enStateHandler?.updateExposureState(state)
	}
}

extension SceneDelegate: ENStateHandlerUpdating {
	func updateEnState(_ state: ENStateHandler.State) {
		log(message: "SceneDelegate got EnState update: \(state)")
		coordinator.updateEnState(state)
	}
}

// MARK: Background Task
extension SceneDelegate {
	@objc
	func backgroundRefreshStatusDidChange() {
		let detectionMode: DetectionMode = currentDetectionMode
		state.detectionMode = detectionMode
	}
}

private var currentDetectionMode: DetectionMode {
	DetectionMode.fromBackgroundStatus()
}

// MARK: url handling

extension SceneDelegate {
	
	func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
		if userActivity.activityType != NSUserActivityTypeBrowsingWeb {
			return
		}
		
		if let url = userActivity.webpageURL {
			/// we add a small delay to make sure the GUI is completely up and running before manipulating it
			/// this is necessary when the app was not running in the background
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
				self.processURLActivity(url)
			}
		}
	}
	
	private func processURLActivity(_ url: URL) {
		let exposureSubmissionService = BEExposureSubmissionServiceImpl(diagnosiskeyRetrieval: self.exposureManager, client: self.client, store: self.store)

		if let activator = BEMobileTestIdActivator(exposureSubmissionService, parentViewController: navigationController, url: url, delegate: self) {
			mobileTestIdActivator = activator
			activator.run()
		}
	}
}

extension SceneDelegate: BEMobileTestIdActivatorDelegate {
	func mobileTestIdActivatorFinished(_: BEMobileTestIdActivator) {
		mobileTestIdActivator = nil
		coordinator.refreshTestResults()
	}
}
