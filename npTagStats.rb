#!/usr/bin/ruby
#-------------------------------------------------------------------------------
# NotePlan Tag Stats Summariser
# (c) JGC, v1.1.2, 15.3.2020
#-------------------------------------------------------------------------------
# Script to give stats on various tags in NotePlan's daily calendar files.
#
# It notices and summarises the following tags from the top of the file
# - #holiday, #halfholiday, #bankholiday
# - #dayoff, #friends
# - #training, #conference, #retreat
# - #preach, #lead..., #wedding, #funeral, #baptism etc.
# - etc.
# It writes output to screen and to a CSV file.
#
# Two ways of running this:
# 1. with a passed year, it will just look in the files for that year.
# 2. with no arguments, it will just look in the current year, and distinguish
#    dates in the future, from year to date
#
# Configuration:
# - StorageType: select iCloud (default) or Drobpox
# - TagsToCount: array of tags to count
# - Username: the username of the Dropbox/iCloud account to use
#-------------------------------------------------------------------------------
# TODO
#-------------------------------------------------------------------------------

require 'date'
require 'time'
require 'etc' # for login lookup, though currently not used
require 'colorize' # for coloured output using https://github.com/fazibear/colorize

# User-settable constants
STORAGE_TYPE = 'iCloud'.freeze # or Dropbox
TAGS_TO_COUNT = ['#holiday', '#halfholiday', '#bankholiday', '#dayoff', '#friends', '#preach',
                 '#wedding', '#funeral', '#baptism', '#dedication', '#thanksgiving',
                 '#welcome', '#homevisit', '#conference', '#training', '#retreat',
                 '#parkrun', '#dogwalk', '#dogrun',
                 '#leadaaw', '#leadmw', '#leadmp', '#leadhc'].freeze # simple array of strings
DATE_FORMAT = '%d.%m.%y'.freeze
DATE_TIME_FORMAT = '%e %b %Y %H:%M'.freeze
USERNAME = 'jonathan'.freeze

# Other Constant Definitions
TODAYS_DATE = Date.today # can't work out why this needs to be a 'constant' to work -- something about visibility, I suppose
DATE_TODAY_YYYYMMDD = TODAYS_DATE.strftime('%Y%m%d')
NP_BASE_DIR = if STORAGE_TYPE == 'iCloud'
                "/Users/#{USERNAME}/Library/Mobile Documents/iCloud~co~noteplan~NotePlan/Documents" # for iCloud storage
              else
                "/Users/#{USERNAME}/Dropbox/Apps/NotePlan/Documents" # for Dropbox storage
              end
NP_CAL_DIR = "#{NP_BASE_DIR}/Calendar".freeze
NP_SUMM_DIR = "#{NP_BASE_DIR}/Summaries".freeze

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
  attr_reader :isFuture

  def initialize(this_file, id)
    # initialise instance variables (that persist with the class instance)
    @filename = this_file
    @id = id
    @lines = []
    @lineCount = 0
    @tags = ''
    @isFuture = false

    # mark this as a future date if the filename YYYYMMDD part as a string is greater than DateToday in YYYYMMDD format
    @isFuture = true if @filename[0..7] > DATE_TODAY_YYYYMMDD
    # puts "initialising #{@filename} #{isFuture}"

    # Open file and read in
    # NB: needs the encoding line when run from launchctl, otherwise you get US-ASCII invalid byte errors (basically the 'locale' settings are different)
    header = ''
    File.open(@filename, 'r', encoding: 'utf-8') do |f|
      # Read through header lines
      f.each_line do |line|
        header += line
      end
    end
    # extract tags from lines
    @tags = header.scan(%r{#[\w/]+}).join(' ')
  rescue StandardError => e
    puts "ERROR: Hit #{e.exception.message} when initialising NPCalendar from #{@filename}!".colorize(WarningColour)
  end
end

#=======================================================================================
# Main logic
#=======================================================================================
timeNow = Time.now
timeNowFmt = timeNow.strftime(DATE_TIME_FORMAT)
thisYear = timeNow.strftime('%Y')
n = 0 # number of notes/calendar entries to work on
calFiles = [] # to hold all relevant calendar objects

# Check if we have a given argument
theYear = ARGV[0] || thisYear
puts "Creating stats at #{timeNowFmt} for #{theYear}:"
begin
  Dir.chdir(NP_CAL_DIR)
  Dir.glob("#{theYear}*.txt").each do |this_file|
    calFiles[n] = NPCalendar.new(this_file, n)
    n += 1
  end
rescue StandardError => e
  puts "ERROR: Hit #{e.exception.message} when reading calendar files.".colorize(WarningColour)
end

# Initialise counting array and zero all its terms
counts = []
futureCounts = []
i = 0
TAGS_TO_COUNT.each do |_t|
  counts[i] = futureCounts[i] = 0
  i += 1
end

if n.positive? # if we have some notes to work on ...
  days = futureDays = 0
  # puts "Found #{n} notes to attempt to summarise."
  # Iterate over all Calendar items, and count tags of interest.
  calFiles.each do |cal|
    # puts "  Scanning file #{cal.filename}: #{cal.tags}"
    i = 0
    TAGS_TO_COUNT.each do |t|
      if cal.tags =~ /#{t}/i # case-insensitive
        if cal.isFuture
          futureCounts[i] = futureCounts[i] + 1
        else
          counts[i] = counts[i] + 1
        end
      end
      i += 1
    end
    if cal.isFuture
      futureDays += 1
    else
      days += 1
    end
  end

  # Write out the counts to screen
  i = 0
  puts "\t\tPast\tFuture\tfor #{theYear}".colorize(TotalColour)
  TAGS_TO_COUNT.each do |t|
    printf("%-15s\t%3d\t%3d\n", t, counts[i], futureCounts[i])
    # puts "#{t}\t#{counts[i]}\t#{futureCounts[i]}"
    i += 1
  end
  printf("(Days found    \t%3d\t%3d)\n", days, futureDays)

  # Write out to a file (replacing any existing one)
  f = File.open(NP_SUMM_DIR + '/' + theYear + '_tag_stats.csv', 'w')
  i = 0
  f.puts "Tag,Past,Future,#{timeNowFmt}"
  TAGS_TO_COUNT.each do |t|
    f.printf("%s,%d,%d\n", t, counts[i], futureCounts[i])
    i += 1
  end
  f.printf("Days found,%d,%d\n", days, futureDays)
  f.close

else
  puts "Warning: No matching files found.\n".colorize(WarningColour)
end
