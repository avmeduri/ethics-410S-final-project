# Script to prepare data for the geographic and media coverage dashboard
# This script processes CCC data for protest geography, media coverage, and organizational analysis

# Load the preparation function
source(file.path("R", "prep_geographic_media_data.R"))

# Run the data preparation
cat("Preparing geographic and media coverage data...\n")
result <- prep_geographic_media_data()

cat("Data preparation complete!\n")
cat("Prepared data files are available in:", result, "\n")
cat("\nTo run the dashboard:\n")
cat("shiny::runApp('app.R', port=3838)\n")
