#!/usr/bin/ruby
#-------------------------------------------------------------------------------
# NotePlan Tag Stats Summariser
# Jonathan Clark, v1.4, 10.10.2020
#-------------------------------------------------------------------------------
# Script to give stats on various tags in NotePlan's daily calendar files.
#
# It notices and summarises the #hashtags specified in TAGS_TO_COUNT, which is
# ignored and counts all tags if -a is specified.
# It also notices and summarises the @mentions(n) specified in MENTIONS_TO_COUNT,
# assuming that the (n) is an integer.
# It writes outputs to screen and to a CSV file.
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
#-------------------------------------------------------------------------------
# For more information, including installation, please see the GitHub repository:
#   https://github.com/jgclark/NotePlan-stats/
#-------------------------------------------------------------------------------
VERSION = '1.4'.freeze
# TODO: do weekly summary of MENTIONS_TO_COUNT
# - and the week commencing date too

require 'date'
require 'time'
require 'etc' # for login lookup, though currently not used
require 'colorize' # for coloured output using https://github.com/fazibear/colorize
require 'optparse'

# User-settable constants
STORAGE_TYPE = 'CloudKit'.freeze # or Dropbox or CloudKit or iCloud
# Tags to count up.
TAGS_TO_COUNT = ['#holiday', '#halfholiday', '#bankholiday', '#dayoff', '#sundayoff',
                 '#friends', '#family', '#bbq', '#bookread',
                 '#preach', '#wedding', '#funeral', '#baptism', '#dedication', '#thanksgiving',
                 '#welcome', '#homevisit', '#conference', '#training', '#retreat', '#mentor', '#mentee',
                 '#parkrun', '#dogwalk', '#dogrun', '#run',
                 '#leadaaw', '#leadmw', '#leadmp', '#leadhc', '#recordvideo', '#editvideo', '#article',
                 '#firekiln', '#glassmaking', '#tiptrip'].sort # simple array of strings
MENTIONS_TO_COUNT = ['@work', '@sleep']
DATE_FORMAT = '%d.%m.%y'.freeze
DATE_TIME_FORMAT = '%e %b %Y %H:%M (week %V, day %j)'.freeze
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
  attr_reader :mentions
  attr_reader :filename
  attr_reader :is_future
  attr_reader :week_num

  def initialize(this_file, id)
    # initialise instance variables (that persist with the class instance)
    @filename = this_file
    @id = id
    @lines = []
    @lineCount = 0
    @tags = ''
    @mentions = ''
    @is_future = false
    @week_num = nil

    # mark this as a future date if the filename YYYYMMDD part as a string is greater than DateToday in YYYYMMDD format
    yyyymmdd = @filename[0..7]
    @is_future = true if yyyymmdd > DATE_TODAY_YYYYMMDD
    puts "  Initialising #{@filename}".colorize(TotalColour) if $verbose
    # save which week number this is (NB: 00-53 are apparently all possible), 
    # based on weeks starting on first Monday of year (1), and before then 0
    this_date = Date.strptime(@filename, "%Y%m%d")
    @week_num = this_date.strftime("%W").to_i

    # Open file and read in
    # NB: needs the encoding line when run from launchctl, otherwise you get US-ASCII invalid byte errors (basically the 'locale' settings are different)
    lines = ''
    File.open(@filename, 'r', encoding: 'utf-8') do |f|
      # Read through header lines
      f.each_line do |line|
        lines += line
      end
    end
    # extract all #hashtags from lines and store
    @tags = lines.scan(%r{#[\w/]+}).join(' ')
    puts "    Found tags: #{@tags}" if $verbose && !@tags.empty?
    # extract all @mentions(something) from lines and store
    @mentions = lines.scan(%r{@[\w/]+\(\d+?\)}).join(' ')
    puts "    Found mentions: #{@mentions}" if $verbose && !@mentions.empty?
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
  options[:all] = false
  options[:write_file] = true
  options[:verbose] = false
  # opts.on('-a', '--all', 'Count all found tags, not just those configured in TAGS_TO_COUNT') do
  #   options[:all] = true
  # end
  opts.on('-h', '--help', 'Show help') do
    puts opts
    exit
  end
  opts.on('-n', '--nofile', 'Do not write summary to file') do
    options[:write_file] = false
  end
  opts.on('-v', '--verbose', 'Show information as I work') do
    options[:verbose] = true
  end
end
opt_parser.parse! # parse out options, leaving file patterns to process
$verbose = options[:verbose]

time_now = Time.now
time_now_fmt = time_now.strftime(DATE_TIME_FORMAT)
this_year_str = time_now.strftime('%Y')
this_week_num = time_now.strftime("%W").to_i
n = 0 # number of notes/calendar entries to work on
calFiles = [] # to hold all relevant calendar objects

# Work out which year's calendar files to be summarising
the_year_str = ARGV[0] || this_year_str
print "Creating stats at #{time_now_fmt} for #{the_year_str} ..."
begin
  Dir.chdir(NP_CALENDAR_DIR)
  Dir.glob("#{the_year_str}*.txt").each do |this_file|
    # ignore this file if the directory starts with '@'
    # fsize = File.size?(this_file) || 0
    # puts "#{this_file} size #{fsize}" if $verbose
    next unless this_file =~ /^[^@]/ # as can't get file glob including [^@] to work
    # ignore this file if it's empty
    next if File.zero?(this_file)

    calFiles[n] = NPCalendar.new(this_file, n)
    n += 1
  end
  print " ... analysed #{n} found notes.\n"
rescue StandardError => e
  puts "ERROR: Hit #{e.exception.message} when reading calendar files.".colorize(WarningColour)
  exit
end

#-----------------------------------------------------------------------
# Initialisation
#-----------------------------------------------------------------------
if options[:all]
  # TODO: complete this, looking over each relevant file
  # will need to turn this option on as well above
end

# if we have some notes to work on ...
if n.positive?

  # Initialise counting arrays for #hashtags and zero all its terms
  tag_counts = Array.new(TAGS_TO_COUNT.count, 0)
  tag_counts_future = Array.new(TAGS_TO_COUNT.count, 0)

  # Initialize counting hash for @mention(n) and zero all its term
  # Helpful ruby hash summary: https://www.tutorialspoint.com/ruby/ruby_hashes.htm
  # Nested hash examples: http://www.korenlc.com/nested-arrays-hashes-loops-in-ruby/
  param_counts = Hash.new(0)
  mention_week_totals = Array.new(53,0) { Array.new(2,0) }
  mi = 0
  MENTIONS_TO_COUNT.each do |m|
    # create empty nested hashes for each @mention
    param_counts[m] = Hash.new(0)
    # w = 0
    # while w<=52
    # puts mention_week_totals[w][mi]
    #   # mention_week_totals[w][mi] = 0
    #   w += 1
    # end
    # mi += 1
  end

  #-----------------------------------------------------------------------
  # Do counts
  #-----------------------------------------------------------------------
  days = futureDays = 0
  # Iterate over all Calendar items
  calFiles.each do |cal|
    # puts "  Scanning file #{cal.filename}: #{cal.tags}"
    i = 0
    # Count #tags of interest
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

    # Count @mentions(n) of interest
    i = 0
    mi = 0
    MENTIONS_TO_COUNT.each do |m|
      next unless cal.mentions =~ /#{m}\(\d+?\)/i # case-insensitive

      puts "   #{cal.filename} has #{cal.mentions}" if $verbose
      cal.mentions.scan(/#{m}\((\d+?)\)/).each do |p|
        pi = p.join.to_i # deal with integers rather than their string equivalents
        pc = param_counts[m].fetch(pi, 0) # get current value, or if doesn't exist, default to 0
        puts "    new #{m}(#{p})   already seen #{pc}" if $verbose
        param_counts[m][pi] = pc + 1
        puts "#{cal.week_num} #{mi} #{pi} = #{mention_week_totals[cal.week_num][mi]}"
        mention_week_totals[cal.week_num][mi] += pi
      end
      mi += 1
    end
  end
  puts if $verbose

  #-----------------------------------------------------------------------
  # Write outputs: screen and perhaps file as well
  #-----------------------------------------------------------------------
  # Write out to a file (replacing any existing one)
  # begin
    if options[:write_file]
      # TODO: Check whether Summaries directory exists. If not, create it.
      filepath = OUTPUT_DIR + '/' + the_year_str + '_tag_stats.csv'
      f = File.open(filepath, 'w')
    end

    # Write out the #hashtag counts
    puts "Tag\t\tPast\tFuture\tfor #{the_year_str}".bold
    f.puts "Tag,Past,Future,#{time_now_fmt}" if options[:write_file]

    # Write out the #tag counts list
    i = 0
    TAGS_TO_COUNT.each do |t|
      printf("%-15s\t%3d\t%3d\n", t, tag_counts[i], tag_counts_future[i])
      f.printf("%s,%d,%d\n", t, tag_counts[i], tag_counts_future[i]) if options[:write_file]
      i += 1
    end
    df = printf("  (Days found  \t%3d\t%3d)\n", days, futureDays)
    puts "#{df}".bold
    f.printf("Days found,%d,%d\n", days, futureDays) if options[:write_file]

    # Write out the @mention counts
    # Involves taking each main part of the hash and converting to an array to sort it
    # items need to be integer, to sort properly here (see pi earlier)
    MENTIONS_TO_COUNT.each do |m|
      ma = param_counts[m].sort
      next if ma.empty?

      m_key_screen = '  Param:'
      m_key_file = 'Param'
      m_value_screen = '  Count:'
      m_value_file = 'Count'
      # m_sum_screen = '  Total:'
      # m_sum_file = 'Total'
      i = 0
      while i < ma.size
        mak = ma[i][0]
        mav = ma[i][1]
        m_key_screen += "\t#{mak}"
        m_value_screen += "\t#{mav}"
        m_key_file += ",#{mak}"
        m_value_file += ",#{mav}"
        i += 1
        # Calculate the sum of this k*v
        # m_sum = mak * mav
        # m_sum_screen += "\t#{m_sum}"
        # m_sum_file += ",#{m_sum}"
      end

      # Write output to screen
      puts "\n#{m} mentions for #{the_year_str}".colorize(TotalColour)
      puts m_key_screen
      puts m_value_screen
      # puts m_sum_screen

      # Write output to file
      next unless options[:write_file]

      f.puts "\n#{m} mentions for #{the_year_str}"
      f.puts m_key_file
      f.puts m_value_file
      # f.puts m_sum_file
    end

    # Calc and write out @mention totals
    m_head_screen = "\nWeek #"
    m_head_file = "\nWeek #"
    m_sum = Array.new(MENTIONS_TO_COUNT.count,0)
    m_sum_screen = 'Total:'
    m_sum_file = 'Total'
    mi = 0
    while mi < MENTIONS_TO_COUNT.count
      m_head_file += "\t#{MENTIONS_TO_COUNT[mi]}"
      m_head_screen += ",#{MENTIONS_TO_COUNT[mi]}"
      mi += 1
    end
    puts m_head_file
    f.puts m_head_screen if options[:write_file]
    w = 0
    while w < this_week_num
      outs = "#{w}"
      outf = "#{w}"
      mi = 0
      mc = 0
      while mi < MENTIONS_TO_COUNT.count
        mwt = mention_week_totals[w][mi]
        m_sum[mi] += mwt # sum how many items for this mention
        mc += mwt # sum how many items reported this week
        outs += "\t#{mwt}"
        outf += ",#{mwt}"
        mi += 1
      end
      # write this week's totals, but only if there if any are non-zero
      if (mc>0) 
        puts outs
        f.puts outf if options[:write_file] # also write output to file
      end
      w += 1
    end
    mi = 0
    while mi < MENTIONS_TO_COUNT.count
      m_sum_screen += "\t#{m_sum[mi]}"
      m_sum_file += ",#{m_sum[mi]}"
      mi += 1
    end
    puts "#{m_sum_screen}".bold
    f.puts m_sum_file if options[:write_file] # also write output to file
    f.close if options[:write_file]

  # rescue StandardError => e
  #   puts "ERROR: Hit #{e.exception.message} when writing out summary to screen or #{filepath}".colorize(WarningColour)
  # end
else
  puts "Warning: No matching files found.\n".colorize(WarningColour)
end
