# gnuplot specification to plot how many tasks were completed over time,
# differentiating goal/projects/other.
# Assumes data structure:
#   Date,Goals,Projects,Others
#   2019-02-03,0,0,1
#   2019-02-04,0,1,0 etc.
# uses Gnuplot 5.2, but would probaby work back to Gnuplot 4.8
# JGC, 23.9.2020
# TODO: Change the done_tasks to be last year only (in weeks)

FILENAME="~/task_done_dates.csv"
todays_date=system("date +%d.%m.%Y")

# version 1: stacked histogram
# set term png size 600, 400 font "Avenir,8"
# set datafile separator comma
# set style histogram rowstacked
# set style data histogram
# set style fill solid 1.0 noborder
# set border 3 # just bottom + left
# set key inside top right vertical box
# set key enhanced
# set key autotitle columnheader    
# set title 'When tasks were done' #(last 6 months)'
# set xlabel 'Date'
# set xtics rotate by 45 right # Make the x axis labels easier to read
# set yrange [0:10<*<20]  # y axis scales between 10 and 20 at most
# set output "donev1.png"
# plot for [COL=2:4] FILENAME using COL:xticlabels(1) title columnheader


# version 2: column stacked
# set term png size 600, 400 font "Avenir,8"
# set datafile separator comma
# set boxwidth 0.9 relative
# set style fill solid 1.0 border
# set border 3 # just bottom + left
# set key inside top right vertical nobox
# set key reverse enhanced
# set key autotitle columnheader    
# set title 'When tasks were done'
# set xtics rotate by 45 right nomirror # turn off top ticks
# set ytics nomirror
# set yrange [0:10<*<20]
# # do main plot, summing together first 2 types to make it look like proper stacked
# set output "donev2.png"
# plot FILENAME using 1:($4+$3+$2) with boxes lc rgb "light-green", \
#   "" using 1:($3+$2) with boxes lc rgb "blue", \
#   "" using 1:2 with boxes lc rgb "red"


# version 3: column stacked
# getting the X axis treated as dates properly
# set term png size 1200, 400 
# set datafile separator comma
# set boxwidth 0.9 relative
# set style fill solid 1.0 border
# set border 3 # just bottom + left
# set key inside top right vertical box
# set key reverse enhanced
# set key autotitle columnheader    
# set title 'When tasks were done (last 3 months)'
# set xdata time
# set timefmt "%Y-%m-%d"
# set format x "%d/%m/%y"
# set xtics rotate by 45 right nomirror
# set ytics nomirror
# set yrange [0:10<*<20]
# set output "donev3.png"
# # do main plot, summing together first 2 types to make it look like proper stacked
# plot "<(tail -n 90 ~/task_done_dates.csv)" using 1:($4+$3+$2) with boxes lc rgb "light-green", \
#   "<(tail -n 90 ~/task_done_dates.csv)" using 1:($3+$2) with boxes lc rgb "blue", \
#   "<(tail -n 90 ~/task_done_dates.csv)" using 1:2 with boxes lc rgb "red"


# version 4: column stacked, with number of entries to display
# set term png size 600, 400 font "Avenir,8"
# set datafile separator comma
# set boxwidth 0.9 relative
# set style fill solid 1.0 border
# set border 3 # just bottom + left
# set key inside top left vertical box
# set key reverse enhanced
# set key Left # as in left-algined; different from 'left' placement
# set key autotitle columnheader
# # use stats to count how many data items. every ::2 = starting row 2
# stats FILENAME every ::1 using 1 nooutput 
# rows = int(STATS_records)
# set title sprintf("When tasks were done (%d rows as at %s)", rows, todays_date)
# set xdata time
# set timefmt "%Y-%m-%d"
# set format x "%d.%m.%y"
# set xtics rotate by 45 right nomirror 
# set ytics nomirror
# set output "donev4.png"
# # do main plot, summing together first 2 types to make it look like proper stacked
# plot FILENAME using 1:($4+$3+$2) with boxes lc rgb "light-green", \
#   "" using 1:($3+$2) bins=50 with boxes lc rgb "blue", \
#   "" using 1:2 bins=50 with boxes lc rgb "red"

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
set title sprintf("How many tasks completed (%d weeks up to %s)", bins_to_use, todays_date) font "Avenir,10"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%b %y"
set xtics scale 1,0 out center nomirror 
set ytics scale 1,0 out nomirror 
# do main plot, summing together first 2 types to make it look like proper stacked
set output "done_tasks.png"
plot FILENAME using 1:($4+$3+$2) bins=bins_to_use with boxes lc rgb "light-green", \
  "" using 1:($3+$2) bins=bins_to_use with boxes lc rgb "blue", \
  "" using 1:2 bins=bins_to_use with boxes lc rgb "red"

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
#
# I raised PR to allow *last* n entries (https://sourceforge.net/p/gnuplot/feature-requests/508/)
# which got the reply to STATS first to count the number of rows and then using every from that


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
