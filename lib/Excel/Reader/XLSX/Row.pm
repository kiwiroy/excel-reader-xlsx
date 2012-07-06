package Excel::Reader::XLSX::Row;

###############################################################################
#
# Row - A class for reading Excel XLSX rows.
#
# Used in conjunction with Excel::Reader::XLSX
#
# Copyright 2012, John McNamara, jmcnamara@cpan.org
#
# Documentation after __END__
#

# perltidy with the following options: -mbl=2 -pt=0 -nola

use 5.008002;
use strict;
use warnings;
use Carp;
use XML::LibXML::Reader;
use Excel::Reader::XLSX::Cell;
use Excel::Reader::XLSX::Package::XMLreader;

our @ISA     = qw(Excel::Reader::XLSX::Package::XMLreader);
our $VERSION = '0.00';

our $FULL_DEPTH = 1;


###############################################################################
#
# new()
#
# Constructor.
#
sub new {

    my $class = shift;
    my $self  = Excel::Reader::XLSX::Package::XMLreader->new();

    $self->{_reader}         = shift;
    $self->{_shared_strings} = shift;
    $self->{_cell}           = shift;

    bless $self, $class;

    return $self;
}


###############################################################################
#
# _init()
#
# TODO.
#
sub _init {

    my $self = shift;

    $self->{_row_number}          = shift;
    $self->{_previous_row_number} = shift;
    $self->{_row_is_empty}        = $self->{_reader}->isEmptyElement();
    $self->{_values}              = undef;

    # TODO. Make the cell initialisation a lazy load.
    # Read the child cell nodes.
    my $row_node   = $self->{_reader}->copyCurrentNode( $FULL_DEPTH );
    my @cell_nodes = $row_node->getChildrenByTagName( 'c' );

    $self->{_cells}           = \@cell_nodes;
    $self->{_max_cell_index}  = scalar @cell_nodes;
    $self->{_next_cell_index} = 0;
}


###############################################################################
#
# next_cell()
#
# Get the cell cell in the current row.
#
sub next_cell {

    my $self = shift;
    my $cell;

    return if $self->{_row_is_empty};

    return if $self->{_next_cell_index} >= $self->{_max_cell_index};

    my $cell_node = $self->{_cells}->[ $self->{_next_cell_index} ];

    # Create or re-use (for efficiency) a Cell object.
    return unless $self->_node_populate_cell($cell_node, $self->{_cell});

    $self->{_next_cell_index}++;
    return $self->{_cell};
}


###############################################################################
#
# values()
#
# Return an array of values for a row. The range is from the first cell up
# to the last cell. Returns '' for empty cells.
#
sub values {

    my $self = shift;
    my @values;

    # The row values are cached to allow multiple calls. Return cached values
    # if present.
    if ( defined $self->{_values} ) {
        @values = @{ $self->{_values} };
    } else {

	# Other wise read the values for the cells in the row.
	
	## As is convention in Excel::Reader::XLSX create a reusable Cell object.
	my $cell = Excel::Reader::XLSX::Cell->new( $self->{_shared_strings} );
	
	# Store any cell values that exist.

	foreach my $cell_node(@{ $self->{_cells} }) {
	    if ($self->_node_populate_cell($cell_node, $cell)) {
		$values[$cell->col] = $cell->value || "";
	    }
	}

	# Convert any undef values to an empty strings by starting with a correctly sized array of such.
	for my $value ( @values ) {
	    $value = '' if !defined $value;
	}
	
	# Store the values to allow multiple calls return the same data.
	$self->{_values} = \@values;
    }

    return @values;
}

###############################################################################
#
# values_by_range($first_index, $last_index)
#
# Return an array of values for a row. The range is from the cell of the first 
# index specified or the first cell up to the cell of the second index specified
# or the last cell. Returns '' for empty cells.
#
sub values_by_range {

    my $self          = shift;
    my ($begin, $end) = @_;

    $begin ||= 0;
    $end   ||= $self->{_max_cell_index} - 1;

    # Get all the values to avoid "complex caching" index confusion.
    my @values = $self->values();
    
    # and now this function looks trivial...

    return @values[$begin .. $end];
}

###############################################################################
#
# row_number()
#
# Return the row number, zero-indexed.
#
sub row_number {

    my $self = shift;

    return $self->{_row_number};
}


###############################################################################
#
# previous_number()
#
# Return the zero-indexed row number of the previously found row. Returns -1
# if there was no previous number.
#
sub previous_number {

    my $self = shift;

    return $self->{_previous_row_number};
}


#
# Internal methods.
#

###############################################################################
#
# _range_to_rowcol($range)
#
# Convert an Excel A1 style ref to a zero indexed row and column.
#
sub _range_to_rowcol {

    my ( $col, $row ) = split /(\d+)/, shift;

    $row--;

    my $length = length $col;

    if ( $length == 1 ) {
        $col = -65 + ord( $col );
    }
    elsif ( $length == 2 ) {
        my @chars = split //, $col;
        $col = -1729 + ord( $chars[1] ) + 26 * ord( $chars[0] );
    }
    else {
        my @chars = split //, $col;
        $col =
          -44_993 +
          ord( $chars[2] ) +
          26 * ord( $chars[1] ) +
          676 * ord( $chars[0] );
    }

    return $row, $col;
}

###############################################################################
#
# _node_populate_cell($node, $cell)
#
# Populate Cell object from a node
#
sub _node_populate_cell {
    my ($self, $node, $cell) = @_;
    my $result = 0;
    my $range  = $node->getAttribute('r');
    return $result unless $range;

    $cell->_init();
    ( $cell->{_row}, $cell->{_col} ) = _range_to_rowcol($range);

    $cell->{_type} = $node->getAttribute('t') || '';
    $result        = 1;

    foreach my $child_node($node->childNodes) {
	my $node_name = $child_node->nodeName();
	
	if ( $node_name eq 'v' ) {
	    $cell->{_value}     = $child_node->textContent();
	    $cell->{_has_value} = 1;
	}
	
	if ( $node_name eq 'is' ) {
	    $cell->{_value}     = $child_node->textContent();
	    $cell->{_has_value} = 1;
	} elsif ( $node_name eq 'f' ) {
	    $cell->{_formula}     = $child_node->textContent();
	    $cell->{_has_formula} = 1;
	}
    }

    return $result;
}

1;


__END__

=pod

=head1 NAME

Row - A class for reading Excel XLSX rows.

=head1 SYNOPSIS

See the documentation for L<Excel::Reader::XLSX>.

=head1 DESCRIPTION

This module is used in conjunction with L<Excel::Reader::XLSX>.

=head1 AUTHOR

John McNamara jmcnamara@cpan.org

=head1 COPYRIGHT

Copyright MMXII, John McNamara.

All Rights Reserved. This module is free software. It may be used, redistributed and/or modified under the same terms as Perl itself.

=head1 LICENSE

Either the Perl Artistic Licence L<http://dev.perl.org/licenses/artistic.html> or the GPL L<http://www.opensource.org/licenses/gpl-license.php>.

=head1 DISCLAIMER OF WARRANTY

See the documentation for L<Excel::Reader::XLSX>.

=cut
