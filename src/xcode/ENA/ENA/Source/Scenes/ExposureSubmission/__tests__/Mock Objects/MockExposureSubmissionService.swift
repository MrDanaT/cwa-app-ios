//
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
//

import Foundation
import ExposureNotification

class MockExposureSubmissionService: BEExposureSubmissionService {

	// MARK: - Mock callbacks.

	var submitExposureCallback: ((@escaping ExposureSubmissionHandler) -> Void)?
	var getRegistrationTokenCallback: ((DeviceRegistrationKey, @escaping RegistrationHandler) -> Void)?
	var getTANForExposureSubmitCallback: ((Bool, @escaping TANHandler) -> Void)?
	var getTestResultCallback: ((@escaping TestResultHandler) -> Void)?
	var hasRegistrationTokenCallback: (() -> Bool)?
	var deleteTestCallback: (() -> Void)?
	var preconditionsCallback: (() -> ExposureManagerState)?
	var acceptPairingCallback: (() -> Void)?

	// MARK: - ExposureSubmissionService methods.

	func submitExposure(completionHandler: @escaping ExposureSubmissionHandler) {
		submitExposureCallback?(completionHandler)
	}

	func getRegistrationToken(forKey deviceRegistrationKey: DeviceRegistrationKey, completion completeWith: @escaping RegistrationHandler) {
		getRegistrationTokenCallback?(deviceRegistrationKey, completeWith)
	}

	func getTANForExposureSubmit(hasConsent: Bool, completion completeWith: @escaping TANHandler) {
		getTANForExposureSubmitCallback?(hasConsent, completeWith)
	}

	func getTestResult(_ completeWith: @escaping TestResultHandler) {
		getTestResultCallback?(completeWith)
	}

	func hasRegistrationToken() -> Bool {
		return hasRegistrationTokenCallback?() ?? false
	}

	func deleteTest() {
		deleteTestCallback?()
	}

	var devicePairingSuccessfulTimestamp: Int64?
	
	var mobileTestId: BEMobileTestId?

	func preconditions() -> ExposureManagerState {
		return preconditionsCallback?() ?? ExposureManagerState(authorized: false, enabled: false, status: .unknown)
	}

	func acceptPairing() {
		acceptPairingCallback?()
	}
	
	func generateMobileTestId(_ symptomsDate: Date?) -> BEMobileTestId {
		let generatedTestId = BEMobileTestId(symptomsStartDate: symptomsDate)
		
		mobileTestId = generatedTestId
		
		return generatedTestId
	}
	
	func retrieveDiagnosisKeys(completionHandler: @escaping BEExposureSubmissionGetKeysHandler) {
		completionHandler(.success([]))
	}
	
	func finalizeSubmissionWithoutKeys() {
		
	}
	
	func submitExposure(keys: [ENTemporaryExposureKey], countries: [BECountry], completionHandler: @escaping ExposureSubmissionHandler) {
		completionHandler(nil)
	}
	
	func submitFakeExposure(completionHandler: @escaping ExposureSubmissionHandler) {
		completionHandler(nil)
	}
	
	func deleteMobileTestIdIfOutdated() -> Bool {
		return false
	}
	
	func deleteTestResultIfOutdated() {
	}
	
	func setTestResultShownOnScreen() {
	}
	
	func getFakeTestResult(completion: @escaping (() -> Void)) {
	}
}
