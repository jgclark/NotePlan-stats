# NotePlan-stats
This provides two scripts to generate stats from your data in the [NotePlan](https://noteplan.co/) app.

<!-- Yes, I'll keep both around. New users will get CloudKit by default, if someone still has files in iCloud Drive, NotePlan will keep iCloud Drive by default till the user changes it manually. 
Folders inside "Notes" will be uploaded. I didn't try adding folders in "Calendar", but they definitely won't be added in the root folder. Also hidden files won't be synced, such as files starting with a dot. -->

## npStats
`npStats` script gives stats on various tags in NotePlan's note and calendar files, writing output to screen and to CSV file `NotePlan/Summaries/task_stats.csv`.
It copes with notes in sub-directories (supported from NotePlan v2.4), though it ignores ones in the built-in @Archive and @Trash directories.

It finds and summarises todos/tasks in note and calendar files:
- it only covers active notes (not archived or cancelled)
- it counts open tasks, open undated tasks, done tasks, future tasks
- it also breaks them down by Goals/Projects/Other. (For more on this particular way of using NotePlan see documentation for a different NotePlan extension, [NotePlan Reviewer]((https://github.com/jgclark/NotePlan-review).)
- it ignores tasks in a #template section. (For more on this particular way of using NotePlan see documentation for a different NotePlan extension, [NotePlan Tools]((https://github.com/jgclark/NotePlan-tools).)

It writes output to screen and appends to a `task_stats.csv` file in the (new) top-level 'Summaries' directory (unless the --nofile option is given). If the storage type is `CloudKit` it will instead save to the user's home directory.

Run with `npStats -h` to see the command line switches available.

## npTagStats
`npTagStats` script gives summary counts of #hashtags and @mentions in NotePlan's daily calendar files:
- for #hashtags it simply counts up any it finds from a configurable list, for example `#gym` or `#readbook` 
- the @mentions counted are of the form `@mention(number)`, e.g. `@work(8)` or `@fruitveg(5)`, this allows simple tracking of numeric items over time, for example hours worked, or number of fruit'n'veg portions eaten. Again, this list is configurable (see below).

There are 2 ways of running this:

1. with a passed year (e.g. `npStats 2020'), it will just look in the files for that year
2. with no arguments (`npStats'), it will just count the current year, and distinguish dates in the future (where relevant)

It writes output to screen and writes to a `<year>_tag_stats.csv` file, unless the `--nofile` command line option is given. (The location depends which NotePlan storage type you use: it goes in the (new) top-level 'Summaries' directory in NotePlan for iCloud Drive or Dropbox, or the user's home directory for CloudKit.)

## Options
Run either script with `-h` or `--help` to see the command line switches available:
- `-n`/`--nofile`: do not write summary to file
- `-v`/`--verbose`: show information as I work

## Installation & Configuration
Check you have installed the `colorize` and `optparse` gems (> gem install colorize optparse).

Add the .rb script(s) to your path, and then set them as executable (`chmod 755 np*.rb`)

For the `npTagStats` script configure a separate `npTagStats.json` file in your home directory, with the following two arrays:
- `tags_to_count`: array of hashtags to count, e.g. ["#holiday", "#halfholiday", "#bankholiday", "#dayoff"]
- `mentions_to_count`: array of mentions to count, e.g. ["@work", "@sleep"]

For example the .json file for these examples would be:
```
{
  "tags_to_count": ["#holiday", "#halfholiday", "#bankholiday", "#dayoff"],
  "mentions_to_count": ["@work", "@sleep"]
}
```
