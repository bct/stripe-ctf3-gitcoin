#!/usr/bin/env ruby

require 'digest/sha1'

# Set up repo
# I'm assuming it's already pulled here
local_path = "./current-round"
Dir.chdir local_path

PUBLIC_USERNAME = "user-jbdufo2q"

def prepare_index()
    system "perl -i -pe 's/(#{PUBLIC_USERNAME}: )(\d+)/$1 . ($2+1)/e' LEDGER.txt"
    
    ledger_contents = File.read "LEDGER.txt"

    File.open("LEDGER.txt", "w") do |ledger|
      matcher = /#{PUBLIC_USERNAME}: (\d+)/
      match = ledger_contents.match(matcher)

      if match
        ledger_contents.gsub! matcher, "#{PUBLIC_USERNAME}: #{match[1].to_i + 1}"
        ledger.puts ledger_contents
      else
        ledger.puts ledger_contents
        ledger.puts "#{PUBLIC_USERNAME}: 1"
      end
    end

    puts File.read("LEDGER.txt")

    system "git add LEDGER.txt"
end

def success! sha1, commit
  puts "success!!!!"


  puts
  puts "Mined a Gitcoin with commit id: #{sha1}"

  cmd = "git hash-object -t commit --stdin -w"

  IO.popen(cmd, "w") do |io|
    io.print commit
  end

  puts "resetting"
 
  system "git reset --hard #{sha1} > /dev/null"

  print "pushing... "

  result = system "git push origin master"

  if result
    puts "succeeded!"
  else
    puts "failed :("
  end
end

def solve
  puts "here we go again..."

  # Create a Git tree object reflecting our current working
  # directory
  tree = `git write-tree`.chomp
  parent = `git rev-parse HEAD`.chomp
  timestamp= `date +%s`.chomp
  difficulty = File.read("difficulty.txt")

  readers = []

  3.times do |i|
    initial_counter = i * 100_000_000_000

    rd, wr = IO.pipe

    if pid = fork
      # in the parent
      wr.close

      readers << rd

      Process.detach(pid)
    else
      # in the child
      rd.close

      # this will never return
      exec "../a.out #{initial_counter} #{tree} #{parent} #{timestamp} #{difficulty}", :out => wr
    end
  end

  loop do
    rs, ws, = IO.select(readers, [], [], 15)

    if rs
      puts "got something?"

      sha1 = rs[0].readline
      commit = rs[0].read
      
      success! sha1, commit

      break
    else
      puts "select timed out"

      check = `git fetch 2>&1`

      if check.match /master/
        puts "the world moved beneath us :("
        break
      end
    end

  end

  readers.each do |rdr|
    rdr.close
  end
end

def fetch
    system "git fetch origin master >/dev/null 2>/dev/null"
end

def reset()
    system "git reset --hard origin/master >/dev/null"
end

fetch

loop do
  reset
  prepare_index
  solve
end
