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

use Mojo::Util qw();


sub genNode($$$);
sub genObjectNodes($$$;$);

my %DECO = (
	'object' => '{}',
	'array' => '[]',
);

sub genObjectNodes($$$;$) {
	my($label,$kPayload,$prefix,$isTable) = @_;
	
	my $origPrefix = undef;
	if(defined($prefix) && length($prefix) > 0) {
		$origPrefix = $prefix;
		$prefix .= '.';
	} else {
		$origPrefix = $prefix = '';
	}
	
	# Avoiding special chars
	$origPrefix = Mojo::Util::md5_sum($origPrefix);
	
	my $origLabel = undef;
	#$label =~ s/([\[\]\{\}])/\\$1/g;
	if($kPayload->{'type'} eq 'object') {
		if(exists($kPayload->{'properties'})) {
			$origLabel = $label;
			if($isTable) {
				$label = <<TLABEL ;
<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0">
	<TR>
		<TD COLSPAN="2" ALIGN="CENTER"><FONT POINT-SIZE="20">$label</FONT></TD>
	</TR>
TLABEL
			} else {
				$label = "\t\t<TD ALIGN=\"LEFT\" PORT=\"$origPrefix\">$label</TD>\n\t\t<TD BORDER=\"0\"><TABLE BORDER=\"0\" CELLBORDER=\"1\" CELLSPACING=\"0\">\n";
			}
			
			my @ret = ();
			
			my $kP = $kPayload->{'properties'};
			foreach my $keyP (keys(%{$kP})) {
				push(@ret,genNode($keyP,$kP->{$keyP},$prefix));
			}
				
			$label .= "\t<TR>\n".join("\t</TR>\n\t<TR>\n",@ret)."\t</TR>\n";
			
			if($isTable) {
				$label .= "</TABLE>";
			} else {
				$label .= "</TABLE></TD>\n";
			}
		}
	}
	
	unless(defined($origLabel)) {
		#$label = "\t\t<TD COLSPAN=\"2\">$label</TD>\n";
		$label = undef;
	}
	
	return $label;
}

sub genNode($$$) {
	my($key,$kPayload,$prefix) = @_;
	
	my $val = $key;
	while(exists($kPayload->{'type'})) {
		$val .= $DECO{$kPayload->{'type'}}  if(exists($DECO{$kPayload->{'type'}}));
		$key .= '[]'  if($kPayload->{'type'} eq 'array');
		
		if($kPayload->{'type'} eq 'array') {
			if(exists($kPayload->{'items'})) {
				$kPayload = $kPayload->{'items'};
				next;
			}
		} elsif($kPayload->{'type'} eq 'object') {
			if(exists($kPayload->{'properties'})) {
				return genObjectNodes($val,$kPayload,$prefix.$key);
			}
		}
		
		last;
	}
	
	# Escaping
	#$val =~ s/([\[\]\{\}])/\\$1/g;
	
	my $toHeaderName = $prefix . $key;
	# Avoiding special chars
	$toHeaderName = Mojo::Util::md5_sum($toHeaderName);
	
	return "\t\t<TD COLSPAN=\"2\" ALIGN=\"LEFT\" PORT=\"$toHeaderName\">$val</TD>\n";
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
	node [shape=plaintext];

PRE
#	node [shape=record];
		my $sCounter = 0;
		my %sHash = ();
		
		# First pass
		foreach my $id (keys(%{$p_schemaHash})) {
			my $payload = $p_schemaHash->{$id};
			my $schema = $payload->[0];
			
			my $nodeId = 's' . $sCounter;
			
			my $headerName = $id;
			my $rSlash = rindex($headerName,'/');
			if($rSlash!=-1) {
				$headerName = substr($headerName,$rSlash + 1);
			}
			
			
			my $label = $headerName;
			
			if(exists($schema->{'properties'})) {
				$label = genObjectNodes($headerName,$schema,undef,1);
				
				if(defined($label)) {
					print $DOT "\t$nodeId \[label=<\n$label\n>\];\n";
					
					$sHash{$id} = $nodeId;
					$sCounter++;
				}
			}
		}
		
		# Second pass
		foreach my $id (keys(%{$p_schemaHash})) {
			my $payload = $p_schemaHash->{$id};
			my $fromNodeId = $sHash{$id};
			
			foreach my $p_FK (@{$payload->[3]}) {
				my $toHeaderName = $p_FK->[0];
				my $rSlash = rindex($toHeaderName,'/');
				if($rSlash!=-1) {
					$toHeaderName = substr($toHeaderName,$rSlash + 1);
				}
				
				my $toNodeId = $sHash{$p_FK->[0]};
				
				foreach my $port (@{$p_FK->[1]}) {
					my $mport = Mojo::Util::md5_sum($port);
					print $DOT "\t$fromNodeId:\"$mport\" -> $toNodeId;\n";
				}
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
