# gnuplot specification to plot charts of mentions over time

$DATAFILE << EOD
# weekly_stats
\\@fruitveg
2021-01-03,4.0,7,28
2021-01-10,4.7,7,33
2021-01-17,5.6,7,39
2021-01-24,3.7,7,26
2021-01-31,4.6,7,32
2021-02-07,4.0,7,28
2021-02-14,4.6,7,32
2021-02-21,4.1,7,29
2021-02-28,4.7,6,28
2021-03-07,4.0,6,24
2021-03-14,6.0,5,30
2021-03-21,4.6,7,32
2021-03-28,4.3,6,26
2021-04-04,4.0,4,16
2021-04-11,4.3,4,17
2021-04-18,4.4,5,22
2021-04-25,4.5,6,27
2021-05-02,4.6,5,23
2021-05-09,3.9,7,27
2021-05-16,4.0,6,24
2021-05-23,4.5,6,27
2021-05-30,4.6,5,23
2021-06-06,4.4,5,22
2021-06-13,4.0,3,12
2021-06-20,5.0,2,10
2021-06-27,5.0,4,20
2021-07-04,5.0,5,25
2021-07-11,4.0,4,16
2021-07-25,4.8,4,19
2021-08-01,4.4,7,31
2021-08-08,3.6,7,25
2021-08-15,3.8,6,23
2021-08-22,3.8,4,15
2021-08-29,3.6,5,18
2021-09-05,5.0,2,10
2021-09-12,1.8,4,7
2021-09-19,0.0,1,0
2021-09-26,3.4,5,17
2021-10-03,4.2,5,21
2021-10-10,3.0,4,12
2021-10-17,3.0,3,9
2021-10-24,4.5,4,18
2021-11-07,3.8,5,19
2021-11-14,4.5,2,9


\\@run
2021-04-18,4.6,1,5
2021-05-23,5.5,1,6
2021-06-13,6.0,1,6
2021-06-20,5.0,1,5
2021-07-04,6.0,1,6
2021-07-18,5.0,1,5
2021-07-25,4.0,1,4
2021-08-01,5.0,1,5
2021-08-15,5.0,1,5
2021-08-22,5.0,1,5
2021-08-29,5.0,1,5
2021-09-05,5.2,1,5
2021-09-26,5.0,1,5
2021-10-03,5.0,2,10
2021-10-17,5.0,1,5
2021-10-24,7.0,1,7
2021-10-31,5.6,1,6
2021-11-07,5.0,1,5


\\@sleep
2021-06-27,7.4,4,30
2021-07-04,7.4,7,52
2021-07-11,7.0,5,35
2021-07-18,7.1,6,43
2021-07-25,7.3,7,51
2021-08-01,6.7,6,40
2021-08-08,7.4,7,52
2021-08-15,7.3,7,51
2021-08-22,6.0,8,48
2021-08-29,7.1,7,50
2021-09-05,7.5,7,53
2021-09-12,8.3,8,66
2021-09-19,7.6,7,53
2021-09-26,7.3,7,51
2021-10-03,7.1,7,50
2021-10-10,7.2,5,36
2021-10-17,7.2,7,51
2021-10-24,7.6,7,53
2021-10-31,7.3,6,44
2021-11-07,6.9,7,48
2021-11-14,7.9,3,24


\\@work
2021-01-03,11.0,6,66
2021-01-10,11.2,6,67
2021-01-17,10.5,6,63
2021-01-24,8.3,6,50
2021-01-31,11.0,6,66
2021-02-07,9.2,6,55
2021-02-14,9.8,6,59
2021-02-21,10.7,6,64
2021-02-28,11.8,5,59
2021-03-07,7.8,6,47
2021-03-14,7.0,6,42
2021-03-21,8.5,6,51
2021-03-28,8.5,6,51
2021-04-04,6.2,5,31
2021-04-11,2.0,2,4
2021-04-18,5.5,2,11
2021-04-25,9.5,6,57
2021-05-02,10.7,3,32
2021-05-09,7.8,6,47
2021-05-16,9.8,5,49
2021-05-23,8.5,6,51
2021-05-30,8.0,4,32
2021-06-06,10.2,5,51
2021-06-13,8.0,4,32
2021-06-20,2.0,1,2
2021-06-27,8.8,3,27
2021-07-04,10.7,3,32
2021-07-11,7.8,7,55
2021-07-18,8.9,7,62
2021-07-25,7.3,7,51
2021-08-01,7.1,7,50
2021-08-08,8.6,5,43
2021-08-15,8.7,6,52
2021-08-22,8.2,6,49
2021-08-29,10.2,5,51
2021-09-05,10.5,4,42
2021-09-12,6.5,2,13
2021-09-19,8.4,5,42
2021-09-26,11.4,5,57
2021-10-03,11.2,6,67
2021-10-10,10.0,4,40
2021-10-17,10.2,5,51
2021-10-24,9.2,6,55
2021-10-31,8.8,5,44
2021-11-07,9.5,6,57
2021-11-14,12.0,1,12
EOD

todays_date=system("date +%d.%m.%Y")

set term png size 800, 360 font "arial,11"
set datafile separator ","
set datafile commentschars "#"
set timefmt "%Y-%m-%d" # format of dates in the input
# stats $DATAFILE # nooutput # calc stats to determine number of indices, but don't show to screen
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
set xdata time
set yrange [0:*]
set xtics format "%b\n%Y" # seems more flexible than set xtics x "..."
set xtics nomirror
unset mxtics # turns off minor tic marks
set ytics nomirror
set output "/Users/jonathan/Dropbox/NPSummaries/test-data-sets.png"
plot for [IDX = 0:*] $DATAFILE index IDX using 1:2 with lines lw 2 title columnheader(1) at end

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
