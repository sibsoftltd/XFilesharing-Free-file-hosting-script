package SecText;
### SibSoft.net, Aug 2007, Art Bogdanov ###
use strict;
use Digest::Perl::MD5 qw(md5_base64);

sub GenerateText
{
 my $random_number = join '', map int rand(10), 1..4;

 my @t = localtime();
 my $key = $t[5].$t[4].$t[3].$ENV{REMOTE_ADDR};
 $key=~s/\.//g;

 my $code = md5_base64( $random_number.$key );
 $code =~ s/[\/\+]//g;

 my @arr = split '', $random_number;
 my $i=0;
 @arr = map { {x=>(int(rand(5))+6+18*$i++), y =>2+int(rand(5)), char=>$_} } @arr;
 @arr = shuffle(@arr);

 my $itext = "<div style='width:80px;height:26px;font:bold 13px Arial;background:#ccc;text-align:left;'>";
 $itext.="<span style='position:absolute;padding-left:$_->{x}px;padding-top:$_->{y}px;'>$_->{char}</span>" for @arr;
 $itext.="</div>";

 return ($code,$itext,$random_number);
}

sub CheckCode
{
   my ($code,$number) = @_;

   my @t = localtime();
   my $key = $t[5].$t[4].$t[3].$ENV{REMOTE_ADDR};
   $key=~s/\.//g;

   my $code2 = md5_base64( $number.$key );
   $code2 =~ s/[\/\+]//g;
   if($code2 eq $code) # OK
   {
      return 1;
   }
   else
   {
      return -2; # Invalid
   }
}

sub shuffle (@) {
  my @a=\(@_);
  my $n;
  my $i=@_;
  map {
    $n = rand($i--);
    (${$a[$n]}, $a[$n] = $a[$i])[0];
  } @_;
}

1;
