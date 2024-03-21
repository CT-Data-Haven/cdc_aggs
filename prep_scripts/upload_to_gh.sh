#!/usr/bin/env bash

# metadata to use in other projects
yr=$1
files=$2

tag="v$yr"

# does github release with this tag exist?
tagged=$(gh release list --json tagName --jq '.[] | select(.tagName == "$tag") | ."tagName"')
# does tagged have length?
if [ -z "$tagged" ]; then
  echo "Creating release $tag"
  gh release create $tag $files \
    --title "Neighborhood profiles data and wide-shaped CSV for CDC's $yr release" \
    --notes ""
else
  echo "Updating release $tag"
  gh release upload $tag $files --clobber
fi

gh release view $tag
