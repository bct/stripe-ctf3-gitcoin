# bct's gitcoin miner #

This is a multiprocess gitcoin miner that I wrote for Stripe's CTF3.

By the time I got the C version working it wasn't really fast enough to compete
with the other miners running in the head-to-head, but I'm pleased with the result.

The core is a Ruby program that forks and execs several processes that search
for a commit with the desired hash. The processes use OpenSSL's SHA1
implementation directly, rather than shelling out to git.

On my server I get about 1 million SHA1s per second (333k × 3 cores).
Judging by the output of `openssl speed` I should have been able to get a lot
more than that.

## setup ##

    gcc -lcrypto gitcoin.c

    git clone <gitcoin repository>

    $EDITOR miner_c.rb    # edit configuration at top of file

    ./miner_c.rb
