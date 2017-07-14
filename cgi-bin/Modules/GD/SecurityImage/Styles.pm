package GD::SecurityImage::Styles;
use strict;
use vars qw[$VERSION];

$VERSION = '1.21';

sub style_default {
   $_[0]->_drcommon(" \ lines will be drawn ");
}

sub style_rect {
   $_[0]->_drcommon;
}

sub style_box {
   my $self = shift;
   my $n    = $self->{lines};
   my $ct   = $self->{_COLOR_}{text};
   my $cl   = $self->{_COLOR_}{lines};
   my $w    = $self->{width};
   my $h    = $self->{height};
   $self->filledRectangle(  0,  0, $w         , $h         , $ct );
   $self->filledRectangle( $n, $n, $w - $n - 1, $h - $n - 1, $cl );
}

sub style_circle {
   my $self  = shift;
   my $cx    = $self->{width}  / 2;
   my $cy    = $self->{height} / 2;
   my $n     = $self->{lines};
   my $cl    = $self->{_COLOR_}{lines};
   my $max   = int $self->{width} / $n;
      $max++;

   my( $i, $mi );
   for $i ( 1..$n ) {
      $mi = $max * $i;
      $self->arc( $cx, $cy, $mi, $mi, 0, 360, $cl );
   }
}

sub style_ellipse {
   my $self  = shift;
   return $self->style_default if $self->{DISABLED}{ellipse}; # GD < 2.07
   my $cx    = $self->{width}  / 2;
   my $cy    = $self->{height} / 2;
   my $n     = $self->{lines};
   my $cl    = $self->{_COLOR_}{lines};
   my $max   = int $self->{width} / $n;
      $max++;

   my( $i, $mi );
   for $i ( 1..$n ) {
      $mi = $max * $i;
      $self->ellipse( $cx, $cy, $mi * 2, $mi, $cl );
   }
}

sub style_ec {
   my $self = shift;
      $self->style_ellipse(@_) if not $self->{DISABLED}{ellipse}; # GD < 2.07
      $self->style_circle(@_);
}

sub style_blank {}

sub _drcommon {
   my $self  = shift;
   my $drawx = shift || 0;
   my $w     = $self->{width};
   my $h     = $self->{height};
   my $max   = $self->{lines};
   my $fx    = $w / $max;
   my $fy    = $h / $max;
   my $cl    = $self->{_COLOR_}{lines};

   my( $ifx );
   for my $i ( 0..$max ) {
      $ifx = $i * $fx;
      $self->line( $ifx, 0, $ifx      , $h, $cl ); # | line
      next if not $drawx;
      $self->line( $ifx, 0, $ifx + $fx, $h, $cl ); # \ line
   }

   my( $ify );
   for my $i ( 1..$max ) {
      $ify = $i * $fy;
      $self->line( 0, $ify, $w, $ify, $cl ); # - line
   }
}

1;
