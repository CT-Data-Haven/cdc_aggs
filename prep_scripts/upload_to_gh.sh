#!/usr/bin/env bash

# metadata to use in other projects
# assign first argument to yr, remaining arguments to files
yr=$1
shift
files=$@

tag="v$yr"

# does github release with this tag exist?
tagged=$(gh release list \
  --repo CT-Data-Haven/cdc_aggs \
  --json tagName --jq '.[] | ."tagName"' | \
  grep "$tag")
echo "tagged: $tagged"
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
