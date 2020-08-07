<h1 align="center">
    Corona Warn App - iOS
</h1>

<p align="center">
   <a href="https://github.com/covid-be-app/cwa-app-ios/commits/" title="Last Commit"><img src="https://img.shields.io/github/last-commit/covid-be-app/cwa-app-ios?style=flat"></a>
   <a href="https://github.com/covid-be-app/cwa-app-ios/issues" title="Open Issues"><img src="https://img.shields.io/github/issues/covid-be-app/cwa-app-ios?style=flat"></a>
   <a href="https://circleci.com/gh/covid-be-app/cwa-app-ios" title="Build Status"><img src="https://circleci.com/gh/covid-be-app/cwa-app-ios.png?circle-token=656940b0df758209128b0d782c5f8885ddceb7a8&style=shield"></a>
   <a href="https://sonarcloud.io/component_measures?id=corona-warn-app_cwa-app-ios&metric=Coverage&view=list" title="Coverage"><img src="https://sonarcloud.io/api/project_badges/measure?project=corona-warn-app_cwa-app-ios&metric=coverage"></a>
   <a href="./LICENSE" title="License"><img src="https://img.shields.io/badge/License-Apache%202.0-green.svg"></a>
   <a href="https://github-tools.github.io/github-release-notes/" title="Automated Release Notes"><img src="https://img.shields.io/badge/%F0%9F%A4%96-release%20notes-00B2EE.svg"></a>
</p>

<p align="center">
  <a href="#development">Development</a> •
  <a href="#architecture--documentation">Documentation</a> •
  <a href="#how-to-contribute">Contribute</a> •
  <a href="#support--feedback">Support</a> •
  <a href="./CHANGELOG.md">Changelog</a> •
  <a href="#licensing">Licensing</a>
</p>

The goal of this project is to develop the official Coronalert app for Belgium, forked from the German Corona-Warn-App, based on the exposure notification API from [Apple](https://www.apple.com/covid19/contacttracing/) and [Google](https://www.google.com/covid19/exposurenotifications/). The apps (for both iOS and Android) use Bluetooth technology to exchange anonymous encrypted data with other mobile phones (on which the app is also installed) in the vicinity of an app user's phone. The data is stored locally on each user's device, preventing authorities or other parties from accessing or controlling the data. This repository contains the **native iOS implementation** of the Coronalert App.

![Figure 1: UI Screens for Apple iOS](https://github.com/covid-be-app/cwa-documentation/blob/master/images/ui_screens/ui_screens_ios.png "Figure 1: UI Screens for Apple iOS")

## Development

### Setup

TODO

### Build

TODO

### Run

TODO

## Architecture & Documentation

The full documentation for the Coronalert App is in the [cwa-documentation](https://github.com/covid-be-app/cwa-documentation) repository. The documentation repository contains technical documents, architecture information, UI/UX specifications, and whitepapers related to this implementation.

## Support & Feedback

The following channels are available for discussions, feedback, and support requests:

| Type                     | Channel                                                |
| ------------------------ | ------------------------------------------------------ |
| **General Discussion**   | <a href="https://github.com/covid-be-app/cwa-documentation/issues/new/choose" title="General Discussion"><img src="https://img.shields.io/github/issues/covid-be-app/cwa-documentation/question.svg?style=flat-square"></a> </a>   |
| **Feature Requests**    | <a href="https://github.com/covid-be-app/cwa-wishlist/issues/new/choose" title="Create Feature Request"><img src="https://img.shields.io/github/issues/covid-be-app/cwa-wishlist?style=flat-square"></a>  |
| **Concept Feedback**    | <a href="https://github.com/covid-be-app/cwa-documentation/issues/new/choose" title="Open Concept Feedback"><img src="https://img.shields.io/github/issues/covid-be-app/cwa-documentation/architecture.svg?style=flat-square"></a>  |
| **iOS App Issue**    | <a href="https://github.com/covid-be-app/cwa-app-ios/issues/new/choose" title="Open iOS Suggestion"><img src="https://img.shields.io/github/issues/covid-be-app/cwa-app-ios?style=flat-square"></a>  |
| **Backend Issue**    | <a href="https://github.com/covid-be-app/cwa-server/issues/new/choose" title="Open Backend Issue"><img src="https://img.shields.io/github/issues/covid-be-app/cwa-server?style=flat-square"></a>  |
| **Other Requests**    | <a href="mailto:covid-be-app.opensource@sap.com" title="Email CWA Team"><img src="https://img.shields.io/badge/email-CWA%20team-green?logo=mail.ru&style=flat-square&logoColor=white"></a>   |

## How to Contribute

Contribution and feedback are encouraged and always welcome. For more information about how to contribute, the project structure, as well as additional contribution information, see our [Contribution Guidelines](./CONTRIBUTING.md). By participating in this project, you agree to abide by its [Code of Conduct](./CODE_OF_CONDUCT.md) at all times.

#### SwiftLint

This project uses [SwiftLint](https://github.com/realm/SwiftLint) to ensure a unified code style. The linter is run on every build and shows all warnings and error within Xcode's Issue Navigator.

Please ensure you have installed SwiftLint when working on this project and fix any warnings or error before committing your changes.

Use `brew install swiftlint` to install SwiftLint or download it manually from https://github.com/realm/SwiftLint. When not installed a warning will be triggered during build.

## Repositories

| Repository          | Description                                                           |
| ------------------- | --------------------------------------------------------------------- |
| [cwa-documentation] | Project overview, general documentation, and white papers.            |
| [cwa-wishlist]      | Community feature requests.                                           |
| [cwa-app-ios]       | Native iOS app using the Apple/Google exposure notification API.      |
| [cwa-app-android]   | Native Android app using the Apple/Google exposure notification API.  |
| [cwa-server]        | Backend implementation for the Apple/Google exposure notification API.|
| [cwa-verification-server] | Backend implementation of the verification process. |

[cwa-verification-server]: https://github.com/covid-be-app/cwa-verification-server
[cwa-documentation]: https://github.com/covid-be-app/cwa-documentation
[cwa-wishlist]: https://github.com/covid-be-app/cwa-wishlist
[cwa-app-ios]: https://github.com/covid-be-app/cwa-app-ios
[cwa-app-android]: https://github.com/covid-be-app/cwa-app-android
[cwa-server]: https://github.com/covid-be-app/cwa-server


## Licensing

Copyright (c) 2020 SAP SE or an SAP affiliate company.

Licensed under the **Apache License, Version 2.0** (the "License"); you may not use this file except in compliance with the License.

You may obtain a copy of the License at https://www.apache.org/licenses/LICENSE-2.0.

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the [LICENSE](./LICENSE) for the specific language governing permissions and limitations under the License.
