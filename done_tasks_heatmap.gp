# gnuplot specification to plot a heatmap of completed tasks, based on the
# view of the year's activity in GitHub repositories.
# Currently uses the sum of Goal+Project+Other completed tasks.
# TODO: Also differentiates goal/projects/other.
# 
# See helpful discussion at https://stackoverflow.com/questions/64834593/how-to-control-how-many-xlabels-are-printed-in-gnuplot
# 
# Assumes data structure:
#   , week N, week N+1, week N+2, ...
#   Mon, tasks completed for that day in the week, ...
#   Tues, tasks completed for that day in the week, ...
#   ...
# JGC, 15.11.2020

DATAFILE="/Users/jonathan/Dropbox/NPSummaries/done_tasks_matrix.csv"
todays_date=system("date +'%e %b %Y'")

reset # reset all things set by 'set' command, apart from term
# clear # clear the current output device. Is this needed?
set term png size 800, 300 font "Avenir,9"

set datafile separator comma columnheaders
# set locale "English_US"    # if not already set, to correctly interpret the month abbreviations. NOT WORKING.
# set gradient through a 'palette', which are complex to understand (see manual p.180)
# useful discussion at https://stackoverflow.com/questions/64813524/set-color-to-grey-for-points-below-some-cutoff-when-plotting-with-palette-in-gnu
# also pointing to 'set palette defined ...' possibility rather than 'rgbformula'
# a few demos at http://gnuplot.sourceforge.net/demo/pm3dcolors.html
# TODO set other palettes for further plots
# set palette rgbformula -9,2,-9 # = RGB: -sqrt(x), x, -sqrt(x) = white to green
set palette rgbformula 2,-9,2 # = RGB: x, -sqrt(x), x = white to purple?
# settings for colour box (key, really)
set cbrange [0:*]
set cblabel "Completed tasks (Goals + Projects + Other)"
unset cbtics
# set X and Y axes. Need to use 'writeback' to make the settings stick on overlay
set xrange writeback
set yrange [6.5:-0.5] writeback # to get it displaying Mon->Sun not Sun->Mon down the page
# set xdata time # this has no effect as it is picking up strings as xtic labels. And stops stats from working.
# set format x "%d %b" # this has no effect as it is picking up strings as xtic labels
# set xlabel "Calendar week"
# set xtics rotate by 45 right  # rotate to fit more in. Needs the 'right' to stop it printing it backwards
unset xmtics # ignore minor (unlabelled) tics
     # TODO: see if xtics lists and series might work instead. See manual p.188-190
# use stats to count how many data items
# myCW(col) = sprintf("%s",strftime("%W",strptime("%d %b %Y",strcol(col))))  # date --> calendar week
stats [*:*][*:*] DATAFILE u 2 skip 1 nooutput  # get the number of columns
# stats DATAFILE matrix nooutput # this claims 'matrix contains missing or undefined values' and 'all points out of range'
weeks = STATS_columns - 1
set title sprintf("Tasks completed (%d weeks to %s)", weeks, todays_date) font ",12"
set output "/Users/jonathan/Dropbox/NPSummaries/done_tasks_heatmap.png"
plot DATAFILE matrix rowheaders columnheaders using 1:2:3 with image, \
     DATAFILE matrix rowheaders columnheaders using 1:2:($3 == 0 ? "" : sprintf("%g",$3) ) \
          with labels font ",8" tc rgb "#22BB22" \
          notitle # this needed as *each plot* defaults to a title or key derived from the plot command. Alternative is to 'unset key'
