# CHANGELOG

## for npStats
## v1.8.1, 2022-12-31
- [Changed] NP 3.8 adds checklists; these are now ignored in the task completion stats

## v1.8.0, 2022-09-25
- [Fixed] sorted folder exlusions, though I don't think it's made a difference in the output

## v1.7.0, 2022-06-26
- [Added] supports new Weekly notes, available with NotePlan 3.6.0.
- [Added] new setting FOLDERS_TO_IGNORE to ignore in counts (but something is weird in the file globbing)

### v1.6.2, 15.5.2022
- [Change] update to handle newer @Templates; improve logging code

### v1.6.1, 31.12.2021
- [Fix] in calendar notes, many tasks were counted as being 'overdue' when they should be counted as overdue.
- [Change] code clean up

### v1.6.0, 18.11.2021
- [Fix] task_done_dates.csv now includes items from daily calendar notes

### v1.5.4, 10.3.2021
- [Fix] task_done_dates.csv no longer includes future dates

### v1.5.2, 9.2.2021
- [Change] Folder for file outputs now set via environment variable NPEXTRAS (if using CloudKit as NP storage type)

### v1.5.1, 17.11.2020
- [Improve] Automatic configuration of NotePlan storage (CloudKit > iCloudDrive > Dropbox)

### v1.5.0, 30.10.2020
- [Change] Now default to using the sandbox location for CloudKit storage (change from NotePlan 3.0.15 beta)

### v1.4.0, 24.10.2020
- [Change] The counts now ignore open or future tasks in a #template section (issue #12)
- [New] New -c option to ignore daily calendar files when counting the stats

### v1.3.4, 23.9.2020
- [Change] The summary file of how many tasks were completed on which ordinal date (unless --nofile option given) now differentiates between Goal/Project/Other. (continuing issue #9)

### v1.3.3, 23.8.2020
- [New] Support data files with .md extensions as well as .txt (issue #8) -- not yet fully tested
- [New] Write out a summary of how many tasks were completed on which ordinal date (unless --nofile option given) (issue #9)

### v1.3.2, 24.7.2020
- [New] Make CloudKit the default file storage location

## v1.3.0, 18.4.2020
- [New] Allow for CloudKit as a storage location, to suit new NP3 beta builds (issue #3)
- [Fix] Ignore empty NP files

## v1.2.2, 18.4.2020
- [Change] Now ignore cancelled tasks, as they were wrongly getting counted in ?undated? open tasks

## v1.2.1, 18.4.2020
- [Fix] Some notes had characters not allowed in US-ASCII. So opened as UTF-8 instead.

## v1.2.0, 27.3.2020
- Improve README

## v1.1.0, 15.3.2020
- [New] support folders (sub-directories) for notes in NP 2.4+ (issue #1)
- [New] add command line options --nofile and --verbose

## v1.0.3, 14.3.2020
- Code clea up

## v1.0.2, 8.3.2020
- [New] Add task counting script
- [New] Add colouring to screen output
- [New] Add file CSV output

## v1.1, 29.2.2020
- Split a single earlier script into these two.

## v1.0.1, 11.2.2020
Initial load into this GitHub project.

## for npTagStats
### v1.7.1, 1.1.2023
- [New] Adds support for NotePlan's new monthly, quarterly and yearly notes

### v1.7.0, 25.9.2022
- [Fix] Weekly 'Calendar' notes are now properly handled
- [Fix] @mention(...)s with floating-point numbers are now better handled in output

### v1.6.2, 9.2.2021
- [Change] Folder for file outputs now set via environment variable NPEXTRAS (if using CloudKit as NP storage type)

### v1.6.1, 19.1.2021
- [New] Now show the first date each tag was used in the time period.

### v1.6.0, 14.12.2020
- [Change] Now specify the `tags_to_count` and `mentions_to_count` through a separate `~/npTagStats.json' file

### v1.5.1, 14.10.2020
- [Fix] Multiple #tags on the same line were only being counted once. Fixed.
- [Improve] Add Total and Average to @mention counts
- [Improve] Automatic configuration of NotePlan storage (CloudKit > iCloudDrive > Dropbox)

### v1.4.1, 11.10.2020
- [New] Support .md as well as .txt files (issue #8)
- [Improve] Improve formatting of @mentions output by adding week commencing date and hiding weeks with no data (issue #10)

### v1.4, 10.10.2020
- [New] Add summary totals of @mention(n) per week (issue #10)

### v1.3.3, 16.8.2020
- [New] npTagStats Sort both types out of @mention summary output (issue #6)
- [Improve] improve documentation

### v1.3.2, 10.8.2020
- [New] Add feature to count and sum @mention(n) and output (towards issue #6)

## v1.3.1, 27.7.2020
- [Change] When running using CloudKit storage, now location of output files defaults to user's home directory. This avoids security issue when running using launchctl.

## v1.3.0, 24.7.2020
- [Fix] Ignore empty NP files

## v1.2.2, 19.7.2020
- [New] Allow for CloudKit as a storage location, to suit new NP3 beta builds (issue #3)

## v1.2.0, 11.7.2020
- [New] Added command line options --nofile and --verbose

## v1.1.1, 8.3.2020
- [New] Added colour to screen outputs
- [New] Add file CSV output
- Code clean up, following rubocop

## v1.1, 29.2.2020
- Split a single earlier script into these two.