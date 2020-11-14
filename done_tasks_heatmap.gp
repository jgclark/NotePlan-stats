# gnuplot specification to plot a heatmap of completed tasks, based on the
# view of the year's activity in GitHub repositories.
# Also differentiates goal/projects/other.
# 
# Assumes data structure:
#   , week N, week N+1, week N+2, ...
#   Mon, tasks completed for that day in the week, ...
#   Tues, tasks completed for that day in the week, ...
#   ...
# JGC, 13.11.2020

DATAFILE="/Users/jonathan/Dropbox/NPSummaries/done_tasks_matrix.csv"
todays_date=system("date +'%e %b %Y'")

reset # reset all things set by 'set' command, apart from term
# clear # clear the current output device. Is this needed?
set term png size 800, 300 font "Avenir,9"

set datafile separator comma columnheaders
# set gradient through a 'palette', which are complex to understand (see manual p.180)
# useful discussion at https://stackoverflow.com/questions/64813524/set-color-to-grey-for-points-below-some-cutoff-when-plotting-with-palette-in-gnu
# also pointing to 'set palette defined ...' possibility rather than 'rgbformula'
# a few demos at http://gnuplot.sourceforge.net/demo/pm3dcolors.html
set palette rgbformula -9,2,-9 # = -sqrt(x), x, -sqrt(x) TODO look for other options
# settings for colour box (key, really)
set cbrange [0:*]
set cblabel "Completed tasks (Goals + Projects + Other)"
unset cbtics
# set X and Y axes. Need to use 'writeback' to make the settings stick on overlay
set xrange writeback
set yrange [6.5:-0.5] writeback # to get it displaying Mon->Sun not Sun->Mon down the page
# unset xtics
set xdata time
set timefmt "%d %b %Y" # format of the dates in the input
set format x "%d %b" # format of dates to show
# set xlabel rotate by -45 # FIXME: not doing anything
# set xmtics

# ---- PREVIOUS FILE TO USE and CLEAN UP ----

# use stats to count how many data items
rows = 26
# FIXME: stats DATAFILE matrix nooutput
# rows = int(STATS_size_x)-1
set title sprintf("Tasks completed (%d weeks to %s)", rows, todays_date) font ",12"
# set xdata time
# set yrange [-200<*:*<200] # autoscale Y axis, but with -200, 200 limits
# set timefmt "%Y-%m-%d"
# set format x "%d %b %y"
# set xtics scale 1,0 out center nomirror 
# set ytics scale 1,0 out nomirror
# set xzeroaxis
# show xzeroaxis
# do main plot, summing together first 2 types to make it look like proper stacked
# where 'added' tasks would go the wrong side of the origin, make zero instead
set output "/Users/jonathan/Dropbox/NPSummaries/done_tasks_heatmap.png"
plot DATAFILE matrix rowheaders columnheaders using 1:2:3 with image, \
     DATAFILE matrix rowheaders columnheaders using 1:2:($3 == 0 ? "" : sprintf("%g",$3) ) with labels font ",8" tc rgb "#22BB22"
