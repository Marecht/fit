# Homebrew Setup Guide

## Creating the Tap

1. Create a new repository on GitHub named `homebrew-tap`:
   ```bash
   # On GitHub, create a new repository called "homebrew-tap"
   ```

2. Clone and set up the tap:
   ```bash
   git clone https://github.com/marecht/homebrew-tap.git
   cd homebrew-tap
   mkdir -p Formula
   ```

3. Copy the formula:
   ```bash
   cp /path/to/fit/Formula/fit.rb Formula/
   ```

4. Commit and push:
   ```bash
   git add Formula/fit.rb
   git commit -m "Add fit formula"
   git push origin main
   ```

## Installing via Homebrew

Users can then install with:
```bash
brew tap marecht/tap
brew install fit
```

## Updating the Formula

When you release a new version:

1. Update the version in `Formula/fit.rb`
2. Update the SHA256 (run `brew fetch` to get it)
3. Commit and push
4. Tag the release in the main fit repository

## Alternative: Direct Formula in Repository

You can also keep the formula in the main fit repository and install with:
```bash
brew install marecht/fit/fit
```

This requires the Formula to be in the root of the repository.
