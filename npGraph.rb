#!/usr/bin/ruby
#-------------------------------------------------------------------------------
# NotePlan Show Stats in a nice little graph
# (c) Jonathan Clark
#-------------------------------------------------------------------------------
# Script to graph the stats collected by the npStats.rb script from NotePlan.
#
# It finds statistics from the INPUT_DIR/task_stats.csv file.
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
# - StorageType: select iCloud (default) or Drobpox
# - Username: the username of the Dropbox/iCloud account to use
#-------------------------------------------------------------------------------
# - v0.2.2, 23.8.2020 - change tasks completed per day graph to differentiate between Goal/Project/Other
# - v0.2.1, 23.8.2020 - add graph for number of tasks completed per day over last 6 months (using local gnuplot)
# - v0.2, 11.7.2020 - produces graphs of number of open tasks over time for Goals/Projects/Other (using Google Charts API)
VERSION = '0.2.1'.freeze

require 'date'
require 'time'
require 'etc' # for login lookup, though currently not used
require 'colorize' # for coloured output using https://github.com/fazibear/colorize
require 'optparse'
require 'googlecharts'
require 'csv' # basic help at https://www.rubyguides.com/2018/10/parse-csv-ruby/
require 'array_arithmetic' # info at https://github.com/CJAdeszko/array_arithmetic

# User-setgpo_table constants
STORAGE_TYPE = 'CloudKit'.freeze # or Dropbox
DATE_FORMAT = '%d.%m.%y'.freeze
DATE_TIME_FORMAT = '%e %b %Y %H:%M'.freeze
USERNAME = 'jonathan'.freeze

# Other Constant Definitions
TODAYS_DATE = Date.today # can't work out why this needs to be a 'constant' to work -- something about visibility, I suppose
DATE_TODAY_YYYYMMDD = TODAYS_DATE.strftime('%Y%m%d')
INPUT_DIR = if STORAGE_TYPE == 'iCloud'
              "/Users/#{USERNAME}/Library/Mobile Documents/iCloud~co~noteplan~NotePlan/Documents/Summaries" # for iCloud storage
            elsif STORAGE_TYPE == 'Dropbox'
              "/Users/#{USERNAME}/Dropbox/Apps/NotePlan/Documents/Summaries" # for Dropbox storage
            else
              "/Users/#{USERNAME}" # for CloudKit use home directory
            end

# Colours, using the colorization gem
TotalColour = :light_yellow
WarningColour = :light_red

#===============================================================================
# Main logic
#===============================================================================

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

# Example data from task_stats.csv file:
# Date,Goals,Projects,Other Notes,Goal Done,G Overdue,G Undated,G Waiting,G Future,Project Done,P Overdue,P Undated,P Waiting,P Future,Other Done,Overdue,Undated,Waiting,Future,Total Done,Overdue,Undated,Waiting,Future
#  5 Jul 2020 22:15,9,14,44,139,27,63,2,6,322,27,71,3,9,2376,968,405,36,78,2837,1022,539,41,93

# From a file: read and parse all at once  (info: https://www.rubyguides.com/2018/10/parse-csv-ruby/)
# (There are other 'Date' and 'DateTime' converters.)
begin
  gpo_table = CSV.parse(File.read(INPUT_DIR + '/task_stats.csv'), headers: true, converters: :all)
  puts "Read #{gpo_table.size} items from task_stats.csv into gpo_table"
rescue StandardError => e
  puts "ERROR: '#{e.exception.message}' when reading #{INPUT_DIR}/task_stats.csv".colorize(WarningColour)
end

# Read file of how many tasks were done when
# Example data from task_done_dates.csv file:
#   orddate (i.e. YYYYOOO ordinal dates),Gcount,Pcount,Ocount
#   2020214,1,4,3 
#   2020216,1,2,4
# Note that this is sparse: not every date in the range will be present
begin
  td_table = CSV.parse(File.read(INPUT_DIR + '/task_done_dates.csv'), headers: true, converters: :integer)
  puts "Created #{td_table.inspect} from reading task_done_dates.csv into td_table"
rescue StandardError => e
  puts "ERROR: '#{e.exception.message}' when reading #{INPUT_DIR}/task_done_dates.csv".colorize(WarningColour)
end

# Create charts
# begin
# Create chart to show difference between complete and open tasks over time
# first create non-sparse table of data for last 180 days (approx 6 months)
ord_date_today = TODAYS_DATE.strftime('%Y%j').to_i
ord_date_6m_ago = (TODAYS_DATE << 6).strftime('%Y%j').to_i
done_goal_last6m = Array.new(180, 0)
done_project_last6m = Array.new(180, 0)
done_other_last6m = Array.new(180, 0)
d = ord_date_6m_ago
td_table.each do |tdt|
  if tdt[0] > ord_date_6m_ago
    done_goal_last6m[tdt[0] - ord_date_6m_ago] = tdt[1]
    done_project_last6m[tdt[0] - ord_date_6m_ago] = tdt[2]
    done_other_last6m[tdt[0] - ord_date_6m_ago] = tdt[3]
end
# puts done_last6m.class
# first_done_date = td_table.by_col['orddate'].min
# last_done_date = td_table.by_col['orddate'].max
# first_date_to_use = ord_date_6m_ago > first_done_date ? ord_date_6m_ago : first_done_date
# last_date_to_use = last_done_date
# puts "Found date range #{first_done_date}..#{last_done_date}, and will use last 6 months (#{first_date_to_use}..#{last_date_to_use})" if $verbose
# done_dates = add(td_table.by_col['orddate'], td_table.by_col['count'])
# puts 'done_dates: ', done_dates
# done_last6m = done_dates

# FIXME: Can't get this GoogleChart to work. Or is it doing just first 11 items or so?
chart_td = Gchart.new(type: 'bar',
                      stacked: false,
                      title: "When tasks were done (6 months to #{TODAYS_DATE})",
                      # size: '1200x600',
                      # :height => '500',
                      # bar_width_and_spacing: { spacing: 2, width: 5 },
                      data: [done_goal_last6m, done_project_last6m, done_other_last6m],
                      # :min_value => 0, # scale this properly
                      bar_colors: '2222ff,ff0000,00ff00',
                      filename: 'done_tasks_6m.png') # define chart
chart_td.file # write chart out
puts '-> done_tasks_6m.png'

# but this example does, grrr.
# temp = Gchart.new(type: 'bar',
#                   data: [[1, 2, 4, 67, 100, 41, 234], [45, 23, 67, 12, 67, 300, 250]],
#                   title: 'SD Ruby Fu level',
#                   legend: %w[matt patrick],
#                   # bg: { color: '76A4FB', type: 'gradient' },
#                   stacked: false,
#                   bar_colors: 'ff0000,00ff00',
#                   filename: 'temp.png')
# temp.file

# Try gnuplot instead ...
# - http://gnuplot.sourceforge.net/demo/layout.html shows multi-layouts of stacked bars
# - downloaded manual
require 'gnuplot'
Gnuplot.open do |gp|
  Gnuplot::Plot.new(gp) do |plot|
    plot.terminal 'png'
    plot.output File.expand_path('done_tasks_6m_ggp.png', __dir__)
    plot.title "When tasks were done (6 months to #{TODAYS_DATE})"
    plot.xlabel 'months ago'
    # plot.boxwidth '0.9 relative'
    # plot.style 'fill solid 1.0'
    x = (0..179).collect { |v| (v.to_f - 179) / 30 }
    yg = done_goal_last6m
    yp = done_project_last6m
    yo = done_other_last6m
    plot.xrange '[-6:0]'
    plot.yrange '[0:10<*]' # keep max at least 10
    plot.data << Gnuplot::DataSet.new([x, yg, yp, yo]) do |ds|
      ds.with = 'boxes fill solid 0.6'
      ds.notitle
    end
  end
end
exit

# -----------------------------------------------------------------------------------------

begin
  # Create chart to show difference between complete and open tasks over time
  goal_open    = add(gpo_table.by_col['G Overdue'], gpo_table.by_col['G Undated'])
  project_open = add(gpo_table.by_col['P Overdue'], gpo_table.by_col['P Undated'])
  other_open   = add(gpo_table.by_col['Overdue'].compact, gpo_table.by_col['Undated'].compact)

  chart_go = Gchart.new(type: 'sparkline',
                        title: "Goal open tasks in NotePlan (#{TODAYS_DATE})",
                        # size: '600x200',
                        height: '70',
                        data: [goal_open],
                        # min_value: 0, # scale this properly
                        line_colors: 'ff2222',
                        filename: 'goal_task_spark.png')
  # Record file in filesystem
  chart_go.file
  puts '-> goal_task_spark.png'

  chart_po = Gchart.new(type: 'sparkline',
                        title: "Project open tasks in NotePlan (#{TODAYS_DATE})",
                        # size: '600x200',
                        height: '70',
                        data: [project_open],
                        # min_value: 0, # scale this properly
                        line_colors: '22ff22',
                        filename: 'project_task_spark.png')
  # Record file in filesystem
  chart_po.file
  puts '-> project_task_spark.png'

  chart_oo = Gchart.new(type: 'sparkline',
                        title: "Other open tasks in NotePlan (#{TODAYS_DATE})",
                        # size: '600x200',
                        height: '70',
                        data: [other_open],
                        # min_value: 0, # scale this properly
                        line_colors: '2222ff',
                        filename: 'other_task_spark.png')
  # Record file in filesystem
  chart_oo.file
  puts '-> other_task_spark.png'

  exit

  #-----------------------------------------------------
  # Earlier versions
  #-----------------------------------------------------

  # Create chart to show task completions over time
  # TODO: Check to see whether this is actually putting out sensible numbers, and scales
  chart1 = Gchart.new(type: 'line',
                      title: "Completed Task stats from NotePlan (#{TODAYS_DATE})",
                      size: '600x400',
                      theme: :thirty7signals,
                      data: [gpo_table.by_col['Goal Done'], gpo_table.by_col['Project Done'], gpo_table.by_col['Other Done']],
                      min_value: 0, # scale this properly
                      line_colors: 'ff2222,22ff22,2222ff',
                      legend: ['Goal tasks', 'Project tasks', 'Other tasks'],
                      axis_with_labels: %w[x y],
                      # :axis_labels => ['date', 'count'],
                      # :axis_range => [[0,100,20], [0,20,5]],
                      filename: 'task_completions.png')
  # Record file in filesystem
  puts chart1.axis_range
  chart1.file
  puts '-> task_completions.png'

  # Create chart to show number of goals, projects, other notes over time
  chart2 = Gchart.new(type: 'line',
                      title: "Number of Goals, Project, Other notes in NotePlan (#{TODAYS_DATE})",
                      size: '600x400',
                      theme: :thirty7signals,
                      data: [gpo_table.by_col['Goals'], gpo_table.by_col['Projects'], gpo_table.by_col['Other Notes']],
                      # min_value: 0, # scale this properly
                      axis_range: [[0, 150, 10], [0, 50, 10]], # FIXME: Why does this have to be specified?
                      line_colors: 'ff8888,88ff88,8888ff',
                      legend: ['# Goals', '# Projects', '# Other notes'],
                      axis_with_labels: %w[y],
                      filename: 'gno.png')
  # Record file in filesystem
  puts chart2.axis_range
  chart2.file
  puts '-> gno.png'

  # Create chart to show difference between complete and open tasks over time
  goal_diff = subtract(gpo_table.by_col['Goal Done'], add(gpo_table.by_col['G Overdue'], gpo_table.by_col['G Undated']))
  project_diff = subtract(gpo_table.by_col['Project Done'], add(gpo_table.by_col['P Overdue'], gpo_table.by_col['P Undated']))
  other_diff   = subtract(gpo_table.by_col['Other Done'].compact, add(gpo_table.by_col['Overdue'].compact, gpo_table.by_col['Undated'].compact))
  chart3 = Gchart.new(type: 'line',
                      title: "Difference between open and completed Tasks in NotePlan (#{TODAYS_DATE})",
                      size: '600x400',
                      theme: :thirty7signals,
                      data: [goal_diff, project_diff, other_diff],
                      min_value: 0, # scale this properly
                      line_colors: 'ff2222,22ff22,2222ff',
                      legend: ['Goal tasks', 'Project tasks', 'Other tasks'],
                      axis_with_labels: %w[x y],
                      filename: 'task_diffs.png')
  # Record file in filesystem
  chart3.file
  puts '-> task_diffs.png'
rescue StandardError => e
  puts "ERROR: Hit '#{e.exception.message}' when creating graphs using GoogleCharts API".colorize(WarningColour)
end
