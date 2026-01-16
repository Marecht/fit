# Publishing to Homebrew - Step by Step

## Prerequisites

✅ You have SSH keys set up with GitHub (already done!)
✅ Your remote is set to SSH: `git@github.com:marecht/fit.git`

## Step 1: Push the Main Repository

1. **Create the GitHub repository:**
   - Go to https://github.com/new
   - Repository name: `fit`
   - Description: "Git workflow tool with safety checks and simplified commands"
   - Make it **Public**
   - **Don't** initialize with README, .gitignore, or license

2. **Commit and push your code:**
   ```bash
   cd ~/.fit
   git add -A
   git commit -m "Initial commit: Fit git workflow tool"
   git branch -M main
   git push -u origin main
   ```

## Step 2: Create a Release Tag

Homebrew needs a release tag to download from:

```bash
cd ~/.fit
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

## Step 3: Create the Homebrew Tap Repository

1. **Create tap repository on GitHub:**
   - Go to https://github.com/new
   - Repository name: `homebrew-tap` (must be exactly this name)
   - Description: "Homebrew tap for fit and other tools"
   - Make it **Public**
   - **Don't** initialize with any files

2. **Set up the tap locally:**
   ```bash
   mkdir -p ~/homebrew-tap/Formula
   cd ~/homebrew-tap
   git init
   git remote add origin git@github.com:marecht/homebrew-tap.git
   ```

3. **Copy and update the formula:**
   ```bash
   cp ~/.fit/Formula/fit.rb ~/homebrew-tap/Formula/fit.rb
   ```

4. **Update the formula URL to use the release tag:**
   Edit `~/homebrew-tap/Formula/fit.rb` and change:
   ```ruby
   url "https://github.com/marecht/fit/archive/refs/heads/main.tar.gz"
   ```
   To:
   ```ruby
   url "https://github.com/marecht/fit/archive/refs/tags/v1.0.0.tar.gz"
   ```

5. **Get the SHA256 hash:**
   ```bash
   cd ~/homebrew-tap
   brew fetch --build-from-source ./Formula/fit.rb
   ```
   This will show you the SHA256. Copy it and update the formula:
   ```ruby
   sha256 "paste-the-sha256-here"
   ```

6. **Commit and push the tap:**
   ```bash
   git add Formula/fit.rb
   git commit -m "Add fit formula"
   git branch -M main
   git push -u origin main
   ```

## Step 4: Test the Installation

Test that it works:

```bash
brew tap marecht/tap
brew install fit
fit setup
```

## Step 5: Update for Future Releases

When you release a new version:

1. **Tag the new release in the main repo:**
   ```bash
   cd ~/.fit
   git tag -a v1.1.0 -m "Release version 1.1.0"
   git push origin v1.1.0
   ```

2. **Update the formula:**
   ```bash
   cd ~/homebrew-tap
   # Edit Formula/fit.rb:
   # - Update version: version "1.1.0"
   # - Update url: url "https://github.com/marecht/fit/archive/refs/tags/v1.1.0.tar.gz"
   # - Get new SHA256: brew fetch --build-from-source ./Formula/fit.rb
   # - Update sha256 in the formula
   ```

3. **Commit and push:**
   ```bash
   git add Formula/fit.rb
   git commit -m "Update fit to v1.1.0"
   git push
   ```

## Alternative: Direct Formula (Simpler)

Instead of a separate tap, you can keep the formula in the main repository:

1. Move `Formula/fit.rb` to the root of the fit repository
2. Users install with: `brew install marecht/fit/fit`

This is simpler but less organized if you plan to add more tools later.

## Quick Reference

**User installation:**
```bash
brew tap marecht/tap
brew install fit
```

**Your repositories:**
- Main: `git@github.com:marecht/fit.git`
- Tap: `git@github.com:marecht/homebrew-tap.git`
