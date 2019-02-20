package Spreadsheet::Read::Ingester ;

use strict;
use warnings;

use Storable;
use File::Spec;
use File::Signature;
use File::UserConfig;
use Spreadsheet::Read 0.68;

### Public methods ###

sub new {
  my $s    = shift;
  my $file = shift;
  my @args = @_;

  my $sig = '';
  eval { $sig  = File::Signature->new($file)->{digest} };

  my %args = @args;
  my $suffix;
  foreach my $key (sort keys %args) {
    $suffix .= $key;
    $suffix .= $args{$key};
  }
  if ($suffix) {
    $sig .= "-$suffix";
  }
  my $configdir = File::UserConfig->new(dist => 'Spreadsheet-Read-Ingester')->configdir;
  my $parsed_file = File::Spec->catfile($configdir, $sig);

  my $data;

  # try to retrieve parsed data
  eval { $data = retrieve $parsed_file };

  # otherwise reingest from raw file
  if (!$data) {
    my $data = Spreadsheet::Read->new($file, @_);
    my $error = $data->[0]{error};
    die "Unable to read data from file: $file. Error: $error" if $data->[0]{error};
    store $data, $parsed_file;
  }

  return $data;
}

sub cleanup {
  my $s = shift;
  my $age = shift;

  if (!defined $age) {
    $age = 30;
  } elsif ($age eq '0') {
    $age = -1
  } elsif ($age !~ /^\d+$/) {
    warn 'cleanup method accepts only positive integer values or 0';
    return;
  }

  my $configdir = File::UserConfig->new(dist => 'Spreadsheet-Read-Ingester')->configdir;

  opendir (DIR, $configdir) or die 'Could not open directory.';
  my @files = readdir (DIR);
  closedir (DIR);
  foreach my $file (@files) {
    $file = File::Spec->catfile($configdir, $file);
    next if (-d $file);
    if (-M $file >= $age) {
      unlink $file or die 'Cannot remove file: $file';
    }
  }
}

1; # Magic true value
# ABSTRACT: ingest and save csv and spreadsheet data to a perl data structure to avoid reparsing

__END__

=head1 SYNOPSIS

  use Spreadsheet::Read::Ingester;

  # ingest raw file, store parsed data file, and return data object
  my $data = Spreadsheet::Read::Ingester->new('/path/to/file');

  # the returned data object has all the methods of a L<Spreadsheet::Read> object
  my $num_cols = $data->sheet(1)->maxcol;

  # delete old data files older than 30 days to save disk space
  Spreadsheet::Read::Ingester->cleanup;

=head1 DESCRIPTION

This module is intended to be a drop-in replacement for L<Spreadsheet::Read> and
is a simple, unobtrusive wrapper for it.

Parsing spreadsheet and csv data files is time consuming, especially with large
data sets. If a data file is ingested more than once, much time and processing
power is wasted reparsing the same data. To avoid reparsing, this module uses
L<Storable> to save a parsed version of the data to disk when a new file is
ingested. All subsequent ingestions are retrieved from the stored Perl data
structure. Files are saved in the directory determined by L<File::UserConfig>
and is a function of the user's OS.

The stored data file names are the unique file signatures for the raw data file.
The signature is used to detect if the original file changed, in which case the
data is reingested from the raw file and a new parsed file is saved using an
updated file signature. Arguments passed to the constructor are appended to the
name of the file to ensure different parse options are accounted for. Parsed
data files are kept indefinitely but can be deleted with the C<cleanup()>
method.

Consult the L<Spreadsheet::Read> documentation for accessing the data object
returned by this module.

=method new( $path_to_file )

  my $data = Spreadsheet::Read::Ingester->new('/path/to/file');

Takes same arguments as the new constructor in L<Spreadsheet::Read> module.
Returns an object identical to the object returned by the L<Spreadsheet::Read>
module along with its corresponding methods.

=method cleanup( $file_age_in_days )

=method cleanup()

  Spreadsheet::Read::Ingester->cleanup(0);

Deletes all stored files from the user's application data directory. Takes an
optional argument indicating the minimum number of days old the file must be
before it is deleted. Defaults to 30 days. Passing a value of 0 deletes all
files.

=head1 DEPENDENCIES

L<File::Spec>
L<File::Signature>
L<File::UserConfig>
L<Spreadsheet::Read>

=head1 SEE ALSO

L<Spreadsheet::Read>
