# gnuplot specification to plot net number of tasks completed vs added over time,
# differentiating goal/projects/other.
# Assumes data structure:
#   Date,Goals,Projects,Others
#   2019051,0,0,1
#   2019064,0,1,0 etc.
# uses Gnuplot 5.2, but would probaby work back to Gnuplot 4.8
# JGC, 13.9.2020
# TODO: Change the done_tasks to be last year only (in weeks)

#==================
# Use Done(today)-(Open(today)-Open(yesterday))
#==================

FILENAME="~/task_done_dates.csv"
todays_date=system("date +%d.%m.%Y")
year_ago_date=system("date -v-1y +%d.%m.%Y")
year_ago_ordinal=system("date -v-1y +%Y%j")

# version 5: column stacked, and now summarised using 14-day-long 'bins'
# tidied up X axis labels etc.
reset # reset all things set by 'set' command, apart from term
clear # clear the current output device. Is this needed?
set term png size 800, 300 font "Avenir,9"
set datafile separator comma
set boxwidth 0.9 relative
set style fill solid 1.0 border
set border 3 # just bottom + left
set key inside top left vertical nobox
set key reverse enhanced
set key Left # as in left-algined; different from 'left' placement
set key autotitle columnheader
# use stats to count how many data items
stats FILENAME every ::1 using 1 nooutput
rows = int(STATS_records)
date_range = (strptime("%Y%j",sprintf("%d",STATS_max)) - strptime("%Y%j", sprintf("%d",STATS_min)))/60/60/24
# TODO change to just the last year
bins_to_use = date_range/7
set title sprintf("Net tasks completed vs added (%d weeks up to %s)", bins_to_use, todays_date) font "Avenir,10"
set xdata time
set timefmt "%Y%j"
set format x "%b %y"
set xtics scale 1,0 out center nomirror 
set ytics scale 1,0 out nomirror 
# do main plot, summing together first 2 types to make it look like proper stacked
set output "done_tasks.png"
plot FILENAME using 1:($4+$3+$2) bins=bins_to_use with boxes lc rgb "light-green" #,\
#  "" using 1:($3+$2) bins=bins_to_use with boxes lc rgb "blue", \
#  "" using 1:2 bins=bins_to_use with boxes lc rgb "red"

exit

#-----------------
# Currently using hacky way of using just last 60 lines; it wouldn't work for data groups in same file:
#   plot for [COL=2:4] "<(tail -n 60 ~/task_done_dates.csv)" ...
#
# Attempt at using just last n rows of a file:
#   from https://stackoverflow.com/questions/9536582/gnuplot-plotting-data-from-a-file-up-to-some-row
#   also https://stackoverflow.com/questions/6564561/gnuplot-conditional-plotting-plot-col-acol-b-if-col-c-x)
# LINEMIN=100
# LINEMAX=130
# #create a function that accepts linenumber as first arg
# #and returns second arg if linenumber in the given range.
# InRange(x,y)=((x>=LINEMIN) ? ((x<=LINEMAX) ? y:1/0) : 1/0)

