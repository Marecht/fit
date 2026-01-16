# Quick Start Guide

## Repository Setup

1. **Create GitHub repository:**
   - Go to https://github.com/new
   - Name: `fit`
   - Description: "Git workflow tool with safety checks and simplified commands"
   - Public repository
   - Don't initialize with any files

2. **Push to GitHub:**
   ```bash
   cd ~/.fit
   git remote add origin https://github.com/marecht/fit.git
   git branch -M main
   git push -u origin main
   ```

## Homebrew Setup

### Option 1: Tap Repository (Recommended)

1. **Create tap repository:**
   - Go to https://github.com/new
   - Name: `homebrew-tap`
   - Public repository
   - Don't initialize with any files

2. **Set up the tap:**
   ```bash
   mkdir -p ~/homebrew-tap/Formula
   cp ~/.fit/Formula/fit.rb ~/homebrew-tap/Formula/
   cd ~/homebrew-tap
   git init
   git add Formula/fit.rb
   git commit -m "Add fit formula"
   git remote add origin https://github.com/marecht/homebrew-tap.git
   git branch -M main
   git push -u origin main
   ```

3. **Install:**
   ```bash
   brew tap marecht/tap
   brew install fit
   ```

### Option 2: Direct Formula

Keep the formula in the main repository and install with:
```bash
brew install marecht/fit/fit
```

## Testing the Installation

After installation:
```bash
fit setup
fit --help
```

## Updating the Formula

When releasing a new version:

1. Update version in `Formula/fit.rb`
2. Get SHA256: `brew fetch --build-from-source marecht/tap/fit`
3. Update SHA256 in formula
4. Commit and push to tap repository
5. Tag release in main repository
