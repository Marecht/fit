# Setting up GitHub Repository

## Steps to create the repository:

1. Go to https://github.com/new
2. Repository name: `fit`
3. Description: "Git workflow tool with safety checks and simplified commands"
4. Make it Public (or Private if you prefer)
5. Don't initialize with README, .gitignore, or license (we already have these)
6. Click "Create repository"

## Then push the code:

```bash
cd ~/.fit
git remote add origin https://github.com/marecht/fit.git
git branch -M main
git push -u origin main
```

## For Homebrew Tap:

Create another repository called `homebrew-tap`:

```bash
# On GitHub, create a new repository called "homebrew-tap"
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

Then users can install with:
```bash
brew tap marecht/tap
brew install fit
```
