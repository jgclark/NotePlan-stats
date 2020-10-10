# gnuplot specification to plot net number of tasks completed vs added over time,
# differentiating goal/projects/other.
# Assumes data structure:
#   Date,Added Goals,Added Projects,Added Others, Done Goals, Done Projects, Done Others, total net G, total net P, total net O
#   2020-09-20,0,2,0, 0,3,1, 0,1,1
#   2020-09-22,0,1,0, 0,0,2, 0,0,3 etc.
# uses Gnuplot 5.2, but would probaby work back to Gnuplot 4.8
# JGC, 26.9.2020
# TODO: If negative added tasks, then treat as zero

DATAFILE="~/tasks_net.csv"
todays_date=system("date +'%e %b %Y'")

# column stacked, and now summarised using week-long 'bins'
reset # reset all things set by 'set' command, apart from term
# clear # clear the current output device. Is this needed?
set term png size 800, 400 font "Avenir,9"
set datafile separator comma
set boxwidth 1.0 relative
set style fill solid 1.0 border
set border 3 # just bottom + left
set key inside bottom center vertical box font "Avenir,10" 
set key maxrows 3 maxcols 3
set key reverse enhanced
set key Left # as in left-algined; different from 'left' placement
# set key autotitle columnheader
# use stats to count how many data items
stats DATAFILE every ::1 using 1 nooutput
rows = int(STATS_records)+1
date_range = (strptime("%Y-%m-%d",sprintf("%d",STATS_max)) - strptime("%Y-%m-%d", sprintf("%d",STATS_min)))/60/60/24
bins_to_use = rows / 7
# bins_to_use = 8 # 91 #date_range / 7
set title sprintf("Net tasks completed vs added (%d weeks to %s)", bins_to_use, todays_date) font "Avenir,12"
set xdata time
set yrange [-100:*]
set timefmt "%Y-%m-%d"
set format x "%d %b %y"
set xtics scale 1,0 out center nomirror 
set ytics scale 1,0 out nomirror
set xzeroaxis
show xzeroaxis
# do main plot, summing together first 2 types to make it look like proper stacked
set output "net_tasks.png"
plot DATAFILE using 1:($5+$6+$7) bins=bins_to_use with boxes lc "#40ee40" title "Completed Other tasks",\
 "" using 1:($5+$6) bins=bins_to_use with boxes lc "#4d4df0" title "Completed Project tasks",\
 "" using 1:($5) bins=bins_to_use with boxes lc "#f04040" title "Completed Goal tasks",\
 "" using 1:(-$2-$3-$4) bins=bins_to_use with boxes lc "#90ee90" title "Added Other tasks",\
 "" using 1:(-$2-$3) bins=bins_to_use with boxes lc "#9090f0" title "Added Project tasks",\
 "" using 1:(-$2) bins=bins_to_use with boxes lc "#f0a2a2" title "Added Goal tasks",\
 "" using 1:10 with lines lw 2 lc "#10ce10" title "Cum. Other (net)",\
 "" using 1:9 with lines lw 2 lc "#1010f0" title "Cum. Project (net)",\
 "" using 1:8 with lines lw 2 lc "#c01010" title "Cum. Goal (net)"

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

