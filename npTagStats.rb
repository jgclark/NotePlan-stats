#!/usr/bin/ruby
# frozen_string_literal: true

#----------------------------------------------------------------------------------
# NotePlan Tag Stats Summariser
# (c) JGC, v1.1, 29.2.2020
#----------------------------------------------------------------------------------
# Script to give stats on various tags in NotePlan's daily calendar files.
#
# It notices and summarises the following tags from the top of the file
# - #holiday, #halfholiday, #bankholiday
# - #dayoff
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
#----------------------------------------------------------------------------------
# TODO
#----------------------------------------------------------------------------------

require 'date'
require 'time'
require 'etc' # for login lookup, though currently not used
require 'colorize' # for coloured output using https://github.com/fazibear/colorize

# User-settable constants
StorageType = 'iCloud' # or Dropbox
TagsToCount = ['#holiday', '#halfholiday', '#bankholiday', '#dayoff', '#preach',
               '#wedding', '#funeral', '#baptism', '#dedication', '#thanksgiving',
               '#homevisit', '#conference', '#training', '#retreat',
               '#parkrun', '#dogwalk', '#dogrun',
               '#leadaaw', '#leadmw', '#leadmp', '#leadhc'].freeze # simple array of strings
DateFormat = '%d.%m.%y'
DateTimeFormat = '%e %b %Y %H:%M'
Username = 'jonathan'

# Other Constant Definitions
TodaysDate = Date.today # can't work out why this needs to be a 'constant' to work -- something about visibility, I suppose
DateTodayYYYYMMDD = TodaysDate.strftime('%Y%m%d')
if StorageType == 'iCloud'
  NPBaseDir = "/Users/#{Username}/Library/Mobile Documents/iCloud~co~noteplan~NotePlan/Documents" # for iCloud storage
else
  NPBaseDir = "/Users/#{Username}/Dropbox/Apps/NotePlan/Documents" # for Dropbox storage
end
NPCalendarDir = "#{NPBaseDir}/Calendar"
NPSummariesDir = "#{NPBaseDir}/Summaries"

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
    @isFuture = true if @filename[0..7] > DateTodayYYYYMMDD
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
    puts "ERROR: Hit #{e.exception.message} when initialising #{@filename}!".colorize(WarningColour)
  end
end

#=======================================================================================
# Main logic
#=======================================================================================
timeNow = Time.now
timeNowFmt = timeNow.strftime(DateTimeFormat)
thisYear = timeNow.strftime('%Y')
n = 0 # number of notes/calendar entries to work on
calFiles = [] # to hold all relevant calendar objects

# Check if we have a given argument
if ARGV[0]
  # We have a year given, so find calendar filenames starting with it.
  theYear = ARGV[0]
else
  # We have no year given, so find calendar files from just this current year
  theYear = thisYear
end
puts "Creating stats at #{timeNowFmt} for #{theYear}:"
# @@@ could use error handling here
Dir.chdir(NPCalendarDir)
Dir.glob("#{theYear}*.txt").each do |this_file|
  calFiles[n] = NPCalendar.new(this_file, n)
  n += 1
end

# Initialise counting array and zero all its terms
counts = []
futureCounts = []
i = 0
TagsToCount.each do |_t|
  counts[i] = futureCounts[i] = 0
  i += 1
end

if n.positive? # if we have some notes to work on ...
  days = futureDays = 0
  # puts "Found #{n} notes to attempt to summarise."
  # Iterate over all Calendar items, and count tags of interest.
  calFiles.each do |cal|
    puts "  Scanning file #{cal.filename}: #{cal.tags}"
    i = 0
    TagsToCount.each do |t|
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
  TagsToCount.each do |t|
    printf("%-15s\t%3d\t%3d\n", t, counts[i], futureCounts[i])
    # puts "#{t}\t#{counts[i]}\t#{futureCounts[i]}"
    i += 1
  end
  printf("(Days found    \t%3d\t%3d)\n", days, futureDays)

  # Write out to a file (replacing any existing one)
  f = File.open(NPSummariesDir + '/' + theYear + '_tag_stats.csv', 'w')
  i = 0
  f.puts 'Tag,Past,Future,#{timeNowFmt}'
  TagsToCount.each do |t|
    f.printf("%s,%d,%d\n", t, counts[i], futureCounts[i])
    i += 1
  end
  f.printf("Days found,%d,%d\n", days, futureDays)
  f.close

else
  puts "Warning: No matching files found.\n".colorize(WarningColour)
end
