#!/bin/bash
set -e

VERSION=$(grep '@version "' mix.exs | sed 's/.*"\(.*\)".*/\1/')

if [ -z "$VERSION" ]; then
  echo "Error: Could not extract version from mix.exs"
  exit 1
fi

echo "Releasing v$VERSION"

if ! grep -q "## \[$VERSION\]" CHANGELOG.md; then
  echo "Error: Version $VERSION not found in CHANGELOG.md"
  echo "Please update CHANGELOG.md before releasing."
  exit 1
fi

if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  echo "Error: Tag v$VERSION already exists"
  exit 1
fi

echo "Running tests..."
mix test

echo "Creating tag v$VERSION..."
git tag "v$VERSION"

echo "Pushing commits and tags..."
git push
git push --tags

echo "Publishing to hex.pm..."
mix hex.publish

echo "Released v$VERSION successfully!"
