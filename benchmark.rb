require 'benchmark'
require 'pry'

require "./testplan.rb"

def debug_results(r)
    #puts "  -- intersections: #{r.length}"
    r
end

def generate_random_array(length)
  min_value = 1
  exp_length = 2 ** length
  max_value = exp_length * 100
  unique_values = (min_value..max_value).to_a.shuffle
  unique_values[0, exp_length].sort
end

def gen_max_array(length)
  exp_length = 2 ** length
  min_value = exp_length * 99
  max_value = exp_length * 100
  (min_value..max_value).to_a
end

def find_matches_ampersand(nums1, nums2, nums3)
  result = nums1 & nums2 & nums3
  debug_results(result)
end

def find_matches_intersect(nums1, nums2, nums3)
  result = nums1.intersection(nums2, nums3)
  debug_results(result)
end

def find_matches_include(nums1, nums2, nums3)
  result = []
  nums1.each do |num|
    result << num if nums2.include?(num) && nums3.include?(num)
  end
  debug_results(result)
end

def find_matches_kiss(nums1, nums2, nums3)
  result = []
  i, j, k = 0, 0, 0

  while i < nums1.length && j < nums2.length && k < nums3.length
    num1, num2, num3 = nums1[i], nums2[j], nums3[k]

    if num1 == num2 && num2 == num3
      result << num1
      i += 1
      j += 1
      k += 1
    elsif num1 <= num2 && num1 <= num3
      i += 1
    elsif num2 <= num1 && num2 <= num3
      j += 1
    else
      k += 1
    end
  end

  debug_results(result)
end

def find_matches_kiss_plus(nums1, nums2, nums3)
  result = []
  i, j, k = 0, 0, 0

  while i < nums1.length && j < nums2.length && k < nums3.length
    num1, num2, num3 = nums1[i], nums2[j], nums3[k]

    if num1 == num2 && num2 == num3
      result << num1
      i += 1
      j += 1
      k += 1
    elsif num2 < num3 && num1 < num3
      i += 1
      j += 1
    elsif num3 < num2 && num1 < num2
      i += 1
      k += 1
    elsif num3 < num1 && num2 < num1
      j += 1
      k += 1
    elsif num1 <= num2 && num1 <= num3
      i += 1
    elsif num2 <= num1 && num2 <= num3
      j += 1
    else
      k += 1
    end
  end

  debug_results(result)
end

def find_matches_intersect_b(nums1, nums2, nums3)
  result = nums1.intersection(nums2).intersection(nums3) # this is the same intersection as above
  debug_results(result)
end

def find_matches_hash(nums1, nums2, nums3)
  freq_hash = {}
  nums1.each { |num| freq_hash[num] = freq_hash[num].to_i + 1 }
  result = nums2.select { |num| freq_hash[num] && freq_hash[num] > 0 } & nums3
  debug_results(result)
end

def find_matches_reduce(nums1, nums2, nums3)
  result = [nums1, nums2, nums3].reduce(:&)
  debug_results(result)
end

# def your_matches_method(nums1, nums2, nums3)
#   your code here
#   debug_results(result)
# end

def plan_okay(plan)
  nway = plan[:arrays].length
  if nway < 3
    puts "too few arrays, skipping for now since methods require 3"
    false
  elsif nway > 3
    puts "too many arrays (#{nway}), skipping..." #could truncate to 3...
    #ary = plan[:arrays][0..2]
    false
  else
    true
  end
end

def benchmark_find_methods(plan)
  testplan_print1(plan)
  ary = plan[:arrays]
  #arysort = ary.map{|a| a.sort}
  sset = ary.map{|a| a.to_set}

  Benchmark.bm(32) do |x|
    r = []
    x.report("find_matches_intersect:") { r << find_matches_intersect(*ary) }
    x.report("find_matches_intersect_b:") { r << find_matches_intersect_b(*ary) }
    x.report("find_matches_reduce:") { r << find_matches_reduce(*ary) }
    x.report("find_matches_ampersand:") { r << find_matches_ampersand(*ary) }
    x.report("find_matches_kiss_plus:") { arysort = ary.map{|a| a.sort}; r << find_matches_kiss_plus(*arysort) }
    x.report("find_matches_kiss:") { arysort = ary.map{|a| a.sort}; r << find_matches_kiss(*arysort) }
    x.report("find_matches_intersect_b [sets]:") { r << find_matches_intersect_b(*sset) }
    x.report("find_matches_ampersand [sets]:") { r << find_matches_ampersand(*sset) }
    x.report("find_matches_hash:") { r << find_matches_hash(*ary) }
    # x.report("find_matches_include:") { find_matches_include(a, b, c) }
    # 100x slower than others, redeuce length limit to 15
    # x.report("your_find_matches_label:") { your_find_matches(a, b, c) }
    lengths = r.map{|a| a.length}
    mm = lengths.minmax
    if mm.first != mm.last
      puts "Intersection lengths don't match; enable printing lengths in debug_results to find out which one"
    end
  end

  puts
end

# nums_1 = [1, 2, 4, 5, 8]
# nums_2 = [2, 3, 5, 7, 9]
# nums_3 = [1, 2, 5, 8, 9]

# d, e, f = nums_1.to_set, nums_2.to_set, nums_3.to_set

# find_matches_ampersand(nums_1, nums_2, nums_3)
# find_matches_intersect(nums_1, nums_2, nums_3)
# find_matches_include(nums_1, nums_2, nums_3)
# find_matches_kiss(nums_1, nums_2, nums_3)
# find_matches_kiss_plus(nums_1, nums_2, nums_3)
# find_matches_set2(d, e, f)
# find_matches_sets(d, e, f)
# find_matches_hash(nums_1, nums_2, nums_3)
# find_matches_reduce(nums_1, nums_2, nums_3)
# add your method here and uncomment to test method functionality

if ARGV.length == 0
  ARGV.push("testplan.yaml")
end

ARGV.each do |f|
  if File.exist?(f)
    planlist = testplan_read(f)

    planlist.filter{|p| plan_okay(p)}.each do |plan|
      benchmark_find_methods(plan)
    end
  end
end

