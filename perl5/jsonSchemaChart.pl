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



sub genNode($$);
sub genObjectNodes($$);

my %DECO = (
	'object' => '{}',
	'array' => '[]',
);

sub genObjectNodes($$) {
	my($label,$kPayload) = @_;
	
	$label =~ s/([\[\]\{\}])/\\$1/g;
	if($kPayload->{'type'} eq 'object') {
		if(exists($kPayload->{'properties'})) {
			my @ret = ($label);
			
			my $kP = $kPayload->{'properties'};
			foreach my $keyP (keys(%{$kP})) {
				push(@ret,genNode($keyP,$kP->{$keyP}));
			}
			
			return join('|',@ret);
		}
	}
	
	return $label;
}

sub genNode($$) {
	my($key,$kPayload) = @_;
	
	my $val = $key;
	while(exists($kPayload->{'type'})) {
		$val .= $DECO{$kPayload->{'type'}}  if(exists($DECO{$kPayload->{'type'}}));
		
		if($kPayload->{'type'} eq 'array') {
			if(exists($kPayload->{'items'})) {
				$kPayload = $kPayload->{'items'};
				next;
			}
		} elsif($kPayload->{'type'} eq 'object') {
			if(exists($kPayload->{'properties'})) {
				return '{'.genObjectNodes($val,$kPayload).'}';
			}
		}
		
		last;
	}
	
	# Escaping
	$val =~ s/([\[\]\{\}])/\\$1/g;
	
	return $val;
}


if(scalar(@ARGV) > 1) {
	my $outputFile = shift(@ARGV);
	
	my $ev = JSON::ExtendedValidator->new();
	$ev->cacheJSONSchemas(@ARGV);
	my $numSchemas = $ev->loadCachedJSONSchemas();
	
	if($numSchemas == 0) {
		print STDERR "FATAL ERROR: No schema was successfuly loaded. Exiting...\n";
		exit 1;
	}
	
	# Now it is time to draw the schemas themselves
	my $p_schemaHash = $ev->getValidSchemas();
	
	if(open(my $DOT,'>:encoding(UTF-8)',$outputFile)) {
		print $DOT <<PRE ;
digraph schemas {
	rankdir=LR;

	node [shape=record];
PRE
		my $sCounter = 0;
		my %sHash = ();
		
		# First pass
		while(my($id,$payload) = each(%{$p_schemaHash})) {
			my $schema = $payload->[0];
			
			my $nodeId = 's' . $sCounter;
			$sHash{$id} = $nodeId;
			
			my $headerName = $id;
			my $rSlash = rindex($headerName,'/');
			if($rSlash!=-1) {
				$headerName = substr($headerName,$rSlash + 1);
			}
			
			
			my $label = $headerName;
			
			if(exists($schema->{'properties'})) {
				$label = genObjectNodes($headerName,$schema);
			}
			
			print $DOT "\t$nodeId \[label=\"$label\"\];\n";
			
			$sCounter++;
		}
		
		# Second pass
		while(my($id,$payload) = each(%{$p_schemaHash})) {
			my $fromNodeId = $sHash{$id};
			
			foreach my $p_FK (@{$payload->[3]}) {
				my $toNodeId = $sHash{$p_FK->[0]};
				print $DOT "\t$fromNodeId -> $toNodeId;\n";
			}
		}
		
		print $DOT <<POST ;
}
POST
		
		close($DOT);
	} else {
		print STDERR "FATAL ERROR: Unable to create output file $outputFile\n";
		exit 2;
	}
} else {
	print STDERR "Usage: $0 {output_dot_file} {json_schema_directory_or_file}+\n";
	exit 1;
}
