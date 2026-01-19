#!/bin/bash

set -e

VERSION=$1
TAP_REPO=${2:-"homebrew-tap"}

if [ -z "$VERSION" ]; then
    echo "Usage: ./setup-homebrew-tap.sh <version> [tap-repo-name]"
    echo "Example: ./setup-homebrew-tap.sh 1.0.0"
    echo ""
    echo "This script will:"
    echo "1. Update the formula with the version"
    echo "2. Create a git tag"
    echo "3. Help you set up the tap repository"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMULA_FILE="$SCRIPT_DIR/Formula/fit.rb"

if [ ! -f "$FORMULA_FILE" ]; then
    echo "Error: $FORMULA_FILE not found"
    exit 1
fi

echo "Setting up Homebrew tap for version $VERSION..."
echo ""

cd "$SCRIPT_DIR"

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    exit 1
fi

echo "Step 1: Updating formula..."
sed -i.bak "s/version \".*\"/version \"$VERSION\"/" "$FORMULA_FILE"
sed -i.bak "s|url \".*\"|url \"https://github.com/marecht/fit/archive/refs/tags/v$VERSION.tar.gz\"|" "$FORMULA_FILE"
rm -f "$FORMULA_FILE.bak"

echo "✓ Formula updated"
echo ""

echo "Step 2: Creating git tag..."
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
    echo "Tag v$VERSION already exists. Skipping..."
else
    read -p "Create tag v$VERSION? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git tag -a "v$VERSION" -m "Release version $VERSION"
        echo "✓ Tag created (local only)"
        echo "  Run 'git push origin v$VERSION' to push the tag"
    fi
fi
echo ""

echo "Step 3: Next steps to publish to Homebrew:"
echo ""
echo "1. Push the tag:"
echo "   git push origin v$VERSION"
echo ""
echo "2. Create or update the tap repository:"
echo "   - Create a repository named '$TAP_REPO' on GitHub"
echo "   - Clone it: git clone https://github.com/marecht/$TAP_REPO.git"
echo "   - Copy the formula: cp $FORMULA_FILE /path/to/$TAP_REPO/Formula/fit.rb"
echo ""
echo "3. Get the SHA256 hash:"
echo "   cd /path/to/$TAP_REPO"
echo "   brew fetch --build-from-source ./Formula/fit.rb"
echo "   (Copy the SHA256 from the output)"
echo ""
echo "4. Update the formula with the SHA256:"
echo "   Edit Formula/fit.rb and update the sha256 line"
echo ""
echo "5. Commit and push:"
echo "   git add Formula/fit.rb"
echo "   git commit -m 'Add fit formula v$VERSION'"
echo "   git push origin main"
echo ""
echo "6. Test installation:"
echo "   brew tap marecht/tap"
echo "   brew install fit"
echo ""
