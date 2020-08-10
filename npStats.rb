#!/usr/bin/ruby
#-------------------------------------------------------------------------------
# NotePlan Task Stats Summariser
# (c) JGC, v1.3.2, 247.7.2020
#-------------------------------------------------------------------------------
# Script to give stats on various tags in NotePlan's note and calendar files.
# From NotePlan v2.5 it also covers notes in sub-directories, but ignores notes
# in the special @Archive and @Trash sub-directories (or others beginning @).
#
# It finds and summarises todos/tasks in note and calendar files:
# - only covers active notes (not archived or cancelled)
# - counts open tasks, open undated tasks, done tasks, future tasks
# - breaks down by Goals/Projects/Other
# It writes output to screen and to a CSV file
#
# Configuration:
# - STORAGE_TYPE: select CloudKit (default from NP3.0), iCloudDrive (default until NP3) or Drobpox
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
DATE_FORMAT = '%d.%m.%y'.freeze
DATE_TIME_FORMAT = '%e %b %Y %H:%M'.freeze
USERNAME = 'jonathan'.freeze

# Other Constant Definitions
TODAYS_DATE = Date.today # can't work out why this needs to be a 'constant' to work -- something about visibility, I suppose
DATE_TODAY_YYYYMMDD = TODAYS_DATE.strftime('%Y%m%d')
STORAGE_TYPE = 'CloudKit'.freeze # or Dropbox or CloudKit or iCloud
NP_BASE_DIR = if STORAGE_TYPE == 'Dropbox'
                "/Users/#{USERNAME}/Dropbox/Apps/NotePlan/Documents" # for Dropbox storage
              elsif STORAGE_TYPE == 'CloudKit'
                "/Users/#{USERNAME}/Library/Application Support/co.noteplan.NotePlan3" # for CloudKit storage
              else
                "/Users/#{USERNAME}/Library/Mobile Documents/iCloud~co~noteplan~NotePlan/Documents" # for iCloud storage (default)
  end
NP_CALENDAR_DIR = "#{NP_BASE_DIR}/Calendar".freeze
NP_NOTE_DIR = "#{NP_BASE_DIR}/Notes".freeze
OUTPUT_DIR = if STORAGE_TYPE == 'CloudKit'
               "/Users/#{USERNAME}" # save in user's home directory as it won't be sync'd in a CloudKit directory
             else
               "#{NP_BASE_DIR}/Summaries".freeze # but otherwise store in Summaries/ directory
  end
puts "(Working dir: #{OUTPUT_DIR})"

# Colours, using the colorization gem
TotalColour = :light_yellow
WarningColour = :light_red

#-------------------------------------------------------------------------
# Class definitions
#-------------------------------------------------------------------------
class NPCalendar
  # Class to hold details of a particular Calendar date; similar but different
  # to the NPNote class used in other related scripts.
  # Define the attributes that need to be visible outside the class instances
  attr_reader :id
  attr_reader :tags
  attr_reader :filename
  attr_reader :is_future
  attr_reader :open
  attr_reader :waiting
  attr_reader :done
  attr_reader :future
  attr_reader :undated

  def initialize(this_file, id)
    # initialise instance variables (that persist with the class instance)
    @filename = this_file
    @id = id
    @open = @waiting = @done = @future = @undated = 0
    @is_future = false
    header = ''

    # mark this as a future date if the filename YYYYMMDD part as a string is greater than DateToday in YYYYMMDD format
    @is_future = true if @filename[0..7] > DATE_TODAY_YYYYMMDD
    puts "initialising #{@filename} #{is_future}" if $verbose

    # Open file and read in. We've already checked it's not empty.
    # NB: needs the encoding line when run from launchctl, otherwise you get US-ASCII invalid byte errors (basically the 'locale' settings are different)
    File.open(@filename, 'r', encoding: 'utf-8') do |f|
      # Read all lines
      f.each_line do |line|
        header += line # join all lines together for later scanning
        # Counting number of open, waiting, done tasks etc.
        if line =~ /\[x\]/
          @done += 1 # count this as a completed task
        elsif line =~ /^\s*\*\s+/ && line !~ /\[\-\]/ # a task, but not cancelled (or by implication not completed)
          if line =~ /#waiting/
            @waiting += 1 # count this as waiting not open
          else
            scheduledDate = nil
            line.scan(/>(\d\d\d\d\-\d\d-\d\d)/) { |m| scheduledDate = Date.parse(m.join) }
            if !scheduledDate.nil?
              if scheduledDate > TODAYS_DATE
                @future += 1 # count this as future
              else
                @open += 1 # count this as dated open (overdue)
              end
            else
              @open += 1 # count this as undated open
            end
          end
        end
      end
    end
  rescue StandardError => e
    puts "ERROR: Hit #{e.exception.message} when initialising #{@filename} in NPCalendar".colorize(WarningColour)
  end
end

#-------------------------------------------------------------------------

# NPNote Class reflects a stored NP note.
class NPNote
  # Define the attributes that need to be visible outside the class instances
  attr_reader :id
  attr_reader :title
  attr_reader :is_active
  attr_reader :is_cancelled
  attr_reader :is_project
  attr_reader :is_goal
  attr_reader :metadata_line
  attr_reader :open
  attr_reader :waiting
  attr_reader :done
  attr_reader :future
  attr_reader :undated
  attr_reader :filename

  def initialize(this_file, id)
    # initialise instance variables (that persist with the class instance)
    @filename = this_file
    @id = id
    @title = nil
    @is_active = true # assume note is active
    @is_cancelled = false
    @open = @waiting = @done = @future = @undated = 0
    @dueDate = nil
    @is_project = false
    @is_goal = false

    # initialise other variables (that don't need to persist with the class instance)
    headerLine = @metadata_line = nil

    puts "  Initializing NPNote for #{this_file}" if $verbose
    # Open file and read the first two lines
    File.open(this_file, 'r', encoding: 'utf-8') do |f|
      headerLine = f.readline
      @metadata_line = f.readline

      # make note active if #active flag set
      @is_active = true    if @metadata_line =~ /#active/
      # but override if #archive set, or complete date set
      @is_active = false   if (@metadata_line =~ /#archive/) || @completeDate
      # make note cancelled if #cancelled or #someday flag set
      @is_cancelled = true  if (@metadata_line =~ /#cancelled/) || (@metadata_line =~ /#someday/)

      # Note if this is a #project or #goal
      @is_project = true if @metadata_line =~ /#project/
      @is_goal    = true if @metadata_line =~ /#goal/

      # Now read through rest of file, counting number of open, waiting, done tasks etc.
      f.each_line do |line|
        if line =~ /\[x\]/
          @done += 1 # count this as a completed task
        elsif line =~ /^\s*\*\s+/ && line !~ /\[\-\]/ # a task, but not cancelled (or by implication not completed)
          if line =~ /#waiting/
            @waiting += 1 # count this as waiting not open
          else
            scheduledDate = nil
            line.scan(/>(\d\d\d\d\-\d\d-\d\d)/) { |m| scheduledDate = Date.parse(m.join) }
            if !scheduledDate.nil?
              if scheduledDate > TODAYS_DATE
                @future += 1 # count this as future
              else
                @open += 1 # count this as dated open (overdue)
              end
            else
              @undated += 1 # count this as undated open
            end
          end
        end
      end
    end
  rescue StandardError => e
    puts "ERROR: Hit #{e.exception.message} when initialising #{@filename} in NPNote".colorize(WarningColour)
  end
end

#===============================================================================
# Main logic
#===============================================================================

# Setup program options
options = {}
opt_parser = OptionParser.new do |opts|
  opts.banner = 'Usage: npStats.rb [options]'
  opts.separator ''
  # options[:verbose] = 0
  # options[:no_file] = 0
  opts.on('-v', '--verbose', 'Show information as I work') do
    options[:verbose] = 1
  end
  opts.on('-n', '--nofile', 'Do not write summary to file') do
    options[:no_file] = 1
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

# counts open (overdue) notes, tasks: open undated, waiting, done tasks, future tasks
# breaks down by Goals/Projects/Other
ton = tpn = tgn = 0
tod = tpd = tgd = 0
too = tpo = tgo = 0
tou = tpu = tgu = 0
tow = tpw = tgw = 0
tof = tpf = tgf = 0

#===============================================================================
# Calendar stats
#===============================================================================
calFiles = [] # to hold all relevant calendar objects
timeNow = Time.now
timeNowFmt = timeNow.strftime(DATE_TIME_FORMAT)
puts "Creating stats at #{timeNowFmt}:"

# Read metadata for all note files in the NotePlan directory
# (and sub-directories from v2.5, ignoring special ones starting '@')
n = 0 # number of calendar entries to work on
begin
  Dir.chdir(NP_CALENDAR_DIR)
  Dir.glob('**/*.txt').each do |this_file|
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
  puts "ERROR: Hit #{e.exception.message} when reading calendar directory".colorize(WarningColour)
end

if n.positive? # if we have some notes to work on ...
  calFiles.each do |cal|
    # count tasks
    tod += cal.done
    too += cal.open
    tou += cal.undated
    tow += cal.waiting
    tof += cal.future
  end
else
  puts "Warning: No matching calendar files found.\n".colorize(WarningColour)
end
puts

#=======================================================================================
# Note stats
#=======================================================================================
notes = [] # read in all notes
activeNotes = [] # list of ID of all active notes

# Read metadata for all note files in the NotePlan directory
# (and sub-directories from v2.5, ignoring special ones starting '@')
i = 0 # number of notes to work on
begin
  Dir.chdir(NP_NOTE_DIR)
  Dir.glob('**/*.txt').each do |this_file|
    fsize = File.size?(this_file) || 0
    puts "  #{this_file} size #{fsize}" if $verbose
    next unless this_file =~ /^[^@]/ # as can't get file glob including [^@] to work
    # ignore this file if it's empty
    next if File.zero?(this_file)

    notes[i] = NPNote.new(this_file, i)
    if notes[i].is_active && !notes[i].is_cancelled
      activeNotes.push(notes[i].id)
      i += 1
    end
  end
rescue StandardError => e
  puts "ERROR: Hit #{e.exception.message} when reading notes directory".colorize(WarningColour)
end

# Count open (overdue) tasks, open undated, waiting, done tasks, future tasks
# broken down by Goals/Projects/Other.
if i.positive? # if we have some notes to work on ...
  activeNotes.each do |nn|
    n = notes[nn]
    if n.is_goal
      tgn += 1
      tgd += n.done
      tgo += n.open
      tgu += n.undated
      tgw += n.waiting
      tgf += n.future
    elsif n.is_project
      tpn += 1
      tpd += n.done
      tpo += n.open
      tpu += n.undated
      tpw += n.waiting
      tpf += n.future
    else
      ton += 1
      tod += n.done
      too += n.open
      tou += n.undated
      tow += n.waiting
      tof += n.future
    end
  end
else
  puts "Warning: No matching active note files found.\n".colorize(WarningColour)
end

tn = ton + tpn + tgn
td = tod + tpd + tgd
to = too + tpo + tgo
tu = tou + tpu + tgu
tw = tow + tpw + tgw
tf = tof + tpf + tgf

# Show results on screen
puts "From #{activeNotes.count} active notes:"
puts "\tNotes\tDone\tOverdue\tUndated\tWaiting\tFuture".colorize(TotalColour)
puts "Goals\t#{tgn}\t#{tgd}\t#{tgo}\t#{tgu}\t#{tgw}\t#{tgf}"
puts "Project\t#{tpn}\t#{tpd}\t#{tpo}\t#{tpu}\t#{tpw}\t#{tpf}"
puts "Other\t#{ton}\t#{tod}\t#{too}\t#{tou}\t#{tow}\t#{tof}"
puts "TOTAL\t#{tn}\t#{td}\t#{to}\t#{tu}\t#{tw}\t#{tf}".colorize(TotalColour)

# Append results to CSV file (unless --nofile option given)
return unless options[:no_file].nil?

# TODO: Check whether Summaries directory exists. If not, create it.
begin
  output = format('%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d',
                  timeNowFmt, tgn, tpn, ton,
                  tgd, tgo, tgu, tgw, tgf,
                  tpd, tpo, tpu, tpw, tpf,
                  tod, too, tou, tow, tof,
                  td, to, tu, tw, tf)
  filepath = OUTPUT_DIR + '/task_stats.csv'
  f = File.open(filepath, 'a')
  f.puts output
  f.close
rescue StandardError => e
  puts "ERROR: Hit #{e.exception.message} when writing out summary to #{filepath}".colorize(WarningColour)
end
