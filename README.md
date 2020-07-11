# NotePlan-stats
This provides two scripts to use with [NotePlan](https://noteplan.co/) app.

## npStats
This script gives stats on various tags in NotePlan's note and calendar files, writing output to screen and to CSV file <code>NotePlan/Summaries/task_stats.csv</code>.
It copes with notes in sub-directories (added in NotePlan v2.5), though it ignores ones in the built-in @Archive and @Trash directories.

It finds and summarises todos/tasks in note and calendar files:
- only covers active notes (not archived or cancelled)
- counts open tasks, open undated tasks, done tasks, future tasks
- breaks down by Goals/Projects/Other

Run with <code>npStats -h</code> to see the few command line switches available.

## npTagStats
This script gives stats on various hashtags in NotePlan's daily calendar files, writing to screen and to CSV file <code>NotePlan/Summaries/{year}_tag_stats.csv</code>.

There are 2 ways of running this:

1. with a passed year, it will just look in the files for that year.
2. with no arguments, it will just count the current year, and distinguish dates in the future (where relevant)

It writes output to screen and appends to a CSV file in the (new) top-level 'Summaries' directory (unless the --nofile option is given).

Run with <code>npTagStats -h</code> to see the few command line switches available.

## Configuration
Set the following variables:
- <code>STORAGE_TYPE</code>: select iCloud (default) or Drobpox
- <code>USERNAME</code>: the username of the Dropbox/iCloud account to use
- <code>TAGS_TO_COUNT</code>: array of tags to count, e.g. ["#holiday", "#halfholiday", "#bankholiday", "#dayoff"]
