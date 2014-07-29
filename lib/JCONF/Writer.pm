package JCONF::Writer;

use strict;
use Carp;
use B;
use JCONF::Writer::Error;

our $VERSION = '0.01';

sub new {
	my ($class, %opts) = @_;
	
	my $self = {
		autodie => delete $opts{autodie}
	};
	
	%opts and croak 'unrecognized options: ', join(', ', keys %opts);
	
	bless $self, $class;
}

sub _err {
	my ($self, $msg) = @_;
	 
	unless (defined $msg) {
			$self->{last_error} = undef;
			return;
	}
	 
	$self->{last_error} = JCONF::Writer::Error->new($msg);
	if ($self->{autodie}) {
		$self->{last_error}->throw();
	}
	
	return;
}

sub last_error {
	return $_[0]->{last_error};
}

sub from_hashref {
	my ($self, $ref) = @_;
	
	$self->_err(undef);
	
	if (ref $ref ne 'HASH') {
		return $self->_err('Root element should be reference to a HASH');
	}
	
	my $rv;
	
	while (my ($name, $value) = each %$ref) {
		unless ($name =~ /^\w+$/) {
			return $self->_err("Root key should be bareword, got `$name'");
		}
		
		$rv .= $name;
		$rv .= " = ";
		
		$self->_write(\$rv, $value, 0);
		
		$rv .= "\n";
	}
	
	return $rv;
}

sub _write {
	my ($self, $rv_ref, $value, $indents) = @_;
	
	$indents++;
	
	if (my $ref = ref $value) {
		if ($ref eq 'HASH') {
			return $self->_write_hash($rv_ref, $value, $indents);
		}
		
		if ($ref eq 'ARRAY') {
			return $self->_write_array($rv_ref, $value, $indents);
		}
		
		if ($ref eq 'Parse::JCONF::Boolean') {
			return $self->_write_boolean($rv_ref, $value);
		}
	}
	
	if (!defined $value) {
		return $self->_write_null($rv_ref);
	}
	
	if (B::svref_2object(\$value)->FLAGS & (B::SVp_IOK | B::SVp_NOK) && 0 + $value eq $value && $value * 0 == 0) {
		return $self->_write_number($rv_ref, $value);
	}
	
	$self->_write_string($rv_ref, $value);
}

sub _write_hash {
	my ($self, $rv_ref, $value, $indents) = @_;
	
	$$rv_ref .= "{\n";
	
	while (my ($k, $v) = each %$value) {
		$$rv_ref .= "\t"x$indents;
		$self->_write_string($rv_ref, $k);
		$$rv_ref .= ": ";
		$self->_write($rv_ref, $v, $indents);
		$$rv_ref .= ",\n";
	}
	
	$$rv_ref .= "\t"x($indents-1);
	$$rv_ref .= "}";
}

sub _write_array {
	my ($self, $rv_ref, $value, $indents) = @_;
	
	$$rv_ref .= "[\n";
	
	for my $v (@$value) {
		$$rv_ref .= "\t"x$indents;
		$self->_write($rv_ref, $v, $indents);
		$$rv_ref .= ",\n";
	}
	
	$$rv_ref .= "\t"x($indents-1);
	$$rv_ref .= "]"
}

sub _write_boolean {
	my ($self, $rv_ref, $value) = @_;
	$$rv_ref .= $value ? 'true' : 'false';
}

sub _write_null {
	my ($self, $rv_ref) = @_;
	$$rv_ref .= 'null';
}

sub _write_number {
	my ($self, $rv_ref, $value) = @_;
	$$rv_ref .= $value;
}

sub _write_string {
	my ($self, $rv_ref, $value) = @_;
	
	$value =~ s/\x5c/\x5c\x5c/g;
	$value =~ s/"/\x5c"/g;
	
	$$rv_ref .= '"' . $value . '"';
}

1;
