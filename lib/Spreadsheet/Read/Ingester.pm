package Spreadsheet::Read::Ingester ;

use strict;
use warnings;

use Storable;
use File::Spec;
use File::Signature;
use File::UserConfig;
use Spreadsheet::Read;

### Public methods ###

sub new {
  my $s    = shift;
  my $file = shift;
  my @args = @_;

  my $sig = '';
  eval { $sig  = File::Signature->new($file)->{digest} };

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
  my $age = shift // 30;

  my $configdir = File::UserConfig->new(dist => 'Spreadsheet-Read-Ingester')->configdir;

  opendir (DIR, $configdir) or die 'Could not open directory.';
  my @files = readdir (DIR);
  closedir (DIR);
  foreach my $file (@files) {
    $file = File::Spec->catfile($configdir, $file);
    unlink $file if -M $file >= $age;
  }
}

1; # Magic true value
# ABSTRACT: ingest spreadsheets to Perl data structure for faster, repeated processing

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

This module is a simple wrapper for L<Spreadsheet::Read> to make repeated
ingestion of raw data files faster.

Processing spreadsheet and csv from raw data files can be time consuming,
especially with large data sets. Sometimes it's necessary to ingest the raw data
file repeatedly. This module saves time be ingesting and parsing the data once
using L<Spreadsheet::Read> and then immediately saves the parsed data to
to the user's home directory with L<Storable>. Files are stored in the directory
determined by L<File::UserConfig>.

Subsequent ingestions of the original data file L<Spreadsheet::Read::Ingester>
are retrieved from the stored Perl data structure instead of the raw file.

L<Spreadsheet::Read::Ingester> generates a unique file signature for the file so
that if the original file changed, the data will be reingested from the raw file
instead and a new parsed file with a new signature will be saved.

To access the data from the stored files and newly ingested files using the
L<Spreadsheet::Read::Ingester> object, consult the L<Spreadsheet::Read>
documentation for the methods it provides.

=method new( $path_to_file )

  my $data = Spreadsheet::Read::Ingester->new('/path/to/file');

Takes same arguments as the new constructor in L<Spreadsheet::Read> module.
Returns an object identical to the object returned by the L<Spreadsheet::Read>
module along with its corresponding methods.

=method cleanup($days)
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
