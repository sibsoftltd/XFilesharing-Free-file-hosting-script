package GD::SecurityImage;
use strict;
use vars qw[@ISA $AUTOLOAD $VERSION $BACKEND];
use GD::SecurityImage::Styles;
use Carp qw(croak);

$VERSION = '1.64';

sub import {
   my $class   = shift;
   my %opt     = scalar(@_) % 2 ? () : (@_);
   # init/reset globals
   $BACKEND    = ''; # name of the back-end
   @ISA        = ();
   # load the drawing interface
   if ( exists $opt{use_magick} && $opt{use_magick} ) {
      require GD::SecurityImage::Magick;
      $BACKEND = 'Magick';
   }
   elsif ( exists $opt{backend} && $opt{backend} ) {
      my $be = __PACKAGE__.'::'.$opt{backend};
      eval "require $be";
      croak "Unable to locate the $class back-end $be: $@" if $@;
      $BACKEND = $opt{backend} eq 'AC' ? 'GD' : $opt{backend};
   }
   else {
      require GD::SecurityImage::GD;
      $BACKEND = 'GD';
   }
   push @ISA, 'GD::SecurityImage::' . $BACKEND;
   push @ISA, qw(GD::SecurityImage::Styles); # load styles
   return;
}

sub new {
   my $class = shift;
      $BACKEND || croak "You didn't import $class!";
   my %opt   = scalar @_ % 2 ? () : (@_);

   my $self  = {
      IS_MAGICK       => $BACKEND eq 'Magick',
      IS_GD           => $BACKEND eq 'GD',
      IS_CORE         => $BACKEND eq 'GD' || $BACKEND eq 'Magick',
      DISABLED        => {}, # list of methods that a backend (or some older version of backend) can't do
      MAGICK          => {}, # Image::Magick configuration options
      GDBOX_EMPTY     => 0,  # GD::SecurityImage::GD::insert_text() failed?
      _RANDOM_NUMBER_ => '', # random security code
      _RNDMAX_        => 6,  # maximum number of characters in a random string.
      _COLOR_         => {}, # text and line colors
      _CREATECALLED_  => 0,  # create() called? (check for particle())
      _TEXT_LOCATION_ => {}, # see info_text
   };
   bless $self, $class;

   my %options = (
      width      => $opt{width}               || 80,
      height     => $opt{height}              || 30,
      ptsize     => $opt{ptsize}              || 20,
      lines      => $opt{lines}               || 10,
      rndmax     => $opt{rndmax}              || $self->{_RNDMAX_},
      rnd_data   => $opt{rnd_data}            || [0..9],
      font       => $opt{font}                || '',
      gd_font    => $self->gdf($opt{gd_font}) || '',
      bgcolor    => $opt{bgcolor}             || [255, 255, 255],
      send_ctobg => $opt{send_ctobg}          || 0,
      frame      => defined($opt{frame}) ? $opt{frame} : 1,
      scramble   => $opt{scramble}            || 0,
      angle      => $opt{angle}               || 0,
      thickness  => $opt{thickness}           || 0,
      _ANGLES_   => [], # angle list for scrambled images
   );

   if($opt{text_location} && ref $opt{text_location} && ref $opt{text_location} eq 'HASH') {
      $self->{_TEXT_LOCATION_} = { %{$opt{text_location}}, _place_ => 1 };
   }
   else {
      $self->{_TEXT_LOCATION_}{_place_} = 0;
   }
   $self->{_RNDMAX_} = $options{rndmax}; 

   $self->{$_} = $options{$_} foreach keys %options;
   if($self->{angle}) { # validate angle
      $self->{angle} = 360 + $self->{angle} if $self->{angle} < 0;
      if($self->{angle} > 360) {
         croak "Angle parameter can take values in the range -360..360";
      }
   }

   if ($self->{scramble}) {
      if ($self->{angle}) {
         # Does the user want a fixed angle?
         push @{ $self->{_ANGLES_} }, $self->{angle};
      }
      else {
         # Generate angle range. The reason for hardcoding these is; 
         # it'll be less random for 0..60 range
         push @{ $self->{_ANGLES_} }, (0,5,8,15,22,26,29,33,35,36,40,43,45,53,56);
         push @{ $self->{_ANGLES_} }, map {360 - $_} @{ $self->{_ANGLES_} }; # push negatives
      }
   }

   $self->init;
   return $self;
}

sub backends {
   my $self  = shift;
   my $class = ref($self) || $self;
   my(@list, @dir_list);
   foreach my $inc (@INC) {
      my $dir = "$inc/GD/SecurityImage";
      next unless -d $dir;
      local  *DIR;
      opendir DIR, $dir or croak "opendir($dir) failed: $!";
      my @dir = readdir DIR;
      closedir DIR;
      push @dir_list, $dir;
      foreach my $file (@dir) {
         next if -d $file;
         next if $file =~ m[^\.];
         next if $file =~ m[^(Styles|AC|Handler)\.pm$];
         $file =~ s[\.pm$][];
         push @list, $file;
      }
   }
   if (defined wantarray) {
      return @list;
   }
   else {
      print "Available back-ends in $class v$VERSION are:\n\t"
            .join("\n\t", @list)
            ."\n\n"
            ."Search directories:\n\t"
            .join("\n\t", @dir_list);
   }
}

sub gdf {
   my $self = shift;
   return if not $self->{IS_GD};
   return $self->gdfx(@_);
}

sub random_angle {
   my $self   = shift;
   my @angles = @{ $self->{_ANGLES_} };
   my @r;
   push @r, $angles[int rand @angles] for 0..$#angles;
   return $r[int rand @r];
}

sub random_str { shift->{_RANDOM_NUMBER_} }

sub random {
   my $self = shift;
   my $user = shift;
   if($user and length($user) >= $self->{_RNDMAX_}) {
      $self->{_RANDOM_NUMBER_} = $user;
   }
   else {
      my @keys = @{ $self->{rnd_data} };
      my $lk   = scalar @keys;
      my $random;
         $random .= $keys[int rand $lk] for 1..$self->{rndmax};
         $self->{_RANDOM_NUMBER_} = $random;
   }
   return $self if defined wantarray;
}

sub cconvert { # convert color codes
   # GD           : return color index number
   # Image::Magick: return hex color code
   my $self   = shift;
   my $data   = shift || croak "Empty parameter passed to cconvert!";
   return $self->backend_cconvert($data) if not $self->{IS_CORE};

   my $is_hex    = $self->is_hex($data);
   my $magick_ok = $self->{IS_MAGICK} && $data && $is_hex;
   # data is a hex color code and Image::Magick has hex support
   return $data if $magick_ok;
   my $color_code = $data              &&
                    ! $is_hex          &&
                    ! ref($data)       &&
                    $data !~ m{[^0-9]} &&
                    $data >= 0;

   if( $color_code ) {
      if ( $self->{IS_MAGICK} ) {
         croak "The number '$data' can not be transformed to a color code!";
      }
      # data is a GD color index number ...
      # ... or it is any number! since there is no way to determine this. 
      # GD object' s rgb() method returns 0,0,0 upon failure...
      return $data;
   }

   my @rgb = $self->h2r($data);
   return $data if @rgb && $self->{IS_MAGICK};

   $data = [@rgb] if @rgb;
   # initialize if not valid
   if(not $data || not ref $data || ref $data ne 'ARRAY' || $#{$data} != 2) {
      $data = [0, 0, 0];
   }
   foreach my $i (0..$#{$data}) { # check for bad values
      if ($data->[$i] > 255 or $data->[$i] < 0) {
         $data->[$i] = 0;
      }
   }

   return $self->{IS_MAGICK} ? $self->r2h(@{$data}) # convert to hex
                             : $self->{image}->colorAllocate(@{$data});
}

sub create {
   my $self   = shift;
   my $method = shift || 'normal';  # ttf or normal
   my $style  = shift || 'default'; # default or rect or box
   my $col1   = shift || [ 0, 0, 0]; # text color
   my $col2   = shift || [ 0, 0, 0]; # line/box color

   $self->{send_ctobg} = 0 if $style eq 'box'; # disable for that style
   $self->{_COLOR_}    = { # set the color hash
        text  => $self->cconvert($col1),
        lines => $self->cconvert($col2),
   };

   # be a smart module and auto-disable ttf if we are under a prehistoric GD
   if ( not $self->{IS_MAGICK} ) {
      $method = 'normal' if $self->_versionlt(1.20);
   }

   if($method eq 'normal' and not $self->{gd_font}) {
      $self->{gd_font} = $self->gdf('giant');
   }

   $style = $self->can('style_'.$style) ? 'style_'.$style : 'style_default';

   $self->$style() if not $self->{send_ctobg};
   $self->insert_text($method);
   $self->$style() if     $self->{send_ctobg};

   if ( $self->{frame} ) {
      # put a frame around the image
      my $w = $self->{width}  - 1;
      my $h = $self->{height} - 1;
      $self->rectangle( 0, 0, $w, $h, $self->{_COLOR_}{lines} );
   }

   $self->{_CREATECALLED_}++;
   return $self if defined wantarray;
}

sub particle {
   # Create random dots. They'll cover all over the surface
   my $self = shift;
   croak "particle() must be called 'after' create()" if not $self->{_CREATECALLED_};
   my $big  = $self->{height} > $self->{width} ? $self->{height} : $self->{width};
   my $f    = shift || $big * 20; # particle density
   my $dots = shift || 1; # number of multiple dots
   my $int  = int $big / 20;

   my @random;
   for (my $x = $int; $x <= $big; $x += $int) {
      push @random, $x;
   }

   my $tc  = $self->{_COLOR_}{text};
   my $len = @random;
   my $r   = sub { $random[ int rand $len ] };
   my($x, $y, $z);

   for (1..$f) {
      $x = int rand $self->{width};
      $y = int rand $self->{height};
      foreach $z (1..$dots) {
         $self->setPixel($x + $z         , $y + $z         , $tc);
         $self->setPixel($x + $z + $r->(), $y + $z + $r->(), $tc);
      }
   }
   undef @random;
   undef $r;

   return $self if defined wantarray;
}

sub raw { $_[0]->{image} } # raw image object

sub info_text { # set text location
   my $self = shift;
   croak "info_text() must be called 'after' create()" if not $self->{_CREATECALLED_};
   my %o = scalar(@_) % 2 ? () : ( qw/ x right y up strip 1 /, @_ );
   return if not %o;

   $self->{_TEXT_LOCATION_}{_place_} = 1;
   $o{scolor}                        = $self->cconvert($o{scolor})       if $o{scolor};
   local $self->{_RANDOM_NUMBER_}    = delete $o{text}                   if $o{text};
   local $self->{_COLOR_}{text}      = $self->cconvert(delete $o{color}) if $o{color};
   local $self->{ptsize}             = delete $o{ptsize}                 if $o{ptsize};

   local $self->{scramble} = 0; # disable. we need a straight text
   local $self->{angle}    = 0; # disable. RT:14618

   $self->{_TEXT_LOCATION_}->{$_} = $o{$_} foreach keys %o;
   $self->insert_text('ttf');
   $self;
}

#--------------------[ PRIVATE ]--------------------#

sub add_strip { # adds a strip to the background of the text
   my $self = shift;
   my($x, $y, $box_w, $box_h) = @_;
   my $tl    = $self->{_TEXT_LOCATION_};
   my $c     = $self->{_COLOR_} || {};
   my $black = $self->cconvert( $c->{text}    ? $c->{text}    : [   0,   0,   0 ] );
   my $white = $self->cconvert( $tl->{scolor} ? $tl->{scolor} : [ 255, 255, 255 ] );
   my $x2    = $tl->{x} eq 'left' ? $box_w : $self->{width};
   my $y2    = $self->{height} - $box_h;
   my $i     = $self->{IS_MAGICK} ? $self  : $self->{image};
   my $up    = $tl->{y} eq 'up';
   my $h     = $self->{height};
   $i->filledRectangle($up ? ($x-1, 0, $x2, $y+1) : ($x-1, $y2-1, $x2  , $h  ), $black);
   $i->filledRectangle($up ? ($x  , 1, $x2-2, $y) : ($x  , $y2  , $x2-2, $h-2), $white);
   return;
}

sub r2h {
   # Convert RGB to Hex
   my $self = shift;
   @_ == 3 || return;
   my $color  = '#';
      $color .= sprintf("%02x", $_) foreach @_;
      $color;
}

sub h2r {
   # Convert Hex to RGB
   my $self  = shift;
   my $color = shift;
   return if ref $color;
   my @rgb   = $color =~ m[^#([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})$]i;
   return @rgb ? map { hex $_ } @rgb : undef;
}

sub is_hex {
   my $self = shift;
   my $data = shift;
   return $data =~ m[^#([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})$]i;
}

sub AUTOLOAD {
   my $self  = shift;
   my $class = ref $self;
   (my $name = $AUTOLOAD) =~ s,.*:,,;
   # fake method for GD compatibility. only GD has this
   return 0 if $name eq 'gdbox_empty';
   croak "Unknown $class method '$name'";
}

sub DESTROY {}

1;
