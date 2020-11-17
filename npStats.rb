#!/usr/bin/ruby
#-------------------------------------------------------------------------------
# NotePlan Task Stats Summariser
# (c) JGC, v1.5.1, 17.11.2020
#-------------------------------------------------------------------------------
# Script to give stats on various tags in NotePlan's Notes and Daily files.
#
# It finds and summarises todos/tasks in note and calendar files:
# - only covers active notes (not archived or cancelled)
# - counts open tasks, open undated tasks, done tasks, future tasks
# - breaks down by Goals/Projects/Other
# - ignores tasks in a #template section
# It writes output to screen and to a CSV file
#
# Configuration:
# - STORAGE_TYPE: select CloudKit (default from NP3.0), iCloudDrive (default until NP3) or Drobpox
# - USERNAME: the username of the Dropbox/iCloud account to use
# Requires gems colorize & optparse (> gem install colorize optparse)
#-------------------------------------------------------------------------------
# For more information please see the GitHub repository:
#   https://github.com/jgclark/NotePlan-stats/
#-------------------------------------------------------------------------------
VERSION = '1.5.1'.freeze

require 'date'
require 'time'
require 'etc' # for login lookup, though currently not used
require 'colorize' # for coloured output using https://github.com/fazibear/colorize
require 'optparse'

# User-settable constants
DATE_FORMAT = '%d.%m.%y'.freeze
DATE_TIME_FORMAT = '%d %b %Y %H:%M'.freeze


# Constants
USERNAME = ENV['LOGNAME'] # pull username from environment
USER_DIR = ENV['HOME'] # pull home directory from environment
DROPBOX_DIR = "#{USER_DIR}/Dropbox/Apps/NotePlan/Documents".freeze
ICLOUDDRIVE_DIR = "#{USER_DIR}/Library/Mobile Documents/iCloud~co~noteplan~NotePlan/Documents".freeze
CLOUDKIT_DIR = "#{USER_DIR}/Library/Containers/co.noteplan.NotePlan3/Data/Library/Application Support/co.noteplan.NotePlan3".freeze
NP_BASE_DIR = DROPBOX_DIR if Dir.exist?(DROPBOX_DIR) && Dir[File.join(DROPBOX_DIR, '**', '*')].count { |file| File.file?(file) } > 1
NP_BASE_DIR = ICLOUDDRIVE_DIR if Dir.exist?(ICLOUDDRIVE_DIR) && Dir[File.join(ICLOUDDRIVE_DIR, '**', '*')].count { |file| File.file?(file) } > 1
NP_BASE_DIR = CLOUDKIT_DIR if Dir.exist?(CLOUDKIT_DIR) && Dir[File.join(CLOUDKIT_DIR, '**', '*')].count { |file| File.file?(file) } > 1
NP_CALENDAR_DIR = "#{NP_BASE_DIR}/Calendar".freeze
NP_NOTE_DIR = "#{NP_BASE_DIR}/Notes".freeze
OUTPUT_DIR = if Dir.exist?(CLOUDKIT_DIR) && Dir[File.join(CLOUDKIT_DIR, '**', '*')].count { |file| File.file?(file) } > 1
               "/Users/#{USERNAME}/Dropbox/NPSummaries" # save in user's home Dropbox directory as it won't be sync'd in a CloudKit directory
             else
               "#{NP_BASE_DIR}/Summaries".freeze # but otherwise store in Summaries/ directory
             end
TODAYS_DATE = Date.today # can't work out why this needs to be a 'constant' to work -- something about visibility, I suppose
DATE_TODAY_YYYYMMDD = TODAYS_DATE.strftime('%Y%m%d')

# Other variables that need to be global
$cal_done_dates = Hash.new(0) # Hash of dates, with new items defaulting to zero

# Colours, using the colorization gem
TotalColour = :light_yellow
WarningColour = :light_red

#-------------------------------------------------------------------------
# Function definitions
#-------------------------------------------------------------------------
# Print multi-dimensional 'tables' of data prettily
# from https://stackoverflow.com/questions/27317023/print-out-2d-array
def print_table(table, margin_width = 2)
  # the margin_width is the spaces between columns (use at least 1)

  column_widths = []
  table.each do |row|
    row.each.with_index do |cell, column_num|
      column_widths[column_num] = [column_widths[column_num] || 0, cell.to_s.size].max
    end
  end

  puts(table.collect do |row|
    row.collect.with_index do |cell, column_num|
      cell.to_s.ljust(column_widths[column_num] + margin_width)
    end.join
  end)
end

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
    puts "  initialising #{@filename}" if $verbose

    # Open file and read in. We've already checked it's not empty.
    # NB: needs the encoding line when run from launchctl, otherwise you get US-ASCII invalid byte errors (basically the 'locale' settings are different)
    File.open(@filename, 'r', encoding: 'utf-8') do |f|
      # Read all lines
      f.each_line do |line|
        header += line # join all lines together for later scanning
        # Counting number of open, waiting, done tasks etc.
        if line =~ /\[x\]/
          @done += 1 # count up the completed task
          # Also make a note of the done date in the $done_dates array
          done_date_string = line.scan(/@done\((\d{4}\-\d{2}\-\d{2})/).join('')
          if done_date_string.empty?
            puts "    Warning: no @done(...) date found in '#{line.chomp}'".colorize(WarningColour) if $verbose
          else
            completed_date = Date.strptime(done_date_string, '%Y-%m-%d') # we only want the first item, but don't know why it needs to be first of the first
            c_d_ordinal = completed_date.strftime('%Y%j')
            # puts "    #{completed_date}: #{c_d_ordinal} #{$done_dates[c_d_ordinal]}" if $verbose
            $cal_done_dates[c_d_ordinal] += 1
          end
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
  rescue EOFError
    # this file has less than two lines, but we can ignore the problem for the stats
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
  attr_reader :done_dates

  def initialize(this_file, id)
    # initialise instance variables (that persist with the class instance)
    @filename = this_file
    @id = id
    @title = nil
    @is_active = true # assume note is active
    @is_completed = false
    @is_cancelled = false
    @open = @waiting = @done = @future = @undated = 0
    @completed_date = nil
    @is_project = false
    @is_goal = false
    @done_dates = Hash.new(0) # Hash of dates for this note, with new items defaulting to zero

    # initialise other variables (that don't need to persist with the class instance)
    headerLine = @metadata_line = nil

    puts "  Initializing NPNote for #{this_file}" if $verbose
    # Open file and read the first two lines
    File.open(this_file, 'r', encoding: 'utf-8') do |f|
      headerLine = f.readline
      @metadata_line = f.readline

      # Now process line 2 (rest of metadata)
      # the following regex matches returns an array with one item, so make a string (by join), and then parse as a date
      @metadata_line.scan(%r{(@completed|@finished)\(([0-9\-\./]{6,10})\)}) { |m| @completed_date = Date.parse(m.join) }

      # make completed if @completed_date set
      @is_completed = true unless @completed_date.nil?
      # make cancelled if #cancelled or #someday flag set
      @is_cancelled = true if @metadata_line =~ /(#cancelled|#someday)/
      # set note to non-active if #archive is set, or cancelled, completed.
      @is_active = false if @metadata_line == /#archive/ || @is_completed || @is_cancelled

      # Note if this is a #project or #goal
      @is_project = true if @metadata_line =~ /#project/
      @is_goal    = true if @metadata_line =~ /#goal/

      # Now read through rest of file, counting number of open, waiting, done tasks etc.
      template_section_header_level = 0 # default to not in a template section
      f.each_line do |line|
        line_header_level = 0
        line.scan(/^(#+)\s/) { |m| line_header_level = m[0].length }
        if line_header_level > 0
          # is this a same- or higher-level header? If so take us out of a #template section
          template_section_header_level = 0 if (line_header_level > 0) && (line_header_level <= template_section_header_level)
          # see if this line takes us into a #template section
          template_section_header_level = line_header_level if line =~ /#template/
        end
        # puts "#{template_section_header_level}/#{line_header_level}: #{line.chomp}" if $verbose
        if line =~ /\[x\]/
          # a completed task (using [x] format)
          @done += 1
          # For each done task, make a note of the done date in the $done_dates array
          # (But sometimes done date is missing; if so, have to ignore.)
          line_scan = line.scan(/@done\((\d{4}\-\d{2}\-\d{2})/).join('')
          # puts "  #{line_scan} (#{line_scan.class})" if $verbose
          if line_scan.empty?
            puts "    Warning: no @done(...) date found in '#{line.chomp}'".colorize(WarningColour) if $verbose
          else
            completed_date = Date.strptime(line_scan, '%Y-%m-%d') # we only want the first item, but don't know why it needs to be first of the first
            c_d_ordinal = completed_date.strftime('%Y%j')
            @done_dates[c_d_ordinal] += 1
          end
        elsif line =~ /^\s*\*\s+/ && line !~ /\[\-\]/ # a task, but not cancelled (or by implication not completed)
          unless template_section_header_level > 0
            # we're not in a #template so continue processing
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
    end
  rescue EOFError
    # this file has less than two lines, but we can ignore the problem for the stats
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
  opts.banner = "NotePlan stats generator v #{VERSION}\nDetails at https://github.com/jgclark/NotePlan-stats/\nUsage: npStats.rb [options]"
  opts.separator ''
  options[:verbose] = false
  options[:no_file] = false
  options[:no_calendar] = false
  opts.on('-c', '--nocal', 'Do not count daily calendar notes') do
    options[:no_calendar] = true
  end
  opts.on('-h', '--help', 'Show help') do
    puts opts
    exit
  end
  opts.on('-n', '--nofile', 'Do not write summary to file') do
    options[:no_file] = true
  end
  opts.on('-v', '--verbose', 'Show information as I work') do
    options[:verbose] = true
  end
end
opt_parser.parse! # parse out options, leaving file patterns to process
$verbose = options[:verbose]

# Log time
time_now = Time.now
time_now_format = time_now.strftime(DATE_TIME_FORMAT)
if options[:no_calendar]
  puts "Creating stats at #{time_now_format} (ignoring daily calendar files):"
else
  puts "Creating stats at #{time_now_format}:"
end
puts "  Writing output files to #{OUTPUT_DIR}/" unless options[:no_file]

#=======================================================================================
# Note stats
#=======================================================================================
notes = [] # read in all notes
activeNotes = [] # list of ID of all active notes
tgdh = Hash.new(0)
tpdh = Hash.new(0)
todh = Hash.new(0)

# Read metadata for all note files in the NotePlan directory
# (and sub-directories from v2.5, ignoring special ones starting '@')
i = 0 # number of notes to work on
begin
  Dir.chdir(NP_NOTE_DIR)
  Dir.glob(['**/*.txt', '**/*.md']).each do |this_file|
    next unless this_file =~ /^[^@]/ # as can't get file glob including [^@] to work
    # ignore this file if it's empty
    next if File.zero?(this_file)

    notes[i] = NPNote.new(this_file, i)
    if notes[i].is_active
      activeNotes.push(notes[i].id)
      i += 1
    end
  end
rescue StandardError => e
  puts "ERROR: Hit #{e.exception.message} when reading notes directory".colorize(WarningColour)
end

# Count open (overdue) tasks, open undated, waiting, done tasks, future tasks
# broken down by Goals/Projects/Other.
ton = tpn = tgn = 0
tod = tpd = tgd = 0
too = tpo = tgo = 0
tou = tpu = tgu = 0
tow = tpw = tgw = 0
tof = tpf = tgf = 0

if i.positive? # if we have some notes to work on ...
  activeNotes.each do |nn|
    n = notes[nn]
    ddh = n.done_dates
    # .nil? ? [] : @done_dates[n]
    # puts n.filename, ddh
    if n.is_goal
      tgn += 1
      tgd += n.done
      tgdh = ddh.merge!(tgdh) { |_key, oldval, newval| newval + oldval }
      tgo += n.open
      tgu += n.undated
      tgw += n.waiting
      tgf += n.future
    elsif n.is_project
      tpn += 1
      tpd += n.done
      tpdh = ddh.merge!(tpdh) { |_key, oldval, newval| newval + oldval }
      tpo += n.open
      tpu += n.undated
      tpw += n.waiting
      tpf += n.future
    else
      ton += 1
      tod += n.done
      todh = ddh.merge!(todh) { |_key, oldval, newval| newval + oldval }
      too += n.open
      tou += n.undated
      tow += n.waiting
      tof += n.future
    end
  end
else
  puts "Warning: No matching active note files found.\n".colorize(WarningColour)
end

#---------------------------------------------------------------------------------------
# Summarise the done_dates:
# - @done_dates from each of the Note files, for each type Goal/Project/Other
# - for now ignore the $done_dates from the Daily 'calendar' files

# sort the hashes, which turns them into arrays
ddga = tgdh.sort
ddpa = tpdh.sort
ddoa = todh.sort
# earliest_orddate = ddga[0][0].to_i < ddpa[0][0].to_i ? ddga[0][0].to_i : ddpa[0][0].to_i
# earliest_orddate = earliest_orddate.to_i < ddoa[0][0].to_i ? earliest_orddate.to_i : ddoa[0][0].to_i
# ord_date_today = TODAYS_DATE.strftime('%Y%j').to_i
# puts "  #{earliest_orddate}, #{earliest_orddate.class}"
# now append these three arrays onto a single one, with data in correct one of three columns,
# with the key (the ordinal date) in column 0
done_dates = Array.new { Array.new(4, 0) }
ddga.each do |aa|
  done_dates += [[aa[0], aa[1], 0, 0]]
end
ddpa.each do |aa|
  done_dates += [[aa[0], 0, aa[1], 0]]
end
ddoa.each do |aa|
  done_dates += [[aa[0], 0, 0, aa[1]]]
end
dds = done_dates.sort
# Now compact the array summing items with the same key
last_key = 0
last_col1 = 0
last_col2 = 0
last_col3 = 0
i = 0
dds.each do |row|
  if last_key == row[0]
    row[1] += last_col1
    row[2] += last_col2
    row[3] += last_col3
    dds[i - 1][0] = 0 # mark for deletion. Trying to delete in place mucks up the loop positioning
  end
  last_key = row[0]
  last_col1 = row[1]
  last_col2 = row[2]
  last_col3 = row[3]
  i += 1
end
# now remove the row set to delete
dds.delete_if { |row| row[0] == 0 }
done_dates = dds
# TODO: change back to using YYYY-MM-DD dates

#===============================================================================
# Calendar stats
#===============================================================================
calFiles = [] # to hold all relevant calendar objects

unless options[:no_calendar]
  # Read metadata for all note files in the NotePlan directory
  # (and sub-directories from v2.5, ignoring special ones starting '@')
  n = 0 # number of calendar entries to work on
  begin
    Dir.chdir(NP_CALENDAR_DIR)
    Dir.glob(['**/*.txt', '**/*.md']).each do |this_file|
      # ignore this file if the directory starts with '@'
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
end

# Sum all the counts from Notes and Daily files
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

# Append results to CSV files (unless --nofile option given)
return if options[:no_file]

begin
  output = format('%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d',
                  time_now_format, tgn, tpn, ton,
                  tgd, tgo, tgu, tgw, tgf,
                  tpd, tpo, tpu, tpw, tpf,
                  tod, too, tou, tow, tof,
                  td, to, tu, tw, tf)
  filepath = OUTPUT_DIR + '/task_stats.csv'
  f = File.open(filepath, 'a') # append
  f.puts output
  f.close
  puts "Written this summary to #{OUTPUT_DIR}/task_stats.csv"

  filepath = OUTPUT_DIR + '/task_done_dates.csv'
  f = File.open(filepath, 'w') # overwrite
  total_done_count = 0
  f.puts 'Date,Goals,Projects,Others' # headers
  done_dates.each do |d|
    # convert date from ordinal back to YYYY-MM-DD
    date_temp = Date.strptime(d[0], '%Y%j') # we only want the first item, but don't know why it needs to be first of the first
    date_YMD = date_temp.strftime('%Y-%m-%d')
    f.puts "#{date_YMD},#{d[1]},#{d[2]},#{d[3]}"
    total_done_count += d[1] + d[2] + d[3]
  end
  f.close
  puts "\nAlso written summary of when the #{total_done_count} tasks were completed to #{OUTPUT_DIR}/task_done_dates.csv"
rescue StandardError => e
  puts "ERROR: Hit #{e.exception.message} when writing out summary to #{filepath}".colorize(WarningColour)
end
