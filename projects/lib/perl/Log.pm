## $Id: Log.pm,v 1.1 2007/03/06 00:35:06 tw Exp $

package Log;

use CGI::Carp;
use Fcntl qw(:DEFAULT :flock);

## Must turn off buffering.
$|=1;

%default = (
	mode => 'append',
	level => 'note',
	console => 0,
	file => 'perl-' . __PACKAGE__ . '.log',
	levels => [ qw{none error warning note info debug trace dump}  ],
	buffer_size => 1000,
	delimiters => 0,
);

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	bless ($self, $class);

	%{$self->{param}} = @_;
	for ( keys %default ) {
		$self->{param}->{$_} = $default{$_} unless defined $self->{param}->{$_};
	}
	
	for ( @{$self->{param}->{levels}} ) {
		$self->{level}->{$_} = $i++;
	}
	
	unlink $self->{param}->{file} if ( lc $self->{param}->{mode} eq 'overwrite' );
	
	$self->note( "################################ BEGIN LOG ################################" ) if $self->{param}->{delimiters};

	return $self;
}

sub isLogged {
	my $self = shift;
	my $level = shift;
	return 1 if ( $self->{level}->{$level} > $self->{level}->{ $self->{param}->{level} } );
	return undef;
}


sub setReport {
	my $self = shift; 
	my $curstate = $self->{param}->{level};
	my $newstate = shift;
	if ( $newstate ) {
		croak "$newstate not a valid logging level!\n" if ( defined $newstate and ! defined $self->{level}->{$newstate} );
		$self->{param}->{level} = $newstate;
	}
	return $curstate;
}


## doesn't seem to work
sub openlog {
	my $self = shift;
	return if defined $self->{fh};
	$level = shift; 
	croak "$level is not a vailid logging level!" unless defined $self->{level}->{$level};
	my $fh;
	if ( $self->{level}->{$level} > $self->{level}->{ $self->{param}->{level} } ) {
		open $fh, ">>/dev/null";
	}
	else {
		sysopen( $fh, $self->{param}->{file}, O_WRONLY | O_CREAT | O_APPEND) 
			or croak "Couldn't sysopen " . $self->{param}->{file} . ": $!\n";
		flock( $fh, LOCK_EX )
			or croak "Can't lock " . $self->{param}->{file} . ": $!\n";
		print $fh "[" . scalar localtime() . "] - ". uc( $level ) . ": ($$ - " . caller() . ")\t", 
			"Log opened by application.\n";
	}
	$self->{fh} = $fh;
	return $fh;
}

## doesn't seem to work
sub closelog {
	my $self = shift; 
	return if ! defined $self->{fh};
	my $fh = $self->{fh};
	print $fh "\nLog closed by application.\n"; 
	close $fh or croak "Couldn't close file!!\n";
	undef $self->{fh};
	return 1;
}

sub getBuffer {
	my $self = shift;
	if ( wantarray ) {
		my @result = @{$self->{buffer}};
		undef $self->{buffer};
		return @result;
	}
	else {
		return shift @{$self->{buffer}};
	}
		
}

## Called for the logging levels.
sub AUTOLOAD {
	return if $AUTOLOAD =~ /::DESTROY$/;
	my $meth = pop @{[ split '::', $AUTOLOAD ]};
	
	my $self = shift;
	
	croak "$meth is not a vailid logging level!" unless defined $self->{level}->{$meth};
		
	my @args = @_;
	chomp @args;
	
	## Don't do anything if this call is more detail than the specified reporting level
	return( wantarray ? @args : join "\n", @args ) if ( $self->{level}->{$meth} > $self->{level}->{ $self->{param}->{level} } );
	
	my $entry =  "[" . scalar localtime() . "] - ". uc( $meth ) . ": ($$ - " . caller() . ")\t" . join( "\n", @args );
	print STDERR $entry, "\n" if ($self->{param}->{console});
	
	sysopen( FILE,  $self->{param}->{file} , O_WRONLY | O_CREAT | O_APPEND)
		or croak "Couldn't sysopen " . $self->{param}->{file} . ": $!\n";
	flock( FILE, LOCK_EX )
		or croak "Can't lock " . $self->{param}->{file} . ": $!\n";
	print FILE $entry, "\n";
	
	close FILE;
	
	push @{$self->{buffer}}, $entry;
	shift @{$self->{buffer}} if scalar @{$self->{buffer}} > $self->{param}->{buffer_size};
	
	return wantarray ? @args : join "\n", @args;
}

sub DESTROY {
	my $self = shift; 
	$self->note( "################################# END LOG #################################\n\n" ) if $self->{param}->{delimiters};
}

1;
__END__

=head1 NAME

Log - provide an easy way to do multiple level, object oriented logging.

=head1 SYNOPSIS

This module provides a simple way to embed log statemets into an application that incorparate several distinct levels of logging, so that debugging can easily be accomplished by simply making a configuration change.

A quick example:

	#!/usr/bin/perl
	
	use Log;
	
	my $log = new Log (
		file => 'some/file.log',
		level => 'note',		## Will log this level and "above"
		console => '0',			## Print all log messages to STDERR if true.
	)
	
	##Log messages:
	
	$log->debug "some debug message";	## Not printed.
	
	$log->error "that's really bad!";	## Printed
		

=head1 DESCRIPTION

This module provides a (hopefully) complete way to handle logging in a moderately complex application. It is designed to have several levels of logging so that log statements can be sprikled throughout any application, or possibly across several modules. A desired level of logging can then be set so that logging can be increased or decreased without having to modify the code.

=head2 Constructor

	my $log = new Log( @parameters );

Valid parameters:

	file => filename	The file used for logging. If it doesn't exist, it will be created.
	level => string		The level at wich we are to begin logging. Often used as a command line parameter
	levels	=> qw/list/	An ordered list of values to use in conjuction with the 'level' parameter.
	console	=> [1/0]	Log to STDOUT if true.	
	buffer_size => int	How many log entries to keep in memory. Useful to introspect on what has already happened.
	delimiters => [1/0]	Use '### BEGIN LOG ###' messages if true.

=head2 Methods

=head3 isLogged('level')

Expects a scalar containing a valid logging level. Returns 1 if that level of logging is "on".

=head3 setReport('level')

Expects a scalar contatining a valid logging level. Sets the current level to the new one and returns the old level.

=head3 getBuffer()

If called in a list context, it will return a list with the entire contents of the buffer and clear the buffer.

If called in a scalar context, it will return a scalar containing the oldest entry in the buffer.

Be sure that this object is created with a large enough buffer size if you intend to use this feature, since the size of the buffer is checked with each write to the log. If the buffer would be too big, the oldest entry is removed to make room for the new one.

=head3 error('message')

=head3 warning('message')

=head3 note('message')

=head3 debug('message')

=head3 trace('message')

=head3 dump('message')

Call one of the above (or your own list defined in the 'levels' parameter) to write a message with the appropriate severity to the defined logging facility.

This is really a call to AUTOLOAD and checks to see what it should do based upon it's name. (If you don't know about this feature of perl, don't worry about it. Or, read the camel book.)

Returns the message that was logged for easy stringing.

=head1 EXAMPLE

First, look at the example above.

But my favorite way to use this is to initalize the important parameters from the command line.

	
	#!/bin/perl
	
	use Getopt::Std;
	use Log;
	
	getopts('cl:');  ## -c is boolean -l requires a level
	
	my $log = new Log( 
		level => $opt_l,
		console => $opt_c,
		file => 'some_file.log',
	);
	
	$log->note( "Starting my program!" );
	
	open FILE, data.file or die $log->error( "Couldn't open file: $!" );
	
	$log->debug( "About to do some stuff");
	## Do stuff;
	$log->info( "Did some stuff" );


=head1 AUTHOR

Tom Whipple <mail@tomwhipple.com>

=cut
	
