package SecImage;
### SibSoft.net, Aug 2007, Art Bogdanov ###
use strict;
use GD::SecurityImage;
use Digest::Perl::MD5 qw(md5_base64);
use XFileConfig;

### Configuration
my $images_path = "$c->{site_path}/captchas/";
my $images_url  = "$c->{site_url}/captchas/";

sub DeleteOldImages
{
   my ($dir) = @_;
   my @ff;
   opendir(DIR, $dir) || die "Can't opendir $dir: $!";
   @ff = readdir(DIR);
   closedir(DIR);
   foreach my $fn (@ff)
   {
      next if ($fn =~ /^\.+$/);
      my $ftime = (lstat("$dir/$fn"))[9];
      my $diff = time() - $ftime;
      unlink("$dir/$fn") if ($diff > 300);
   }
}


### Generate image and code

sub GenerateImage
{
 my $image = GD::SecurityImage->new(width   => 80,
                                    height  => 26,
                                    lines   => 3,
                                    rndmax  => 4,
                                    gd_font => 'giant'
                                   );
 $image->random();
 $image->create('normal', 'circle', [0,0,0], [100,100,100]);
 $image->particle(100);
 my ($image_data, undef, $random_number) = $image->out(force => 'png' , compress => 1);

 my @t = localtime();
 my $key = $t[5].$t[4].$t[3].$ENV{REMOTE_ADDR};
 $key=~s/\.//g;

 my $code = md5_base64( $random_number.$key );
 $code =~ s/[\/\+]//g;
 open(FILE,">$images_path/$code.png");
 print FILE $image_data;
 close FILE;
 my $image_url = $images_url.$code.'.png';
 return ($code,$image_url,$random_number);
}


### Check user number with code from hidden field

sub CheckCode
{
   my ($code,$number) = @_;
   &DeleteOldImages($images_path);

   my @t = localtime();
   my $key = $t[5].$t[4].$t[3].$ENV{REMOTE_ADDR};
   $key=~s/\.//g;

   my $code2 = md5_base64( $number.$key );
   $code2 =~ s/[\/\+]//g;
   if($code2 eq $code && -e "$images_path/$code.png") # OK
   {
      unlink("$images_path/$code.png");
      return 1;
   }
   elsif($code2 eq $code) # expired
   {
      unlink("$images_path/$code.png");
      return -1;
   }
   else
   {
      unlink("$images_path/$code.png");
      return -2; # Invalid
   }
}

1;
