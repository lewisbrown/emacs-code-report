#!env perl

## code-report.pl --- An emacs documentation generator
#
# Copyright © 2014 Lewis Brown
#
# Author: Lewis Brown <lewisbrown@gmail.com>
# URL: https://github.com/lewisbrown/code-report
# Version: 1.0.0
# Keywords: emacs
#
# This file is not part of GNU Emacs.
#
# License:
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GNU Emacs; see the file COPYING.  If not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301, USA.
#
# Commentary:
#
# code_report scans any set of emacs files, collects various
# information such as requires, commands, defuns, macros,
# define-keys, set-keys, along with their arguments and docs, and
# organizes them in various ways for viewing in org-mode. This
# provides a birds eye view of the entire file set, making it
# easier to understand, program with, operate, and change the code.
#
# Code:


use 5.20.0;
use warnings;

use experimental 'signatures';
# use feature 'switch', 'say';

use feature ':5.20';
use experimental 'postderef';
use autodie;
# constant
# use Const::Fast;

package LB::Scrape::API::elisp 0.02;

#use Modern::Perl;
# use perl5i;
use IO::File;
use Carp ();
# use IO::Dir;
# use Exception::Class;
# use Try::Tiny;
# use Data::Dumper;

our @types = qw(commentary
               require provide
               defgroup defcustom
               command defun defmacro defadvice defalias
               define_key
               set_key
               key_chord
             );

our @keybindings_types = qw(define_key2
                           set_key2
                           key_chord2);

exit main( @ARGV );

sub main {
    my %files;
    my %forms;
    my %keybindings;

    foreach my $filename (@ARGV) {
        my $data = scan_file($filename);
        $files{$filename} = $data;

        build_form_hash(\%forms, $data);
        build_keybindings_hash(\%keybindings, $data);
    }

    print_by_file(\%files);
    print_by_type(\%forms);
    print_by_keybinding(\%keybindings);

    return 0;
}

sub print_by_file ($files) {
    say "* Prelude by file";
    foreach my $file (sort (keys %{$files})) {
        say "** $file";
        foreach my $type (@types) {
            if ( my @k = keys %{$files->{$file}{$type}} ) {
                say "*** $type";
                foreach my $item (sort @k) {
                    my $ptr = $files->{$file}{$type}{$item};
                    print "**** $item";
                    print defined($ptr->{args}) ? " $ptr->{args}\n" : "\n";
                    print @{$ptr->{doc}} if defined($ptr->{doc});
                }
            }
        }
    }
}

sub print_by_type ($forms) {
    our %types;

    say "* Prelude by type";
    foreach my $type (@types) {
        if ( my @k = keys %{$forms->{$type}} ) {
            say "** $type";
            foreach my $item (sort @k) {
                my $ptr = $forms->{$type}{$item};
                print "*** $item";
                print defined($ptr->{args}) ? " $ptr->{args}\n" : "\n";
                print @{$ptr->{doc}} if defined($ptr->{doc});
            }
        }
    }
}

sub print_by_keybinding ($keybindings) {
    say "* Prelude by keybindings";
    foreach my $item (sort (keys %{$keybindings})) {
        my $ptr = $keybindings->{$item};
        print "** $item";
        print defined($ptr->{args}) ? " $ptr->{args}\n" : "\n";
    }
}

sub build_form_hash ($forms, $data) {
    our @types;

    foreach my $type (@types) {
        foreach my $item (keys %{$data->{$type}}) {
            $forms->{$type}{$item} = $data->{$type}{$item};
        }
    }
}

sub build_keybindings_hash ($keybindings, $data) {
    our @keybindings_types;
    foreach my $type (@keybindings_types) {
        foreach my $item (keys %{$data->{$type}}) {
            if (defined $keybindings->{$item}) {
                # random in case of duplicate bindings
                my $item_mod = $item . int(rand(100));
                $keybindings->{$item_mod} = $data->{$type}{$item};
            } else {
                $keybindings->{$item} = $data->{$type}{$item};
            }
        }
    }
}

sub scan_file($filename) {
    my $fh = IO::File->new("< $filename")
            or die " Can't open file $filename: $!";

    my %data;

    while (<$fh>) {
        get_commentary($fh, \%data, $filename);
        get_require($fh, \%data);
        get_provide($fh, \%data);
        get_defgroup($fh, \%data);
        get_defcustom($fh, \%data);
        defvar($fh, \%data);
        get_defun($fh, \%data);
        get_defmacro($fh, \%data);
        get_defadvice($fh, \%data);
        get_define_key($fh, \%data);
        get_defalias($fh, \%data);
        get_set_key($fh, \%data);
        get_key_chord($fh, \%data);
    }

    $fh->close;
    return \%data;
}

sub get_require ($fh, $data) {
    if ( /\(require '(.*)\)/ ) {
        $data->{require}{$1}{args} = "";
    }
}

sub get_provide ($fh, $data) {
    if ( /\(provide '(.*)\)/ ) {
        $data->{provide}{$1}{args} = "";
    }
}

sub get_defvar ($fh, $data) {
    if ( /^\(defvar ([\w-]+)/ ) {
        my $name = $1;
        get_doc($fh, $data->{defvar}{$name}{doc} = []);
    }
}

sub get_defun ($fh, $data) {
    if ( /^\(defun ([\w-]+) (\(.*\))/ ) {
        my @tmp;
        my $name = $1;
        my $args = $2;
        local $_; # so get_doc can use same pointer

        get_doc($fh, \@tmp);

        if (/\(interactive/) {
            $data->{command}{$name}{args} = $args;
            $data->{command}{$name}{doc} = \@tmp;
        } else {
            $data->{defun}{$name}{args} = $args;
            $data->{defun}{$name}{doc} = \@tmp;
        }
    }
}

sub get_doc ($fh, $data) {
    while ( $_ = <$fh>, /^ *\"/ .. /\"$/ ) {
        push @{$data}, "$_";
    }
    #TODO: don't return $_
    return $_;
}

sub get_define_key ($fh, $data) {
    if ( /\(define-key map \(kbd (.*)\) \'(.*)\)/ ) {
        $data->{define_key}{$2}{args} = "\t" . $1;
        $data->{define_key2}{$1}{args} = "\t" . $2;
   }
}

sub get_set_key ($fh, $data) {
    if ( /\(global-set-key \(kbd (.*)\) \'(.*)\)/ ) {
        $data->{set_key}{$2}{args} = "\t" . $1;
        $data->{set_key2}{$1}{args} = "\t" . $2;
   }
}

sub get_key_chord ($fh, $data) {
    if ( /\(key-chord-define-global (.*) \'(.*)\)/ ) {
        $data->{key_chord}{$2}{args} = "\t" . $1;
        $data->{key_chord2}{$1}{args} = "\t" . $2;
   }
}

sub get_defmacro ($fh, $data) {
    if ( /^\(defmacro ([\w-]+) (\(.*\))/ ) {
        my $name = $1;

        $data->{defmacro}{$name}{args} = $2;
        get_doc($fh, $data->{defmacro}{$name}{doc} = []);
   }
}

sub get_defgroup ($fh, $data) {
    if ( /^\(defgroup ([\w-]+) .*/ ) {
        my $name = $1;
        #print "$name\n";
        $data->{defgroup}{$name}{args} = "";
        get_doc($fh, $data->{defgroup}{$name}{doc} = []);
   }
}

sub get_defcustom ($fh, $data) {
    if ( /^\(defcustom ([\w-]+) .*/ ) {
        my $name = $1;
        #print "$name\n";
        $data->{defcustom}{$name}{args} = "";
        get_doc($fh, $data->{defcustom}{$name}{doc} = []);
   }
}

sub get_defadvice ($fh, $data) {
    if ( /^\(defadvice ([\w-]+) (\(.*\))/ ) {
        my $name = $1;

        $data->{defadvice}{$name}{args} = $2;
        get_doc($fh, $data->{defadvice}{$name}{doc} = []);
   }
}

sub get_defalias ($fh, $data) {
    if ( /^\(defalias \'([\w-]+) \'([\w-]+)\)$/ ) {
        my $name = $1;

        $data->{defalias}{$name}{args} = "\t" . $2;
    }
}

sub get_commentary ($fh, $data, $fn) {
    if ( /^\;\;\; Commentary:/ ) {
        local $_;
        my @tmp;

        push @tmp, "Commentary";
        while ( $_ = <$fh>, /^\;\;\;/ ) {
            print;
            push @tmp, "$_";
        }
        push @tmp, "\n";

        $data->{commentary}{$fn}{args} = "bob";
        $data->{commentary}{$fn}{doc} = \@tmp;
    }
}
