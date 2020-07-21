# NotePlan-stats
This provides two scripts to use with [NotePlan](https://noteplan.co/) app.

<!-- Yes, I'll keep both around. New users will get CloudKit by default, if someone still has files in iCloud Drive, NotePlan will keep iCloud Drive by default till the user changes it manually. 
Folders inside "Notes" will be uploaded. I didn't try adding folders in "Calendar", but they definitely won't be added in the root folder. Also hidden files won't be synced, such as files starting with a dot. -->

## npStats
`npStats` script gives stats on various tags in NotePlan's note and calendar files, writing output to screen and to CSV file <code>NotePlan/Summaries/task_stats.csv</code>.
It copes with notes in sub-directories (added in NotePlan v2.5), though it ignores ones in the built-in @Archive and @Trash directories.

It finds and summarises todos/tasks in note and calendar files:
- only covers active notes (not archived or cancelled)
- counts open tasks, open undated tasks, done tasks, future tasks
- breaks down by Goals/Projects/Other

Run with <code>npStats -h</code> to see the few command line switches available.

## npTagStats
`npTagStats` script gives stats on various hashtags in NotePlan's daily calendar files, writing to screen and to CSV file <code>NotePlan/Summaries/{year}_tag_stats.csv</code>.

There are 2 ways of running this:

1. with a passed year, it will just look in the files for that year.
2. with no arguments, it will just count the current year, and distinguish dates in the future (where relevant)

It writes output to screen and appends to a CSV file in the (new) top-level 'Summaries' directory (unless the --nofile option is given).

Run with <code>npTagStats -h</code> to see the few command line switches available.

## Configuration
Set the following variables:
- <code>STORAGE_TYPE</code>: select whether you're using `iCloud` for storage (the default) or `CloudKit` (from v3.0) or `Drobpox`. If you're not sure, see NotePlan's `Sync Settings`.
- <code>USERNAME</code>: the username of the Dropbox/iCloud account to use
- <code>TAGS_TO_COUNT</code>: array of tags to count, e.g. ["#holiday", "#halfholiday", "#bankholiday", "#dayoff"]

Check you have installed the `colorize` and `optparse` gems (> gem install colorize optparse).
