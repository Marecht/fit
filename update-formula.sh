#!/bin/bash

VERSION=$1

if [ -z "$VERSION" ]; then
    echo "Usage: ./update-formula.sh <version>"
    echo "Example: ./update-formula.sh 1.0.0"
    exit 1
fi

FORMULA_FILE="Formula/fit.rb"

if [ ! -f "$FORMULA_FILE" ]; then
    echo "Error: $FORMULA_FILE not found"
    exit 1
fi

echo "Updating formula to version $VERSION..."

sed -i "s/version \".*\"/version \"$VERSION\"/" "$FORMULA_FILE"
sed -i "s|url \".*\"|url \"https://github.com/marecht/fit/archive/refs/tags/v$VERSION.tar.gz\"|" "$FORMULA_FILE"

echo "Formula updated!"
echo ""
echo "Next steps:"
echo "1. Tag the release: git tag -a v$VERSION -m \"Release version $VERSION\" && git push origin v$VERSION"
echo "2. Get SHA256: brew fetch --build-from-source ./$FORMULA_FILE"
echo "3. Update sha256 in $FORMULA_FILE"
echo "4. Commit and push the tap repository"
