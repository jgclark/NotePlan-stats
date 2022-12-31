#!/usr/bin/env ruby
#-------------------------------------------------------------------------------
# NotePlan Task Stats Summariser
# (c) JGC, v1.8.1, 31.12.2022
#-------------------------------------------------------------------------------
# Script to give stats on various tags in NotePlan's Notes and Daily files.
#
# It finds and summarises todos/tasks in note and calendar files:
# - only covers active notes (not archived or cancelled)
# - counts open tasks, open undated tasks, done tasks, future tasks
# - breaks down by Goals/Projects/Other
# - ignores tasks in a #template section
#
# It writes output to screen and to CSV files:
# - current summary of all G/P/O open/done/future to task_stats.csv
# - re-calculated list of all done tasks by date to task_done_dates.csv
#
# Configuration:
# - Requires gems colorize & optparse ('gem install colorize optparse')
#-------------------------------------------------------------------------------
# For more information please see the GitHub repository:
#   https://github.com/jgclark/NotePlan-stats/
#-------------------------------------------------------------------------------
VERSION = '1.8.1'.freeze

require 'date'
require 'time'
require 'colorize' # for coloured output using https://github.com/fazibear/colorize
require 'optparse'
require 'find'

# User-settable constants
DATE_FORMAT = '%d.%m.%y'.freeze
DATE_TIME_FORMAT = '%d %b %Y %H:%M'.freeze
FOLDERS_TO_IGNORE = ['@Archive', '@Trash', '@Templates', '@Searches', 'TEST', 'Reviews', 'Saved Searches', 'Summaries'].freeze 
# also set NPEXTRAS environment variable if needed for location of file output

# Constants
USER_DIR = ENV['HOME'] # pull home directory from environment
DROPBOX_DIR = "#{USER_DIR}/Dropbox/Apps/NotePlan/Documents".freeze
ICLOUDDRIVE_DIR = "#{USER_DIR}/Library/Mobile Documents/iCloud~co~noteplan~NotePlan/Documents".freeze
CLOUDKIT_DIR = "#{USER_DIR}/Library/Containers/co.noteplan.NotePlan3/Data/Library/Application Support/co.noteplan.NotePlan3".freeze
NP_BASE_DIR = if Dir.exist?(CLOUDKIT_DIR) && Dir[File.join(CLOUDKIT_DIR, '**', '*')].count { |file| File.file?(file) } > 1
                CLOUDKIT_DIR
              elsif Dir.exist?(ICLOUDDRIVE_DIR) && Dir[File.join(ICLOUDDRIVE_DIR, '**', '*')].count { |file| File.file?(file) } > 1
                ICLOUDDRIVE_DIR
              elsif Dir.exist?(DROPBOX_DIR) && Dir[File.join(DROPBOX_DIR, '**', '*')].count { |file| File.file?(file) } > 1
                DROPBOX_DIR
              end
NP_CALENDAR_DIR = "#{NP_BASE_DIR}/Calendar".freeze
NP_NOTE_DIR = "#{NP_BASE_DIR}/Notes".freeze
# NB: a user-set directory, not the usual CloudKit directory, as non-NotePlan folders won't sync from it.
OUTPUT_DIR = if Dir.exist?(CLOUDKIT_DIR) && Dir[File.join(CLOUDKIT_DIR, '**', '*')].count { |file| File.file?(file) } > 1
               ENV['NPEXTRAS'] # save in user-specified directory as it won't be sync'd in a CloudKit directory
             else
               "#{np_base_dir}/Summaries".freeze # but otherwise can store in Summaries/ directory in NP
             end
TODAYS_DATE = Date.today # can't work out why this needs to be a 'constant' to work -- something about visibility, I suppose
DATE_TODAY_YYYYMMDD = TODAYS_DATE.strftime('%Y%m%d')

# Other variables that need to be global
$cal_done_dates = Hash.new(0) # Hash of dates, with new items defaulting to zero

# Colours, using the colorization gem
TotalColour = :light_yellow
ErrorColour = :light_red

#-------------------------------------------------------------------------
# Helper functions
#-------------------------------------------------------------------------

def main_message_screen(message)
  puts message.colorize(TotalColour)
end

def message_screen(message)
  puts message
end

def log_message_screen(message)
  puts message if $verbose
end

def error_message_screen(message)
  puts message.colorize(ErrorColour)
end

def warning_message_screen(message)
  puts message.colorize(ErrorColour) if $verbose
end

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
  attr_reader :open_overdue
  attr_reader :waiting
  attr_reader :done
  attr_reader :future
  attr_reader :open_undated

  def initialize(this_file, id)
    # initialise instance variables (that persist with the class instance)
    @filename = this_file
    @id = id
    @open_overdue = @waiting = @done = @future = @open_undated = 0
    @is_future = false
    header = ''

    # is this a future date?
    if @filename =~ /\d{8}\.(txt|md)/
      # for daily notes
      # mark this as a future date if the filename YYYYMMDD part as a string is greater than DateToday in YYYYMMDD format
      @is_future = true if @filename[0..7] > DATE_TODAY_YYYYMMDD
    elsif @filename =~ /\d{4}-W\d{2}\.(txt|md)/
      # for weekly notes
      # mark this as a future date if the date representing the start of the week of filename YYYY-Wnn as a string is greater than DateToday in YYYYMMDD format
      start_of_week_date = Date.parse(@filename[0..7]).to_s.gsub('-', '')
      log_message_screen("  initialising Weekly note '#{@filename}' (date=#{start_of_week_date})")
      @is_future = true if start_of_week_date > DATE_TODAY_YYYYMMDD
    end

    # Open file and read in. We've already checked it's not empty.
    # NB: needs the encoding line when run from launchctl, otherwise you get US-ASCII invalid byte errors (basically the 'locale' settings are different)
    File.open(@filename, 'r', encoding: 'utf-8') do |f|
      # Read all lines
      f.each_line do |line|
        header += line # join all lines together for later scanning
        # Counting number of open, waiting, done tasks etc.
        if line =~ /^\s*\*\s+/ && line =~ /\[x\]/
          @done += 1 # count up the completed task
          # Also make a note of the done date in the $cal_done_dates array
          done_date_string = line.scan(/@done\((\d{4}-\d{2}-\d{2}.*)/).join('')
          if done_date_string.empty?
            warning_message_screen("    Warning: no @done(...) date found in '#{line.chomp}'")
          else
            completed_date = Date.strptime(done_date_string, '%Y-%m-%d') # we only want the first item, but don't know why it needs to be first of the first
            c_d_ordinal = completed_date.strftime('%Y%j')
            # log_message_screen("    #{completed_date}: #{c_d_ordinal} #{$cal_done_dates[c_d_ordinal]}")
            $cal_done_dates[c_d_ordinal] += 1
          end
        elsif line =~ /^\s*\*\s+/ && line !~ /\[-\]/ # a task, but not cancelled (or by implication not completed)
          if line =~ /#waiting/
            @waiting += 1 # count this as waiting not open
          else
            # Ideally, find inbound copy of a scheduled date (<date) and ignore
            # However, there's no consistency in my data for when <date and >date are used, so won't do this now
            # find if this includes a scheduled date
            scheduledDate = nil
            line.scan(/\s>(\d{4}-\d{2}-\d{2})/) { |m| scheduledDate = Date.parse(m.join) }
            if !scheduledDate.nil?
              if scheduledDate > TODAYS_DATE
                @future += 1 # count this as future
              else
                @open_overdue += 1 # count this as dated open (overdue)
              end
            else
              @open_undated += 1 # count this as undated open
            end
          end
        end
      end
    end
  rescue EOFError
    # this file has less than two lines, but we can ignore the problem for the stats
  rescue StandardError => e
    error_message_screen("ERROR: Hit #{e.exception.message} when initialising #{@filename} line <#{line}> in NPCalendar")
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
  attr_reader :open_overdue
  attr_reader :waiting
  attr_reader :done
  attr_reader :future
  attr_reader :open_undated
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
    @open_overdue = @waiting = @done = @future = @open_undated = 0
    @completed_date = nil
    @is_project = false
    @is_goal = false
    @done_dates = Hash.new(0) # Hash of dates for this note, with new items defaulting to zero

    # initialise other variables (that don't need to persist with the class instance)
    headerLine = @metadata_line = nil

    log_message_screen("  Initializing NPNote for #{this_file}")
    # Open file and read the first two lines
    # FIXME: This won't work properly with frontmatter
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
        if line_header_level.positive?
          # is this a same- or higher-level header? If so take us out of a #template section
          template_section_header_level = 0 if line_header_level.positive? && line_header_level <= template_section_header_level
          # see if this line takes us into a #template section
          template_section_header_level = line_header_level if line =~ /#template/
        end
        # log_message_screen("#{template_section_header_level}/#{line_header_level}: #{line.chomp}")
        if line =~ /^\s*\*\s+/ && line =~ /\[x\]/
          # a completed task (using [x] format)
          @done += 1
          # For each done task, make a note of the done date in the $done_dates array
          # (But sometimes done date is missing; if so, have to ignore.)
          line_scan = line.scan(/@done\((\d{4}-\d{2}-\d{2}).*/).join('')
          # log_message_screen("  #{line_scan} (#{line_scan.class})")
          if line_scan.empty?
            warning_message_screen("    Warning: no @done(...) date found in '#{line.chomp}'")
          else
            completed_date = Date.strptime(line_scan, '%Y-%m-%d') # we only want the first item, but don't know why it needs to be first of the first
            c_d_ordinal = completed_date.strftime('%Y%j')
            @done_dates[c_d_ordinal] += 1
          end
        elsif line =~ /^\s*\*\s+/ && line !~ /\[-\]/ # a task, but not cancelled (and by implication not completed)
          unless template_section_header_level.positive?
            # we're not in a #template so continue processing
            if line =~ /#waiting/
              @waiting += 1 # count this as waiting not open
            else
              # Ideally, find inbound copy of a scheduled date (<date) and ignore
              # However, there's no consistency in my data for when <date and >date are used, so won't do this now.
              # Find if this includes a scheduled date
              scheduledDate = nil
              line.scan(/\s>(\d{4}-\d{2}-\d{2})/) { |m| scheduledDate = Date.parse(m.join) }
              if !scheduledDate.nil?
                if scheduledDate > TODAYS_DATE
                  @future += 1 # count this as future
                else
                  @open_overdue += 1 # count this as dated open (overdue)
                end
              else
                @open_undated += 1 # count this as undated open
              end
            end
          end
        end
      end
    end
  rescue EOFError
    # this file has less than two lines, but we can ignore the problem for the stats
  rescue StandardError => e
    error_message_screen("ERROR: Hit #{e.exception.message} when initialising #{@filename} in NPNote")
  end
end

#===============================================================================
# Main logic
#===============================================================================

# Setup program options
options = {}
opt_parser = OptionParser.new do |opts|
  opts.banner = "NotePlan stats generator v#{VERSION}\nDetails at https://github.com/jgclark/NotePlan-stats/\nUsage: npStats.rb [options] [file-pattern]"
  opts.separator ''
  options[:verbose] = false
  options[:no_file] = false
  options[:no_calendar] = false
  opts.on('-c', '--nocal', 'Do not count daily calendar notes') do
    options[:no_calendar] = true
  end
  opts.on('-h', '--help', 'Show help') do
    message_screen(opts)
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
  message_screen("Running npReview v#{VERSION} at #{time_now_format}\n- for files (ignoring Calendar files and folders #{FOLDERS_TO_IGNORE})")
else
  message_screen("Running npReview v#{VERSION} at #{time_now_format}\n- for files (ignoring folders #{FOLDERS_TO_IGNORE})")
end
message_screen("- writing output files to #{OUTPUT_DIR}/") unless options[:no_file]

#=======================================================================================
# Note stats

notes = [] # read in all notes
activeNotes = [] # list of ID of all active notes
tgdh = Hash.new(0)
tpdh = Hash.new(0)
todh = Hash.new(0)

# Read metadata for all note files in the NotePlan directory
notes_to_work_on = 0 # number of notes to work on
begin
  # our file globbing needs are too complex for simple Dir.glob, so using Find.find instead
  Find.find(NP_NOTE_DIR) do |path|
    name = File.basename(path)
    if FileTest.directory?(path)
      if FOLDERS_TO_IGNORE.include?(name)
        Find.prune
      else
        next
      end
    else
      if name =~ /.(md|txt)$/
        # message_screen("- found #{name}")
        if File.zero?(path)
          warning_message_screen("#{path} is empty, so will ingore")
          next
        end

        notes[notes_to_work_on] = NPNote.new(path, notes_to_work_on)
        if notes[notes_to_work_on].is_active
          activeNotes.push(notes[notes_to_work_on].id)
          notes_to_work_on += 1
        end
      end
    end
  end
rescue StandardError => e
  error_message_screen("ERROR: Hit #{e.exception.message} when reading Notes directory")
end

# Count open (overdue) tasks, open undated, waiting, done tasks, future tasks
# broken down by Goals/Projects/Other.
ton = tpn = tgn = 0
tod = tpd = tgd = 0
too = tpo = tgo = 0
tou = tpu = tgu = 0
tow = tpw = tgw = 0
tof = tpf = tgf = 0

if notes_to_work_on.positive? # if we have some notes to work on ...
  activeNotes.each do |nn|
    n = notes[nn]
    ddh = n.done_dates
    # log_message_screen(n.filename, ddh)
    if n.is_goal
      tgn += 1
      tgd += n.done
      tgdh = ddh.merge!(tgdh) { |_key, oldval, newval| newval + oldval }
      tgo += n.open_overdue
      tgu += n.open_undated
      tgw += n.waiting
      tgf += n.future
    elsif n.is_project
      tpn += 1
      tpd += n.done
      tpdh = ddh.merge!(tpdh) { |_key, oldval, newval| newval + oldval }
      tpo += n.open_overdue
      tpu += n.open_undated
      tpw += n.waiting
      tpf += n.future
    else
      ton += 1
      tod += n.done
      todh = ddh.merge!(todh) { |_key, oldval, newval| newval + oldval }
      too += n.open_overdue
      tou += n.open_undated
      tow += n.waiting
      tof += n.future
    end
  end
else
  warning_message_screen("Warning: No matching active note files found.\n")
end

#===============================================================================
# Calendar stats

# add these onto previous 'other' task counts
calFiles = [] # to hold all relevant calendar objects

unless options[:no_calendar]
  # Read metadata for all note files in the NotePlan directory
  # (and sub-directories from v2.5, ignoring special ones starting '@')
  cal_entries_to_work_on = 0 # number of calendar entries to work on
  begin
    Dir.chdir(NP_CALENDAR_DIR)
    Dir.glob(['**/*.txt', '**/*.md']).each do |this_file|
      # ignore this file if the directory starts with '@'
      next unless this_file =~ /^[^@]/ # as can't get file glob including [^@] to work
      # ignore this file if it's empty
      next if File.zero?(this_file)

      calFiles[cal_entries_to_work_on] = NPCalendar.new(this_file, cal_entries_to_work_on)
      cal_entries_to_work_on += 1
    end
  rescue StandardError => e
    error_message_screen("ERROR: Hit #{e.exception.message} when reading Calendar directory")
  end

  if cal_entries_to_work_on.positive? # if we have some notes to work on ...
    calFiles.each do |cal|
      # count tasks
      tod += cal.done
      too += cal.open_overdue
      tou += cal.open_undated
      tow += cal.waiting
      tof += cal.future
    end
  else
    warning_message_screen("Warning: No matching calendar files found.\n")
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
message_screen("From #{activeNotes.count} active notes:")
main_message_screen("\tNotes\tDone\tOverdue\tUndated\tWaiting\tFuture")
message_screen("Goals\t#{tgn}\t#{tgd}\t#{tgo}\t#{tgu}\t#{tgw}\t#{tgf}")
message_screen("Project\t#{tpn}\t#{tpd}\t#{tpo}\t#{tpu}\t#{tpw}\t#{tpf}")
message_screen("Other\t#{ton}\t#{tod}\t#{too}\t#{tou}\t#{tow}\t#{tof}")
main_message_screen("TOTAL\t#{tn}\t#{td}\t#{to}\t#{tu}\t#{tw}\t#{tf}")

#-------------------------------------------------------------------------
# Write out new summary stats as a CSV line to file (unless --nofile option given)
# Append results to CSV files

unless options[:no_file]
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
    message_screen("Written this summary to #{OUTPUT_DIR}/task_stats.csv")
  rescue StandardError => e
    error_message_screen("ERROR: Hit #{e.exception.message} when writing out summary to #{filepath}")
  end
end

#===============================================================================
# Summarise the done_dates from each of the Note files, for each type Goal/Project/Other

# sort the hashes, which turns them into arrays
ddga = tgdh.sort
ddpa = tpdh.sort
ddoa = todh.sort
# earliest_orddate = ddga[0][0].to_i < ddpa[0][0].to_i ? ddga[0][0].to_i : ddpa[0][0].to_i
# earliest_orddate = earliest_orddate.to_i < ddoa[0][0].to_i ? earliest_orddate.to_i : ddoa[0][0].to_i
# ord_date_today = TODAYS_DATE.strftime('%Y%j').to_i
# log_message_screen("  #{earliest_orddate}, #{earliest_orddate.class}")

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

# Now do similarly for $cal_done_dates (all go just to the 'other' category)
unless options[:no_calendar]
  cdo = 0
  $cal_done_dates.each do |cdd|
    cdo += cdd[1]
    done_dates += [[cdd[0], 0, 0, cdd[1]]]
  end
  log_message_screen("\nFound #{cdo} done tasks from #{$cal_done_dates.size} daily notes")
end

dds = done_dates.sort
# Now compact the array summing items with the same key
previous_key = 0
previous_col1 = 0
previous_col2 = 0
previous_col3 = 0
i = 0
dds.each do |row|
  if previous_key == row[0]
    row[1] += previous_col1
    row[2] += previous_col2
    row[3] += previous_col3
    # Mark this row for deletion by setting to zero. (Trying to delete in place mucks up the loop positioning.)
    dds[i - 1][0] = 0
  end
  previous_key = row[0]
  previous_col1 = row[1]
  previous_col2 = row[2]
  previous_col3 = row[3]
  i += 1
end
# now remove the row set to delete
dds.delete_if { |row| row[0] == 0 } # .zero? fails to work here for some reason
done_dates = dds

#-------------------------------------------------------------------------
# Write out set of all done task stats per date as CSV file (if writing to files)

unless options[:no_file]
  begin
    # FIXME: something making last weekend not get written out early Mon morning
    filepath = OUTPUT_DIR + '/task_done_dates.csv'
    f = File.open(filepath, 'w') # overwrite
    total_done_count = 0
    f.puts 'Date,Goals,Projects,Others' # headers
    done_dates.each do |d|
      date_temp = Date.strptime(d[0], '%Y%j') # we only want the first item, but don't know why it needs to be first of the first
      # ignore this date if its in the future
      next if date_temp >= TODAYS_DATE

      # convert date from ordinal back to YYYY-MM-DD
      date_YMD = date_temp.strftime('%Y-%m-%d')
      f.puts "#{date_YMD},#{d[1]},#{d[2]},#{d[3]}"
      total_done_count += d[1] + d[2] + d[3]
    end
    f.close
    message_screen("Written summary of when the #{total_done_count} tasks were completed to #{OUTPUT_DIR}/task_done_dates.csv")
  rescue StandardError => e
    error_message_screen("ERROR: Hit #{e.exception.message} when writing out summary to #{filepath}")
  end
end
