# Publish to GitHub

This prepared folder is intended to become a **new public Git history** so previously hard-coded private configuration does not accidentally remain in old commits.

## 1. Final local check

```bash
./script/check_public_repo.sh
```

Public repository target: `https://github.com/mihozip/DeskPet`.

## 2. Create a fresh repository

Using GitHub CLI:

```bash
git init
git branch -M main
git add .
git commit -m "chore: prepare DeskPet 0.9.5.1 for open source"
gh repo create DeskPet --public --source=. --remote=origin --push
```

Or create an empty public repository in GitHub's web UI, then add the remote and push.

## 3. Tag the source release

```bash
git tag -a v0.9.5.1 -m "DeskPet 0.9.5.1 — Custom App Icon"
git push origin v0.9.5.1
```

For the first public release, a **source-only prerelease** is reasonable. Do not attach an ad-hoc signed `.app` as if it were a normal distributable build.

## 4. Recommended GitHub settings

- enable Issues
- enable Discussions only if you want community Q&A
- enable private vulnerability reporting / Security Advisories
- protect `main` once outside contributions begin
- require the CI check before merge

Suggested topics:

```text
macos swift swiftui appkit desktop-pet productivity gemini google-apps-script
```

Suggested repository description:

```text
A local-first macOS desktop work agent for capture, human-confirmed actions, GAS task workflows and a daily work diary.
```

## 5. Before publishing binaries

Follow `docs/RELEASING.md`: Developer ID signing, Hardened Runtime, notarization and validation.
