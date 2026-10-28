# React

React is a free, ad-free native iOS app for organizing and sharing photos, memes, and sounds.

- Unlimited boards and photos, including multiple-photo import and sharing from other apps.
- Swipe between Sound, Discover, and your boards.
- Hold and drag photos to rearrange them; rearrange boards from the menu.
- Copy original photos without watermarks and access boards from the keyboard extension.
- iCloud backup and restore for everyone (requires an available iCloud account and storage).

There are no in-app purchases, subscriptions, upgrade prompts, or advertising SDKs.

Open `React.xcodeproj` and select the shared `React` scheme. See [CONTRIBUTING.md](CONTRIBUTING.md) for signing and Git workflow details. This Swift app is unrelated to the React JavaScript framework.

## License

The source code is available under the [MIT License](LICENSE).

## Devices and languages

The interface supports iPhone and iPad on iOS/iPadOS 17 or later, including
 iPhone 12-sized displays, landscape layouts, and iPad multitasking widths.
Hindi, Indian English, French, Spanish (including Latin America), Japanese,
and Indonesian are included in the app, keyboard, and share extension.
User-created board names and remotely supplied titles remain as entered.

React Keyboard uses the system-managed keyboard canvas rather than sizing
itself to its photos or empty state. Tap a photo to copy it, then touch and hold
the destination field and choose Paste. iOS does not expose image insertion or
Command-V injection through the public custom keyboard text proxy.
