# NotePlan-stats
Script to give stats on various hashtags in NotePlan's daily calendar files.

## Running it
Two ways of running this:

1. with a passed year, it will just look in the files for that year.
2. with no arguments, it will just look in the current year, and distinguish dates in the future, from year to date

## Configuration
Set the following variables:
- StorageType: select iCloud (default) or Drobpox
- Username: the username of the Dropbox/iCloud account to use
- TagsToCount: array of tags to count, e.g. ["#holiday", "#halfholiday", "#bankholiday", "#dayoff"]
