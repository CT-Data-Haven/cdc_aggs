library(tidyverse)
library(cwi)

############# META
meta <- read_csv("utils/cdc_indicators.txt")
nhood_wts <- lst(new_haven = nhv_tracts, bridgeport_tracts, hartford_tracts, stamford_tracts) %>%
  set_names(str_remove, "_tracts") %>%
  set_names(camiller::clean_titles, cap_all = TRUE) %>%
  bind_rows(.id = "city") %>%
  select(-tract)
tract2reg <- cwi::regions[c("Greater New Haven", "Greater Hartford", "Fairfield County")] %>%
  enframe(value = "town") %>%
  unnest(town) %>%
  inner_join(tract2town, by = "town") %>%
  select(-town)

pops15 <- tidycensus::get_acs("tract", table = "B01003", year = 2015, state = "09") %>%
  janitor::clean_names() %>%
  select(geoid, pop = estimate)

############# PLACES, FKA 500 CITIES
places_url <- "https://chronicdata.cdc.gov/resource/cwsq-ngmh.csv"
places_q <- list("$select" = "year, short_question_text as question, locationname as geoid, data_value as value, totalpopulation as pop",
                 "$where" = "stateabbr='CT'",
                 "$limit" = "25000")
places <- httr::GET(places_url, query = places_q) %>%
  httr::content() %>%
  as_tibble() %>%
  mutate(question = camiller::clean_titles(question),
         value = value / 100) %>%
  semi_join(meta, by = c("question" = "display"))

pl_lvls <- list()
pl_lvls[["state"]] <- places %>%
  mutate(name = "Connecticut")
pl_lvls[["regions"]] <- places %>%
  inner_join(tract2reg, by = c("geoid" = "tract"))
pl_lvls[["towns"]] <- places %>%
  left_join(tract2town, by = c("geoid" = "tract")) %>%
  rename(name = town)
pl_lvls[["neighborhoods"]] <- places %>%
  inner_join(nhood_wts, by = "geoid") %>%
  mutate(pop = pop * weight)
pl_lvls[["tracts"]] <- places %>%
  rename(name = geoid)
places_df <- bind_rows(pl_lvls, .id = "level") %>%
  mutate(level = as_factor(level),
         year = as.character(year)) %>%
  group_by(question, level, year, city, town, name) %>%
  summarise(value = weighted.mean(value, pop)) %>%
  ungroup() %>%
  select(level, question, year, city, town, everything())


################ LIFE EXPECTANCY
life_exp <- read_csv("https://ftp.cdc.gov/pub/Health_Statistics/NCHS/Datasets/NVSS/USALEEP/CSV/CT_A.CSV") %>%
  select(tract = 1, value = 5) %>%
  mutate(year = "2010-2015", question = "Life expectancy") %>%
  left_join(pops15, by = c("tract" = "geoid"))

life_lvls <- list()
life_lvls[["state"]] <- life_exp %>%
  mutate(name = "Connecticut")
life_lvls[["regions"]] <- life_exp %>%
  inner_join(tract2reg, by = "tract")
life_lvls[["towns"]] <- life_exp %>%
  left_join(tract2town, by = "tract") %>%
  rename(name = town)
life_lvls[["neighborhoods"]] <- life_exp %>%
  inner_join(nhood_wts, by = c("tract" = "geoid")) %>%
  mutate(pop = pop * weight)
life_lvls[["tracts"]] <- life_exp %>%
  rename(name = tract)
life_df <- bind_rows(life_lvls, .id = "level") %>%
  mutate(level = as_factor(level)) %>%
  group_by(question, level, year, city, town, name) %>%
  summarise(value = weighted.mean(value, pop)) %>%
  ungroup() %>%
  select(level, question, year, city, town, everything())


####### BIND & OUTPUT
bind_rows(places_df, life_df) %>%
  write_csv("output_data/cdc_health_all_lvls_nhood_2020.csv")
