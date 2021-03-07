#!/usr/bin/ruby
#-------------------------------------------------------------------------------
# NotePlan Attribute 
# Jonathan Clark, v0.1, 21.2.2021
#-------------------------------------------------------------------------------
# Script to summarise attributes from NP notes for different time periods,
# or projects.
#
# It uses any found 'attribute::'s, or reads from a local json file listing which
# ones to include.
# It writes outputs to screen
#
# TODO:
# * [ ] get working for project files as well
# * [ ] allow for multuple attributes on same line (up to next attr or @ or #) -- see Expressions ... need to 
# * [ ] allow for numeric attributes (specify differently in JSON)
# * [ ] write to a suitable monthly file
# * [ ] option to add into a note in NP itself
#-------------------------------------------------------------------------------
VERSION = '0.1.0'.freeze

require 'date'
require 'time'
require 'colorize' # for coloured output using https://github.com/fazibear/colorize
require 'optparse'
require 'json'

# Other User-settable Constant Definitions
JSON_SETTINGS_FILE = "#{ENV['NPEXTRAS']}/npAttributes.json".freeze
wanted_attrs = ['Alive', 'Mood']
default_interval = '1w' # time interval (in b/d/w/m/q/y) to summarise over by default
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
TOMORROWS_DATE = Date.today + 1
DATE_TODAY_YYYYMMDD = TODAYS_DATE.strftime('%Y%m%d')
NP_NOTE_DIR = "#{np_base_dir}/Notes".freeze
NP_CALENDAR_DIR = "#{np_base_dir}/Calendar".freeze
# TODO: Check whether Summaries directory exists. If not, create it.
OUTPUT_DIR = if Dir.exist?(CLOUDKIT_DIR) && Dir[File.join(CLOUDKIT_DIR, '**', '*')].count { |file| File.file?(file) } > 1
               "#{ENV['NPEXTRAS']}" # save in user-specified directory as it won't be sync'd in a CloudKit directory
             else
               "#{np_base_dir}/Summaries".freeze # but otherwise can store in Summaries/ directory in NP
             end

# Colours, using the colorization gem
TotalColour = :light_yellow
WarningColour = :light_red

#-------------------------------------------------------------------------
# Helper definitions
#-------------------------------------------------------------------------

def calc_offset_date(old_date, interval)
  # Calculate next review date, assuming:
  # - old_date is type
  # - interval is string of form nn[bdwmq]
  #   - where 'b' is weekday (i.e. Monday-Friday in English)
  # puts "    c_o_d: old #{old_date} interval #{interval} ..."
  days_to_add = 0
  unit = interval[-1] # i.e. get last characters
  num = interval.chop.to_i
  case unit
  when 'b' # week days
    # Method from Arjen at https://stackoverflow.com/questions/279296/adding-days-to-a-date-but-excluding-weekends
    # Avoids looping, and copes with negative intervals too
    current_day_of_week = old_date.strftime("%u").to_i  # = day of week with Monday = 0, .. Sunday = 6
    dayOfWeek = num.negative? ? (current_day_of_week - 12).modulo(7) : (current_day_of_week + 6).modulo(7)
    num -= 1 if dayOfWeek == 6
    num += 1 if dayOfWeek == -6
    days_to_add = num + (num + dayOfWeek).div(5) * 2
  when 'd'
    days_to_add = num
  when 'w'
    days_to_add = num * 7
  when 'm'
    days_to_add = num * 30 # on average. Better to use >> operator, but it only works for months
  when 'q'
    days_to_add = num * 91 # on average
  when 'y'
    days_to_add = num * 365 # on average
  else
    puts "    Unknown unit '#{unit}' in calc_offset_date from #{old_date} by #{interval}".colorize(WarningColour)
  end
  puts "    c_o_d: with #{old_date} interval #{interval} found #{days_to_add} days_to_add" if $verbose
  return old_date + days_to_add
end

def create_new_empty_file(title, ext)
  # Populate empty NPFile object, adding just title

  # Use x-callback scheme to add a new note in NotePlan,
  # as defined at http://noteplan.co/faq/General/X-Callback-Url%20Scheme/
  #   noteplan://x-callback-url/addNote?text=New%20Note&openNote=no
  # Open a note identified by the title or date.
  # Parameters:
  # - noteTitle optional, will be prepended if it is used
  # - text optional, text will be added to the note
  # - openNote optional, values: yes (opens the note, if not already selected), no
  # - subWindow optional (only Mac), values: yes (opens note in a subwindow) and no
  # NOTE: So far this can only create notes in the top-level Notes folder
  # Does cope with emojis in titles.
  uriEncoded = "noteplan://x-callback-url/addNote?noteTitle=" + URI.escape(title) + "&openNote=no"
  begin
    response = `open "#{uriEncoded}"` # TODO: try simpler open(...) with no response, and rescue errors
  rescue StandardError => e
    puts "    Error #{e.exception.message} trying to add note with #{uriEncoded}. Exiting.".colorize(WarningColour)
    exit
  end

  # Now read this new file into the $allNotes array
  Dir.chdir(NP_NOTES_DIR)
  sleep(3) # wait for the file to become available. TODO: probably a smarter way to do this
  filename = "#{title}.#{ext}"
  new_note = NPFile.new(filename)
  new_note_id = new_note.id
  $allNotes[new_note_id] = new_note
  puts "Added new note id #{new_note_id} with title '#{title}' and filename '#{filename}'. New $allNotes count = #{$allNotes.count}" if $verbose
end

#-------------------------------------------------------------------------
# Class definition
#-------------------------------------------------------------------------
class NPNote
  # Class to hold details of a particular Calendar date; similar but different
  # to the NPNote class used in other related scripts.
  # Define the attributes that need to be visible outside the class instances
  attr_reader :id
  attr_reader :filename
  attr_reader :date_yyyymmdd
  attr_reader :week_num
  attr_reader :attrs  # TEMP: is this needed?
  attr_reader :attr_count

  def initialize(this_file, id)
    # initialise instance variables (that persist with the class instance)
    @filename = this_file
    @id = id
    @lines = [] # array
    @lineCount = 0
    @attrs = {} # hash
    # @attr_keys = [] # hold array of attribute keys found
    # @attr_values = [] # hold array of attribute values found
    @attr_count = 0

    @date_yyyymmdd = @filename[0..7]
    # save which week number this is (NB: 00-53 are apparently all possible),
    # based on weeks starting on first Monday of year (1), and before then 0
    # this_date = Date.strptime(@filename, '%Y%m%d')
    @week_num = Date.strptime(@filename, '%Y%m%d').strftime('%W').to_i
    puts "  Initialising #{@filename}".colorize(TotalColour) if $verbose

    # Open file and read in
    # NB: needs the encoding line when run from launchctl, otherwise you get US-ASCII
    # invalid byte errors (basically the 'locale' settings are different)
    lines = ''
    File.open(@filename, 'r', encoding: 'utf-8') do |f|
      # Read in all lines
      f.each_line do |line|
        lines += line
        # extract all attributes:: from lines and store in an array
        parts = line.scan(/^([\w\s]+\w)::(.+)/) # FIXME: to allow multiple ones in a line -- need positive lookbehind or something?
        next if parts.empty?

        key = parts[0][0].strip
        value = parts[0][1].strip
        # ignore if the value is blank
        next if value.empty?

        @attrs[key] = value
        # @attr_keys << parts[0][0].strip!
        # @attr_values << parts[0][1].strip!
        @attr_count += 1
        puts "    Found #{key}::#{value}" if $verbose
      end
    end
  rescue StandardError => e
    puts "ERROR: Hit #{e.exception.message} when initialising NPCalendar from #{@filename}!".colorize(WarningColour)
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
  opts.banner = 'Usage: npAttributes.rb [options] WEEKS'
  opts.separator ''
  options[:attribute] = ''
  options[:write_file] = true
  options[:verbose] = false
  opts.on('-a', '--attribute STRING', String, 'Just look for the given single attribute (specify without colons)') do |s|
    options[:attribute] = s
  end
  opts.on('-h', '--help', 'Show help') do
    puts opts
    exit
  end
  opts.on('-f', '--nofile', 'Do not write summary to file') do
    options[:write_file] = false
  end
  opts.on('-p', '--projects', 'Summarise attributes in #project notes') do
    options[:p] = false
  end
  opts.on('-v', '--verbose', 'Show information as I work') do
    options[:verbose] = true
  end
end
opt_parser.parse! # parse out options, leaving file patterns to process
puts options
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
  # puts parsed if $verbose
  wanted_attrs = parsed['attributes_to_summarise'] # probably don't sort them
  default_interval = parsed['default_interval_to_summarise']
rescue StandardError => e
  puts "ERROR: Hit #{e.exception.message} when reading JSON settings file.".colorize(WarningColour)
  exit
end

# Work out time range for Calendar files
interval = ARGV[0] || default_interval
first_date = calc_offset_date(TODAYS_DATE + 1, "-#{interval}") # +1 to make the interval be e.g. 7 days, not 8
last_date = TODAYS_DATE
puts "Summarising attributes at #{time_now_fmt} for last #{interval}"
puts "    (just looking for '#{options[:attribute]}::' attributes)."
puts "  between #{first_date} and #{last_date}" if $verbose
begin
  Dir.chdir(NP_CALENDAR_DIR)
  # Get all matching files, *in sorted order*
  Dir.glob(["*.{md,txt}"]).sort.each do |this_file|
    # ignore this file if the directory starts with '@'
    # (as can't get file glob including [^@] to work)
    next unless this_file =~ /^[^@]/
    # ignore this file if it's empty
    next if File.zero?(this_file)
    # ignore this file if it's not in the right date range
    this_file_date = "#{this_file[0..3]}-#{this_file[4..5]}-#{this_file[6..7]}"
    next if this_file_date < first_date.to_s || this_file_date > last_date.to_s
    # read this file in
    cal_files << NPNote.new(this_file, n)
    n += 1
  end
  print " -> read in #{n} relevant daily notes.\n\n"
rescue StandardError => e
  puts "ERROR: Hit #{e.exception.message} when reading calendar files.".colorize(WarningColour)
  exit
end

# if we have found files to work on ...
if cal_files.size.positive?
  # Initialize array for storing wanted attributes to filter/output
  attr_details = Array.new() { Array.new(3, '') }
  mi = 0
  # read list of attrs in each file, and match against wanted list
  cal_files.each do |c|
    puts "ID #{c.id}: Filename #{c.filename} week #{c.week_num} dated #{c.date_yyyymmdd} with #{c.attr_count} attrs" if $verbose
    if c.attr_count.positive?
      c.attrs.each do |fa|
        puts "    #{mi}: #{fa[0]} #{fa[1]}" if $verbose
        attr_details << [ fa[0], fa[1], c.date_yyyymmdd ]
        mi += 1
      end
    end
  end

  #-----------------------------------------------------------------------
  # Summarise to screen
  #-----------------------------------------------------------------------
  puts "# Attribute summary for #{first_date} to #{last_date}:\n"
  wanted_attrs.each do |wa|
    puts "\n### #{wa}:"
    attr_details.each do |ad|
      puts "- #{ad[1]} (#{ad[2]})" if ad[0] == wa
    end
  end


  # #-----------------------------------------------------------------------
  # # Do counts of tags
  # #-----------------------------------------------------------------------
  # days = futureDays = 0
  # # Iterate over all Calendar items
  # cal_files.each do |cal|
  #   puts "  Scanning file #{cal.filename}:" if $verbose > 0
  #   i = 0

  #   # Count @mentions(n) of interest -- none of which should be in the future
  #   # and also make a note on which week they were found
  #   mi = 0 # counter for which @mention we're looking for
  #   MENTIONS_TO_COUNT.each do |m|
  #     # for each @mention(n) get the value of n
  #     cal.mentions.scan(/#{m}\((\d+?)\)/i).each do |ns| # case-insensitive scan
  #       ni = ns.join.to_i # turn string element from array into integer
  #       pc = param_counts[m].fetch(ni, 0) # get current value, or if doesn't exist, default to 0
  #       puts "    #{cal.filename} has #{m}(#{ni}); already seen #{pc} of them" if $verbose
  #       param_counts[m][ni] = pc + 1
  #       puts "      #{cal.week_num} #{mi} #{ni} = #{mention_week_totals[cal.week_num][mi]}" if $verbose
  #       mention_week_totals[cal.week_num][mi] += ni
  #     end
  #     mi += 1
  #   end

  #   # also track number of future vs past days
  #   if cal.is_future
  #     futureDays += 1
  #   else
  #     days += 1
  #   end
  # end
  # puts if $verbose

  # #-----------------------------------------------------------------------
  # # Write outputs: screen and perhaps file as well
  # #-----------------------------------------------------------------------
  # # Write out to a file (replacing any existing one)
  # # begin
  # if options[:write_file]
  #   filepath = OUTPUT_DIR + '/' + the_year_str + '_tag_stats.csv'
  #   f = File.open(filepath, 'w')
  # end

  # # TODO: Ideally don't show 'future' items if date period is all in the past

  # # Write out the #hashtag counts
  # puts "Tag\t\tPast\tFuture\tFirst seen\tfor #{the_year_str}".colorize(TotalColour)
  # f.puts "Tag,Past,Future,First seen,#{time_now_fmt}" if options[:write_file]

  # # Write out the #tag counts list
  # i = 0
  # TAGS_TO_COUNT.each do |t|
  #   printf("%-15s\t%3d\t%3d\t%s\n", t, tag_counts[i], tag_counts_future[i], tag_count_first_date[i])
  #   f.printf("%s,%d,%d,%s\n", t, tag_counts[i], tag_counts_future[i], tag_count_first_date[i]) if options[:write_file]
  #   i += 1
  # end
  # df = printf("  (Days found  \t%3d\t%3d)\n", days, futureDays)
  # puts df.to_s.bold
  # f.printf("Days found,%d,%d\n", days, futureDays) if options[:write_file]

  # # Write out the @mention counts
  # # Involves taking each main part of the hash and converting to an array to sort it
  # # items need to be integer, to sort properly here (see pi earlier)
  # MENTIONS_TO_COUNT.each do |m|
  #   ma = param_counts[m].sort
  #   next if ma.empty?

  #   m_avg = (m_sum / m_count).round(1)
  #   m_sum_screen += "\t#{m_sum}"
  #   m_average_screen += "\t#{m_avg}"
  #   m_sum_file += ",#{m_sum}"
  #   m_average_file += ",#{m_avg}"

  #   # Write output to screen
  #   puts "\n#{m} mentions for #{the_year_str}".colorize(TotalColour)
  #   puts m_key_screen
  #   puts m_value_screen
  #   puts m_sum_screen
  #   puts m_average_screen

  #   # Write output to file
  #   next unless options[:write_file]

  #   f.puts "\n#{m} mentions for #{the_year_str}"
  #   f.puts m_key_file
  #   f.puts m_value_file
  #   f.puts m_sum_file
  #   f.puts m_average_file
  # end

  # while mi < MENTIONS_TO_COUNT.count
  #   m_head_screen += "\t#{MENTIONS_TO_COUNT[mi]}"
  #   m_head_file += ",#{MENTIONS_TO_COUNT[mi]}"
  #   mi += 1
  # end
  # puts m_head_screen.colorize(TotalColour)
  # f.puts m_head_file if options[:write_file]
  # w = 1 # start from week 1, as otherwise week commencing won't work
  # while w <= this_week_num
  #   wp = "#{this_year_str} #{w}"
  #   wc = Date.strptime(wp, '%Y %W').strftime('%-d.%-m.%Y') # week commencing
  #   outs = format('%2d     %-10s  ', w, wc).to_s
  #   outf = "#{w},#{wc}"
  #   mi = 0
  #   mc = 0
  #   while mi < MENTIONS_TO_COUNT.count
  #     mwt = !mention_week_totals[w][mi].nil? ? mention_week_totals[w][mi] : 0
  #     m_sum[mi] += mwt # sum how many items for this mention
  #     mc += mwt # sum how many items reported this week
  #     outs += "\t#{mwt}"
  #     outf += ",#{mwt}"
  #     mi += 1
  #   end

  #   # write this week's totals, if there if any are non-zero
  #   if mc.positive?
  #     puts outs
  #     f.puts outf if options[:write_file] # also write output to file
  #   end
  #   w += 1
  # end
  # mi = 0
  # while mi < MENTIONS_TO_COUNT.count
  #   m_sum_screen += "\t#{m_sum[mi]}"
  #   m_sum_file += ",#{m_sum[mi]}"
  #   mi += 1
  # end
  # puts "#{m_sum_screen}".colorize(TotalColour)
  # f.puts m_sum_file if options[:write_file] # also write output to file
  # f.close if options[:write_file]

  # rescue StandardError => e
  #   puts "ERROR: Hit #{e.exception.message} when writing out summary to screen or #{filepath}".colorize(WarningColour)
  # end
else
  puts "Warning: No matching files found.\n".colorize(WarningColour)
end

# INFO: on hashes 
# Hashes also offer the values_at method, which allows you to provide numerous keys and receive their values in an array. Values in hashes have to be called using these methods (fetch, [key], or values_at); hashes do not offer methods like pop in arrays.
# Ruby also offers a few methods that test elements in a hash; these are helpful to grab information about the hash without traversing the whole hash. For example:
# my_wombats.has_key?('Wilma Wombat') → true
# my_wombats.has_value?('Lamps and pandas') → false
# my_wombats.empty? → false
# my_wombats.delete['Wilma Wombat'] → its value is returned.

# INFO: Test data for finding attributes in lines:
# Test Attr:: several word value
# Another Attr:: several word value Test::34 #alpha Text:: weird eh? @words(1234)
# Test::345 #alpha Text::strange-ness @words(4321)
