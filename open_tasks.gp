# gnuplot specification to plot how many open tasks there are over time,
# differentiating goal/projects/other.
# Also plot % tasks completed for each type.
# uses Gnuplot 5.2, but would probaby work back to Gnuplot 4.8
# JGC, 12.9.2020
# TODO: change to just go back over last ?6 months?

FILENAME="/Users/jonathan/Dropbox/NPSummaries/task_stats.csv"
date=system("date +'%e %b %y'")

# version 1: line charts combined into one
# set term png size 600, 400 font "Avenir,9"
# set datafile separator comma
# set border 3 # just bottom + left
# set key inside center right vertical box
# set key enhanced
# set key autotitle columnheader    
# set title sprintf("Open tasks in NotePlan (to %s)", date)
# set xtics out nomirror # Make the x axis labels easier to read
# set xdata time
# set timefmt "%d %b %Y %H:%M"
# set format x "%d-%b-%y"
# set yrange [1:*]  # y axis scales between 10 and 20 at most
# set ytics out nomirror
# set style line 1 lw 3 lc rgb "red"
# set style line 2 lw 3 lc rgb "blue" 
# set style line 3 lw 3 lc rgb "green"
# set output "openv1.png"
# plot FILENAME using 1:($6+$7) with lines ls 1 title 'Goals',\
#   "" using 1:($11+$12) with lines ls 2 title 'Projects',\
#   "" using 1:($16+$17) with lines ls 3 title 'Others'


# version 2: line charts, but separately so can get better scaling
# set term png size 600, 400 font "Avenir,9"
# set datafile separator comma
# set border 3 # just bottom + left
# set key inside top left vertical box
# set key enhanced
# set key autotitle columnheader
# # set title sprintf("Open tasks in NotePlan (%s)", date)
# set xtics out nomirror # Make the x axis labels easier to read
# set xdata time
# set timefmt "%d %b %Y %H:%M"
# set format x "%b-%y"
# set yrange [0:*]  # automatic
# set ytics out nomirror
# set notitle
# set style line 1 lw 3 lc rgb "red"
# set style line 2 lw 3 lc rgb "blue"
# set style line 3 lw 3 lc rgb "green"
# set output "openv1.png"
# set multiplot title sprintf("Open tasks in NotePlan (%s)", date) font "Avenir,11" \
#   layout 2,1 downwards \
#   spacing 10,10
# plot FILENAME using 1:($6+$8) with lines ls 1 title 'Goals',\
#   "" using 1:($11+$13) with lines ls 2 title 'Projects'
# plot FILENAME using 1:($16+$18) with lines ls 3 title 'Others'
# unset multiplot


# version 3: using auto-layout of stacked plots
set term png size 800, 400 font "Avenir,9"
set datafile separator comma columnheader
set border 15 lw 1 # all
set key inside bottom left nobox
set key enhanced
# set key autotitle columnheader
stats FILENAME using 1 nooutput
set xdata time
set timefmt "%d %b %Y %H:%M" # format of the dates in the input
# We need to give xrange start and end dates explicitly as we are about to unset xaxis
# first_date = GPVAL_X_MIN # doesn't work as we haven't yet plotted anything
# first_date = STATS_min # doesn't work; trying STATS_min on timedata
first_date = system("head -n 2 " . FILENAME . " | tail -1 | cut -f 1 -d ','")
todays_date = system("date +'%d %b %Y %H:%M'") # today's date in current timefmt
set xrange [first_date:todays_date]
set format x "%b'%y"
unset xtics # unset for first two graphs. This appears to change xscale.
set yrange [0:*]  # automatic
set ytics out nomirror font ",8"
# set y2tics out nomirror font ",8" # turned this off as it's just %
set notitle
set style line 1 lw 3 lc rgb "red"
set style line 2 lw 1 lc rgb "light-red"
set style line 3 lw 3 lc rgb "blue"
set style line 4 lw 1 lc rgb "light-blue"
set style line 5 lw 3 lc rgb "green"
set style line 6 lw 1 lc rgb "light-green"
set style line 7 lw 1 lc rgb "gray" dashtype "--   " # TODO: make dashed (see manual p.42)
set tmargin 1
set bmargin 0
set lmargin 6
set rmargin 3
set output "/Users/jonathan/Dropbox/NPSummaries/open_tasks.png"
set multiplot layout 3,1 downwards \
  title sprintf("Open tasks in NotePlan (at %s)", date) font ",11"
set y2range [0:100]
plot FILENAME using 1:($6+$7+$8) with lines ls 1 axes x1y1 title '# Goal tasks open', \
  "" using 1:2 with lines ls 7 axes x1y1 title '# Goals open', \
  "" using 1:(($5)/($5+$6+$7+$8)*100) with lines ls 2 axes x1y2 title '% tasks complete'
set tmargin 0
plot FILENAME using 1:($11+$12+$13) with lines ls 3 axes x1y1 title '# Project tasks open', \
  "" using 1:3 with lines ls 7 axes x1y1 title '# Projects open', \
  "" using 1:(($10)/($10+$11+$12+$13)*100) with lines ls 4 axes x1y2 title '% tasks complete'
set bmargin 2
set xtics out nomirror font ",8"
set yrange [0:*]
plot FILENAME using 1:($16+$17+$18) with lines ls 5 axes x1y1 title '# Other tasks open', \
  "" using 1:4 with lines ls 7 axes x1y1 title '# Other open notes', \
  "" using 1:(($15)/($15+$16+$17+$18)*100) with lines ls 6 axes x1y2 title '% tasks complete'
unset multiplot
