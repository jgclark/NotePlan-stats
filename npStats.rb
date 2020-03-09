#!/usr/bin/ruby
# frozen_string_literal: true

#-------------------------------------------------------------------------------
# NotePlan Task Stats Summariser
# (c) JGC, v1.0.2, 9.3.2020
#-------------------------------------------------------------------------------
# Script to give stats on various tags in NotePlan's note and calendar files.
# (Forking earlier npTagStats.rb script.)
#
# It finds and summarises todos/tasks in note and calendar files:
# - only covers active notes (not archived or cancelled)
# - counts open tasks, open undated tasks, done tasks, future tasks
# - breaks down by Goals/Projects/Other
# It writes output to screen and to a CSV file
#
# Configuration:
# - StorageType: select iCloud (default) or Drobpox
# - Username: the username of the Dropbox/iCloud account to use
#-------------------------------------------------------------------------------
# TODO:
# - add more error handling
#-------------------------------------------------------------------------------

require 'date'
require 'time'
require 'etc' # for login lookup, though currently not used
require 'colorize' # for coloured output using https://github.com/fazibear/colorize

# User-settable constants
STORAGE_TYPE = 'iCloud' # or Dropbox
DATE_FORMAT = '%d.%m.%y'
DATE_TIME_FORMAT = '%e %b %Y %H:%M'
USERNAME = 'jonathan'

# Other Constant Definitions
TodaysDate = Date.today # can't work out why this needs to be a 'constant' to work -- something about visibility, I suppose
DateTodayYYYYMMDD = TodaysDate.strftime('%Y%m%d')
if STORAGE_TYPE == 'iCloud'
  NP_BASE_DIR = "/Users/#{USERNAME}/Library/Mobile Documents/iCloud~co~noteplan~NotePlan/Documents" # for iCloud storage
else
  NP_BASE_DIR = "/Users/#{USERNAME}/Dropbox/Apps/NotePlan/Documents" # for Dropbox storage
end
NP_CALENDAR_DIR = "#{NP_BASE_DIR}/Calendar"
NP_NOTE_DIR = "#{NP_BASE_DIR}/Notes"
NP_SUMMARIES_DIR = "#{NP_BASE_DIR}/Summaries"

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
  attr_reader :isFuture
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
    @tags = ''
    @isFuture = false
    header = ''

    # mark this as a future date if the filename YYYYMMDD part as a string is greater than DateToday in YYYYMMDD format
    @isFuture = true if @filename[0..7] > DateTodayYYYYMMDD
    #    puts "initialising #{@filename} #{isFuture}"

    # Open file and read in
    # NB: needs the encoding line when run from launchctl, otherwise you get US-ASCII invalid byte errors (basically the 'locale' settings are different)
    File.open(@filename, 'r', encoding: 'utf-8') do |f|
      # Read all lines
      f.each_line do |line|
        header += line # join all lines together for later scanning
        # Counting number of open, waiting, done tasks etc.
        if line =~ /\[x\]/
          @done += 1 # count this as a completed task
        elsif line =~ /^\s*\*\s+/ # a task, but (by implication) not completed
          if line =~ /#waiting/
            @waiting += 1 # count this as waiting not open
          else
            scheduledDate = nil
            line.scan(/>(\d\d\d\d\-\d\d-\d\d)/) { |m| scheduledDate = Date.parse(m.join) }
            if !scheduledDate.nil?
              if scheduledDate > TodaysDate
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
    # extract tags from lines
    @tags = header.scan(%r{#[\w/]+}).join(' ')
  rescue StandardError => e
    puts "ERROR: Hit #{e.exception.message} when initialising #{@filename}".colorize(WarningColour)
  end
end

# NPNote Class reflects a stored NP note.
class NPNote
  # Define the attributes that need to be visible outside the class instances
  attr_reader :id
  attr_reader :title
  attr_reader :isActive
  attr_reader :isCancelled
  attr_reader :isProject
  attr_reader :isGoal
  attr_reader :metadataLine
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
    @isActive = true # assume note is active
    @isCancelled = false
    @open = @waiting = @done = @future = @undated = 0
    @dueDate = nil
    @isProject = false
    @isGoal = false

    # initialise other variables (that don't need to persist with the class instance)
    headerLine = @metadataLine = nil

    # puts "  Initializing NPNote for #{this_file}"
    # Open file and read the first two lines
    File.open(this_file) do |f|
      headerLine = f.readline
      @metadataLine = f.readline

      # make active if #active flag set
      @isActive = true    if @metadataLine =~ /#active/
      # but override if #archive set, or complete date set
      @isActive = false   if (@metadataLine =~ /#archive/) || @completeDate
      # make cancelled if #cancelled or #someday flag set
      @isCancelled = true  if (@metadataLine =~ /#cancelled/) || (@metadataLine =~ /#someday/)

      # Note if this is a #project or #goal
      @isProject = true if @metadataLine =~ /#project/
      @isGoal    = true if @metadataLine =~ /#goal/

      # Now read through rest of file, counting number of open, waiting, done tasks etc.
      f.each_line do |line|
        if line =~ /\[x\]/
          @done += 1 # count this as a completed task
        elsif line =~ /^\s*\*\s+/ # a task, but (by implication) not completed
          if line =~ /#waiting/
            @waiting += 1 # count this as waiting not open
          else
            scheduledDate = nil
            line.scan(/>(\d\d\d\d\-\d\d-\d\d)/) { |m| scheduledDate = Date.parse(m.join) }
            if !scheduledDate.nil?
              if scheduledDate > TodaysDate
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
    puts "ERROR: Hit #{e.exception.message} when initialising #{@filename}".colorize(WarningColour)
  end
end

#===============================================================================
# Main logic
#===============================================================================
# counts open (overdue) tasks, open undated, waiting, done tasks, future tasks
# breaks down by Goals/Projects/Other
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

n = 0 # number of notes/calendar entries to work on
# @@@ could use error handling here
Dir.chdir(NP_CALENDAR_DIR)
Dir.glob('*.txt').each do |this_file|
  calFiles[n] = NPCalendar.new(this_file, n)
  n += 1
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
Dir.chdir(NP_NOTE_DIR)
notes = [] # read in all notes
activeNotes = [] # list of ID of all active notes which are Goals
nonActiveNotes = 0 # simple count of non-active notes

# Read metadata for all note files in the NotePlan directory
i = 0
Dir.glob('*.txt').each do |this_file|
  notes[i] = NPNote.new(this_file, i)
  if notes[i].isActive && !notes[i].isCancelled
    activeNotes.push(notes[i].id)
    i += 1
  else
    nonActiveNotes += 1
  end
end

# Count open (overdue) tasks, open undated, waiting, done tasks, future tasks
# broken down by Goals/Projects/Other.
if i.positive? # if we have some notes to work on ...
  activeNotes.each do |nn|
    n = notes[nn]
    if n.isGoal
      tgd += n.done
      tgo += n.open
      tgu += n.undated
      tgw += n.waiting
      tgf += n.future
    elsif n.isProject
      tpd += n.done
      tpo += n.open
      tpu += n.undated
      tpw += n.waiting
      tpf += n.future
    else
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
td = tod + tpd + tgd
to = too + tpo + tgo
tu = tou + tpu + tgu
tw = tow + tpw + tgw
tf = tof + tpf + tgf

# Show results on screen
puts "From #{activeNotes.count} active notes:"
puts "\tDone\tOverdue\tUndated\tWaiting\tFuture".colorize(TotalColour)
puts "Goals\t#{tgd}\t#{tgo}\t#{tgu}\t#{tgw}\t#{tgf}"
puts "Project\t#{tpd}\t#{tpo}\t#{tpu}\t#{tpw}\t#{tpf}"
puts "Other\t#{tod}\t#{too}\t#{tou}\t#{tow}\t#{tof}"
puts "TOTAL\t#{td}\t#{to}\t#{tu}\t#{tw}\t#{tf}".colorize(TotalColour)

# Write results to CSV file, appending
output = format('%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d',
                timeNowFmt, activeNotes.count, nonActiveNotes,
                tgd, tgo, tgu, tgw, tgf,
                tpd, tpo, tpu, tpw, tpf,
                tod, too, tou, tow, tof,
                td, to, tu, tw, tf)
f = File.open(NP_SUMMARIES_DIR + '/task_stats.csv', 'a')
f.puts output
f.close
