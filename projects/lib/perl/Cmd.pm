## $Id: Cmd.pm,v 1.1 2007/03/06 00:35:06 tw Exp $

package Cmd;

use Log;

use Cwd;
use CGI::Carp;
use POSIX ":sys_wait_h";


#unless ( defined $log and $self->{log}->isa("Log") ) {
#	$log = new Log ( 
#		report => 'none',
#	);
#}

#$SIG{CHLD} = sub { $self->{log}->warning( "Unprocessd child signal!" ); };

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	bless ($self, $class);

	my %param = @_;
	$self->{fatal} = $param{fatal} || 1;
	
	if ( defined $param{log} and $param{log}->isa('Log') ) {
		$self->{log} = $param{log};
		$param{log} = 0;
	}
	else {
		$self->{log} = new Log ( 
			report => 'none',
		);
	}

	$self->{log}->trace( "Cmd module initialized. Logger connected." );

	if ( $param{'test_mode'} ) {
		$self->{log}->note( 'Cmd is in test mode. Commands will not actually be executed.' );
		$self->{test_mode} = 1; 
	}

	return $self;
}

sub errors {
	my $self = shift;
	my $arg = shift;
	return 0 unless defined @{$self->{errstr}};
	my @que = @{$self->{errstr}};
	undef @{$self->{errstr}} if lc $arg eq 'reset';
	return scalar @que unless wantarray;
	return @que;
}		
	
# private method.
sub throwerr {
	my $self = shift;
	push @{$self->{errstr}}, $self->{log}->error( @_ );
	croak join ' ', @_ if $self->{fatal};
	return undef;
}

sub execute {
	my $self = shift;
	return $self->throwerr( "My filehandle exists! Aborting." ) if defined $self->{fh};
	
	my $cmd = join ' ', @_;
	
	$self->{log}->debug( "Current directory is: " . getcwd );
	$self->{log}->info( "Doing command:\t'$cmd'" );
	
	return 2 if $self->{test_mode};
	
	my $fh;
	open $fh, "$cmd 2>&1 |" or return $self->throwerr( "Couldn't fork '$cmd': $!" );
	$self->{fh} = $fh;
	
	return 1;
}

sub result {
	my $self = shift;
	
	return if $self->{test_mode};

	unless ( defined $self->{fh} ) {
#		$self->throwerr( "No filehandle defined to get results from!" );
		$self->{log}->error( "No filehandle defined to get results from!" );
		return;
	}
	my $fh = $self->{fh};
	my @result = undef;
	if ( wantarray ) {
		## This bit will sit here and wait for the command to complete, then put everything into an array. Good for quick commands that don't return a ton of stuff.
		
		$self->{log}->trace( "All results:" );
		while ( <$fh> ) {
			chomp;
			push @result, $_;
			$self->{log}->info( "result line:\t$_" );
		}
		$self->{log}->dump( "RESULT ARRAY:", @result );
	} 
	else { 
		## Alternatively, we can return one line per function call. This is best for commands that take lots of time (you can do something else while you wait) or commands that return lots of stuff. (you don't exceed memory limits)
		
		## This is a loop so that it won't ever return undef while the command is running. You can do 'while ( $x = $s->result)'.
		do {
			if ( $resultstr = <$fh> ) {
				$self->{log}->info( "result line:\t$resultstr" );
				return $resultstr if defined wantarray;  ## This really means want scalar.
			}
		} while ( ! defined wantarray and $resultstr);
	}

	## The only way we can get here is if we hit an EOF.
	close $fh or do {
		$os_err = $!;
		$chld_err = $?;
	};
	$self->{exit_status} = $chld_err >> 8 and $self->{log}->note( "Exit status " . $self->{exit_status} );

	if ( $os_err ) {
		$self->throwerr( "System error closing pipe: $os_err\n" );
		return;
	}
	elsif ( $chld_err and ! $self->{exit_status} ) {
		$self->throwerr( "Wait status $chld_err from pipe!\n" );
		return;
	}
	undef $self->{fh};
	chomp @result;
	return @result; ## if @result is defined	
}

sub abort {
	my $self = shift;
	return unless defined $self->{fh};
	
	$self->{log}->note( "Aborting!" );
	
	
	close $fh or do {
		$os_err = $!;
		$chld_err = $?;
	};
	$self->{exit_status} = $chld_err >> 8 and $self->{log}->note( "Exit status " . $self->{exit_status} );

	if ( $os_err ) {
		$self->{log}->warning( "System error closing pipe during abort: $os_err\n" );
	}
	if ( $chld_err and ! $self->{exit_status} ) {
		$self->{log}->warning( "Wait status $chld_err from pipe!\n" );
	}
	undef $self->{fh};
	undef $self->{exit_status};
	return;
}	

sub discard {
	my $self = shift;
	return unless defined $self->{fh};
	
	$self->{log}->trace( "Discarding results!" );
	
	my $fh = $self->{fh};
	
	seek $fh, 0, 2; ## Go to the end of the filehandle
	return 1 if defined <$fh>; ## Return if the there is more "on the way". (not EOF)
	
	$self->{log}->trace( "Command complete - all results discarded." );
	
	close $fh or do {
		$os_err = $!;
		$chld_err = $?;
	};
	$self->{exit_status} = $chld_err >> 8 and $self->{log}->note( "Exit status " . $self->{exit_status} );

	if ( $os_err ) {
		$self->{log}->warning( "System error closing pipe during abort: $os_err\n" );
	}
	if ( $chld_err and ! $self->{exit_status} ) {
		$self->{log}->warning( "Wait status $chld_err from pipe!\n" );
	}
	undef $self->{fh};
	return;
}
	

sub exit_status {
	$self = shift;
	return $self->{exit_status};
}

sub doit {
	my $self = shift;
	$self->execute( @_ ); 
	$self->result;
	return 1 unless $self->{exit_status};
	$self->throwerr( "Bad exit code in doit!" );
}

1;
__END__

=head1 NAME

Cmd - easy way to do piped opening of a command.

=head1 SYNOPSIS

Cmd is designed to be an easy way to fork a shell script or other program and process its 
output as the command runs. 

A quick example:

	#!/usr/bin/perl

	use Cmd;
	my $sh = new Cmd;

	$sh->execute('bin/some_command -very_verbose');

	while ( $out_line = $sh->result ) { ## Note: This won't put result into $_ by default!
		# process the result
	}

=head1 DESCRIPTION

Cmd provides a way to process examine the output of a child shell WHILE IT IS RUNNING. This is desireable
if the child script taks a long time to run and produces a lot of output. Using the backquote operator it 
is theoretically possible to exhaust all of memory before the child script terminates. Cmd provides a workaround. 

=head2 Constructor arguments

	fatal => a true value will cause die to be called if the command returns a non-zero exit code

	log => a referance to a Log.pm object. Command results are logged at the 'info' level.

=head2 Methods

=head3 execute('cmd_string') 

Fork and execute the given command

=head3 result() 

This is where the command results are grabbed from the filehandle.
Return the top of the result que if called in a scalar context.
Return the whole result que if called in an array context.
Return undefined if the command has terminated.

=head3 abort() 

Closes the filehandle to the command. 

=head3 exit_status() 

Return the most recently executed command's exit status.

=head3 doit('cmd_string') 

Do the command without returning a result. Returns 1 if command exits with 0.

=head3 discard() 

Seek the end of the child's output buffer and resume processing there.


=head1 AUTHOR

Tom Whipple <mail@tomwhipple.com>

=cut

