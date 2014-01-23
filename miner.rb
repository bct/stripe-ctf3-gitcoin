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

def solve
  puts "here we go again..."

  # Create a Git tree object reflecting our current working
  # directory
  tree = `git write-tree`.chomp
  parent = `git rev-parse HEAD`.chomp
  timestamp= `date +%s`.chomp

  readers = []

  3.times do |i|
    initial_counter = i * 100_000_000

    rd, wr = IO.pipe

    if fork
      # in the parent
      wr.close

      readers << rd
    else
      # in the child
      rd.close

      # this will never return
      solve_single initial_counter, wr, tree, parent, timestamp
    end
  end

  rs, ws, = IO.select(readers, [])

  puts "success!!!!"

  sha1 = rs[0].readline
  commit = rs[0].read

  puts
  puts "Mined a Gitcoin with commit id: #{sha1}"

  cmd = "git hash-object -t commit --stdin -w"

  IO.popen(cmd, "w") do |io|
    io.print commit
  end

  puts "resetting"
 
  system "git reset --hard #{sha1} > /dev/null"

  puts "pushing"

  result = system "git push origin master"

  if result
    puts "success!"
  else
    puts "failed :("
  end

  readers.each do |rdr|
    rdr.close
  end
end

def solve_single(initial_counter, success_fd, tree, parent, timestamp)
    # Brute force until you find something that's lexicographically
    # small than $difficulty.
    difficulty = File.read("difficulty.txt")

    counter = initial_counter

    head = <<END
tree #{tree}
parent #{parent}
author CTF user <bct@diffeq.com> #{timestamp} +0000
committer CTF user <bct@diffeq.com> #{timestamp} +0000

Give me a Gitcoin
END

    head_length = head.length
    last_length = 0
    head_digest = nil

    t1 = Time.now

    loop do
      #start = Time.now

      counter += 1

      if counter % 1_000_000 == 0
        if IO.select [success_fd], [], [], 0
          # our parent has exited, we should too
          exit
        end

        p counter

        t2 = Time.now
        p t2 - t1 
        t1 = t2
      end

      length = head.length + counter.to_s.length

      if length != last_length
        head_digest = Digest::SHA1.new
        head_digest.update "commit #{length}\0#{head}"
        last_length = length
      end

      #before_hash = Time.now

      digester = head_digest.dup
      digester.update counter.to_s
      sha1 = digester.hexdigest

      #after_hash = Time.now

      if sha1 < difficulty
        success_fd.puts sha1
        success_fd.print head
        success_fd.print counter

        success_fd.close

        exit
      end

      #after_test = Time.now

      #puts "#{before_hash - start} #{after_hash - before_hash} #{after_test - after_hash}"
      #exit
    end
end

def reset()
    system "git fetch origin master >/dev/null 2>/dev/null"
    system "git reset --hard origin/master >/dev/null"
end

loop do
  reset
  prepare_index
  solve
end
