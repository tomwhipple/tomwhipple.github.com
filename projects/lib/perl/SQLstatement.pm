package SQLstatement;

use Carp;
use Log;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	bless ($self, $class);

	my $in = shift; ## File path.
	
	my %param = @_;
	if ( defined $param{log} and $param{log}->isa('Log') ) {
		$self->{log} = $param{log};
		$param{log} = 0;
	}
	else {
		$self->{log} = new Log ( 
			report => 'none',
		);
	}
	
	open FILE, $in or croak $self->{log}->error( "Could not open $in for read: $!" );
	
	while ( <FILE> ) {
		## Uncomment if you have windoze file problems.
#		s/[\n\r]/ /g;
		if ( ! $statement && m|/\*--(\w+)--\*/| ) { 
			$statement = $1;
			$self->{statement}->{$statement} = '';
		}
		elsif ( $statement && m/(.*);/ ) {
			$self->{statement}->{$statement} .= $1;
			undef $statement;
		}
		elsif ( $statement && $_ ) {
			$self->{statement}->{$statement} .= $_;
		}
		else {
			## Skip
		}
	}
	
	close FILE;
	return $self;
}

sub AUTOLOAD {
	return if $AUTOLOAD =~ /::DESTROY$/;
	my $self = shift;
	
	my $meth = pop @{[ split '::', $AUTOLOAD ]};
	
	if ( defined $self->{statement}->{$meth} ) {
		$self->{log}->trace( "Statement '$meth' is:", $self->{statement}->{$meth} );
		return $self->{statement}->{$meth};
	}
	else {
		carp "WARNING: SQL statement $meth is not defined!";
		return undef;
	}
}

sub list {
	my $self = shift;
	return keys %{$self->{statement}};
}


1;
__END__

=head1 NAME

SQLstatement - Easily allow sql statements to be kept in files outside of perl code.

=head1 SYNOPSIS

In many situations, it is highly desireable to separate SQL from the perl code. This is especially 
true when the two code bases are maintained by separate people. 

SQLstatement allows SQL to be stored in a file that can be executed directly by your favorite SQL tool.

=head1 DESCRIPTION

SQL commands are available as methods, delimeted by SQL (c-style) comments. Methods are indicated as 

	/*--method_name--*/

where method_name contains no spaces. The SQL statement is terminated by a ';' character.

SQL methods should NOT be named 'new', 'list', or 'AUTOLOAD', though these are not explicitly checked.

=head1 EXAMPLE

First create some SQL file that has statements in the form of:

	/* comment ignored by SQLstatement */
	/*--the_date--*/
	SELECT sysdate FROM DUAL; 

Note the ';' at the end of each SQL statement. (sysdate and DUAL are specific to Oracle.)

Now use them:
	
	#!/usr/bin/perl
	
	use SQLstatement; 
	
	my $sql = new SQLstatement 'some/file.sql';

	my @methods = $sql->list
	
	print "Here is the statement I have:\n";
	print $sql->the_date, "\n";

=head1 AUTHOR

Tom Whipple <mail@tomwhipple.com>

=cut

