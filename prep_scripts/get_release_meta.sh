#!/usr/bin/env bash
url="https://data.cdc.gov/resource/cwsq-ngmh.csv"
uuid=$(echo "$url" | grep -Eo "([a-z]{4}\-[a-z]{4})")
domain=$(echo "$url" | grep -Eo "^https?://[^/]+")
metaurl="$domain/api/views/metadata/v1/$uuid"
name=$(curl -s "$metaurl" | jq ".name")
year=$(echo "$name" | grep -Eo "[0-9]{4}")

echo "$year" > utils/release_year.txt