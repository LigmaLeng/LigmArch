#!/usr/bin/perl

use strict;
use warnings;
use Term::ANSIColor qw(:constants);
use Term::Readkey;

Readmode 4;
my $kbin;
my $pid = fork();

# Function to read input and search keymaps incrementally
sub _simple_select {

    if (not $pid) {
        while (1) {
            say CYAN "hello subby wubby", RESET;
            sleep 2;
        }
    } 
    
    while (1) {
        $kbin = Readkey(-1);
        given ($kbin) {
           when ("q") {
               system (kill -9 $pid);
               Readmode 0;
               exit;
           }
           default { say BLACK ON_RED "hello dommy mommy", RESET; }
        }
    }

}

# Function to display available disks for partitioning

# Function to test optimal block size to wipe disk
sub _bs_test {
    my ($disk, @opts) = @_;
    say "$disk";
}

# Function to read input and search locale codes

_simple_select()
