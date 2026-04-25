#!/bin/bash

echo "🚀 Starting Protest Visibility Dashboard..."
echo "Step 1: Installing dependencies..."
Rscript scripts/install_dashboard_deps.R

echo "Step 2: Preparing geographic and media data..."
Rscript scripts/prep_geographic_media_dashboard.R

echo "Step 3: Launching dashboard..."
echo "🌐 Dashboard will be available at: http://localhost:3838"
echo "Press Ctrl+C to stop the dashboard"
Rscript -e "shiny::runApp('app.R', port=3838)"
