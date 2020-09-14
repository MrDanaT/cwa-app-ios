// Corona-Warn-App
//
// SAP SE and all other contributors
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
import FMDB
import UIKit

protocol CoronaWarnAppDelegate: AnyObject {
	var client: HTTPClient { get }
	var downloadedPackagesStore: DownloadedPackagesStore { get }
	var store: Store { get }
	var riskProvider: RiskProvider { get }
	var exposureManager: ExposureManager { get }
	var taskScheduler: ENATaskScheduler { get }
	var lastRiskCalculation: String { get set } // TODO: REMOVE ME
}

extension AppDelegate: CoronaWarnAppDelegate {
	// required - otherwise app will crash because cast will fails
}

extension AppDelegate: ExposureSummaryProvider {
	func detectExposure(completion: @escaping (ENExposureDetectionSummary?) -> Void) {
		exposureDetection = ExposureDetection(delegate: exposureDetectionExecutor)
		exposureDetection?.start { result in
			switch result {
			case .success(let summary):
				completion(summary)
			case .failure(let error):
				self.showError(exposure: error)
				completion(nil)
			}
		}
	}

	private func showError(exposure didEndPrematurely: ExposureDetection.DidEndPrematurelyReason) {

		guard
			let scene = UIApplication.shared.connectedScenes.first,
			let delegate = scene.delegate as? SceneDelegate,
			let rootController = delegate.window?.rootViewController,
			let alert = didEndPrematurely.errorAlertController(rootController: rootController)
		else {
			return
		}

		func _showError() {
			rootController.present(alert, animated: true, completion: nil)
		}

		if rootController.presentedViewController != nil {
			rootController.dismiss(
				animated: true,
				completion: _showError
			)
		} else {
			rootController.present(alert, animated: true, completion: nil)
		}
	}
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	//TODO: Handle it
	var store: Store = SecureStore(subDirectory: "database")
	
	private let consumer = RiskConsumer()
	let taskScheduler: ENATaskScheduler = ENATaskScheduler.shared

	lazy var riskProvider: RiskProvider = {
		
		// :BE: change detection interval to every 2 hours
		let exposureDetectionInterval = DateComponents(hour: 2)

		let config = RiskProvidingConfiguration(
			exposureDetectionValidityDuration: DateComponents(day: 2),
			exposureDetectionInterval: exposureDetectionInterval,
			detectionMode: .default
		)


		let provider = RiskProvider(
			configuration: config,
			store: self.store,
			exposureSummaryProvider: self,
			appConfigurationProvider: CachedAppConfiguration(client: self.client),
			exposureManagerState: self.exposureManager.preconditions()
		)
		
		#if UITESTING
			// :BE: add positive risk
			if let isAtRisk = UserDefaults.standard.value(forKey: "isAtRisk") as? String {
				if isAtRisk != "NO" {
					provider.setHighRiskForTesting()
				}
			}
		#endif

		return provider
	}()

	#if targetEnvironment(simulator) || COMMUNITY
	// Enable third party contributors that do not have the required
	// entitlements to also use the app
	let exposureManager: ExposureManager = {
		let tempKey = ENTemporaryExposureKey.random(Date())
		
		let keys = [tempKey]
		let manager = MockExposureManager(exposureNotificationError: nil, diagnosisKeysResult: (keys, nil))

		return manager
	}()
	#else
		let exposureManager: ExposureManager = ENAExposureManager()
	#endif

	private var exposureDetection: ExposureDetection?
	// :BE: use BE protocol as variable type
	private var exposureSubmissionService: BEExposureSubmissionService?
	
	// :BE: Add fake requests executor
	private lazy var fakeRequestsExecutor: BEFakeRequestsExecutor = {
		BEFakeRequestsExecutor(store: self.store, exposureManager: self.exposureManager, client: self.client)
	}()

	let downloadedPackagesStore: DownloadedPackagesStore = DownloadedPackagesSQLLiteStore(fileName: "packages")

	var client: HTTPClient = HTTPClient(configuration: .backendBaseURLs)

	// TODO: REMOVE ME
	var lastRiskCalculation: String = ""

	private lazy var exposureDetectionExecutor: ExposureDetectionExecutor = {
		ExposureDetectionExecutor(
			client: self.client,
			downloadedPackagesStore: self.downloadedPackagesStore,
			store: self.store,
			exposureDetector: self.exposureManager
		)
	}()

	func application(
		_: UIApplication,
		didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
	) -> Bool {
		UIDevice.current.isBatteryMonitoringEnabled = true

		taskScheduler.delegate = self

		riskProvider.observeRisk(consumer)

		return true
	}

	// MARK: UISceneSession Lifecycle

	func application(
		_: UIApplication,
		configurationForConnecting connectingSceneSession: UISceneSession,
		options _: UIScene.ConnectionOptions
	) -> UISceneConfiguration {
		UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
	}

	func application(_: UIApplication, didDiscardSceneSessions _: Set<UISceneSession>) {}
}

extension AppDelegate: ENATaskExecutionDelegate {

	/// This method executes the background tasks needed for: a) fetching test results and b) performing exposure detection requests
	// :BE: Add fake requests and refactor
	func executeENABackgroundTask(completion: @escaping ((Bool) -> Void)) {
		self.fakeRequestsExecutor.execute {
			log(message: "Fake requests done")
			self.executeFetchTestResults {
				log(message: "Fetch test results done")
				self.executeExposureDetectionRequest {
					log(message: "Exposure detection done")
					completion(true)
				}
			}
		}
	}

	/// This method executes a  test result fetch, and if it is successful, and the test result is different from the one that was previously
	/// part of the app, a local notification is shown.
	private func executeFetchTestResults(completion: @escaping (() -> Void)) {
		log(message: "Start fetch test results...")
		// :BE: replace ENAExposureSubmissionService with BEExposureSubmissionService
		let service = BEExposureSubmissionServiceImpl(diagnosiskeyRetrieval: exposureManager, client: client, store: store)
		exposureSubmissionService = service

		if store.registrationToken != nil && store.testResultReceivedTimeStamp == nil {
			// :BE: see if we passed the validity time for this test result
			if !service.deleteTestIfOutdated() {
				self.exposureSubmissionService?.getTestResult { result in
					switch result {
					case .failure(let error):
						logError(message: error.localizedDescription)
					case .success(let testResult):
						
						// :BE: testresult enum to struct
						if testResult.result != .pending {
							UNUserNotificationCenter.current().presentNotification(
								title: AppStrings.LocalNotifications.testResultsTitle,
								body: AppStrings.LocalNotifications.testResultsBody,
								identifier: ENATaskIdentifier.exposureNotification.backgroundTaskSchedulerIdentifier + ".test-result"

							)
						}
					}
					completion()
				}
				return
			}
		}
		
		completion()
	}

	/// This method performs a check for the current exposure detection state. Only if the risk level has changed compared to the
	/// previous state, a local notification is shown.
	private func executeExposureDetectionRequest(completion: @escaping (() -> Void)) {
		log(message: "Start exposure detection...")

		// At this point we are already in background so it is safe to assume background mode is available.
		riskProvider.configuration.detectionMode = .fromBackgroundStatus(.available)

		riskProvider.requestRisk(userInitiated: false) { risk in
			// present a notification if the risk score has increased.
			if let risk = risk,
				risk.riskLevelHasChanged {
				UNUserNotificationCenter.current().presentNotification(
					title: AppStrings.LocalNotifications.detectExposureTitle,
					body: AppStrings.LocalNotifications.detectExposureBody,
					identifier: ENATaskIdentifier.exposureNotification.backgroundTaskSchedulerIdentifier + ".risk-detection"
				)
			}
			completion()
		}
	}
}

