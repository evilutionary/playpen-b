require 'psych'

def testplan_msg1(raw)
  STDERR.puts raw
end

def testplan_msg(name, acount, details)
  m = "YAML test #{name} array #{acount}: #{details}"
  testplan_msg1(m)
end

# faster when range is <= 10x elements
def generate_sample(elements, min, max)
  if elements > (max-min+1)
    return []
  end
  ary = (min..max).to_a.sample(elements)
end

# faster when range is > 10x elements
def generate_random(elements, min, max, factor=1.0)
  range = max-min + 1
  p_full_end = elements / range.to_f # fill ratio when done
  p_empty_end = 1-p_full_end
  ratio = 1.0/p_empty_end
  ary = []
  while ary.length < elements
    ary.concat(Array.new(elements*ratio*factor) { rand(range) + min })
    ary.uniq!
    #puts "looped"
  end
  puts("gen random: #{ary.length} elements")

  ary
end

def generate_randomexp(elements, min, max, type)
  range = max-min + 1
  lamd = 0.75
  expscale = range / 6.0 # 95%, 1-Math.exp(-0.5*6)

  p_full_end = elements / range.to_f # fill ratio when done
  p_empty_end = 1-p_full_end
  ratio = 1.0/p_empty_end

  egen = (elements * ratio).ceil  # initial try

  ary = []
  prevcount = 0
  round = 0
  eratio = 0
  while ary.length < elements
    round += 1
    if type == :explow
      ary.concat Array.new(egen) { (-expscale*lamd * Math.log(lamd*rand())).floor + min }
    elsif type == :exphigh
      ary.concat Array.new(egen) {
        (max - (-expscale*lamd * Math.log(lamd*rand())).floor).clamp(min, max)
      }
    else
      return []
    end
    ary.uniq!
    diff = ary.length - prevcount
    prevcount = ary.length

    if diff == 0
      diff = 0.5
    end

    eratio = (egen.to_f / diff).ceil

    remaining = elements - ary.length
    egen = remaining * eratio
  end
  ary
end

def generate_array(mmet, name, aryidx)
  type, elements, min, max = mmet[:type], mmet[:elements], mmet[:min], mmet[:max]
  range = max - min
  ratio = range / elements.to_f
  ds = nil
  if ratio < 1.5
    ds = "very dense"
  elsif ratio < 4
    ds = "dense"
  elsif ratio < 16
    ds = "medium"
  else
    ds = "sparse"
  end


  ary = []
  if type == :normal
    if ratio <= 10
      ary = generate_sample(elements, min, max)
    else
      ary = generate_random(elements, min, max)
    end
  elsif type == :explow || type == :exphigh
    if ratio < 1.25
      testplan_msg(name, aryidx, " ::low ratio #{ratio}<1.25 for exp-type array... this could take a while")
    end
    ary = generate_randomexp(elements, min, max, type)
  else
    testplan_msg(name, aryidx, "unknown type #{mmet[:type]}")
  end
  puts " ::generated #{type} array, #{ds}, ratio #{ratio}.  specs #{elements} from #{min} - #{max}"
  puts "  :: samples... #{ary.sample(5)}"

  ary
end


def testplan_read(f)
  t_raw = Psych.safe_load_file(f, aliases: true)
  STDERR.puts "yaml plan length: #{t_raw.length}"
  t_plan = []
  count = 1
  t_raw.each do |p|
    if p.has_key?("name")
      name = p["name"]
    else
      name = "Batch #{count}"
    end
    if !p.has_key?("arrays")
      next
    end
    testplan_msg1("\nprocessing plan: \"#{name}\" : #{p["arrays"].length} arrays")

    aryidx = 0
    arrays = []
    params = []
    for a in p["arrays"]
      aryidx += 1
      # possible keys: min, max, elements, type (exp-(low|lower) or exp-(high|upper))
      mmet = {}
      # defaults
      mmet[:min], mmet[:max], mmet[:elements] = nil, nil, nil
      mmet[:type] = :normal
      #STDERR.puts "processing array definition #{a}"
      if a.nil?
        testplan_msg(name, aryidx, "malformed array spec was parsed as nil")
        next
      end
      for k in mmet.keys
        ks = k.to_s
        if a.has_key?(ks)
          if k == :type
            if a[ks] == "exp-lower" || a[ks] == "exp-low"
              mmet[:type] = :explow
            elsif a[ks] == "exp-upper" || a[ks] == "exp-high"
              mmet[:type] = :exphigh
            elsif a[ks] == "normal"
              # already set
            else
              testplan_msg(name, aryidx, "type invalid and ignored: #{a[ks]}")
            end
          else
            if a[ks].class == String
              mmet[k] = a[ks].to_i
            elsif a[ks].class == Integer
              mmet[k] = a[ks]
            else
              testplan_msg(name, aryidx, "unknown type for key #{ks}.. #{a[ks].class}")
            end
          end
        end
      end

      # basic sanity checking and parameter generation
      if mmet[:min].nil?
        testplan_msg(name, aryidx, "min missing")
        next
      elsif mmet[:elements].nil?
        testplan_msg(name, aryidx, "(# of) elements missing")
        next
      end

      if mmet[:max].nil?
        mmet[:max] = mmet[:min] + mmet[:elements]*10
      end
      if mmet[:min] > mmet[:max]
        testplan_msg(name, aryidx, "min > max, so swapping")
        mmet[:min], mmet[:max] = mmet[:max], mmet[:min]
      end

      range = mmet[:max] - mmet[:min] + 1
      perc = mmet[:elements] / range.to_f
      if (mmet[:type] == :normal && perc >= 1) || perc > 0.8
        pr = perc.round(2)
        testplan_msg(name, aryidx, "too dense: #{pr} (probability) for type #{mmet[:type]}")
        next
      end


      # generate the array
      #testplan_msg(name, aryidx, "generating array #{mmet[:type]}, #{mmet[:elements]}, #{mmet[:min]} - #{mmet[:max]}")
      ary = generate_array(mmet, name, aryidx)
      #puts "received array of class #{ary.class}"
      if ary.nil?
        testplan_msg(name, aryidx, "array parsing returned nil (type #{mmet[:type]}), ignoring")

        next
      end
      arrays.push(ary)
      params.push(mmet)
    end
    if arrays.length < 2
      testplan_msg1("YAML test #{name} had fewer than 2 valid arrays, can't intersect")
      next
    end
    t_plan.push({:name => name, :arrays => arrays, :params => params})
  end
  t_plan
end


def testplan_print1(plan)
  puts "\nPlan: #{plan[:name]}  ::  #{plan[:arrays].length}-way intersection"
  plan[:params].each_index do |i|
    p = plan[:params][i]
    a = plan[:arrays][i]
    puts "  array: %9i ~ %9i from %6i to %9i [%s]" % [
      a.length,
      p[:elements],
      p[:min],
      p[:max],
      p[:type]
    ]
    if false && a.length < 50
      puts "raw array (shown for <50 elements): #{a}"
    end
  end
end

def runplans(planlist)
  Benchmark.bm(32) do |x|
    x.report("") { }
  end
end

