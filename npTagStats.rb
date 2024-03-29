#!/usr/bin/env ruby
#-------------------------------------------------------------------------------
# NotePlan Tag Stats Summariser
# Jonathan Clark, v1.7.1, 1.1.2023
#-------------------------------------------------------------------------------
# Note: The rounding arithmetic is a little crude
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
# - see README for details of the .json file
#-------------------------------------------------------------------------------
# For more information, including installation, please see the GitHub repository:
#   https://github.com/jgclark/NotePlan-stats/
#-------------------------------------------------------------------------------
VERSION = '1.7.1'.freeze

require 'date'
require 'time'
require 'colorize' # for coloured output using https://github.com/fazibear/colorize
require 'optparse'
require 'json'
# require 'FileList'

# Other User-settable Constant Definitions
JSON_SETTINGS_FILE = "#{ENV['NPEXTRAS']}/npTagStats.json".freeze
DATE_FORMAT = '%d.%m.%y'.freeze
DATE_TIME_FORMAT = '%e %b %Y %H:%M (week %V, day %j)'.freeze

# Constants
USER_DIR = ENV['HOME'] # pull home directory from environment
DROPBOX_DIR = "#{USER_DIR}/Dropbox/Apps/NotePlan/Documents".freeze
ICLOUDDRIVE_DIR = "#{USER_DIR}/Library/Mobile Documents/iCloud~co~noteplan~NotePlan/Documents".freeze
CLOUDKIT_DIR = "#{USER_DIR}/Library/Containers/co.noteplan.NotePlan3/Data/Library/Application Support/co.noteplan.NotePlan3".freeze
np_base_dir = DROPBOX_DIR if Dir.exist?(DROPBOX_DIR) && Dir[File.join(DROPBOX_DIR, '**', '*')].count { |file| File.file?(file) } > 1
np_base_dir = ICLOUDDRIVE_DIR if Dir.exist?(ICLOUDDRIVE_DIR) && Dir[File.join(ICLOUDDRIVE_DIR, '**', '*')].count { |file| File.file?(file) } > 1
np_base_dir = CLOUDKIT_DIR if Dir.exist?(CLOUDKIT_DIR) && Dir[File.join(CLOUDKIT_DIR, '**', '*')].count { |file| File.file?(file) } > 1
TODAYS_DATE = Date.today # can't work out why this needs to be a 'constant' to work -- something about visibility, I suppose
DATE_TODAY_YYYYMMDD = TODAYS_DATE.strftime('%Y%m%d')
WEEK_TODAY_YYYYWWW = TODAYS_DATE.strftime('%Y-W%W')
NP_NOTE_DIR = "#{np_base_dir}/Notes".freeze
NP_CALENDAR_DIR = "#{np_base_dir}/Calendar".freeze
# TODO: Check whether Summaries directory exists. If not, create it.
OUTPUT_DIR = if Dir.exist?(CLOUDKIT_DIR) && Dir[File.join(CLOUDKIT_DIR, '**', '*')].count { |file| File.file?(file) } > 1
               ENV['NPEXTRAS'] # save in user-specified directory as it won't be sync'd in a CloudKit directory
             else
               "#{np_base_dir}/Summaries".freeze # but otherwise can store in Summaries/ directory in NP
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
    date_part = @filename[0..7]
    if @filename =~ /\d{8}/ # daily note
      @is_future = true if date_part > DATE_TODAY_YYYYMMDD
      # save which week number this is (NB: 00-53 are all possible),
      # based on weeks starting on first Monday of year (1), and before then 0
      this_date = Date.strptime(@filename, '%Y%m%d')
      @week_num = this_date.strftime('%W').to_i
    elsif @filename =~ /\d{4}-W[0-5]\d/ # weekly note
      @is_future = true if date_part > WEEK_TODAY_YYYYWWW
      @week_num = @filename[6..7].to_i
    elsif @filename =~ /\d{4}-[0-1]\d/ # monthly note
      # TODO: work out @is_future here
      this_date = Date.strptime(@filename, '%Y-%m')
      @week_num = this_date.strftime('%W').to_i
    elsif @filename =~ /\d{4}-Q[1-4]/ # quarterly note
      # as strptime doesn't recognise quarters, need to convert to fake month
      q = @filename[6]
      fake_date_part = (q=='1') ? @filename[0..3]+'0101' 
        : (q=='2') ? @filename[0..3]+'0401' 
        : (q=='3') ? @filename[0..3]+'0701' 
        : (q=='4') ? @filename[0..3]+'1001' : ''
      this_date = Date.strptime(fake_date_part, '%Y%m%d')
      @is_future = true if fake_date_part > DATE_TODAY_YYYYMMDD
      @week_num = this_date.strftime('%W').to_i
    elsif @filename =~ /\d{4}/ # yearly note
      # TODO: work out @is_future here
      this_date = Date.strptime(@filename, '%Y')
      @week_num = this_date.strftime('%W').to_i
    end
    puts "  Initialising #{@filename}".colorize(TotalColour) if $verbose > 1

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
    puts "    Found tags: #{@tags}" if !@tags.empty? && $verbose > 1

    # extract all @mentions(something) from lines and store in an array
    @mentions = lines.scan(%r{@[\w/]+\(\d+\.?\d*\)}).join(' ')
    puts "    Found mentions: #{@mentions}" if !@mentions.empty? && $verbose > 1
  rescue StandardError => e
    puts "ERROR: Hit #{e.exception.message} when initialising NPCalendar from #{@filename}".colorize(WarningColour)
  end
end

#=======================================================================================
# Main logic
#=======================================================================================

#-----------------------------------------------------------------------
# Setup program options
#-----------------------------------------------------------------------
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

#-----------------------------------------------------------------------
# Initialisation
#-----------------------------------------------------------------------
time_now = Time.now
time_now_fmt = time_now.strftime(DATE_TIME_FORMAT)
this_year_str = time_now.strftime('%Y')
this_week_num = time_now.strftime('%W').to_i
n = 0 # number of notes/calendar entries to work on
cal_files = [] # to hold all relevant calendar objects

# Read JSON settings from a file
begin
  f = File.open(JSON_SETTINGS_FILE)
  json = f.read
  f.close
  parsed = JSON.parse(json) # returns a hash
  puts parsed if $verbose > 1
  TAGS_TO_COUNT = parsed['tags_to_count'].sort
  puts TAGS_TO_COUNT if $verbose > 1
  MENTIONS_TO_COUNT = parsed['mentions_to_count'].sort
  puts MENTIONS_TO_COUNT if $verbose > 1
rescue JSON::ParserError => e
  # FIXME: why doesn't this error fire when it can't find the file?
  puts "ERROR: Hit #{e.exception.message} when reading JSON settings file.".colorize(WarningColour)
  exit
end

if options[:all]
  # TODO: complete this, looking over each relevant file
  # will need to turn this option on as well above
end

# Work out which year's calendar files to be summarising
the_year_str = ARGV[0] || this_year_str
puts "Creating stats at #{time_now_fmt} for #{the_year_str} - v#{VERSION}"
begin
  Dir.chdir(NP_CALENDAR_DIR)
  # Get all matching files, *in sorted order*
  Dir.glob(["#{the_year_str}*.txt", "#{the_year_str}*.md"]).sort.each do |this_file|
    # ignore this file if the directory starts with '@'
    # (as can't get file glob including [^@] to work)
    next unless this_file =~ /^[^@]/

    # puts "#{this_file} size #{fsize}" if $verbose.positive?
    # ignore this file if it's empty
    if File.zero?(this_file)
      puts "  NB: file #{this_file} is empty".colorize(WarningColour)
      next
    end

    cal_files[n] = NPCalendar.new(this_file, n)
    n += 1
  end
  print " ... analysed #{n} found notes.\n\n"
rescue StandardError => e
  puts "ERROR: Hit #{e.exception.message} when reading calendar files.".colorize(WarningColour)
  exit
end

# if we have some notes to work on ...
if n.positive?

  # Initialise counting arrays for #hashtags and zero all its terms
  tag_counts = Array.new(TAGS_TO_COUNT.count, 0)
  tag_counts_future = Array.new(TAGS_TO_COUNT.count, 0)
  tag_count_first_date = Array.new(TAGS_TO_COUNT.count, '')

  # Initialize counting hash for @mention(n) and zero all its term
  # Helpful ruby hash summary: https://www.tutorialspoint.com/ruby/ruby_hashes.htm
  # Nested hash examples: http://www.korenlc.com/nested-arrays-hashes-loops-in-ruby/
  param_counts = Hash.new(0)
  mention_week_totals = Array.new(53) { Array.new(MENTIONS_TO_COUNT.count, 0) }
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
  cal_files.each do |cal|
    puts "  Scanning file #{cal.filename}:" if $verbose > 1
    i = 0

    # Count #tags of interest
    TAGS_TO_COUNT.each do |t|
      cal.tags.each do |c|
        next if c !~ /#{t}/i # case-insensitive search

        if cal.is_future
          tag_counts_future[i] = tag_counts_future[i] + 1
        else
          tag_counts[i] = tag_counts[i] + 1
          tag_count_first_date[i] = "#{cal.filename[6..7]}/#{cal.filename[4..5]}" if tag_count_first_date[i] == ''
        end
        puts "    Found #{t}; counts now #{tag_counts[i]} #{tag_counts_future[i]}; first date #{tag_count_first_date[i]}" if $verbose > 1
      end
      i += 1
    end

    # Save and count @mentions(n) of interest -- none of which should be in the future
    # and also make a note on which week they were found
    mi = 0 # counter for which @mention we're looking for
    MENTIONS_TO_COUNT.each do |m|
      # for each @mention(n) get the value of n
      cal.mentions.scan(/#{m}\((\d+\.?\d*)\)/i).each do |ns| # case-insensitive scan
        # Note: This is a bit of a hack as it started life with only integer values
        ni = ns.join.to_i # turn string element from array into integer
        nf = ns[0].to_f
        pc = param_counts[m].fetch(ni, 0) # get current value, or if doesn't exist, default to 0
        param_counts[m][ni] = pc + 1
        puts "    #{cal.filename} has #{m}(#{nf}); already seen #{pc} of them. Wk #{cal.week_num} mi #{mi} ni #{ni} -> #{mention_week_totals[cal.week_num][mi]}" if $verbose > 1
        mention_week_totals[cal.week_num][mi] += nf
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

  # TODO: Ideally don't show 'future' items if date period is all in the past

  # Write out the #hashtag counts
  puts "Tag\t\tPast\tFuture\tFirst seen\tfor #{the_year_str}".colorize(TotalColour)
  f.puts "Tag,Past,Future,First seen,#{time_now_fmt}" if options[:write_file]

  # Write out the #tag counts list
  i = 0
  TAGS_TO_COUNT.each do |t|
    printf("%-15s\t%3d\t%3d\t%s\n", t, tag_counts[i], tag_counts_future[i], tag_count_first_date[i])
    f.printf("%s,%d,%d,%s\n", t, tag_counts[i], tag_counts_future[i], tag_count_first_date[i]) if options[:write_file]
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
    m_avg = (((m_sum / m_count)*1000).round(0))/1000
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
  m_sum = Array.new(MENTIONS_TO_COUNT.count, 0)
  m_sum_screen = '            Total:'
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
    outs = format('%2d     %-10s  ', w, wc).to_s
    outf = "#{w},#{wc}"
    mi = 0
    mc = 0
    while mi < MENTIONS_TO_COUNT.count
      mwt = !mention_week_totals[w][mi].nil? ? mention_week_totals[w][mi].round(0) : 0
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
    m_this_sum = m_sum[mi].round(0)
    m_sum_screen += "\t#{m_this_sum}"
    m_sum_file += ",#{m_this_sum}"
    mi += 1
  end
  puts m_sum_screen.colorize(TotalColour)
  f.puts m_sum_file if options[:write_file] # also write output to file
  f.close if options[:write_file]

  # rescue StandardError => e
  #   puts "ERROR: Hit #{e.exception.message} when writing out summary to screen or #{filepath}".colorize(WarningColour)
  # end
else
  puts "Warning: No matching files found.\n".colorize(WarningColour)
end
