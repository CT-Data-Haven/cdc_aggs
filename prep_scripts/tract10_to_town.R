sf::sf_use_s2(FALSE)

tract10_sf <- tigris::tracts(state = "09", year = 2019) |>
  dplyr::select(tract10 = GEOID)

tract10_to_town <- sf::st_join(
  tract10_sf,
  cwi::town_sf |> dplyr::select(town = name),
  largest = TRUE
) |>
  sf::st_drop_geometry()

saveRDS(tract10_to_town, file.path("utils", "tract10_to_town.rds"))