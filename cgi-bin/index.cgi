#!/usr/bin/perl
### SibSoft.net, Jan 2008, Art Bogdanov ###
use strict;
use CGI::Carp qw(fatalsToBrowser);
use lib '.';
use XFileConfig;
use Process;
use HTML::Template;  
use CGI qw/:standard/;
use Digest::Perl::MD5 qw(md5_base64);

my $ses = Process->new();
my $f = $ses->f;
my $db= $ses->db;

my $IP = $ENV{HTTP_X_FORWARDED_FOR} || $ENV{REMOTE_ADDR};
$c->{ip_allowed}=~s/\./\\./g;
$c->{ip_not_allowed}=~s/\./\\./g;
$ses->message("Your IP was banned by administrator") if ($c->{ip_allowed} && $IP!~/$c->{ip_allowed}/) || ($c->{ip_not_allowed} && $IP=~/$c->{ip_not_allowed}/);

my $act = $f->{act};
&UploadResult if $act eq 'upload_result';
&Download1    if $act eq 'download1';
&Download2    if $act eq 'download2';
&Page         if $act eq 'page';
&ContactSend  if $act eq 'contact_send';
&DelFile      if $f->{del};
&AdminScreen   if $act eq 'admin';
&AdminSettings if $act eq 'admin_settings';
&UploadForm;


sub UploadForm
{
   my ($site_cgi_rel) = $c->{site_cgi}=~/^http:\/\/.+?(\/.+)/i;

   $ses->PrintTemplate("upload_form.html",
                       'ext_allowed'      => $c->{ext_allowed},
                       'ext_not_allowed'  => $c->{ext_not_allowed},
                       'max_upload_files' => $c->{max_upload_files},
                       'max_upload_size'  => $c->{max_upload_size},
                       'enable_file_descr'=> $c->{enable_file_descr},
                       'site_cgi_rel'     => $site_cgi_rel,
                      );
}

sub UploadResult
{
   my $fnames      = &ARef($f->{'filename'});
   my $dids        = &ARef($f->{'del_id'});
   my $fnames_orig = &ARef($f->{'filename_original'});
   my $size        = &ARef($f->{'size'});
   my $descr       = &ARef($f->{'description'});
   my $status      = &ARef($f->{'status'});
   my @arr;
   for(my $i=0;$i<=$#$fnames;$i++)
   {
      $size->[$i] = $size->[$i]<1048576 ? sprintf("%.01f Kb",$size->[$i]/1024) : sprintf("%.01f Mb",$size->[$i]/1048576);
      $descr->[$i]=~s/</&lt;/gs;
      $descr->[$i]=~s/>/&gt;/gs;
      $descr->[$i]=~s/"/&quote;/gs;
      push @arr, {'id'        => $fnames->[$i],
                  'del_id'    => $dids->[$i],
                  'filename'  => $fnames_orig->[$i],
                  'size'      => $size->[$i],
                  'descr'     => $descr->[$i],
                  'site_url'  => $c->{site_url},
                  'status'    => $status->[$i],
                  "status_$status->[$i]"=>1,
                 };
   }

   $ses->PrintTemplate("upload_results.html",
                       'links' => \@arr,
                      );
}

sub Download1
{
   my $file = $db->SelectRow("SELECT * FROM Files WHERE file_code=?",$f->{id});
   $ses->message("No such file") unless $file;
   my $dx = sprintf("%05d",$file->{file_id}/$c->{files_per_folder});
   $ses->message("No file found on server! Please contact administrator.") unless -e "$c->{target_dir}/$dx/$file->{file_code}";

   my ($fname) = $ENV{QUERY_STRING}=~/&fname=(.+)$/;
   $fname||=$f->{fname};
   $fname=~s/\.html?$//i;
   $ses->message("No file with this filename found") unless $fname eq $file->{file_name};

   my %captcha = &GenerateCaptcha;
   my $rand = $ses->randchar(5);
   &SecSave( $file->{file_id}, $ses->getIP(), $captcha{number}, $rand );
   
   $file->{file_size} = $file->{file_size}<1048576 ? sprintf("%.01f Kb",$file->{file_size}/1024) : sprintf("%.01f Mb",$file->{file_size}/1048576);
   $ses->message("Sorry but this file reached max downloads limit") if $c->{max_downloads_number} && $file->{file_downloads} >= $c->{max_downloads_number};

   $ses->PrintTemplate("download.html",
                       'id'        => $f->{id}, 
                       'fname'     => $fname, 
                       'fsize'     => $file->{file_size},
                       'descr'     => $file->{file_descr},
                       'downloads' => $file->{file_downloads},
                       'created'   => $file->{file_created},
                       'msg'       => $f->{msg},
                       'site_name' => $c->{site_name},
                       'pass_required' => $file->{file_password} && 1,
                       'countdown' => $c->{download_countdown},
                       'rand'      => $rand,
                       %captcha,
                      );
}

sub Download2
{
   &UploadForm unless $ENV{REQUEST_METHOD} eq 'POST';

   my $file = $db->SelectRow("SELECT * FROM Files WHERE file_code=?",$f->{id});
   $ses->message("No such file") unless $file;
   my $fname = $f->{fname};
   $ses->message("No file with this filename found") unless $fname eq $file->{file_name};

   my $dx = sprintf("%05d",$file->{file_id}/$c->{files_per_folder});
   $ses->message("No file found on server! Please contact administrator.") unless -e "$c->{target_dir}/$dx/$file->{file_code}";
   
   &Download1 unless &SecCheck( $file->{file_id}, $ses->getIP(), $f->{'rand'}, $f->{code} );

   $ses->message("Sorry but this file reached max downloads limit") if $c->{max_downloads_number} && $file->{downloads} >= $c->{max_downloads_number};

   if($file->{file_password} && $file->{file_password} ne $f->{password})
   {
      $f->{msg} = 'Wrong password';
      sleep 2;
      &Download1;
   }

   $db->Exec("UPDATE Files SET file_downloads=file_downloads+1 WHERE file_id=?",$file->{file_id});

   #Start Download
   my $fsize = -s "$c->{target_dir}/$dx/$f->{id}";
   $|++;
   open(my $in_fh,"$c->{target_dir}/$dx/$f->{id}") || die"Can't open source file";
   my $buf;
   print"Content-Type: application/force-download\n";
   print qq{Content-Disposition: attachment; filename="$fname"\n};
   print"Content-length: $fsize\n\n";
   while( read($in_fh,$buf,4096) )
   {
      print $buf;
      select(undef, undef, undef,0.006);
   }
   exit;
}

sub Page
{
   my $tmpl = shift || $f->{tmpl};
   &UploadForm unless -e "Templates/Pages/$tmpl.html";
   if($tmpl eq 'contact')
   {
      my %captcha = &GenerateCaptcha;
      my $rand = $ses->randchar(5);
      &SecSave( 0, $ses->getIP(), $captcha{number}, $rand );
      $ses->PrintTemplate("Pages/$tmpl.html",
                          %{$f},
                          %captcha,
                          'rand' => $rand,
                         );
   }
   $ses->PrintTemplate("Pages/$tmpl.html");
}

sub ContactSend
{
   &Page('contact') unless $ENV{REQUEST_METHOD} eq 'POST';

   &Page('contact') unless &SecCheck( 0, $ses->getIP(), $f->{'rand'}, $f->{code} );

   $f->{msg}.="Email is not valid. " unless $f->{email} =~ /.+\@.+\..+/;
   $f->{msg}.="Subject required. " unless $f->{subject};
   $f->{msg}.="Message required. " unless $f->{message};

   $f->{message} = $ses->SecureStr($f->{message});
   $f->{subject} = $ses->SecureStr($f->{subject});
   $f->{email} = $ses->SecureStr($f->{email});
   $f->{name} = $ses->SecureStr($f->{name});

   $f->{subject}=~s/[\n\r"]+//g;

   &Page('contact') if $f->{msg};
   $f->{subject} = "$c->{site_name}: $f->{subject}";
   $f->{message} = "You've got message from $f->{name} ($f->{email}) on $c->{site_name} site:\n\n$f->{message}";

   &SendMail($c->{contact_email}, $c->{confirm_email_from}, $f->{subject}, $f->{message});
   $f->{msg} = 'Message sent successfully';
   &UploadForm;
}

sub DelFile
{
   my $str = $f->{del};
   my ($id,$del_id) = split('-',$str);

   my $file = $db->SelectRow("SELECT * FROM Files WHERE file_code=?",$id);
   $ses->message("No such file") unless $file;
   my $dx = sprintf("%05d",$file->{file_id}/$c->{files_per_folder});
   unless($file->{file_del_id} eq $del_id)
   {
      sleep 2;
      $ses->PrintTemplate("delete_file.html", 'error'=>'Wrong delete ID' );
   }
   if($f->{confirm} eq 'yes')
   {
      unlink("$c->{target_dir}/$dx/$id");
      $db->Exec("DELETE FROM Files WHERE file_code=? AND file_del_id=?",$id,$del_id);
      $ses->PrintTemplate("delete_file.html", 'status'=>'File was deleted successfully' );
   }
   else
   {
      $ses->PrintTemplate("delete_file.html",
                          'confirm' =>1,
                          'id'      => $id,
                          'del_id'  => $del_id,
                          'fname'   => $file->{file_name},
                         );
   }
}

sub SecSave
{
   my ($file_id,$ip,$captcha,$rand) = @_;
   $db->Exec("REPLACE INTO Secure (file_id,ip,rand,captcha,time) VALUES (?,INET_ATON(?),?,?,NOW()+INTERVAL ? SECOND)",$file_id,$ip,$rand,$captcha,$c->{download_countdown});
}

sub SecCheck
{
   my ($file_id,$ip,$rand,$captcha) = @_;

   $db->Exec("DELETE FROM Secure WHERE time<NOW() - INTERVAL 1 HOUR"); #remove expired d-sessions
   my $s = $db->SelectRow("SELECT *, UNIX_TIMESTAMP()-UNIX_TIMESTAMP(time) as dt 
                           FROM Secure 
                           WHERE file_id=? AND ip=INET_ATON(?) AND rand=?",$file_id,$ip,$rand);
   $db->Exec("DELETE FROM Secure WHERE file_id=? AND ip=INET_ATON(?) AND rand=?",$file_id,$ip,$rand);
   unlink("$c->{site_path}/captchas/$f->{sc}.png") if $s->{captcha} && -f "$c->{site_path}/captchas/$f->{sc}.png" && $f->{sc}=~/^\w+$/i;
   #unless(defined $s->{file_id}){$f->{msg}="Download session expired";return 0;}
   if($s->{captcha} && $s->{captcha} ne $captcha){sleep 2;$f->{msg}="Wrong captcha";return;}
   #if($s->{dt}<0 && $f->{op}=~/download/i){$f->{msg}="Skipped countdown";return;}
   if($f->{act}=~/download/i)
   {
      unless(defined $s->{file_id}){$f->{msg}="Download session expired";return 0;}
      if($s->{dt}<0){$f->{msg}="Skipped countdown";return 0;}
   }


   ##Clean old captchas here
   if($c->{use_captcha})
   {
      opendir(DIR, "$c->{site_path}/captchas");
      foreach (readdir(DIR))
      {
         next if /^\.{1,2}$/;
         my $file = "$c->{site_path}/captchas/$_";
         unlink($file) if (time -(lstat($file))[9]) > 3600;
      }
      closedir DIR;
   }

   return 1;
}

sub GenerateCaptcha
{
   my ($sc,$iurl,$itext,$number);
   if($c->{use_captcha}==1)
   {
      eval {require SecImage;};
      ($sc,$iurl,$number) = &SecImage::GenerateImage unless $@;
   }
   elsif($c->{use_captcha}==2)
   {
      require SecText;
      ($sc,$itext,$number) = &SecText::GenerateText;
   }

   return ('sc' => $sc, 'iurl' => $iurl, 'itext' => $itext, 'number' => $number);
}

sub AdminScreen
{
   &UploadForm if $f->{password} && $ENV{REQUEST_METHOD} ne 'POST';
   if($f->{password})
   {
     $ses->setCookie('admhash',md5_base64($f->{password})) if $f->{password} eq $c->{admin_password};
     $ses->redirect('?act=admin');
   }
   if($f->{logout})
   {
       $ses->setCookie('admhash','');
       $ses->redirect("$c->{site_url}/?act=admin");
   }
   $ses->PrintTemplate("admin.html") if $ses->{cookies}->{admhash} ne md5_base64($c->{admin_password});

   if($f->{admdel})
   {
      my $id = $f->{admdel};
      my $file = $db->SelectRow("SELECT * FROM Files WHERE file_code=?",$id);
      $ses->message("No such file") unless $file;
      my $dx = sprintf("%05d",$file->{file_id}/$c->{files_per_folder});
      unlink("$c->{target_dir}/$dx/$id");
      $db->Exec("DELETE FROM Files WHERE file_code=?",$id);
      print $ses->redirect("$c->{site_url}/?act=admin");
      exit;
   }

   $f->{sort_field}||='file_created';
   $f->{sort_order}||='down';
   $f->{per_page}||=10;
   my $filter_key = "AND file_name LIKE '%$f->{key}%'" if $f->{key}=~/^[\w\s\-\!\.\,\'\&\(\)\[\]]+$/;
   my $filter_size = "AND file_sizw > 1048576*$f->{max_size}" if $f->{max_size}=~/^\d+$/;
   my $files = &ARef( $db->Select("SELECT *, file_downloads*file_size as traffic,
                                          INET_NTOA(file_ip) as file_ip
                                   FROM Files 
                                   WHERE 1
                                   $filter_key
                                   $filter_size
                                   ".&makeSortSQLcode($f,'file_created').&makePagingSQLSuffix($f->{page},$f->{per_page}) ) );
   my $totals = $db->SelectRow("SELECT COUNT(*) as total_count, 
                                SUM(file_size)/1048576 as total_size,
                                SUM(file_downloads) as total_downloads,
                                SUM(file_downloads*file_size)/1048576 as total_traffic
                                FROM Files WHERE 1 $filter_key $filter_size");

   for(@$files)
   {
      $_->{site_url} = $c->{site_url};
      $_->{file_name2} = $_->{file_name};
      $_->{file_name2}=~s/['"]//g;
      $_->{file_size2} = sprintf("%.02f Mb",$_->{file_size}/1048576);
      $_->{traffic}    = sprintf("%.01f Mb",$_->{traffic}/1048576);
   }
   my %sort_hash = &makeSortHash($f,['file_name','file_downloads','file_size','traffic','file_created']);
   
   $ses->PrintTemplate("admin.html",
                  'signed' => 1,
                  'files'  => $files,
                  %{$totals},
                  'key'    => $f->{key},
                  "per_$f->{per_page}" => ' checked',
                  %sort_hash,
                  'paging' => &makePagingLinks($f,$totals->{total_count}),
                 );
}

sub AdminSettings
{
   my $passcook = $ses->{cookies}->{admhash};
   &AdminScreen if !$passcook || $passcook ne md5_base64($c->{admin_password});
   if($f->{save})
   {
      my @fields = qw(site_name
                      files_expire_created
                      files_expire_access
                      max_upload_files
                      max_upload_size
                      max_upload_filesize
                      max_downloads_number
                      enable_file_descr
                      ext_allowed
                      ext_not_allowed
                      ip_allowed
                      ip_not_allowed
                      use_captcha
                      confirm_email
                      confirm_email_from
                      contact_email
                      abuse_email
                      download_countdown
                     );
      my $conf;
      open(F,"XFileConfig.pm")||$ses->message("Can't read XFileConfig");
      $conf.=$_ while <F>;
      close F;

      for my $x (@fields)
      {
         my $val = $f->{$x};
         if($x=~/(ip_allowed|ip_not_allowed)/)
         {
            $val=~s/\r//gs;
            $val=~s/\n/|/gs;
            $val=~s/\*/\\d+/gs;
            $val="^($val)\$" if $val;
         }
         $conf=~s/$x\s*=>\s*(\S+)\s*,/"$x => '$val',"/e;
      }
      open(F,">XFileConfig.pm")||$ses->message("Can't write XFileConfig");
      print F $conf;
      close F;
      print $ses->redirect('?act=admin_settings');
   }

   $c->{ip_allowed}=~s/[\^\(\)\$\\]//g;
   $c->{ip_allowed}=~s/\|/\n/g;
   $c->{ip_allowed}=~s/d\+/*/g;
   $c->{ip_not_allowed}=~s/[\^\(\)\$\\]//g;
   $c->{ip_not_allowed}=~s/\|/\n/g;
   $c->{ip_not_allowed}=~s/d\+/*/g;

   #push @{$f->{cookies}}, cookie(-name=>'admhash',-value=>$passcook,-expire=>'+30m');
   $ses->PrintTemplate("admin_settings.html",
                       %{$c},
                       "captcha_$c->{use_captcha}" => ' checked',
                      );
}

###
sub ARef
{
  my $data=shift;
  $data=[] unless $data;
  $data=[$data] unless ref($data) eq 'ARRAY';
  return $data;
}

sub getTime
{
    my ($t) = @_;
    my @t = $t ? localtime($t) : localtime();
    return ( sprintf("%04d",$t[5]+1900),
             sprintf("%02d",$t[4]+1), 
             sprintf("%02d",$t[3]), 
             sprintf("%02d",$t[2]), 
             sprintf("%02d",$t[1]), 
             sprintf("%02d",$t[0]) 
           );
}

sub SendMail
{
my ($mail_to, $mail_from, $subject, $body) = @_;  
  
open (OUTMAIL,"|".$c->{sendmail_path} ." -t") || return "Can't open Unix Sendmail:".$!;

print OUTMAIL <<EOM;
To:   $mail_to
From: $mail_from
Subject: $subject
Content-Type: text/plain


$body
.
EOM
;
close OUTMAIL;
}

sub makePagingLinks
{ 
 my ($f,$total_items) = @_;
 my $range = 5;
 my $items_per_page = $f->{per_page} || $c->{items_per_page} || 5;
 return '' if $items_per_page eq 'all';
  my $par;
  foreach my $key(keys %{$f})
  {
    my $val = $f->{$key};
    $par .= '&'.$key.'='.$val if (ref $val ne "ARRAY" && $key ne 'page');
    map({$par.='&'.$key.'='.$_}@$val) if (ref $val eq 'ARRAY');
  }

 my $t = HTML::Template->new( filename => "Templates/paging.html", die_on_bad_params => 0 );
 my $total_pages = sprintf("%.0f",0.5+$total_items/$items_per_page);
    my $current_page = $f->{page}||1;
    $current_page = 1 if $f->{page} eq 'all';
    return '' if $total_pages<2;
 my @pages;

 my $i1 = $current_page - $range;
 my $i2 = $current_page + $range;
 if ($i2 > $total_pages)
 {
    $i1 -= ($i2-$total_pages);
    $i2 = $total_pages;
 }

 my $i = $i1;
 while( $i <= $i2 )
 {
    if( $i > 0 )
    {
       my $cp = ($i eq $current_page) ? 1 : undef;
       push(@pages, {page => $i, is_cp => $cp, params=>$par} );
    }
    else
    {
       $i2++ if ( $i2 < $total_pages );
    }
    $i++;
 }
 if($i1>1)
 {
    $t->param(  left       => 1,
                page_left  => $i1-1,
              );
 }
 if($i2<$total_pages)
 {
    $t->param(  right       => 1,
                page_right  => $i2+1,
              );
 }
  
  $t->param(  page_list => (\@pages),
              params    =>  $par,
              total     => $total_items,
            );
  $t->param( show_all => 1) if $f->{per_page} eq 'all';
 return  $t->output(); 
}

sub makePagingSQLSuffix
{
    my ($current_page,$per_page)  = @_;
    
    my $items_per_page = $per_page || $c->{items_per_page} || 5;
    my $end = $current_page*$items_per_page;
    my $start = $end - $items_per_page; 
       $start = $start>0 ? $start:0;
    return " LIMIT $start, $items_per_page" unless $per_page eq "all";
    return undef; 
}

sub makeSortSQLcode
{
  my ($f,$default_field) = @_;
  
  my ($sort_field,$sort_order);
  if (!$f->{sort_field})
  {
     $sort_field = $default_field;
  }
  else
  {
     $sort_field = $f->{sort_field};
  }
  if ($f->{sort_order} eq 'down'){$sort_order = 'DESC';} else {$sort_order = '';}
  return " ORDER BY $sort_field $sort_order ";
}

sub makeSortHash
{
   my ($f,$default_field) = @_;
   my $params;
   foreach my $key (%{$f})
   {
    my $val = $f->{$key};
    $params .= '&'.$key.'='.$val if ($val && $key ne 'sort_field' && $key ne 'sort_order' && ref $val ne 'ARRAY' );
    map({$params.='&'.$key.'='.$_}@$val) if (ref($val) eq 'ARRAY');
   }
   my $sort_field = $f->{sort_field};
   my $sort_order = $f->{sort_order};
   $sort_field = @{$default_field}[0] if (!$sort_field);
   my $sort_order2 = $sort_order eq 'up' ? 'down' : 'up';   
   my %hash = ('sort_'.$sort_field         => 1,
               'sort_order_'.$sort_order2  => 1,
               'params'                    => $params,
               );
   for my $fld (@$default_field)
   {
      $hash{"s_$fld"}  = "<a href='?$params&sort_field=$fld&sort_order=$sort_order2'>";
      $hash{"s2_$fld"} = "<img border=0 src='$c->{site_url}/images/$sort_order.gif'>" if $fld eq $sort_field;
      $hash{"s2_$fld"}.= "</a>";
   }

   return %hash;
}
