# gnuplot specification to plot charts of mentions over time
# Assumes data structure:
#   # Title...
#   ## Subtitle ...
#   @run
#   2021-04-01,1,5.5,5.5
#   2021-04-08,2,10,5
#   2021-04-15,1,6,6
#
#
#   #friends
#   2021-04-01,0
#   2021-04-08,2
#   2021-04-15,2
#
#
# - i.e. with 2 blank lines between data blocks
# - single blank lines indicating missing data
# uses Gnuplot 5.2, but would probaby work back to Gnuplot 4.8
# JGC, 30.10.2021

DATAFILE="/Users/jonathan/Dropbox/NPSummaries/weekly_stats.md"
todays_date=system("date +%d.%m.%Y")

set term png size 800, 360 font "arial,11"
set datafile separator ","
set datafile commentschars "#"
# stats DATAFILE skip 1 nooutput # calc stats to determine number of indices, but don't show to screen
# TITLE = system("awk 'NR==1 {print substr($0,4); exit} ' < ".DATAFILE)
# TITLE = sprintf("Weekly Stats for %d-%d (with %d data sets)", STATS_min_x, STATS_max_x, STATS_blocks + 1)
TITLE = 'Weekly Stats (up to '.todays_date.')'
set title TITLE
# set title sprintf("Weekly stats", todays_date) font "Arial:Bold,12"
set border 3 # just bottom + left
# set key inside bottom left vertical box
# set key font "arial,10"
# set key enhanced 
# set key spacing 1.2 # line spacing in key
# set key height 1 # increase height a little
# set key autotitle columnheader
# set linetype 1 lw 2 lc rgb "blue" pointtype 6
# set linetype 2 lw 2 lc rgb "forest-green" pointtype 8
# set title '{/Arial:Bold=14 Monthly \@mentions averages}'
# getting the X axis treated as dates properly
set timefmt "%Y-%m-%d" # format of dates in the input
set xdata time
set yrange [0:*]
set xtics format "%b\n%Y" # seems more flexible than set xtics x "..."
set xtics nomirror
unset mxtics # turns off minor tic marks
set ytics nomirror
# set timestamp "%d.%m.%Y %H:%M" bottom rotate font "arial,10"
set output "/Users/jonathan/Dropbox/NPSummaries/mentions.png"
# plot for [INDEX = 0:STATS_blocks-1] DATAFILE index INDEX \
plot for [IDX = 0:*] DATAFILE index IDX using 1:2 with lines lw 3 title columnheader(1) at end

#-----------------
# Other notes:
# - can have a here-file: $mydata << END // ... // .. // ... // END
#   which then is referenced by plot $mydata using ...
# - every 1::1::30 = first 30 entries
# - can refer to columns by "header_name" not just number
# - useful note about getting x axis as dates: http://psy.swansea.ac.uk/staff/carter/gnuplot/gnuplot_time_histograms.htm
# - way of addinfg timestamp to output: 
#   set timestamp "%d.%m.%Y" {top|bottom} {{no}rotate} {offset <xoff>{,<yoff>}}  {textcolor <colorspec>}
#   show timestamp
