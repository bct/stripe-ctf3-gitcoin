#!/usr/bin/env ruby

PUBLIC_USERNAME = "user-jbdufo2q"
GITCOIN_REPO_PATH = "./current-round"

WORKER_COUNT = 3
WORKER_SEPARATION = 100_000_000_000


## --- config ends here --

# Set up repo
# I'm assuming it's already cloned here
Dir.chdir GITCOIN_REPO_PATH

def add_gitcoin_to_ledger
  ledger_contents = File.read "LEDGER.txt"

  File.open("LEDGER.txt", "w") do |ledger|
    matcher = /#{PUBLIC_USERNAME}: (\d+)/
    match = ledger_contents.match(matcher)

    if match
      # modify our line in the ledger
      ledger_contents.gsub! matcher, "#{PUBLIC_USERNAME}: #{match[1].to_i + 1}"
      ledger.puts ledger_contents
    else
      # append our line to the ledger
      ledger.puts ledger_contents
      ledger.puts "#{PUBLIC_USERNAME}: 1"
    end
  end
end

def prepare_index
  add_gitcoin_to_ledger

  puts File.read("LEDGER.txt")

  system "git add LEDGER.txt"
end

def success! sha1, commit
  puts "success!!!!"
  puts
  puts "Mined a Gitcoin with commit id: #{sha1}"

  # write this commit object to the repository
  git_write_commit(commit)

  puts "resetting"
 
  git_reset sha1

  print "pushing... "

  if git_push
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

  WORKER_COUNT.times do |i|
    initial_counter = i * WORKER_SEPARATION

    rd, wr = IO.pipe

    if pid = fork
      # in the parent
      wr.close

      readers << rd

      # we don't want our children to be zombies, and we don't care about their exit status.
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

      # the commit data is written in 2 pieces, so it has to be read in 2 pieces
      # lol portability and robustness
      commit = rs[0].read + rs[0].read

      success! sha1, commit

      git_fetch

      break
    else
      puts "select timed out"

      # if the remote changed then someone mined a coin before us (or the round ended)
      check = `git fetch 2>&1`

      if check.match /master/
        # we'll have to restart
        puts "the world moved beneath us :("
        break
      end
    end
  end

  # close our result channels, the children we spawned will die when they notice.
  readers.each do |rdr|
    rdr.close
  end
end

def git_fetch
  system "git fetch origin master >/dev/null 2>/dev/null"
end

def git_reset(ref)
  system "git reset --hard #{ref} >/dev/null"
end

def git_push
  system "git push origin master"
end

def git_write_commit(commit)
  cmd = "git hash-object -t commit --stdin -w"

  IO.popen(cmd, "w") do |io|
    io.print commit
  end
end

git_fetch

loop do
  git_reset "origin/master"
  prepare_index
  solve
end
