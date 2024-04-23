library(dplyr)
library(readr)
library(purrr)
library(stringr)
library(tibble)
library(tidyr)
library(forcats)
library(cwi)

############# META
# hosp_regs <- readRDS("utils/hospital_areas_list.rds")
# includes hospitals
# extra_regs <- readRDS("utils/misc_regions_list.rds")
# reg_puma_list downloaded from towns2023 release
if (exists("snakemake")) {
  places_release <- snakemake@params[["year"]]
} else {
  places_release <- readLines("utils/release_year.txt")[1]
}
cli::cli_h1("CDC Places {places_release} release")
# places_release <- readLines("utils/release_year.txt")
reg_puma_list <- readRDS("utils/reg_puma_list.rds")
meta <- read_csv("utils/cdc_indicators.txt", show_col_types = FALSE)
nhood_wts <- lst(new_haven_tracts19, bridgeport_tracts19, hartford_tracts19, stamford_tracts19) |>
  set_names(str_remove, "_tracts.+") |>
  set_names(camiller::clean_titles, cap_all = TRUE) |>
  bind_rows(.id = "city")

# still uses pre-2020 tracts, but cwi data is updated already
tract10_to_town <- readRDS("utils/tract10_to_town.rds") |>
  rename(tract = tract10)
tract2reg <- bind_rows(
  enframe(reg_puma_list, value = "town") |>
    unnest(town),
  distinct(cwi::xwalk, county, town) |>
    rename(name = county)
) |>
  inner_join(tract10_to_town, by = "town", relationship = "many-to-many") |>
  distinct(name, tract)

pops15 <- tidycensus::get_acs("tract", table = "B01003", year = 2015, state = "09", cache_table = TRUE) |>
  janitor::clean_names() |>
  select(geoid, pop = estimate)

############# PLACES, FKA 500 CITIES ----
# seems like this url always has most recent release; previous releases get moved out to different dataset
places_url <- "https://data.cdc.gov/resource/cwsq-ngmh.csv"
places_q <- list("$select" = "year, categoryid as topic, short_question_text as question, locationname as geoid, data_value as value, totalpopulation as pop",
                 "$where" = "stateabbr='CT'",
                 "$limit" = "50000")
places <- httr::GET(places_url, query = places_q) |>
  httr::content() |>
  as_tibble() |>
  mutate(question = camiller::clean_titles(question),
         value = value / 100) |>
  semi_join(meta, by = c("question" = "display"))

pl_lvls <- list()
pl_lvls[["state"]] <- places |>
  mutate(name = "Connecticut")
pl_lvls[["region"]] <- places |>
  inner_join(tract2reg, by = c("geoid" = "tract"), relationship = "many-to-many")
# pl_lvls[["pumas"]] <- places |>
#   inner_join(tract2puma, by = c("geoid" = "tract")) |>
#   rename(name = puma_fips)
pl_lvls[["town"]] <- places |>
  left_join(tract10_to_town, by = c("geoid" = "tract")) |>
  rename(name = town)
pl_lvls[["neighborhood"]] <- places |>
  inner_join(nhood_wts, by = "geoid", relationship = "many-to-many") |>
  mutate(pop = pop * weight)
pl_lvls[["tract"]] <- places |>
  rename(name = geoid)
places_df <- bind_rows(pl_lvls, .id = "level") |>
  mutate(level = as_factor(ifelse(grepl("^\\d{7}$", name), "puma", level)),
         year = as.character(year)) |>
  group_by(topic, question, level, year, city, town, name) |>
  summarise(value = weighted.mean(value, pop)) |>
  ungroup() |>
  select(level, question, year, city, town, everything())


################ LIFE EXPECTANCY ----
life_exp <- read_csv("https://ftp.cdc.gov/pub/Health_Statistics/NCHS/Datasets/NVSS/USALEEP/CSV/CT_A.CSV") |>
  select(tract = 1, value = 5) |>
  mutate(year = "2010-2015", question = "Life expectancy") |>
  left_join(pops15, by = c("tract" = "geoid"))

life_lvls <- list()
life_lvls[["state"]] <- life_exp |>
  mutate(name = "Connecticut")
life_lvls[["region"]] <- life_exp |>
  inner_join(tract2reg, by = "tract")
# life_lvls[["pumas"]] <- life_exp |>
#   inner_join(tract2puma, by = "tract") |>
#   rename(name = puma_fips)
life_lvls[["town"]] <- life_exp |>
  left_join(tract10_to_town, by = "tract") |>
  rename(name = town)
life_lvls[["neighborhood"]] <- life_exp |>
  inner_join(nhood_wts, by = c("tract" = "geoid")) |>
  mutate(pop = pop * weight)
life_lvls[["tract"]] <- life_exp |>
  rename(name = tract)
life_df <- bind_rows(life_lvls, .id = "level") |>
  mutate(level = as_factor(ifelse(grepl("^\\d{7}$", name), "puma", level))) |>
  group_by(topic = "life_expectancy", question, level, year, city, town, name) |>
  summarise(value = weighted.mean(value, pop)) |>
  ungroup() |>
  select(level, question, year, city, town, everything())


####### BIND & OUTPUT
## TODO: don't round to 2 digits for small values---use signif?
out_df <- lst(
  life_df |> mutate(value = round(value, 1)),
  places_df |> mutate(value = signif(value, 2))
) |>
  bind_rows() |>
  mutate(
    topic = as_factor(topic)
  ) |>
  select(topic, everything()) |>
  arrange(topic, question, city, level)
rds_path <- str_glue("output_data/cdc_health_all_lvls_nhood_{places_release}.rds")
saveRDS(out_df, rds_path)

csv_path <- str_glue("output_data/cdc_health_all_lvls_wide_{places_release}.csv")
out_df |>
  select(-topic) |>
  pivot_wider(names_from = c(question, year)) |>
  write_csv(csv_path)
