library(dplyr)
library(data.table)
library(DT)



# set.seed(123)
# 
# # Define dataset size
# n <- 1000000  # 1 million rows
# 
# # Create the dataset
# large_data <- data.frame(
#   ID = 1:n,
#   Age = sample(18:65, n, replace = TRUE),
#   Income = round(rnorm(n, mean = 50000, sd = 15000), 0),
#   Education = sample(c("High School", "Bachelor", "Master", "PhD"), 
#                      n, replace = TRUE, prob = c(0.3, 0.4, 0.2, 0.1)),
#   Score = round(runif(n, min = 50, max = 100), 1)
# )
# 
# # Size of the dataframe
# object.size(large_data)      #/1024^2


#============================
#============================  For copying directly from file explorer the file path
#============================

df <- read.csv(r"(F:\NCRM\2_Jan2026 Training\data\big5_personality_traits.csv)")

#============================
#============================
#============================




# ===================================================
# 1. data.table vs dplyr for join operation
# ===================================================

# Load libraries
library(data.table)
library(dplyr)



# -------------------------------
# Create big tables
# -------------------------------
set.seed(123)
n <- 1000000      #1e6  # 1 million rows

# data.table version
DT1 <- data.table(id = 1:n, x = rnorm(n))
DT2 <- data.table(id = sample(1:n), y = rnorm(n))

# tibble version for dplyr
df1 <- as_tibble(DT1)
df2 <- as_tibble(DT2)

# -------------------------------
#  Define join functions
# -------------------------------

# data.table join (left join)
setkey(DT1, id)
setkey(DT2, id)
result_dt <- DT1[DT2, on = "id"]

# dplyr join (left join)
result_dplyr <- left_join(df1, df2, by = "id")

-------------------------------
  # data.table join timing
  # -------------------------------
setkey(DT1, id)
setkey(DT2, id)

cat("Running data.table join...\n")
start_dt <- Sys.time()
result_dt <- DT1[DT2, on = "id"]
end_dt <- Sys.time()
cat("data.table join time:", end_dt - start_dt, "\n")

# -------------------------------
# dplyr join timing
# -------------------------------
cat("Running dplyr join...\n")
start_dplyr <- Sys.time()
result_dplyr <- left_join(df1, df2, by = "id")
end_dplyr <- Sys.time()
cat("dplyr join time:", end_dplyr - start_dplyr, "\n")




# ===================================================
# 2. base and readr in chunks for huge files
# ===================================================

library(readr)

file_path <- "covid/covid_global.csv"

# -------------------------------
# Using base R read.csv
# -------------------------------
start_base <- Sys.time()
df_base <- read.csv(file_path)
end_base <- Sys.time()
cat("Time using read.csv:", end_base - start_base, "\n")
class(df_base)
# -------------------------------
# Using readr read_csv
# -------------------------------
start_readr <- Sys.time()
df_readr <- read_csv(file_path)
end_readr <- Sys.time()
cat("Time using readr::read_csv:", end_readr - start_readr, "\n")
class(df_readr)


### For Write operation
# Base
start_base_write <- Sys.time()
write.csv(df_base, "covid/covid_global_base.csv", row.names = FALSE)
end_base_write <- Sys.time()
cat("Time writing CSV (base R):", end_base_write - start_base_write, "\n")

# readr
start_readr_write <- Sys.time()
write_csv(df_readr, "covid/covid_global_readr.csv")
end_readr_write <- Sys.time()
cat("Time writing CSV (readr):", end_readr_write - start_readr_write, "\n")





# ===================================================
# 3. Advantage of Arrow
# ===================================================

# Can process data larger than RAM with memory mapping

library(arrow)
library(dplyr)

# Using Arrow to read as a dataset 
ds <- open_dataset("covid/covid_global.csv", format = "csv")

# Filter using dplyr syntax without loading full dataset
result <- ds %>%
  filter(location == "Brazil") %>%
  select(total_cases, date) %>%
  collect()  # only now loads into memory

head(result)

## Save data frame as parquet file
file_path <- "covid/covid_global.csv"
df_readr <- read_csv(file_path)
write_parquet(df_readr, "covid/covid_global.parquet")


# -------------------------------
# Process CSV using Arrow
# -------------------------------
csv_file <- "covid/covid_global.csv"
ds_csv <- open_dataset(csv_file, format = "csv")


start_csv <- Sys.time()
result_csv <- ds_csv %>%
  filter(location == "Brazil") %>%
  select(total_cases, date) %>%
  collect()  # triggers actual reading
end_csv <- Sys.time()
cat("Time to filter CSV:", end_csv - start_csv, "\n")

# -------------------------------
# Process Parquet using Arrow
# -------------------------------
parquet_file <- "covid/covid_global.parquet"
ds_parquet <- open_dataset(parquet_file, format = "parquet")

start_parquet <- Sys.time()
result_parquet <- ds_parquet %>%
  filter(location == "Brazil") %>%
  select(total_cases, date) %>%
  collect()  # triggers actual reading
end_parquet <- Sys.time()
cat("Time to filter Parquet:", end_parquet - start_parquet, "\n")





# ===================================================
# 4. Parallel vs Sequential Processing
# For even 1 million row daat set parallel processing 
# is not a good practice
# ===================================================


library(dplyr)
library(parallel)
library(readr)


# -------------------------------
# Create 1 million row dataset
# -------------------------------
set.seed(123)
n <- 1e6
demo_data <- data.frame(
  id = 1:n,
  location = sample(c("Brazil", "UK", "India", "Ethiopia", "China", "Spain"), n, replace = TRUE),
  total_cases = round(runif(n, 1000, 1000000)),
  date = seq.Date(from = as.Date("2020-01-01"), by = "day", length.out = n)
)

# -------------------------------
# Define processing function
# -------------------------------
process_chunk <- function(df) {
  df %>%
    filter(location == "Brazil") %>%
    mutate(total_cases_scaled = total_cases / max(total_cases, na.rm = TRUE))
}

# -------------------------------
# Split into 4 chunks
# -------------------------------
chunks <- split(demo_data, cut(seq_len(nrow(demo_data)), 4, labels = FALSE))

# -------------------------------
# Sequential processing
# -------------------------------
start_seq <- Sys.time()
seq_final <- NULL
for (chunk in chunks) {
  processed <- process_chunk(chunk)
  seq_final <- rbind(seq_final, processed)
}
seq_time <- as.numeric(Sys.time() - start_seq)
cat("Sequential processing time (s):", seq_time, "\n")

# -------------------------------
# Parallel processing (6 cores)
# -------------------------------
start_par <- Sys.time()
cl <- makeCluster(6)
clusterExport(cl, "process_chunk")
clusterEvalQ(cl, library(dplyr))
par_results <- parLapply(cl, chunks, process_chunk)
stopCluster(cl)
par_final <- do.call(rbind, par_results)
par_time <- as.numeric(Sys.time() - start_par)
cat("Parallel processing time (s):", par_time, "\n")





# ===================================================
# 5. Base R plot with par()
# ===================================================

# Use mtcars dataset
data(mtcars)

# Set layout for 2x2 plots
par(mfrow = c(2,2), mar = c(4,4,6,1))  # 2x2 grid, margins

# -------------------------------
# Scatterplot: mpg vs wt
# -------------------------------
plot(mtcars$wt, mtcars$mpg,
     main = "Scatterplot: MPG vs Weight",
     xlab = "Weight (1000 lbs)", ylab = "Miles/Gallon",
     pch = 19, col = "blue")

# # Locally Weighted Scatterplot Smoothing
# lines(lowess(mtcars$wt, mtcars$mpg),  
#       col = "red",
#       lwd = 2)

# -------------------------------
# Histogram: mpg
# -------------------------------
hist(mtcars$mpg,
     main = "Histogram of MPG",
     xlab = "Miles/Gallon",
     col = "lightgreen", border = "black")

# -------------------------------
# Boxplot: mpg by cyl
# -------------------------------
boxplot(mpg ~ cyl, data = mtcars,
        main = "Boxplot: MPG by Cylinders",
        xlab = "Cylinders", ylab = "Miles/Gallon",
        col = "orange")

# -------------------------------
# Barplot: count of cars by gear
# -------------------------------
barplot(table(mtcars$gear),
        main = "Barplot: Cars by Gears",
        xlab = "Gears", ylab = "Count",
        col = "purple")

# -------------------------------
# Overall title
# -------------------------------
mtext("MTCars: Multiple Plots", outer = TRUE, line = -2, cex = 1.5)





# ===================================================
# 6. ggplot
# ===================================================

# Use mtcars dataset
data(mtcars)

library(ggplot2)

# Scatterplot: mpg vs wt
ggplot(mtcars, aes(x = wt, y = mpg)) +
  geom_point(color = "red") +
  labs(title = "Scatterplot: MPG vs Weight",
       x = "Weight (1000 lbs)",
       y = "Miles/Gallon") 
  # theme_minimal()         


table(mtcars$cyl)

# Scatterplot with facet_wrap
g1 <- ggplot(mtcars, aes(x = wt, y = mpg)) +
  geom_point(color = "blue") +
  facet_wrap(~ cyl) +
  labs(title = "Scatterplot of MPG vs Weight by Cylinders",
       x = "Weight (1000 lbs)",
       y = "Miles/Gallon")

g1

# Save file
ggsave("covid/custom_ggplot.png",          # filename
       plot = g1,                 # plot to save
       width = 10,                         # width in inches
       height = 6,                         # height in inches
       dpi = 300)                          # resolution



# ===================================================
# 7. plotly
# ===================================================
library(plotly)

ggplotly(g1)



# 3D scatterplot
plot_ly(mtcars, 
        x = ~wt, 
        y = ~mpg, 
        z = ~hp, 
        type = "scatter3d", 
        mode = "markers",
        marker = list(size = 5, color = ~cyl, colorscale = "Viridis", showscale = TRUE)) %>%
  layout(title = "3D Scatterplot: MPG vs Weight vs HP",
         scene = list(
           xaxis = list(title = "Weight (1000 lbs)"),
           yaxis = list(title = "Miles/Gallon"),
           zaxis = list(title = "Horsepower")
         ))


#==================================================
# Date formats
#==================================================

library(lubridate)

# Example data with different formats
dates <- c(
  "2026-02-11 14:30:00",
  "11/02/2026 2:30 PM",
  "Feb 11, 2026 14:30",
  "2026/02/11"
)

# Convert to proper datetime format
parsed_dates <- parse_date_time(
  dates,
  orders = c("ymd HMS", "dmy IMp", "b d, Y HM", "ymd")
)

# Extract components
date_only  <- as_date(parsed_dates)
time_only  <- format(parsed_dates, "%H:%M:%S")
day        <- day(parsed_dates)
month      <- month(parsed_dates)
month_name_short <- month(parsed_dates, label = TRUE, abbr = TRUE)
year       <- year(parsed_dates)

# Combine into a data frame
result <- data.frame(
  original = dates,
  parsed = parsed_dates,
  date = date_only,
  time = time_only,
  day = day,
  month = month,
  month_name = month_name_short,
  year = year
)

print(result)




# ===================================================
# 8. Geospatial
# ===================================================

library(sf)
# data source : https://diva-gis.org/data.html
library(rnaturalearth)
library(leaflet)
library(mapview)


boun1 <- st_read("covid/DZA_adm/DZA_adm1.shp")
boun2 <- st_read("covid/DZA_adm/DZA_adm2.shp")
plot(boun1$geometry) 




plot(st_geometry(boun2),
     col = "lightblue", border = "red")

plot(st_geometry(boun1),
     col = NA, border = "black", add = TRUE, 
     main = "ADM2 regions inside ADM1 (Algeria)")




# Create simple point features manually
points_data <- data.frame(
  name = c("London", "Paris", "Berlin", "Madrid", "Rome"),
  population = c(8982000, 2161000, 3645000, 3223000, 2873000),
  lon = c(-0.1278, 2.3522, 13.4050, -3.7038, 12.4964),
  lat = c(51.5074, 48.8566, 52.5200, 40.4168, 41.9028)
)

# Convert to sf object
cities_sf <- st_as_sf(points_data, 
                      coords = c("lon", "lat"), 
                      crs = 4326)  # WGS84 coordinate system


# Get world country boundaries from Natural Earth
world <- ne_countries(scale = "medium", returnclass = "sf")


plot(world$geometry)
plot(cities_sf$geometry, add = TRUE, col = "red", cex = 2, pch = 16)


# Create simple point features manually
points_data <- data.frame(
  name = c("London", "Paris", "Berlin", "Madrid", "Rome"),
  population = c(8982000, 2161000, 3645000, 3223000, 2873000),
  lon = c(-0.1278, 2.3522, 13.4050, -3.7038, 12.4964),
  lat = c(51.5074, 48.8566, 52.5200, 40.4168, 41.9028)
)

# Convert to sf object
cities_sf <- st_as_sf(points_data, 
                      coords = c("lon", "lat"), 
                      crs = 4326)  # WGS84 coordinate system


# Get world country boundaries from Natural Earth
world <- ne_countries(scale = "medium", returnclass = "sf")


plot(world$geometry)
plot(cities_sf$geometry, add = TRUE, col = "red", cex = 2, pch = 16)






# ===================================================
# 9. Simple interactive map (mapview)
# ===================================================


# Simple interactive map (leaflet)
leaflet(data = cities_sf) %>%
  addTiles() %>%  # Add default OpenStreetMap tiles
  addMarkers(popup = ~name)



mapview(world) + 
  mapview(cities_sf, zcol = "population") 
  # mapview(cities_sf, cex = "population", col.regions = "red") +
  # mapview(boun2, col.regions = "green")















# ===================================================
# 10. Shiny
# ===================================================
# library(shiny)
# 
# ui <- fluidPage(
#   
#   titlePanel("Simple Iris Plot App"),
#   
#   sidebarLayout(
#     sidebarPanel(
#       selectInput(
#         inputId = "plot_type",
#         label = "Choose plot type:",
#         choices = c("Scatterplot", "Histogram", "Boxplot")
#       )
#     ),
#     
#     mainPanel(
#       plotOutput("plot")
#     )
#   )
# )
# 
# server <- function(input, output) {
#   
#   output$plot <- renderPlot({
#     
#     if (input$plot_type == "Scatterplot") {
#       plot(iris$Sepal.Length, iris$Petal.Length,
#            main = "Scatterplot: Sepal vs Petal Length",
#            xlab = "Sepal Length",
#            ylab = "Petal Length",
#            col = "blue", pch = 19)
#       
#     } else if (input$plot_type == "Histogram") {
#       hist(iris$Sepal.Length,
#            main = "Histogram of Sepal Length",
#            xlab = "Sepal Length",
#            col = "lightgreen")
#       
#     } else if (input$plot_type == "Boxplot") {
#       boxplot(Sepal.Length ~ Species, data = iris,
#               main = "Boxplot of Sepal Length by Species",
#               xlab = "Species",
#               ylab = "Sepal Length",
#               col = "orange")
#     }
#   })
# }
# 
# shinyApp(ui = ui, server = server)
# 
# 
# 
# #===================================================
# 
# 
# 
# library(shiny)
# 
# ui <- fluidPage(
#   
#   titlePanel("Random Scatterplot App"),
#   
#   sidebarLayout(
#     sidebarPanel(
#       
#       sliderInput(
#         inputId = "n_points",
#         label = "Number of points:",
#         min = 10,
#         max = 500,
#         value = 100,
#         step = 10
#       ),
#       
#       selectInput(
#         inputId = "point_color",
#         label = "Point color:",
#         choices = c("blue", "red", "green", "purple", "black")
#       ),
#       
#       checkboxInput(
#         inputId = "show_lowess",
#         label = "Add LOWESS curve",
#         value = FALSE
#       )
#     ),
#     
#     mainPanel(
#       plotOutput("scatter_plot", height = "600px")
#     )
#   )
# )
# 
# server <- function(input, output) {
#   
#   output$scatter_plot <- renderPlot({
#     
#     # Create random data
#     set.seed(123)
#     df <- data.frame(
#       x = rnorm(input$n_points),
#       y = rnorm(input$n_points)
#     )
#     
#     # Scatter plot
#     plot(df$x, df$y,
#          pch = 19,
#          col = input$point_color,
#          main = "Random Scatterplot",
#          xlab = "X",
#          ylab = "Y")
#     
#     # Add LOWESS if checked
#     if (input$show_lowess) {
#       lines(lowess(df$x, df$y), col = "red", lwd = 2)
#     }
#   })
# }
# 
# shinyApp(ui = ui, server = server)


