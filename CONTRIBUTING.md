# Contributing to React

An iOS app with a custom keyboard and share extension, built with Swift and Xcode.

## Development

Open `React.xcodeproj` in Xcode and select the shared `React` scheme.
The app has no third-party package dependencies or advertising SDKs.
Configure signing locally for device builds; never commit private signing keys or
provisioning profiles. Shared schemes, entitlements, project files, and assets
belong in Git; personal Xcode settings and build output do not.

## Git workflow

Keep your working checkout outside iCloud Drive, for example at
`~/Developer/React`. Use GitHub to exchange commits between computers and
Time Machine or another versioned backup for uncommitted work.

Before committing, inspect both `git diff` and `git diff --cached`. Make focused
commits on feature branches and use pull requests to review changes. Fetch before
integrating remote changes. This checkout uses fast-forward-only pulls, so a
diverged branch requires an explicit merge or rebase decision.

After connecting a GitHub remote, configure a tracking branch with
`git push -u origin <branch>`. Use your intended GitHub commit email (or your
GitHub-provided private commit email) in the repository's `user.email` setting.

## Recommended GitHub configuration

- Keep the repository private unless publishing its code is intentional.
- Protect the actual default branch against deletion and force pushes.
- Prefer pull requests and squash merging; delete merged feature branches.
- For a solo-maintained project, avoid requiring another person's approval.
- Enable dependency alerts and available secret scanning/push protection.
- Add a simulator build check, verify it passes on GitHub, then require that
  check before merging. Do not require a check that has never run.
- Keep Actions workflow token permissions read-only unless a job needs more.

The local branch names `Main`, `Discoverv1`, and `DiscoverV2` are case-sensitive.
Confirm the intended default branch before renaming branches or setting rules.

## App identity

The project, targets, modules, and source folders use React. Existing bundle
identifiers, app groups, and iCloud container identifiers retain their original
PictoBoard values to preserve App Store identity and access to existing user data.
Changing those requires a separate signing and data migration plan.

The public repository is https://github.com/jiajunhe1997/React.
The legacy privacy-policy URL is retained for existing links.
