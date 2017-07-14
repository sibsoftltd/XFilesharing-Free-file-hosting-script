package Process;

use strict;
use HTML::Template;
use CGI qw(param cookie header);
use CGI::Cookie ();
use XFileConfig;
use DataBase;

sub new {
  my $class = shift;
  binmode(STDIN);
     $class = ref( $class ) || $class;
  my $self = {} ;
  bless $self, $class;
  
   $self->{user} = undef;
   $self->{cookies} = undef;
   $self->{form}   = undef;
   $self->initCGI();
   $self->{auth_cook}='xfss';
  
  return $self;
}


sub DESTROY{
  shift->UnInitDB();
}

sub initCGI{
  my $self= shift;
  my $in = CGI->new();
  my @vals=$in->param();
  my %f;
  my $isFHexist =0;

  for my $k(@vals)
  {
    my @val=$in->param($k);
    for(@val)
    {
       s/</&lt;/gs;
       s/>/&gt;/gs;
       s/"/&quot;/gs;
       s/\0//gs;
       s/\.\.\///gs;
    }
      if(@val>1){
         $f{$k}=\@val;
      }else{
         $f{$k}=$val[0];
      }
     $isFHexist=1 if (ref($val[0]) eq 'Fh');
   }
  
  my %cook;
  for my $k($in->cookie())
  {
    $cook{$k}=$in->cookie($k);
  }
  $self->{form} = \%f;
  $self->{cookies} = \%cook;
  $self->{cgi_query} = $in;
}

sub f
{
  my $self = shift;
  return $self->{form};
}

sub db
{
  my $self = shift;
  return $self->{db} if defined($self->{db});
  $self->{db} = DataBase->new();
  return $self->{db}; 
}

sub getCookie
{
  my ($self,$name) = @_;
  return $self->{cookies}->{ $name };
}

sub setCookie
{
   my ($self,$name,$value) = @_;
   $self->{cookies_send}->{ $name } = $value;
}

sub CreateTemplate
{
  my ($self,$filename)=@_;
  my $t=HTML::Template->new( filename => "$filename",
                             die_on_bad_params => 0,
                             loop_context_vars => 1,
                            );

  $t->param( 'site_name'  => $c->{site_name},
             'site_url'   => $c->{site_url},
             'site_cgi'   => $c->{site_cgi},
             'abuse_email'=> $c->{abuse_email},
             'msg'        => $self->f->{msg},
           );

  return $t;
}


sub PrintTemplate
{
  my ($self,$template) = @_;

  my $t=$self->CreateTemplate( "Templates/main.html" );
  my $t2=$self->CreateTemplate( "Templates/$template" );
  if(@_){ $t2->param(@_); }
  $t->param( 'tmpl' => $t2->output );

  my @Cookies;
  foreach my $name (keys %{ $self->{cookies_send} })
  {
    my $c =  CGI::Cookie->new( -name    => $name,
                               -value   => $self->{cookies_send}->{$name},
                             );
    push(@Cookies, $c);
  }
  print header(-cookie=> [@Cookies] ,
               -type  => 'text/html');
  print output($t->output);
  exit;
}


sub message
{
    my ($self,$err) = @_;
    return unless $err;
    $self->PrintTemplate("message.html", 'err'=>$err );
}

sub redirect
{
   my ($self,$url) = @_;

   my @Cookies;
   foreach my $k (keys %{ $self->{cookies_send} })
   {
     push @Cookies, CGI::Cookie->new( -name    => $k, 
                                      -value   => $self->{cookies_send}->{$k}, 
                                      -expires => '+3M'
                                    );
   }

   print $self->{cgi_query}->redirect( -uri    => $url, 
                                       -cookie => [@Cookies],
                                     );
   exit;
}

sub getIP{return $ENV{HTTP_X_FORWARDED_FOR} || $ENV{REMOTE_ADDR};}
sub output{my $x=shift;$x=~s/\x3c\x2f\x62\x6f\x64\x79\x3e/\x3c\x62\x72\x3e\x3c\x43\x65\x6e\x74\x65\x72\x3e\x3c\x61\x20\x68\x72\x65\x66\x3d\x22\x68\x74\x74\x70\x3a\x2f\x2f\x73\x69\x62\x73\x6f\x66\x74\x2e\x6e\x65\x74\x2f\x78\x66\x69\x6c\x65\x73\x68\x61\x72\x69\x6e\x67\x2e\x68\x74\x6d\x6c\x22\x20\x73\x74\x79\x6c\x65\x3d\x22\x63\x6f\x6c\x6f\x72\x3a\x23\x39\x39\x39\x3b\x74\x65\x78\x74\x2d\x64\x65\x63\x6f\x72\x61\x74\x69\x6f\x6e\x3a\x6e\x6f\x6e\x65\x3b\x66\x6f\x6e\x74\x2d\x73\x69\x7a\x65\x3a\x31\x31\x70\x78\x3b\x22\x3e\x50\x6f\x77\x65\x72\x65\x64\x20\x62\x79\x20\x58\x46\x69\x6c\x65\x53\x68\x61\x72\x69\x6e\x67\x3c\x2f\x61\x3e\x3c\x2f\x43\x65\x6e\x74\x65\x72\x3e\x3c\x2f\x62\x6f\x64\x79\x3e/i;return $x;}
sub randchar{my $self = shift;my @range = ('0'..'9','A'..'Z');my $x = int scalar @range;join '', map $range[rand $x], 1..shift||1;}
sub SecureStr
{
   my ($self,$str)=@_;
   $str=~s/</&lt;/gs;
   $str=~s/>/&gt;/gs;
   $str=~s/"/&quote;/gs;
   #$str=~s/\&/&#38;/gs;
   return $str;
}

1;
