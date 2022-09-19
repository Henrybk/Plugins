package DrunkPath;

use strict;
use warnings;
use Log;
use Globals;
use Carp;

use Field;

sub new {
	my $class = shift;
	my $self = create();
	$self->reset(@_) if (@_);
	return $self;
}

sub reset {
	my $class = shift;
	my %args = @_;

	# Check arguments
	croak "Required arguments missing or wrong, specify correct 'field' or 'weight_map' and 'width' and 'height'\n"
	unless ($args{field} && UNIVERSAL::isa($args{field}, 'Field')) || ($args{weight_map} && $args{width} && $args{height});
	croak "Required argument 'start' missing\n" unless $args{start};
	croak "Required argument 'dest' missing\n" unless $args{dest};

	# Rebuild 'field' arg temporary here, to avoid that stupid bug, when weightMap not available
	if ($args{field} && UNIVERSAL::isa($args{field}, 'Field') && !$args{field}->{weightMap}) {
		$args{field}->loadByName($args{field}->name, 1);
	}

	# Default optional arguments
	my %hookArgs;
	$hookArgs{args} = \%args;
	$hookArgs{return} = 1;
	Plugins::callHook("DrunkPathReset", \%hookArgs);
	if ($hookArgs{return}) {
		$args{weight_map} = \($args{field}->{weightMap}) unless (defined $args{weight_map});
		$args{width} = $args{field}{width} unless (defined $args{width});
		$args{height} = $args{field}{height} unless (defined $args{height});
		$args{timeout} = 1500 unless (defined $args{timeout});
		$args{avoidWalls} = 1 unless (defined $args{avoidWalls});
		$args{min_x} = 0 unless (defined $args{min_x});
		$args{max_x} = ($args{width}-1) unless (defined $args{max_x});
		$args{min_y} = 0 unless (defined $args{min_y});
		$args{max_y} = ($args{height}-1) unless (defined $args{max_y});
		$args{drunkness} = $config{"drunk"} unless (defined $args{drunkness});
	}

	return $class->_reset(
		$args{weight_map}, 
		$args{avoidWalls}, 
		$args{width}, 
		$args{height},
		$args{start}{x}, 
		$args{start}{y},
		$args{dest}{x}, 
		$args{dest}{y},
		$args{timeout},
		$args{min_x},
		$args{max_x},
		$args{min_y},
		$args{max_y},
		$args{drunkness}
	);
}

1;