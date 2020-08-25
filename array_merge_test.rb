#!/usr/bin/ruby
#-------------------------------------------------------------------------------
# Test how best to merge 3 2-dimensional [key][value] arrays into a single
# array with shared key value, and 3 [value] columns.
# JGC, 25.8.2020
#-------------------------------------------------------------------------------
# Try to decide on different methods, and whether array, hash, table or possibly
# matrices are the way to go.
# --> use Method 2 for arrays

#-------------------------------------------------------------------------------
# helper function to print multi-dimensional 'tables' of data prettily
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

#-------------------------------------------------------------------------------
# Test data
a1 = [[2020101, 4], [2020102, 3], [2020103, 3], [2020105, 1], [2020106, 2], [2020110, 6]]
a2 = [[2020101, 6], [2020102, 3], [2020103, 7], [2020105, 1], [2020106, 2], [2020110, 4]]
a3 = [[2020021, 10], [2020102, 4], [2020105, 8], [2020106, 6], [2020140, 2], [2020190, 6], [2020198, 2], [2020199, 3]]

#-------------------------------------------------------------------------------
# Method 1: Very simnple append and then merge
# -> appends, but doesn't distinguish into 1+3 columns
a = a1 + a2 + a3
as = a.sort # works
# print_table as
# didn't get as far as trying merge here

#-------------------------------------------------------------------------------
# Method 2: Append and then merge
a = Array.new { Array.new(4, 0) }
a1.each do |aa|
  a += [[aa[0], aa[1], 0, 0]]
end
a2.each do |aa|
  a += [[aa[0], 0, aa[1], 0]]
end
a3.each do |aa|
  a += [[aa[0], 0, 0, aa[1]]]
end
as = a.sort # works
print_table as
puts

last_key = 0
last_col1 = 0
last_col2 = 0
last_col3 = 0
i = 0
as.each do |row|
  if last_key == row[0]
    row[1] += last_col1
    row[2] += last_col2
    row[3] += last_col3
    as[i - 1][0] = 0 # mark for deletion. Trying to delete in place mucks up the loop positioning
  end
  last_key = row[0]
  last_col1 = row[1]
  last_col2 = row[2]
  last_col3 = row[3]
  i += 1
end
print_table as
puts
# now remove the row set to delete
as.delete_if { |row| row[0] == 0 }
print_table as

#-------------------------------------------------------------------------------
# Method 3: use zip array command?
# this is just what the docs say:
#   Converts any arguments to arrays, then merges elements of self with corresponding elements from each argument.
#   This generates a sequence of ary.size n-element arrays, where n is one more than the count of arguments.
#   If the size of any argument is less than the size of the initial array, nil values are supplied.
#   If a block is given, it is invoked for each output array, otherwise an array of arrays is returned.
# Didn't get as far as testing this
a = [4, 5, 6]
b = [7, 8, 9]
[1, 2, 3].zip(a, b)   #=> [[1, 4, 7], [2, 5, 8], [3, 6, 9]]
[1, 2].zip(a, b)      #=> [[1, 4, 7], [2, 5, 8]]
a.zip([1, 2], [8])    #=> [[4, 1, 8], [5, 2, nil], [6, nil, nil]]
