#!/usr/bin/ruby
#-------------------------------------------------------------------------------
# NotePlan Tag Stats Summariser
# Jonathan Clark, v1.5.1, 14.11.2020
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
VERSION = '1.5.1'.freeze

require 'date'
require 'time'
require 'etc' # for login lookup, though currently not used
require 'colorize' # for coloured output using https://github.com/fazibear/colorize
require 'optparse'

# Tags to count up.
TAGS_TO_COUNT = ['#holiday', '#halfholiday', '#bankholiday', '#dayoff', '#sundayoff',
                 '#friends', '#family', '#bbq', '#readtheology', '#finishedbook', '#gardened', '#nap',
                 '#preach', '#wedding', '#funeral', '#baptism', '#dedication', '#thanksgiving',
                 '#welcome', '#homevisit', '#conference', '#training', '#retreat', '#mentor', '#mentee', '#call', '#greek',
                 '#parkrun', '#dogwalk', '#dogrun', '#run',
                 '#leadaaw', '#leadmw', '#leadmp', '#leadhc', '#recordvideo', '#editvideo', '#article',
                 '#firekiln', '#glassmaking', '#tiptrip'].sort # simple array of strings
MENTIONS_TO_COUNT = ['@work', '@written', '@sleep', '@water'].freeze

# Other User-settable Constant Definitions
DATE_FORMAT = '%d.%m.%y'.freeze
DATE_TIME_FORMAT = '%e %b %Y %H:%M (week %V, day %j)'.freeze

# Constants
USERNAME = ENV['LOGNAME'] # pull username from environment
USER_DIR = ENV['HOME'] # pull home directory from environment
DROPBOX_DIR = "#{USER_DIR}/Dropbox/Apps/NotePlan/Documents".freeze
ICLOUDDRIVE_DIR = "#{USER_DIR}/Library/Mobile Documents/iCloud~co~noteplan~NotePlan/Documents".freeze
CLOUDKIT_DIR = "#{USER_DIR}/Library/Containers/co.noteplan.NotePlan3/Data/Library/Application Support/co.noteplan.NotePlan3".freeze
np_base_dir = DROPBOX_DIR if Dir.exist?(DROPBOX_DIR) && Dir[File.join(DROPBOX_DIR, '**', '*')].count { |file| File.file?(file) } > 1
np_base_dir = ICLOUDDRIVE_DIR if Dir.exist?(ICLOUDDRIVE_DIR) && Dir[File.join(ICLOUDDRIVE_DIR, '**', '*')].count { |file| File.file?(file) } > 1
np_base_dir = CLOUDKIT_DIR if Dir.exist?(CLOUDKIT_DIR) && Dir[File.join(CLOUDKIT_DIR, '**', '*')].count { |file| File.file?(file) } > 1
TODAYS_DATE = Date.today # can't work out why this needs to be a 'constant' to work -- something about visibility, I suppose
DATE_TODAY_YYYYMMDD = TODAYS_DATE.strftime('%Y%m%d')
NP_NOTE_DIR = "#{np_base_dir}/Notes".freeze
NP_CALENDAR_DIR = "#{np_base_dir}/Calendar".freeze
# TODO: Check whether Summaries directory exists. If not, create it.
OUTPUT_DIR = if Dir.exist?(CLOUDKIT_DIR) && Dir[File.join(CLOUDKIT_DIR, '**', '*')].count { |file| File.file?(file) } > 1
               "/Users/#{USERNAME}/Dropbox/NPSummaries" # save in user's home directory as it won't be sync'd in a CloudKit directory
             else
               "#{np_base_dir}/Summaries".freeze # but otherwise store in Summaries/ directory
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
    @tags = [] # hold array of #tags found
    @mentions = '' # hold string space-separated list of @mentions found
    @is_future = false
    @week_num = nil

    # mark this as a future date if the filename YYYYMMDD part as a string is greater than DateToday in YYYYMMDD format
    yyyymmdd = @filename[0..7]
    @is_future = true if yyyymmdd > DATE_TODAY_YYYYMMDD
    puts "  Initialising #{@filename}".colorize(TotalColour) if $verbose > 1
    # save which week number this is (NB: 00-53 are apparently all possible),
    # based on weeks starting on first Monday of year (1), and before then 0
    this_date = Date.strptime(@filename, '%Y%m%d')
    @week_num = this_date.strftime('%W').to_i

    # Open file and read in
    # NB: needs the encoding line when run from launchctl, otherwise you get US-ASCII invalid byte errors (basically the 'locale' settings are different)
    lines = ''
    File.open(@filename, 'r', encoding: 'utf-8') do |f|
      # Read through header lines
      f.each_line do |line|
        lines += line
      end
    end

    # extract all #hashtags from lines and store in an array
    @tags = lines.scan(%r{#[\w/]+})
    puts "    Found tags: #{@tags}" if $verbose > 1 && !@tags.empty?

    # extract all @mentions(something) from lines and store in an array
    @mentions = lines.scan(%r{@[\w/]+\(\d+?\)}).join(' ')
    puts "    Found mentions: #{@mentions}" if $verbose > 1 && !@mentions.empty?
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
  options[:verbose] = 0
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
    options[:verbose] = 1
  end
  opts.on('-w', '--moreverbose', 'Show more information as I work') do
    options[:verbose] = 2
  end
end
opt_parser.parse! # parse out options, leaving file patterns to process
$verbose = options[:verbose]

time_now = Time.now
time_now_fmt = time_now.strftime(DATE_TIME_FORMAT)
this_year_str = time_now.strftime('%Y')
this_week_num = time_now.strftime('%W').to_i
n = 0 # number of notes/calendar entries to work on
calFiles = [] # to hold all relevant calendar objects

# Work out which year's calendar files to be summarising
the_year_str = ARGV[0] || this_year_str
puts "Creating stats at #{time_now_fmt} for #{the_year_str}"
begin
  Dir.chdir(NP_CALENDAR_DIR)
  Dir.glob(["#{the_year_str}*.txt", "#{the_year_str}*.md"]).each do |this_file|
    # ignore this file if the directory starts with '@'
    # fsize = File.size?(this_file) || 0
    # puts "#{this_file} size #{fsize}" if $verbose.positive?
    next unless this_file =~ /^[^@]/ # as can't get file glob including [^@] to work
    # ignore this file if it's empty
    if File.zero?(this_file)
      puts "  NB: file #{this_file} is empty".colorize(WarningColour)
      next
    end

    calFiles[n] = NPCalendar.new(this_file, n)
    n += 1
  end
  print " ... analysed #{n} found notes.\n\n"
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
  mention_week_totals = Array.new(53) { Array.new(2, 0) }
  mi = 0
  MENTIONS_TO_COUNT.each do |m|
    # create empty nested hashes for each @mention
    param_counts[m] = Hash.new(0)
  end

  #-----------------------------------------------------------------------
  # Do counts of tags
  #-----------------------------------------------------------------------
  days = futureDays = 0
  # Iterate over all Calendar items
  calFiles.each do |cal|
    # puts "  Scanning file #{cal.filename}: #{cal.tags}"
    i = 0

    # Count #tags of interest
    TAGS_TO_COUNT.each do |t|
      cal.tags.each do |c|
        if c =~ /#{t}/i # case-insensitive search
          if cal.is_future
            tag_counts_future[i] = tag_counts_future[i] + 1
          else
            tag_counts[i] = tag_counts[i] + 1
          end
        end
      end
      i += 1
    end

    # Count @mentions(n) of interest -- none of which should be in the future
    # and also make a note on which week they were found
    mi = 0 # counter for which @mention we're looking for
    MENTIONS_TO_COUNT.each do |m|

      # for each @mention(n) get the value of n
      cal.mentions.scan(/#{m}\((\d+?)\)/i).each do |ns| # case-insensitive scan
        ni = ns.join.to_i # turn string element from array into integer
        pc = param_counts[m].fetch(ni, 0) # get current value, or if doesn't exist, default to 0
        puts "   #{cal.filename} has #{m}(#{ns}); already seen #{pc} of them" if $verbose > 1
        param_counts[m][ni] = pc + 1
        puts "     #{cal.week_num} #{mi} #{ni} = #{mention_week_totals[cal.week_num][mi]}" if $verbose > 1
        mention_week_totals[cal.week_num][mi] += ni
      end
      mi += 1 
    end

    # also track number of future vs past days
    if cal.is_future
      futureDays += 1
    else
      days += 1
    end
  end
  puts if $verbose > 1

  #-----------------------------------------------------------------------
  # Write outputs: screen and perhaps file as well
  #-----------------------------------------------------------------------
  # Write out to a file (replacing any existing one)
  # begin
  if options[:write_file]
    filepath = OUTPUT_DIR + '/' + the_year_str + '_tag_stats.csv'
    f = File.open(filepath, 'w')
  end

  # Write out the #hashtag counts
  puts "Tag\t\tPast\tFuture\tfor #{the_year_str}".colorize(TotalColour)
  f.puts "Tag,Past,Future,#{time_now_fmt}" if options[:write_file]

  # Write out the #tag counts list
  i = 0
  TAGS_TO_COUNT.each do |t|
    printf("%-15s\t%3d\t%3d\n", t, tag_counts[i], tag_counts_future[i])
    f.printf("%s,%d,%d\n", t, tag_counts[i], tag_counts_future[i]) if options[:write_file]
    i += 1
  end
  df = printf("  (Days found  \t%3d\t%3d)\n", days, futureDays)
  puts df.to_s.bold
  f.printf("Days found,%d,%d\n", days, futureDays) if options[:write_file]

  # Write out the @mention counts
  # Involves taking each main part of the hash and converting to an array to sort it
  # items need to be integer, to sort properly here (see pi earlier)
  MENTIONS_TO_COUNT.each do |m|
    ma = param_counts[m].sort
    next if ma.empty?

    # puts ma if $verbose > 1
    m_key_screen = 'Value:'
    m_key_file = 'Value'
    m_value_screen = 'Count:'
    m_value_file = 'Count'
    m_sum_screen = 'Total:'
    m_sum_file = 'Total'
    m_average_screen = 'Avg:  '
    m_average_file = 'Avg:  '
    i = 0
    m_sum = 0
    m_count = 0
    m_avg = 0.0
    while i < ma.size
      mak = ma[i][0]
      mav = ma[i][1]
      m_key_screen += "\t#{mak}"
      m_value_screen += "\t#{mav}"
      m_key_file += ",#{mak}"
      m_value_file += ",#{mav}"
      i += 1
      # Track the sum of this k*v
      m_sum += mav * mak
      m_count += mav
      puts "   #{mav} * #{mak} -> #{m_sum} (cum) over #{m_count} (cum)" if $verbose > 1
    end
    m_avg = (m_sum / m_count).round(1)
    m_sum_screen += "\t#{m_sum}"
    m_average_screen += "\t#{m_avg}"
    m_sum_file += ",#{m_sum}"
    m_average_file += ",#{m_avg}"

    # Write output to screen
    puts "\n#{m} mentions for #{the_year_str}".colorize(TotalColour)
    puts m_key_screen
    puts m_value_screen
    puts m_sum_screen
    puts m_average_screen

    # Write output to file
    next unless options[:write_file]

    f.puts "\n#{m} mentions for #{the_year_str}"
    f.puts m_key_file
    f.puts m_value_file
    f.puts m_sum_file
    f.puts m_average_file
  end

  # Calc and write out @mention totals
  m_head_screen = "\nWeek#  W/C       "
  m_head_file = "\nWeek#,W/C"
  m_sum = Array.new(MENTIONS_TO_COUNT.count,0)
  m_sum_screen = "            Total:"
  m_sum_file = ',Total'
  mi = 0
  mc = 0
  while mi < MENTIONS_TO_COUNT.count
    m_head_screen += "\t#{MENTIONS_TO_COUNT[mi]}"
    m_head_file += ",#{MENTIONS_TO_COUNT[mi]}"
    mi += 1
  end
  puts m_head_screen.colorize(TotalColour)
  f.puts m_head_file if options[:write_file]
  w = 1 # start from week 1, as otherwise week commencing won't work
  while w <= this_week_num
    wp = "#{this_year_str} #{w}"
    wc = Date.strptime(wp, '%Y %W').strftime('%-d.%-m.%Y') # week commencing
    outs = sprintf("%2d     %-10s  ", w, wc).to_s
    outf = "#{w},#{wc}"
    mi = 0
    mc = 0
    while mi < MENTIONS_TO_COUNT.count
      mwt = !mention_week_totals[w][mi].nil? ? mention_week_totals[w][mi] : 0
      m_sum[mi] += mwt # sum how many items for this mention
      mc += mwt # sum how many items reported this week
      outs += "\t#{mwt}"
      outf += ",#{mwt}"
      mi += 1
    end
    
    # write this week's totals, if there if any are non-zero
    if mc.positive?
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
  puts "#{m_sum_screen}".colorize(TotalColour)
  f.puts m_sum_file if options[:write_file] # also write output to file
  f.close if options[:write_file]

  # rescue StandardError => e
  #   puts "ERROR: Hit #{e.exception.message} when writing out summary to screen or #{filepath}".colorize(WarningColour)
  # end
else
  puts "Warning: No matching files found.\n".colorize(WarningColour)
end
