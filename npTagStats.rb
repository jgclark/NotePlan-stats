#!/usr/bin/ruby
#-------------------------------------------------------------------------------
# NotePlan Tag Stats Summariser
# Jonathan Clark, v1.3.2, 9.8.2020
#-------------------------------------------------------------------------------
# Script to give stats on various tags in NotePlan's daily calendar files.
#
# It notices and summarises the tags specified in TAGS_TO_COUNT, which is
# ignored and counts all tags if -a is specified.
# It writes output to screen and to a CSV file.
#
# There are two ways of running this:
# 1. with a passed year, it will just look in the files for that year.
# 2. with no arguments, it will just look in the current year, and distinguish
#    dates in the future, from year to date
#
# Configuration:
# - STORAGE_TYPE: select CloudKit (default from NP3.0), iCloudDrive (default until NP3) or Drobpox
# - TAGE_TO_COUNT: array of tags to count
# - USERNAME: the username of the Dropbox/iCloud account to use
# Requires gem colorize optparse (> gem install colorize optparse)
#-------------------------------------------------------------------------------
# For more information please see the GitHub repository:
#   https://github.com/jgclark/NotePlan-stats/
#-------------------------------------------------------------------------------

require 'date'
require 'time'
require 'etc' # for login lookup, though currently not used
require 'colorize' # for coloured output using https://github.com/fazibear/colorize
require 'optparse'

# User-settable constants
STORAGE_TYPE = 'CloudKit'.freeze # or Dropbox or CloudKit or iCloud
# Tags to count up.
TAGS_TO_COUNT = ['#holiday', '#halfholiday', '#bankholiday', '#dayoff', '#sundayoff',
                 '#friends', '#family', '#bbq',
                 # '#work1', '#work5', '#work6', '#work7', '#work8', '#work9', '#work10', '#work11', '#work12', '#work13', '#work14',
                 '#preach', '#wedding', '#funeral', '#baptism', '#dedication', '#thanksgiving',
                 '#welcome', '#homevisit', '#conference', '#training', '#retreat', '#mentor', '#mentee',
                 '#parkrun', '#dogwalk', '#dogrun', '#run',
                 '#leadaaw', '#leadmw', '#leadmp', '#leadhc', '#recordvideo', '#editvideo',
                 '#firekiln', '#glassmaking', '#tiptrip'].freeze # simple array of strings
PARAMS_TO_COUNT = ['@work', '@sleep'].freeze
DATE_FORMAT = '%d.%m.%y'.freeze
DATE_TIME_FORMAT = '%e %b %Y %H:%M'.freeze
USERNAME = 'jonathan'.freeze

# Other Constant Definitions
TODAYS_DATE = Date.today # can't work out why this needs to be a 'constant' to work -- something about visibility, I suppose
DATE_TODAY_YYYYMMDD = TODAYS_DATE.strftime('%Y%m%d')
NP_BASE_DIR = if STORAGE_TYPE == 'Dropbox'
                "/Users/#{USERNAME}/Dropbox/Apps/NotePlan/Documents" # for Dropbox storage
              elsif STORAGE_TYPE == 'CloudKit'
                "/Users/#{USERNAME}/Library/Application Support/co.noteplan.NotePlan3" # for CloudKit storage
              else
                "/Users/#{USERNAME}/Library/Mobile Documents/iCloud~co~noteplan~NotePlan/Documents" # for iCloud storage (default)
              end
NP_NOTE_DIR = "#{NP_BASE_DIR}/Notes".freeze
NP_CALENDAR_DIR = "#{NP_BASE_DIR}/Calendar".freeze
OUTPUT_DIR = if STORAGE_TYPE == 'CloudKit'
               "/Users/#{USERNAME}" # save in user's home directory as it won't be sync'd in a CloudKit directory
             else
               "#{NP_BASE_DIR}/Summaries".freeze # but otherwise store in Summaries/ directory
             end

# Colours, using the colorization gem
TotalColour = :light_yellow
WarningColour = :light_red

#-------------------------------------------------------------------------
# Class definition
#-------------------------------------------------------------------------
class NPCalendar
  # Class to hold details of a particular Calendar date; similar but different
  # to the NPNote class used in other related scripts.
  # Define the attributes that need to be visible outside the class instances
  attr_reader :id
  attr_reader :tags
  attr_reader :filename
  attr_reader :is_future

  def initialize(this_file, id)
    # initialise instance variables (that persist with the class instance)
    @filename = this_file
    @id = id
    @lines = []
    @lineCount = 0
    @tags = ''
    @is_future = false

    # mark this as a future date if the filename YYYYMMDD part as a string is greater than DateToday in YYYYMMDD format
    @is_future = true if @filename[0..7] > DATE_TODAY_YYYYMMDD
    puts "initialising #{@filename} #{is_future}" if $verbose == 1

    # Open file and read in
    # NB: needs the encoding line when run from launchctl, otherwise you get US-ASCII invalid byte errors (basically the 'locale' settings are different)
    lines = ''
    File.open(@filename, 'r', encoding: 'utf-8') do |f|
      # Read through header lines
      f.each_line do |line|
        lines += line
      end
    end
    # extract tags from lines
    @tags = lines.scan(%r{#[\w/]+}).join(' ')
    puts "  Found tags #{@tags}" if $verbose == 1
    # extract tag params from lines
    @tag_params = lines.scan(%r{@[\w/]+\(\d+\)}).join(' ')
    puts "  Found tag params #{@tag_params}" if $verbose == 1
  rescue StandardError => e
    puts "ERROR: Hit #{e.exception.message} when initialising NPCalendar from #{@filename}!".colorize(WarningColour)
  end
end

#=======================================================================================
# Main logic
#=======================================================================================

# Setup program options
options = {}
opt_parser = OptionParser.new do |opts|
  opts.banner = 'Usage: npTagStats.rb [options]'
  opts.separator ''
  options[:all] = 0
  options[:no_file] = 0
  options[:verbose] = 0
  opts.on('-a', '--all', 'Count all tags') do
    options[:all] = 1
  end
  opts.on('-h', '--help', 'Show help') do
    puts opts
    exit
  end
  opts.on('-n', '--nofile', 'Do not write summary to file') do
    options[:no_file] = 1
  end
  opts.on('-v', '--verbose', 'Show information as I work') do
    options[:verbose] = 1
  end
end
opt_parser.parse! # parse out options, leaving file patterns to process
$verbose = options[:verbose]

timeNow = Time.now
timeNowFmt = timeNow.strftime(DATE_TIME_FORMAT)
thisYear = timeNow.strftime('%Y')
n = 0 # number of notes/calendar entries to work on
calFiles = [] # to hold all relevant calendar objects

# Work out which year's calendar files to be summarising
theYear = ARGV[0] || thisYear
puts "Creating stats at #{timeNowFmt} for #{theYear}:"
begin
  Dir.chdir(NP_CALENDAR_DIR)
  Dir.glob("#{theYear}*.txt").each do |this_file|
    # ignore this file if the directory starts with '@'
    fsize = File.size?(this_file) || 0
    puts "  #{this_file} size #{fsize}" if $verbose
    next unless this_file =~ /^[^@]/ # as can't get file glob including [^@] to work
    # ignore this file if it's empty
    next if File.zero?(this_file)

    calFiles[n] = NPCalendar.new(this_file, n)
    n += 1
  end
rescue StandardError => e
  puts "ERROR: Hit #{e.exception.message} when reading calendar files.".colorize(WarningColour)
end

#----------------------------
# Count tags - main logic
#----------------------------
if options[:all]
  # TODO: complete this, looking over each relevant file
end

# Initialise counting array and zero all its terms
tag_counts = []
tag_counts_future = []
param_counts = []
i = 0
TAGS_TO_COUNT.each do |_t|
  tag_counts[i] = tag_counts_future[i] = 0
  i += 1
end
PARAMS_TO_COUNT.each do |_t|
  param_counts[i]
  i += 1
end

# if we have some notes to work on ...
if n.positive?
  # Do counts

  days = futureDays = 0
  puts "Found #{n} notes to summarise." if $verbose == 1
  # Iterate over all Calendar items
  calFiles.each do |cal|
    # puts "  Scanning file #{cal.filename}: #{cal.tags}"
    i = 0
    # Count tags of interest
    TAGS_TO_COUNT.each do |t|
      if cal.tags =~ /#{t}/i # case-insensitive
        if cal.is_future
          tag_counts_future[i] = tag_counts_future[i] + 1
        else
          tag_counts[i] = tag_counts[i] + 1
        end
      end
      i += 1
    end
    if cal.is_future
      futureDays += 1
    else
      days += 1
    end

    # Count params of interest
    PARAMS_TO_COUNT.each do |t|
      # TODO
    end
  end

  # Sum param counts as well TODO

  # Write out the counts to screen
  puts "\t\tPast\tFuture\tfor #{theYear}".colorize(TotalColour)
  # Write out the tag counts list to screen
  i = 0
  TAGS_TO_COUNT.each do |t|
    printf("%-15s\t%3d\t%3d\n", t, tag_counts[i], tag_counts_future[i])
    i += 1
  end
  printf("(Days found    \t%3d\t%3d)\n", days, futureDays)
  # Write out the param counts table to screen
  PARAMS_TO_COUNT.each do |p|
    printf("%-15s\t%3d\n", p, param_counts[i])
    # TODO
    i += 1
  end
  # Write out the param counts sum as list
  # TODO:

  exit if options[:no_file]

  # Write out to a file (replacing any existing one)
  # TODO: Check whether Summaries directory exists. If not, create it.
  begin
    filepath = OUTPUT_DIR + '/' + theYear + '_tag_stats.csv'
    f = File.open(filepath, 'w')
    # Write out the tag counts list
    i = 0
    f.puts "Tag,Past,Future,#{timeNowFmt}"
    TAGS_TO_COUNT.each do |t|
      f.printf("%s,%d,%d\n", t, tag_counts[i], tag_counts_future[i])
      i += 1
    end
    f.printf("Days found,%d,%d\n", days, futureDays)
    # Write out the param counts as table
    # TODO:
    # Write out the param counts sum as list
    # TODO:
    f.close
  rescue StandardError => e
    puts "ERROR: Hit #{e.exception.message} when writing out summary to #{filepath}".colorize(WarningColour)
  end
else
  puts "Warning: No matching files found.\n".colorize(WarningColour)
end
