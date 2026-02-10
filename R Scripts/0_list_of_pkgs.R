#=============================================================================
#=============================================================================

# List of packages
packages <- c( "devtools", "remotes",
               "DT", "readr", "parallel",
              "arrow", "plotly", 
              "sf", "leaflet",
              "viridis", "rnaturalearth",
              "rnaturalearthdata", "shiny")

# Install packages that are not installed
new_packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new_packages)) install.packages(new_packages, dependencies = TRUE)

# Load all packages
lapply(packages, library, character.only = TRUE)

#=============================================================================
#=============================================================================
# https://r-spatial.github.io/mapview/
remotes::install_github("r-spatial/mapview")