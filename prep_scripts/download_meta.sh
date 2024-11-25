#!/usr/bin/env bash

# get xwalks from scratchpad
gh release download xwalks \
    --repo CT-Data-Haven/scratchpad \
    --pattern "tract_to_legislative.rds" \
    --dir utils \
    --clobber

# get cdc_indicators from scratchpad
gh release download meta \
    --repo CT-Data-Haven/scratchpad \
    --pattern "cdc_indicators.txt" \
    --dir utils \
    --clobber

# reg puma list from towns
gh release download metadata \
    --repo CT-Data-Haven/towns2023 \
    --pattern "reg_puma_list.rds" \
    --dir utils \
    --clobber