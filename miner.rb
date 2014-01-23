#!/usr/bin/env ruby

require 'digest/sha1'

if ARGV.length != 2
    puts "Usage: $0 <clone_url> <public_username>

A VERY SLOW mining implementation. This should give you an idea of
where to start, but it probably won't successfully mine you any
Gitcoins.

Arguments:

<clone_url> is the string you'd pass to git clone (i.e.
  something of the form username@hostname:path)

<public_username> is the public username provided to you in
  the CTF web interface."
    exit
end

# Set up repo
# I'm assuming it's already pulled here
local_path = "./level1"
Dir.chdir local_path

PUBLIC_USERNAME = ARGV[1]

def prepare_index()
    system "perl -i -pe 's/(#{PUBLIC_USERNAME}: )(\d+)/$1 . ($2+1)/e' LEDGER.txt"
    
    File.open("LEDGER.txt", "r+") do |ledger|
      contents = ledger.read

      unless contents.match PUBLIC_USERNAME
        puts "adding username"
        ledger.puts "#{PUBLIC_USERNAME}: 1"
      end
    end

    system "git add LEDGER.txt"
end

def solve
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

  IO.popen("xxd", "w") do |io|
    io.print commit
  end

  puts
  puts "Mined a Gitcoin with commit: #{sha1}"

  cmd = "git hash-object -t commit --stdin -w"

  IO.popen(cmd, "w") do |io|
    io.print commit
  end

  puts "resetting"
 
  system "git reset --hard #{sha1} > /dev/null"

  exit
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

reset
prepare_index
solve
