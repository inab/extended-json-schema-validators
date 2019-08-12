#!/usr/bin/perl

use warnings 'all';
use strict;

use File::Spec qw();
use FindBin;
# We cannot use local::lib because at this point we cannot be sure
# about having it installed
use lib File::Spec->catdir($FindBin::Bin,'deps','lib','perl5');

use lib File::Spec->catdir($FindBin::Bin,'lib');

use IO::Handle;
STDOUT->autoflush;
STDERR->autoflush;

use JSON::ExtendedValidator;

if(scalar(@ARGV) > 0) {
	my $jsonSchemaDir = shift(@ARGV);
	
	my $ev = JSON::ExtendedValidator->new();
	$ev->cacheJSONSchemas($jsonSchemaDir);
	my $numSchemas = $ev->loadCachedJSONSchemas();
	
	if(scalar(@ARGV) > 0) {
		if($numSchemas == 0) {
			print STDERR "FATAL ERROR: No schema was successfuly loaded. Exiting...\n";
			exit 1;
		}
		
		$ev->jsonValidate(@ARGV);
	}
} else {
	print STDERR "Usage: $0 {json_schema_directory} {json_file_or_directory}*\n";
	exit 1;
}
