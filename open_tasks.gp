# gnuplot specification to plot how many open tasks there are over time,
# differentiating goal/projects/area/other.
# Also plot % tasks completed for each type.
# Uses Gnuplot, and needs to be 5.x or later.
# JGC, 2026-06-14

# Expected CSV header row:
# Timestamp,GoalNotes,ProjectNotes,AreaNotes,OtherNotes,GoalDone,GoalOverdue,GoalUndated,GoalWaiting,GoalFuture,ProjectDone,ProjectOverdue,ProjectUndated,ProjectWaiting,ProjectFuture,AreaDone,AreaOverdue,AreaUndated,AreaWaiting,AreaFuture,OtherDone,OtherOverdue,OtherUndated,OtherWaiting,OtherFuture,TotalDone,TotalOverdue,TotalUndated,TotalWaiting,TotalFuture

FILENAME="/Users/jonathan/Dropbox/NPSummaries/task_stats_to_graph.csv"
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
set term png size 800, 567 font "Avenir,9"
set datafile separator comma columnheader
set border 3 lw 1 # left+bottom only (avoid boxed panels)
set key inside left center nobox
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
set style line 7 lw 1 lc rgb "gray" dashtype "--   " # non-purple line style for Goals/Projects/Areas open notes
set style line 8 lw 3 lc rgb "purple"
set style line 9 lw 1 lc rgb "violet"
set style line 10 lw 1 lc rgb "gray" dashtype "--   " # percent complete for the Other pane
set tmargin 0
set bmargin 2
set lmargin 6
set rmargin 3
set output "/Users/jonathan/Dropbox/NPSummaries/open_tasks.png"
set y2range [0:100]
set multiplot title sprintf("Open tasks in NotePlan (at %s)", date) font "Avenir,12" layout 4,1 downwards spacing 0,0

plot FILENAME using "Timestamp":(column("GoalOverdue")+column("GoalUndated")+column("GoalWaiting")) with lines ls 1 axes x1y1 title '# Goal tasks open', \
  "" using "Timestamp":"GoalNotes" with lines ls 7 axes x1y1 title '# Goals open', \
  "" using "Timestamp":(column("GoalDone")/(column("GoalDone")+column("GoalOverdue")+column("GoalUndated")+column("GoalWaiting"))*100) with lines ls 2 axes x1y2 title '% tasks complete'
plot FILENAME using "Timestamp":(column("ProjectOverdue")+column("ProjectUndated")+column("ProjectWaiting")) with lines ls 3 axes x1y1 title '# Project tasks open', \
  "" using "Timestamp":"ProjectNotes" with lines ls 7 axes x1y1 title '# Projects open', \
  "" using "Timestamp":(column("ProjectDone")/(column("ProjectDone")+column("ProjectOverdue")+column("ProjectUndated")+column("ProjectWaiting"))*100) with lines ls 4 axes x1y2 title '% tasks complete'
plot FILENAME using "Timestamp":(column("AreaOverdue")+column("AreaUndated")+column("AreaWaiting")) with lines ls 5 axes x1y1 title '# Area tasks open', \
  "" using "Timestamp":"AreaNotes" with lines ls 7 axes x1y1 title '# Areas open', \
  "" using "Timestamp":(column("AreaDone")/(column("AreaDone")+column("AreaOverdue")+column("AreaUndated")+column("AreaWaiting"))*100) with lines ls 6 axes x1y2 title '% tasks complete'
set xtics out nomirror font ",8"
set yrange [0:*]
plot FILENAME using "Timestamp":(column("OtherOverdue")+column("OtherUndated")+column("OtherWaiting")) with lines ls 8 axes x1y1 title '# Other tasks open', \
  "" using "Timestamp":"OtherNotes" with lines ls 9 axes x1y1 title '# Other open notes', \
  "" using "Timestamp":(column("OtherDone")/(column("OtherDone")+column("OtherOverdue")+column("OtherUndated")+column("OtherWaiting"))*100) with lines ls 10 axes x1y2 title '% tasks complete'
unset multiplot
