# Duplicate Contacts Cleaner

SwiftUI iOS app for finding duplicate contacts by normalized phone number or email address.

The app:

- Requests Contacts permission only when the user taps Scan.
- Shows duplicate groups before making changes.
- Keeps the first contact in each group unselected by default.
- Requires confirmation before deletion.
- Does not upload contacts or use a network connection.

Open these files in a new iOS App project in Xcode and add the Contacts usage description:

`Privacy - Contacts Usage Description` = `This app scans your contacts on this device to find duplicates. Contacts are not uploaded.`

Deployment target: iOS 16.0 or newer.

## Codemagic

1. Push this folder to a Git repository.
2. In Codemagic, connect the repository and select `codemagic.yaml`.
3. Add an App Store Connect API integration named `app_store_connect_api`.
4. Add a development certificate/profile for `com.omen.duplicatecontacts`.
5. Start the `ios-duplicate-contacts` workflow and download the IPA artifact.

## Build from Windows without signing

Push the repository to GitHub, open the Actions tab, select `Build unsigned IPA`,
and run it manually. GitHub builds it on a hosted macOS runner and uploads
`DuplicateContacts-unsigned.ipa` as an artifact. Import that IPA into eSign for signing.
