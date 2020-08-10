#!/usr/bin/ruby
#-------------------------------------------------------------------------------
# NotePlan Show Stats in a nice little graph
# (c) JGC, v0.1.3, 11.7.2020
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
# - RMagick?
# - Chartkick? https://github.com/ankane/chartkick.js  Assumes HTML context (and Rails?)
# - chart.js? -- [How to use two Y axes in Chart.js v2?](https://stackoverflow.com/questions/38085352/how-to-use-two-y-axes-in-chart-js-v2)
#
# Configuration:
# - StorageType: select iCloud (default) or Drobpox
# - Username: the username of the Dropbox/iCloud account to use
#-------------------------------------------------------------------------------

require 'date'
require 'time'
require 'etc' # for login lookup, though currently not used
require 'colorize' # for coloured output using https://github.com/fazibear/colorize
require 'optparse'
require 'googlecharts'
require 'csv' # basic help at https://www.rubyguides.com/2018/10/parse-csv-ruby/
require 'array_arithmetic' # info at https://github.com/CJAdeszko/array_arithmetic

# User-settable constants
STORAGE_TYPE = 'iCloud'.freeze # or Dropbox
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
              File.getcwd # for CloudKit use current directory
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

include ArrayArithmetic
# one = [10,20,30,40]
# two = [5,6,6,7]
# three = [3,4,4,5]
# puts subtract(one, add(two,three))

# Sample data from task_stats.csv file:
# Date,Goals,Projects,Other Notes,Goal Done,G Overdue,G Undated,G Waiting,G Future,Project Done,P Overdue,P Undated,P Waiting,P Future,Other Done,Overdue,Undated,Waiting,Future,Total Done,Overdue,Undated,Waiting,Future
#  5 Jul 2020 22:15,9,14,44,139,27,63,2,6,322,27,71,3,9,2376,968,405,36,78,2837,1022,539,41,93

# From a file: read and parse all at once  (info: https://www.rubyguides.com/2018/10/parse-csv-ruby/)
# check out other 'Date' and 'DateTime' converters
begin
  table = CSV.parse(File.read(INPUT_DIR + '/task_stats.csv'), headers: true, converters: :all)
rescue StandardError => e
  puts "ERROR: '#{e.exception.message}' when reading #{INPUT_DIR}/task_stats.csv".colorize(WarningColour)
end

# Create charts
begin
  # Create chart to show difference between complete and open tasks over time
  goal_open    = add(table.by_col['G Overdue'], table.by_col['G Undated'])
  project_open = add(table.by_col['P Overdue'], table.by_col['P Undated'])
  other_open   = add(table.by_col['Overdue'].compact, table.by_col['Undated'].compact)
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

  # Create chart to show task completions over time
  # TODO: Check to see whether this is actually putting out sensible numbers, and scales
  chart1 = Gchart.new(type: 'line',
                      title: "Completed Task stats from NotePlan (#{TODAYS_DATE})",
                      size: '600x400',
                      theme: :thirty7signals,
                      data: [table.by_col['Goal Done'], table.by_col['Project Done'], table.by_col['Other Done']],
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
                      data: [table.by_col['Goals'], table.by_col['Projects'], table.by_col['Other Notes']],
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
  goal_diff = subtract(table.by_col['Goal Done'], add(table.by_col['G Overdue'], table.by_col['G Undated']))
  project_diff = subtract(table.by_col['Project Done'], add(table.by_col['P Overdue'], table.by_col['P Undated']))
  other_diff   = subtract(table.by_col['Other Done'].compact, add(table.by_col['Overdue'].compact, table.by_col['Undated'].compact))
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
