#!/usr/bin/sh
#
# Fetch data from a deye pv-inverter and weather data from wttr.in.
# Combine data inside a `.csv` file to see weather effects on
# solar power production.
#
# This script writes data to ~/.cache/pv/$date.csv.
# Data is then ploted to ~/.cache/pv/$date.png.

# Source config containing credentials, location, ip & path
source ./pv-power-analyze-config

# Get current power output [W] from pv-inverter via the html landing page.
get_pv_data() {
  pv_w=$(curl -u $INVERTER_USER:$INVERTER_PASSWORD "http://$INVERTER_IP/status.html" \
    | grep -oP 'var webdata_now_p = "([^"]*)"' \
    | grep -oE '[0-9]+')

  echo "$pv_w"
}

# Get weather from wttr.in. Response is json encoded. Just
# get the current weather condition.
get_wttr_data() {
  wttr=$(curl "wttr.in/$INVERTER_LOCATION?format=j1" \
    | jq ".current_condition.[]")
  temp_c=$(jq --raw-output ".temp_C" < $wttr)
  humidity=$(jq --raw-output ".humidity" < $wttr)
  uv_index=$(jq --raw-output ".uvIndex" < $wttr)
  cloud_cover=$(jq --raw-output ".cloudcover" < $wttr)

  echo "$temp_c, $humidity, $uv_index, $cloud_cover"
}

main() {
  test ! -d $PV_LOG_PATH && mkdir -p $PV_LOG_PATH
  test ! -f .config && echo "Configuration file not avaliable, exiting." && exit 1
  date=$(date +%d-%m-%y)
  time=$(date +%H:%M)
  pv_data=$(get_pv_data)
  wttr_data=$(get_wttr_data)

  echo "$time, $pv_data, $wttr_data" >> $PV_LOG_PATH/$date.csv
  
  # Use GNUplot to plot data and visualize it with a diagram.
  gnuplot < "
    set output \"$PV_LOG_PATH/$date.png\"

    set terminal png size 1920,1080
    set mytics 10
    set mxtics 6
    set timefmt \"%H:%M\"
    set xdata time
    set xrange [\"00:00\": \"23:50\"]
    set xtics \"01:00\"
    set pointsize 0.5
    
    set multiplot layout 3,1 title \"$date\"
    set yrange [0:750]
    set ylabel \"Power in [W]\"
    plot \
    \"$PV_LOG_PATH/$date.csv\" using 1:2 with linespoints pt 2 title \"Power in [W]\"

    set yrange [-25: 45]
    set ylabel \"Temperture in [°C], UV Index\"
    plot \
    \"$PV_LOG_PATH/$date.csv\" using 1:3 with linespoints pt 2 title \"Temperature in [°C]\" , \
    \"$PV_LOG_PATH/$date.csv\" using 1:5 with linespoints pt 2 title \"UV Index\"

    set yrange [0: 100]
    set ylabel \"Humidity in [%], Cloudcover\"
    set xlabel \"Time in [h]\"
    plot \
    \"$PV_LOG_PATH/$date.csv\" using 1:4 with linespoints pt 2 title \"Humidity in [%]\" , \
    \"$PV_LOG_PATH/$date.csv\" using 1:6 with linespoints pt 2 title \"Cloudcover\"
    unset multiplot
  "
}

main
