# gnuplot specification to plot a heatmap of net tasks, based on the
# view of the year's activity in NotePlan notes.
# Currently uses the sum of Goal+Project+Other completed tasks.
# 
# See helpful discussion at https://stackoverflow.com/questions/64834593/how-to-control-how-many-xlabels-are-printed-in-gnuplot
# 
# Assumes data structure:
#   Week start, week N, week N+1, week N+2, ...
#   Mon, net tasks for that day in the week, ...
#   Tues, net tasks for that day in the week, ...
#   ...
# JGC, 29.11.2020

# To get the X labels only every 4th time is flippipn' complicated..
# Method worked out by @theozh at https://stackoverflow.com/questions/64834593/how-to-control-how-many-xlabels-are-printed-in-gnuplot
# Requires unsetting columnheader, and treating first row as a special *data* not *label* row,
# so 'skip 1' past it. Then using 'for' loop to create series of further plots with just single labels!

reset session # reset all things set by 'set' command, apart from term

DATAFILE="/Users/jonathan/Dropbox/NPSummaries/net_tasks_matrix.csv"
todays_date=system("date +'%d %b %Y'")
set term png size 800, 260 font "Avenir,9"
set output "/Users/jonathan/Dropbox/NPSummaries/net_tasks_heatmap.png"

set datafile separator comma
# set locale "English_US"    # if not already set, to correctly interpret the month abbreviations. NOT WORKING.
# set gradient through a 'palette', which are complex to understand (see manual p.180)
# useful discussion at https://stackoverflow.com/questions/64813524/set-color-to-grey-for-points-below-some-cutoff-when-plotting-with-palette-in-gnu
# also pointing to 'set palette defined ...' possibility rather than 'rgbformula'
# a few demos at http://gnuplot.sourceforge.net/demo/pm3dcolors.html
# TODO set other palettes for further plots
# set palette rgbformula -9,2,-9 # = RGB: -sqrt(x), x, -sqrt(x) = white to green
# set palette rgbformula -9,-12,-9 # = RGB: -sqrt(x), ?, -sqrt(x) = purple (-ve) to green (+ve)
set palette defined ( -2 "red", 0 "white", 2 "green" ) # works only with a defined cbrange with 0 in the middle
# settings for colour box (key, really)
set cbrange [-40:40]
set cblabel "Net tasks (Done - Added)"
set cbtics # show colour change numeric labels
# set X and Y axes. Need to use 'writeback' to make the settings stick on overlay
# set xrange writeback
set yrange [6.5:-0.5] # writeback # to get it displaying Mon->Sun not Sun->Mon down the page
# set xdata time # this has no effect as it is picking up strings as xtic labels. And stops stats from working.
# set format x "%d %b" # this has no effect as it is picking up strings as xtic labels
set xtics out nomirror
# set xtics rotate by 45 right  # rotate to fit more in. Needs the 'right' to stop it printing it backwards
# use stats to count how many data items
# myCW(col) = sprintf("%s",strftime("%W",strptime("%d %b %Y",strcol(col))))  # date --> calendar week
# stats DATAFILE matrix nooutput # this claims 'matrix contains missing or undefined values' and 'all points out of range'
stats [*:*][*:*] DATAFILE using 2 skip 1 nooutput  # get the number of columns, skipping first one
MaxCol = STATS_columns
Nxtic = 4   # variable to show every Nth x label
Noffset = 1 # variable to skip to the Nth x label to start displaying
unset key
set title sprintf("Net tasks completed (%d weeks to %s)", MaxCol-1, todays_date) font ",12"

plot DATAFILE matrix rowheaders using 1:2:3 skip 1 with image, \
     DATAFILE matrix rowheaders using 1:2:(sprintf("%g",$3) ) skip 1 with labels font ",8" tc rgb "#666666" notitle, \
     for [i=2+Noffset:MaxCol:Nxtic] DATAFILE u (i-2):(NaN):xtic(i) every ::0::0 

# Trick: to avoid printing '0' in cells: using 1:2:($3 == 0 ? "" : sprintf("%g",$3) )
