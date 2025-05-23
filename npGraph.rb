#!/usr/bin/env ruby
#-------------------------------------------------------------------------------
# NotePlan Show Stats in nice little graphs
# (c) Jonathan Clark
#-------------------------------------------------------------------------------
# Script to graph the stats collected by the npStats.rb script from NotePlan.
#
# It finds statistics from the IO_DIR/task_stats.csv file.
# It creates graphs (.png files) summarising these statistics.
#
# It uses the 'googlecharts' gem, but it's no longer maintained.
# - See intro at https://github.com/mattetti/googlecharts
# - and library docs at https://www.rubydoc.info/gems/googlecharts/1.6.12/Gchart
# - need to consult internet archive for more helpful detail:
#   https://web.archive.org/web/20170305075702/http://googlecharts.rubyforge.org/
# - NB: It doesn't cover the whole of Google's Chart system.
# - can't see other
#
# Other options?
# - http://googlevisualr.herokuapp.com/examples/interactive/annotation_chart produces SVG and 5 years old
# - JavaScript chioces
#   - chart.js? -- [How to use two Y axes in Chart.js v2?](https://stackoverflow.com/questions/38085352/how-to-use-two-y-axes-in-chart-js-v2)
#   - http://www.highcharts.com/
#   - Chartkick? https://github.com/ankane/chartkick.js  Assumes HTML context (and Rails?)
# - ggplot
#   - https://github.com/rdp/ruby_gnuplot
#   - http://gnuplot.sourceforge.net/demo/layout.html
# - http://effectif.com/ruby/manor/data-visualisation-with-ruby lists more choices, not yet sure how recent it is
#   - R (rsruby gem) doc last updated 2009
#     - setup info https://www.rubydoc.info/gems/rsruby/0.5.1.1
#     - brief manual downloaded from http://web.kuicr.kyoto-u.ac.jp/~alexg/rsruby/manual.pdf
#     - the gem install failed to build
#   - gnuplot
#
# Configuration:
# - none needed to read data from NotePlan itself
# - GP_SCRIPTS_DIR for where the various *.gp scripts live
# - *_FILENAME for output files
#-------------------------------------------------------------------------------
# gnuplot help:
# using 2 means that gnuplot will use the 2nd column from the file for the data it is plotting. If you are plotting x data vs. y data, the command is plot data using 1:2 if x data is in column 1 and y data is in column 2.  plot using 2 will plot the data from column 2 on the y axis, and for each data point the x coordinate will be incremented by 1.
# You'll notice that the green and red bars are the same size: they both use column 2. If you don't want the first (red) bar to appear, you could change the plot command to
# plot 'test.dat' using 2:xtic(1) title 'Col1', '' using 3 title 'Col2', '' using 4 title 'Col3'
# With this command, the xtic labels will stay the same, and the first bar will no longer be there. Note that the colors for the data will change with this command, since the first thing plotted will be red, the second green and the third blue.
#-------------------------------------------------------------------------------

VERSION = '0.8.2'.freeze

require 'date'
require 'time'
require 'etc' # for login lookup, though currently not used
require 'colorize' # for coloured output using https://github.com/fazibear/colorize
require 'optparse'
# require 'googlecharts'
require 'csv' # basic help at https://www.rubyguides.com/2018/10/parse-csv-ruby/
require 'array_arithmetic' # info at https://github.com/CJAdeszko/array_arithmetic
require 'gnuplot'

# Constants
USER_DIR = ENV['HOME'] # pull home directory from environment
NPEXTRAS = ENV['NPEXTRAS'] # save in user-specified directory as it won't be sync'd in a CloudKit directory
DROPBOX_DIR = "#{USER_DIR}/Dropbox/Apps/NotePlan/Documents".freeze
ICLOUDDRIVE_DIR = "#{USER_DIR}/Library/Mobile Documents/iCloud~co~noteplan~NotePlan/Documents".freeze
CLOUDKIT_DIR = "#{USER_DIR}/Library/Containers/co.noteplan.NotePlan3/Data/Library/Application Support/co.noteplan.NotePlan3".freeze
# NB: a user-set directory, not the usual CloudKit directory, as non-NotePlan folders won't sync from it.
puts CLOUDKIT_DIR
NP_BASE_DIR = if Dir.exist?(CLOUDKIT_DIR) && Dir[File.join(CLOUDKIT_DIR, '**', '*')].count { |file| File.file?(file) } > 1
                CLOUDKIT_DIR
              elsif Dir.exist?(ICLOUDDRIVE_DIR) && Dir[File.join(ICLOUDDRIVE_DIR, '**', '*')].count { |file| File.file?(file) } > 1
                ICLOUDDRIVE_DIR
              elsif Dir.exist?(DROPBOX_DIR) && Dir[File.join(DROPBOX_DIR, '**', '*')].count { |file| File.file?(file) } > 1
                DROPBOX_DIR
              end
puts NP_BASE_DIR
IO_DIR = if Dir.exist?(CLOUDKIT_DIR) && Dir[File.join(CLOUDKIT_DIR, '**', '*')].count { |file| File.file?(file) } > 1
           NPEXTRAS
         else
           "#{NP_BASE_DIR}/Summaries".freeze # but otherwise can store in Summaries/ directory in NP
         end
puts IO_DIR
# Allow for both M1 and Intel versions of Homebrew
GP_CALL = if Dir.exist?("/opt/homebrew/bin")
                "/opt/homebrew/bin/gnuplot"
              else
                "/usr/local/bin/gnuplot"
              end

# User-settable Constant Definitions
DATE_FORMAT = '%d.%m.%y'.freeze
TODAYS_DATE = Date.today # can't work out why this needs to be a 'constant' to work -- something about visibility, I suppose
DATE_TODAY_YYYYMMDD = TODAYS_DATE.strftime('%Y%m%d')
GP_SCRIPTS_DIR = '/Users/jonathan/GitHub/NotePlan-stats'.freeze
NET_FILENAME = "#{IO_DIR}/tasks_net.csv".freeze
NET_HEATMAP_FILENAME = "#{IO_DIR}/net_tasks_matrix.csv".freeze
DONE_HEATMAP_FILENAME = "#{IO_DIR}/done_tasks_matrix.csv".freeze
NET_LOOKBACK_DAYS = 26 * 7 # 26 weeks
DONE_PERIOD_WEEKS = 26 # 26 weeks = 6 months
DATE_OUT_FORMAT = '%d %b' # when writing new CSVs. Ignoring %Y now.

# Colours, using the colorization gem
TotalColour = :light_yellow
WarningColour = :light_red

#-------------------------------------------------------------------------
# Function definitions
#-------------------------------------------------------------------------
# Print multi-dimensional 'tables' of data prettily
# from https://stackoverflow.com/questions/27317023/print-out-2d-array
def print_table(table, margin_width = 2)
  # the margin_width is the spaces between columns (use at least 1)

  column_widths = []
  table.each do |row|
    row.each.with_index do |cell, column_num|
      column_widths[column_num] = [column_widths[column_num] || 0, cell.to_s.size].max
    end
  end

  puts(table.collect do |row|
    row.collect.with_index do |cell, column_num|
      cell.to_s.ljust(column_widths[column_num] + margin_width)
    end.join
  end)
end

#===============================================================================
# Main logic
#===============================================================================

# Make sure we have set working directory to /Users/jonathan/GitHub/NotePlan-stats
# which is needed if this is run automatically as a launchctl script.
Dir.chdir(GP_SCRIPTS_DIR)

# Setup program options
options = {}
opt_parser = OptionParser.new do |opts|
  opts.banner = 'Usage: npGraph.rb [options]'
  opts.separator ''
  # options[:verbose] = 0
  # options[:no_file] = 0
  opts.on('-v', '--verbose', 'Show information as I work') do
    options[:verbose] = 1
  end
  opts.on('-h', '--help', 'Show help') do
    puts opts
    exit
  end
end
opt_parser.parse! # parse out options, leaving file patterns to process
$verbose = options[:verbose]
# puts options
# exit

# include ArrayArithmetic
# one = [10,20,30,40]
# two = [5,6,6,7]
# three = [3,4,4,5]
# puts subtract(one, add(two,three))

# -----------------------------------------------------------------------------------
# Do graphs of totals/averages from hashtags or mentions
# -----------------------------------------------------------------------------------

gp_call_params = 'mentions.gp'
gp_call_result = system("#{GP_CALL} '#{gp_call_params}'")
puts 'ERROR: Hit problem when creating graphs using gnuplot'.colorize(WarningColour) unless gp_call_result

# -----------------------------------------------------------------------------------
# Do graphs of when tasks were completed
# -----------------------------------------------------------------------------------

# Read file of how many tasks were done when
# Example data from task_done_dates.csv file:
#   Date,Gcount,Pcount,Ocount
#   2020-02-14,1,4,3
#   2020-02-16,1,2,4
# Note that this is sparse: not every date in the range might be present
# begin
#   td_table = CSV.parse(File.read(IO_DIR + '/task_done_dates.csv'), headers: true, converters: :all)
#   puts "Created #{td_table.inspect} from reading task_done_dates.csv into td_table"
# rescue StandardError => e
#   puts "ERROR: '#{e.exception.message}' when reading #{IO_DIR}/task_done_dates.csv".colorize(WarningColour)
# end

# ------------------------------------------------------------------------------------
# Previous way to create charts -- directly in Gnuplot using a gem ...

# Create chart to show difference between complete and open tasks over time
# first create non-sparse table of data for last 180 days (approx 6 months)
# date_6m_ago = (TODAYS_DATE << 6).strftime('%Y-%m-%d').to_i
# puts date_6m_ago
# done_goal_last6m = Array.new(180, 0)
# done_project_last6m = Array.new(180, 0)
# done_other_last6m = Array.new(180, 0)
# d = date_6m_ago
# td_table.each do |tdt|
#   d = tdt[0]
#   next unless d > date_6m_ago

#   done_goal_last6m[d - date_6m_ago] = tdt[1]
#   done_project_last6m[d - date_6m_ago] = tdt[2]
#   done_other_last6m[d - date_6m_ago] = tdt[3]
# end
# puts done_other_last6m, done_other_last6m.size

# puts done_last6m.class
# first_done_date = td_table.by_col['orddate'].min
# last_done_date = td_table.by_col['orddate'].max
# first_date_to_use = date_6m_ago > first_done_date ? date_6m_ago : first_done_date
# last_date_to_use = last_done_date
# puts "Found date range #{first_done_date}..#{last_done_date}, and will use last 6 months (#{first_date_to_use}..#{last_date_to_use})" if $verbose
# done_dates = add(td_table.by_col['orddate'], td_table.by_col['count'])
# puts 'done_dates: ', done_dates
# done_last6m = done_dates

# Try gnuplot instead ...
# - http://gnuplot.sourceforge.net/demo/layout.html shows multi-layouts of stacked bars
# - downloaded manual
# - TODO: switch to YYYY-MM-DD using note at https://stackoverflow.com/questions/33442463/gnuplot-xrange-using-dates-in-ruby
# Gnuplot.open do |gp|
#   Gnuplot::Plot.new(gp) do |plot|
#     plot.terminal 'png'
#     plot.output File.expand_path('done_tasks_6m_ggp.png', __dir__)
#     plot.title "When tasks were done (6 months to #{TODAYS_DATE})"
#     plot.xlabel 'date'
#     # plot.boxwidth '0.9 relative'
#     # plot.style 'fill solid 1.0'
#     x = (0..179).to_a
#     # x = (0..179).collect { |v| (v.to_f - 179) / 30 }
#     yg = done_goal_last6m
#     yp = done_project_last6m
#     yo = done_other_last6m
#     plot.xrange '[0:*]'
#     plot.yrange '[0:10<*]' # keep max at least 10
#     plot.style  'data histograms'
#     plot.style  'histogram rowstacked' # fill solid 0.5 border'
#     plot.boxwidth '0.9 relative'
#     plot.key 'inside right top vertical nobox'
#     plot.key 'left reverse enhanced autotitles columnheader'
#     plot.data << Gnuplot::DataSet.new([x, yg, yp, yo]) do |ds|
#       ds.using = '2:xtic(1) title "G", "" using 3 title "P", "" using 4 title "O"'
#       ds.with = 'boxes fill lt rgb "red"'
#       ds.title = 'Goals'
#     end
#   end
# end
# exit

# Alternatively use separate gnuplot definition file and call:
# - https://stackoverflow.com/questions/2232/how-to-call-shell-commands-from-ruby
# gp_call_params = 'done_tasks.gp'
# gp_call_result = system("#{GP_CALL} '#{gp_call_params}'")
# puts 'ERROR: Hit problem when creating Done Tasks graph using gnuplot'.colorize(WarningColour) unless gp_call_result

# -----------------------------------------------------------------------------------
# Do graphs of net tasks
# NB: Now commented out as I don't feel it's worth doing
# -----------------------------------------------------------------------------------

# Plot net number of tasks completed vs added over time,
# differentiating goal/projects/other.
# This might be possible in gnuplot, but its not straightforward, so instead will
# pre-compute the data and send to a file. Structure:
#   date (%d %b %Y %H:%M), added G, added P, added O, done G, done P, done O, cumulative net G, cumulative net P, cumulative net O
# Added = all the task_stats categories for one day minus the previous day
# Done = actual log of the number completed per day
# NOTE: will use latest entries from CSV if there are multiple entries for a day

begin
  stats_table = CSV.parse(File.read(IO_DIR + '/task_stats.csv'), headers: true, converters: :all)
  puts "Read #{stats_table.size} items from task_stats.csv into stats_table (class #{stats_table.class})"
rescue StandardError => e
  puts "ERROR: '#{e.exception.message}' when reading #{IO_DIR}/task_stats.csv".colorize(WarningColour)
end

begin
  done_table = CSV.parse(File.read(IO_DIR + '/task_done_dates.csv'), headers: true, converters: :all)
  puts "Read #{done_table.size} items from task_done_dates.csv into done_table  (class #{done_table.class})"
rescue StandardError => e
  puts "ERROR: '#{e.exception.message}' when reading #{IO_DIR}/task_done_dates.csv".colorize(WarningColour)
end
start_date = TODAYS_DATE - NET_LOOKBACK_DAYS

# Create hash of added tasks (g/p/o) for each day
addedh = Hash.new { Array.new(3, '') } # NOTE: was (3,0), but trying blank ...
last_gt = last_pt = last_ot = 0
stats_table.each do |st| # FIXME: can be nil with missing data?
  # puts "working out added for #{st}"
  d = Date.strptime(st[0][0..10], "%d %b %Y") # ignore time portion of datetime string
  next unless d >= start_date

  addedh.store(d.to_s, [st[4] + st[5] + st[6] + st[7] + st[8] - last_gt,
                        st[9] + st[10] + st[11] + st[12] + st[13] - last_pt,
                        st[14] + st[15] + st[16] + st[17] + st[18] - last_ot])
  last_gt = st[4] + st[5] + st[6] + st[7] + st[8]
  last_pt = st[9] + st[10] + st[11] + st[12] + st[13]
  last_ot = st[14] + st[15] + st[16] + st[17] + st[18]
end

# Create hash of done tasks (g/p/o) for each day
doneh = Hash.new { Array.new(3, 0) }
done_table.each do |dt|
  d = dt[0]
  next unless d >= start_date

  doneh.store(d.to_s[0..9], [dt[1], dt[2], dt[3]])
end

# # Create summary array to write out
# summarya = Array.new(NET_LOOKBACK_DAYS, 0)
# i = 0
# d = start_date + 1
# rtag = rtap = rtao = 0
# while i < NET_LOOKBACK_DAYS
#   aa = addedh.fetch(d.to_s, [0, 0, 0]) # lookup from addedh, defaulting to 0
#   da = doneh.fetch(d.to_s, [0, 0, 0])  # lookup from doneh, defaulting to 0
#   rtag += da[0] - aa[0] # running total of net G
#   rtap += da[1] - aa[1] # running total of net P
#   rtao += da[2] - aa[2] # running total of net O
#   summarya[i] = [d.to_s, aa[0], aa[1], aa[2], da[0], da[1], da[2], rtag, rtap, rtao]
#   i += 1
#   d += 1
# end
# begin
#   # Use the CSV library to help make this (a bit) easier
#   CSV.open(NET_FILENAME, 'w') do |csv_file|
#     summarya.each do |sa|
#       row = sa
#       csv_file << row
#     end
#   end
#   puts "Written #{i} lines to #{NET_FILENAME}"
# rescue StandardError => e
#   puts "ERROR: '#{e.exception.message}' when writing #{NET_FILENAME}".colorize(WarningColour)
# end

# gp_call_params = 'net_tasks.gp'
# gp_call_result = system("#{GP_CALL} '#{gp_call_params}'")
# puts 'ERROR: Hit problem when creating Net Tasks graph using gnuplot'.colorize(WarningColour) unless gp_call_result

# -----------------------------------------------------------------------------------
# Do heatmap graphs of net tasks
# NB: Also now commented out, as low value
# -----------------------------------------------------------------------------------

# Reuse data worked out in last step, and write out in a new file structure:
#   W/C, Mon, Tues, Weds ...
#   date, tasks completed for that day in the week, ...
#   date of next week, tasks completed for that day in the week, ...
#   ...
# NOTE: week starting Mondays. Days in Jan before Monday are in week 0.

# Create new data structure, reusing data doneh hash from above
net_grida = Array.new(DONE_PERIOD_WEEKS + 1) { Array.new(8) { 0 } } # extra week to allow for data not starting on a Monday
# populate first week specially with week of first data entry, as it might not fall on week start
start_date = TODAYS_DATE - (DONE_PERIOD_WEEKS * 7) + 1 # +1 to get past first day which will always be odd as doing net
week_number = start_date.strftime('%W').to_i # rubocop:disable Lint/UselessAssignment
week_counter = 0
net_grida[week_counter][0] = start_date.strftime(DATE_OUT_FORMAT)
current_day = start_date
while current_day < TODAYS_DATE
  day_of_week = current_day.strftime('%u').to_i # Monday is 1, ...
  if day_of_week == 1
    week_counter += 1
    week_number = current_day.strftime('%W').to_i # don't just increment, as it might be a year boundary
    # create string of date at start of the week to use as X label
    # puts "  Collating net data for w/c #{week_number} #{current_day} #{week_counter} ..."
    net_grida[week_counter][0] = if week_number > 1
                                   current_day.strftime(DATE_OUT_FORMAT)
                                 else # But if week 1 just show year instead (should never find week 0?)
                                   current_day.strftime('%Y')
                                 end
  end
  data_done = doneh.fetch(current_day.to_s, [0, 0, 0]) # get data, defaulting to zeros
  data_added = addedh.fetch(current_day.to_s, [0, 0, 0]) # get data, defaulting to zeros

  calc = (data_done[0] + data_done[1] + data_done[2]) - (data_added[0] + data_added[1] + data_added[2]) # all done - all added
  net_grida[week_counter][day_of_week] = calc
  current_day += 1
end

# Now transpose the array so that it is wide not deep
# net_grida.reverse!
# puts net_grida
net_grida[0] = ['Week start', 'Mon', 'Tues', 'Weds', 'Thurs', 'Fri', 'Sat', 'Sun']
net_grid_transposeda = net_grida.transpose

# Write out new structure to CSV file
begin
  # Use the CSV library to help make this (a bit) easier
  CSV.open(NET_HEATMAP_FILENAME, 'w') do |csv_file|
    net_grid_transposeda.each do |sa|
      row = sa
      csv_file << row
    end
  end
  puts "Written #{week_counter} lines to #{NET_HEATMAP_FILENAME}"
rescue StandardError => e
  puts "ERROR: '#{e.exception.message}' when writing #{NET_HEATMAP_FILENAME}".colorize(WarningColour)
end

gp_call_params = 'net_tasks_heatmap.gp'
gp_call_result = system("#{GP_CALL} '#{gp_call_params}'")
puts 'ERROR: Hit problem when creating graphs using gnuplot'.colorize(WarningColour) unless gp_call_result

# -----------------------------------------------------------------------------------
# Do heatmap graphs of completed tasks
# -----------------------------------------------------------------------------------

# Reuse data worked out in last step, and write out in a new file structure:
#   W/C, Mon, Tues, Weds ...
#   date, tasks completed for that day in the week, ...
#   date of next week, tasks completed for that day in the week, ...
#   ...
# NOTE: week starting Mondays. Days in Jan before Monday are in week 0.

# Create new data structure, reusing data doneh hash from above
done_grida = Array.new(DONE_PERIOD_WEEKS + 1) { Array.new(8) { 0 } } # extra week to allow for data not starting on a Monday
# populate first week specially with week of first data entry, as it might not fall on week start
start_date = TODAYS_DATE - (DONE_PERIOD_WEEKS * 7) + 1 # +1 to get past first day which will always be odd as doing net
week_number = start_date.strftime('%W').to_i # rubocop:disable Lint/UselessAssignment
week_counter = 0
done_grida[week_counter][0] = start_date.strftime(DATE_OUT_FORMAT)
current_day = start_date
while current_day < TODAYS_DATE
  # FIXME: why does this not work for today when run at the end of the day?
  day_of_week = current_day.strftime('%u').to_i # Monday is 1, ...
  if day_of_week == 1
    week_counter += 1
    week_number = current_day.strftime('%W').to_i # don't just increment, as it might be a year boundary
    # create string of date at start of the week to use as X label
    # puts "  Collating done data for w/c #{week_number} #{current_day} #{week_counter} ..."
    done_grida[week_counter][0] = if week_number > 1
                                    current_day.strftime(DATE_OUT_FORMAT)
                                  else
                                    # But if week 1 just show year instead (should never find week 0?)
                                    current_day.strftime('%Y')
                                  end
  end
  data = doneh.fetch(current_day.to_s, [0, 0, 0]) # get data, defaulting to zeros
  calc = data[0] + data[1] + data[2] # for now save sum of G+P+O tasks completed TODO: change in time
  done_grida[week_counter][day_of_week] = calc
  current_day += 1
end

# Now transpose the array so that it is wide not deep
# done_grida.reverse!
# puts done_grida
done_grida[0] = ['Week number', 'Mon', 'Tues', 'Weds', 'Thurs', 'Fri', 'Sat', 'Sun']
done_grid_transposeda = done_grida.transpose

# Write out new structure to CSV file
begin
  # Use the CSV library to help make this (a bit) easier
  CSV.open(DONE_HEATMAP_FILENAME, 'w') do |csv_file|
    done_grid_transposeda.each do |sa|
      row = sa
      csv_file << row
    end
  end
  puts "Written #{week_counter} lines to #{DONE_HEATMAP_FILENAME}"
rescue StandardError => e
  puts "ERROR: '#{e.exception.message}' when writing #{DONE_HEATMAP_FILENAME}".colorize(WarningColour)
end

gp_call_params = 'done_tasks_heatmap.gp'
gp_call_result = system("#{GP_CALL} '#{gp_call_params}'")
puts 'ERROR: Hit problem when creating graphs using gnuplot'.colorize(WarningColour) unless gp_call_result

# -----------------------------------------------------------------------------------
# Do graphs of open tasks
# -----------------------------------------------------------------------------------

# Example data from task_stats.csv file:
# Date,Goals,Projects,Other Notes,Goal Done,G Overdue,G Undated,G Waiting,G Future,Project Done,P Overdue,P Undated,P Waiting,P Future,Other Done,Overdue,Undated,Waiting,Future,Total Done,Overdue,Undated,Waiting,Future
#  5 Jul 2020 22:15,9,14,44,139,27,63,2,6,322,27,71,3,9,2376,968,405,36,78,2837,1022,539,41,93

# From a file: read and parse all at once  (info: https://www.rubyguides.com/2018/10/parse-csv-ruby/)
# (There are other 'Date' and 'DateTime' converters.)
begin
  gpo_table = CSV.parse(File.read(IO_DIR + '/task_stats.csv'), headers: true, converters: :all)
  puts "Read #{gpo_table.size} items from task_stats.csv into gpo_table"
rescue StandardError => e
  puts "ERROR: '#{e.exception.message}' when reading #{IO_DIR}/task_stats.csv".colorize(WarningColour)
end

gp_call_params = 'open_tasks.gp'
gp_call_result = system("#{GP_CALL} '#{gp_call_params}'")
puts 'ERROR: Hit problem when creating graphs using gnuplot'.colorize(WarningColour) unless gp_call_result

exit
