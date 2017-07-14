#!/usr/bin/perl
use strict;
use lib '.';
use XFileConfig;
use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use File::Copy;
use HTML::Template;
use DataBase;
use Fcntl ':flock';

my $IP = &GetIP;
my $start_time = time;

#$CGI::POST_MAX = 1024 * $c->{max_upload_size};   # set max Total upload size


&logit("Starting upload. Size: $ENV{'CONTENT_LENGTH'}");
my ($sid) = ($ENV{QUERY_STRING}=~/upload_id=(\d+)/); # get the random id for temp files
$sid ||= join '', map int rand 10, 1..7;         # if client has no javascript, generate server-side
unless($sid=~/^\d+$/) # Checking for invalid IDs (hacker proof)
{
   &lmsg("ERROR: Invalid Upload ID");
   &xmessage("ERROR: Invalid Upload ID");
}
my $temp_dir = "$c->{temp_dir}/$sid";
my $mode = 0777;
mkdir $temp_dir, $mode;
chmod $mode,$temp_dir;

# Tell CGI.pm to use our directory based on sid
$CGITempFile::TMPDIRECTORY = $TempFile::TMPDIRECTORY = $temp_dir;


# Remove all files if user presses stop
sub CleanUp
{
   &logit('Upload stopped');
   &DelData($temp_dir);
   exit(0);
}

$c->{ip_allowed}=~s/\./\\./g;
$c->{ip_not_allowed}=~s/\./\\./g;
if( ($c->{ip_allowed} && $IP!~/$c->{ip_allowed}/) || ($c->{ip_not_allowed} && $IP=~/$c->{ip_not_allowed}/) )
{
   &lmsg("ERROR: $c->{msg}->{ip_not_allowed}");
   sleep 5;
   &DelData($temp_dir);
   &xmessage("ERROR: $c->{msg}->{ip_not_allowed}");
}

if($ENV{'CONTENT_LENGTH'} > 1048576*$c->{max_upload_size} || $ENV{'CONTENT_LENGTH'} > 1048576*$c->{max_upload_filesize})
{
   &lmsg("ERROR: $c->{msg}->{upload_size_big}$c->{max_upload_size} Mb");
   sleep 5;
   &DelData($temp_dir);
   &xmessage("ERROR: $c->{msg}->{upload_size_big}$c->{max_upload_size} Mb");
}
else
{
   open FILE,">$temp_dir/flength";
   print FILE $ENV{'CONTENT_LENGTH'}."\n";
   close FILE;
   my $mode = 0777; chmod $mode,"$temp_dir/flength";
}

#my $cg = new CGI;

my ($fname_old,$current_bytes,$speed,$buff_old,$time,$time_spent,$total_old);
my ($old_size,$old_time);
my $files_uploaded = 0;
my $time_start = $old_time = time;

my $cg = CGI->new(\&hook);

#########################
sub hook
{
  my ($fname, $buffer) = @_;
  
  my $buff_size = length($buffer);
  $current_bytes+=$buff_size;
  $time = time;
  $time_spent = $time - $time_start;
  my ($changed,$nf);
  if($fname_old ne $fname || $buff_old<$buff_size)
  {
     $files_uploaded++ if $fname_old;
     $fname_old=$fname;
     my $fsize = $current_bytes-$total_old;
     $total_old=$current_bytes;
     $nf = "file_uploaded:$files_uploaded:$fsize\n";
  }
  $buff_old = $buff_size;

  if($time>$old_time)
  {
     $speed = int( ($current_bytes-$old_size)/($time-$old_time) );
     $old_size = $current_bytes;
     $old_time = $time;
     $changed=1;
  }

  if($changed || $nf)
  {
     open F,"$temp_dir/flength";
     my @arr = <F>;
     close F;
   
     $arr[0] = "$ENV{CONTENT_LENGTH}:$current_bytes:$time_spent:$speed:$files_uploaded\n";
     push(@arr, $nf) if $nf;
   
     open F,"+< $temp_dir/flength" or die"Can't open flength";
     flock F, LOCK_EX or die"Can't lock flength";
     truncate F, 0;
     print F @arr;
     close F;
  }
}

$files_uploaded++;
my $fsize = $current_bytes-$total_old;
open F,">>$temp_dir/flength" or die"Can't open flength";
flock F, LOCK_EX or die"Can't lock flength";
print F "file_uploaded:$files_uploaded:$fsize\n";
close F;
#########################

my (@fileslots,@filenames,@file_status);

my $db = DataBase->new();

&lmsg("UPLOADED\n");
&lmsg("MSG: Upload complete. Saving files...");
sleep 1; #?

my ($files_saved,@files);

for my $k ( $cg->param() )
{
   next unless my $u=$cg->upload($k);
   
   my ($filename)=$cg->uploadInfo($u)->{'Content-Disposition'}=~/filename="(.+?)"/i;
   $filename=~s/^.*\\([^\\]*)$/$1/;

   my %fhash;
   $fhash{field_name}=$k;
   $fhash{file_name_orig} = $filename;
   $fhash{file_size}  = -s $u;
   $fhash{file_descr} = $cg->param("$k\_descr");
   $fhash{file_mime}  = $cg->uploadInfo($u)->{'Content-Type'};
   my $rand = &randchar(12);
   while($db->SelectOne("SELECT file_id FROM Files WHERE file_code=?",$rand)){$rand = &randchar(12);}
   $fhash{file_name}  = $rand;
   $fhash{del_id} = &randchar(10);

   $fhash{file_name_orig}=~s/[^a-zA-Z0-9-_\.]/_/gs;
   $fhash{file_descr}=~s/</&lt;/gs;
   $fhash{file_descr}=~s/>/&gt;/gs;
   $fhash{file_descr}=~s/"/&quote;/gs;
   $fhash{file_descr}=~s/\(/&#40;/gs;
   $fhash{file_descr}=~s/\)/&#41;/gs;
   $fhash{file_descr}=~s/\#/&#35;/gs;
   $fhash{file_descr}=~s/\&/&#38;/gs;

   if($fhash{file_size}==0)
   {
      &lmsg("MSG:$filename ".$c->{msg}->{null_filesize});
      $fhash{file_status}="null filesize or wrong file path";
      push @files, \%fhash;
      next;
   }

   if($fhash{file_size} > $c->{max_upload_filesize}*1048576)
   {
      &lmsg("MSG:$filename ".$c->{msg}->{file_size_big});
      $fhash{file_status}="filesize too big";
      push @files, \%fhash;
      next;
   }

   if( $c->{ext_not_allowed} && $filename=~/\.($c->{ext_not_allowed})$/i )
   {
      &lmsg("MSG:$filename ".$c->{msg}->{bad_extension});
      $fhash{file_status}="unallowed extension";
      push @files, \%fhash;
      next;
   }

   if($files_saved==$c->{max_upload_files})
   {
      &lmsg("MSG:$filename ".$c->{msg}->{too_many_files});
      $fhash{file_status}="too many files";
      push @files, \%fhash;
      next;
   }

   my $maxid = $db->SelectOne("SELECT MAX(file_id) FROM Files")+1;
   my $dx = sprintf("%05d",$maxid/$c->{files_per_folder});
   unless(-d "$c->{target_dir}/$dx")
   {
      my $mode = 0777;
      mkdir("$c->{target_dir}/$dx",$mode);
      chmod $mode,"$c->{target_dir}/$dx";
   }

   &SaveFile( $cg->tmpFileName($u), "$c->{target_dir}/$dx", $fhash{file_name} );

   if($c->{enable_clamav_virus_scan})
   {
      &lmsg("MSG:'$fhash{file_name_orig}': Scanning for viruses...");
      my $clam = join '', `clamscan --no-summary $c->{target_dir}/$dx/$fhash{file_name}`;
      if($clam!~/command not found/ && $clam!~/$fhash{file_name}: OK/)
      {
         unlink("$c->{target_dir}/$dx/$fhash{file_name}");
         &lmsg("MSG:'$fhash{file_name_orig}' contain virus. Skipping.");
         $fhash{file_status}="contain virus";
         push @files, \%fhash;
         next;
      }
   }
   
   $db->Exec("INSERT INTO Files SET file_name=?, file_descr=?, file_code=?, file_del_id=?, file_size=?, file_password=?, file_ip=INET_ATON(?), file_created=NOW()",
             $fhash{file_name_orig},$fhash{file_descr},$fhash{file_name},$fhash{del_id},$fhash{file_size},$cg->param('link_pass'),$IP);

   $files_saved++;
   $fhash{file_status}||='OK';
   push @files, \%fhash;

   &lmsg("MSG:'$fhash{file_name_orig}' ".$c->{msg}->{saved_ok});
}


&lmsg("MSG:".$c->{msg}->{transfer_complete});
&lmsg("DONE\n");


sleep 1; ### Small pause to sync last messages with pop-up
&DelData($temp_dir);
&DeleteExpiredFiles( $c->{temp_dir}, 86400 );
&CleanExpired;

# Generate parameters array for E-mail/POST
my @har;
my $style=1;
for my $f (@files)
{
   $style^=1;
   $f->{file_descr}=~s/>/&gt;/g;
   $f->{file_descr}=~s/</&lt;/g;
   $f->{file_descr}=~s/"/&quote;/g;
   $f->{file_descr}=substr($f->{file_descr},0,128);
   push @har, { name=>"filename",      'value'=>$f->{file_name},  'style'=>$style };
   push @har, { name=>"del_id",        'value'=>$f->{del_id},     'style'=>$style };
   push @har, { name=>"filename_original", 'value'=>$f->{file_name_orig},'style'=>$style };
   push @har, { name=>"status",        'value'=>$f->{file_status},'style'=>$style };
   push @har, { name=>"size",          'value'=>$f->{file_size},  'style'=>$style, value2=>sprintf("%.2f",$f->{file_size}/1048576)." Mbytes ($f->{file_size} bytes)" };
   push @har, { name=>"description",   'value'=>$f->{file_descr}, 'style'=>$style } if $c->{enable_file_descr};
   push @har, { name=>"$f->{field_name}_mime",     'value'=>$f->{file_mime},     'style'=>$style };
}

for my $k ($cg->param)
{
   next unless $k;
   for my $p ($cg->param($k))
   {
      next if ref $p eq 'Fh';
      next if $k =~ /(link_rcpt|link_pass|tos|act|xmode|xpass|pbmode|ref|js_on|upload_id|css_name|tmpl_name|inline|upload_password|popup|file_\d)/i;
      push @har, { name=>$k, value=>$p, 'style'=>2 };
   }
}
push @har, { name=>'number_of_files', value=>scalar(@files),   'style'=>2 };
push @har, { name=>'ip',              value=>$IP,              'style'=>2 };
push @har, { name=>'host',            value=>$ENV{'REMOTE_HOST'},'style'=>2 };
push @har, { name=>'duration',        value=>(time-$start_time).' seconds', 'style'=>2 };

### Send E-mail to Admin
if($c->{confirm_email} && $c->{sendmail_path}) # Admin notification
{
   my @t = &getTime;
   my $tmpl = HTML::Template->new( filename => "Templates/confirm_email.html", die_on_bad_params => 0 );
   $tmpl->param('params'    => \@har,
                'time'      => "$t[0]-$t[1]-$t[2] $t[3]:$t[4]:$t[5]",
                'total_size'=> "$ENV{CONTENT_LENGTH} bytes",
                'total_size_mb' => sprintf("%.1f",$ENV{CONTENT_LENGTH}/1048576)." Mb",
               );
   my $subject = $c->{email_subject} || "XUpload: New file(s) uploaded";
   &SendMail( $c->{confirm_email}, $c->{confirm_email_from}, $subject, $tmpl->output() );
}

### Send E-mail to Uploader
if($cg->param('link_rcpt'))
{
   my @t = &getTime;
   my @arr;
   push @arr,{'fname' => $_->{file_name_orig},
              'fsize' => sprintf("%.2f",$_->{file_size}/1048576)." Mbytes ($_->{file_size} bytes)",
              'descr' => $_->{file_descr},
              'id'    => $_->{file_name},
              'site_url' => $c->{site_url}
             } for grep {$_->{file_status} eq 'OK'} @files;
   my $tmpl = HTML::Template->new( filename => "Templates/confirm_email_user.html", die_on_bad_params => 0 );
   $tmpl->param('files' => \@arr,
                'site_name' => $c->{site_name},
                'site_url'  => $c->{site_url},
               );
   my $subject = "$c->{site_name}: File send notification";
   &SendMail( $cg->param('link_rcpt'), $c->{confirm_email_from}, $subject, $tmpl->output() );
}

### Sending data with POST request if need
my $url_post = "$c->{site_url}/" || $ENV{HTTP_REFERER};
if($url_post)
{
   push @har, { name=>'act', value=>'upload_result' };
   if($ENV{QUERY_STRING}!~/js_on=1/)
   {
     $url_post.='?';
     $url_post.="\&$_->{name}=$_->{value}" for @har;
     print $cg->redirect( $url_post );
     exit;
   }
   
   print"Content-type: text/html\n\n";
   print"<HTML><BODY><Form name='F1' action='$url_post' target='_parent' method='POST'>";
   print"<textarea name='$_->{name}'>$_->{value}</textarea>" for @har;
   print"</Form><Script>document.location='javascript:false';document.F1.submit();</Script></BODY></HTML>";
   exit;
}

print"Content-type: text/html\n\n";
print"Upload complete.";

exit;

#############################################

sub CleanExpired
{
   my $del_list1 = $db->SelectARef("SELECT file_id,file_code FROM Files WHERE file_created<NOW()-INTERVAL ? DAY",$c->{files_expire_created}) if $c->{files_expire_created};
   my $del_list2 = $db->SelectARef("SELECT file_id,file_code FROM Files WHERE file_last_download<NOW()-INTERVAL ? DAY",$c->{files_expire_access}) if $c->{files_expire_access};
   my @list;
   push @list, @$del_list1 if $del_list1;
   push @list, @$del_list2 if $del_list2;
   &lmsg("2del: ".$#list);
   for my $ff (@list)
   {
      my $dx = sprintf("%05d",$ff->{file_id}/$c->{files_per_folder});
      unlink("$c->{target_dir}/$dx/$ff->{file_code}") if -f "$c->{target_dir}/$dx/$ff->{file_code}";
      $db->Exec("DELETE FROM Files WHERE file_id=?",$ff->{file_id});
   }
}

sub DeleteExpiredFiles
{
   my ($dir,$lifetime,$access) = @_;
   return unless $lifetime;
   opendir(DIR, $dir) || &xmessage("Fatal Error: Can't opendir temporary folder ($dir)($!)");
   foreach my $fn (readdir(DIR))
   {
      next if $fn =~ /^\.{1,2}$/;
      my $file = $dir.'/'.$fn;
      my $ftime = $access ? (lstat($file))[8] : (lstat($file))[9];
      next if (time - $ftime) < $lifetime;
      -d $file ? &DelData($file) : unlink($file);
   }
   closedir(DIR);
}

sub SaveFile
{
   my ($temp,$dir,$fname) = @_;
   move($temp,"$dir/$fname") || copy($temp,"$dir/$fname") || xmessage("Fatal Error: Can't copy file from temp dir ($!)");
   my $mode = 0666;
   chmod $mode,"$dir/$fname";
}

sub DelData
{
   my ($dir) = @_;
   $cg->DESTROY if $cg; # WIN: unlock all files
   return unless -d $dir;
   opendir(DIR, $dir) || return;
   unlink("$dir/$_") for readdir(DIR);
   closedir(DIR);
   rmdir("$dir");
}

sub xmessage
{
   my ($msg) = @_;
   $msg=~s/'/\\'/g;
   $msg=~s/<br>/\\n/g;
   print"Content-type: text/html\n\n";
   print"<HTML><HEAD><Script>alert('$msg');</Script></HEAD><BODY><b>$msg</b></BODY></HTML>";
   exit;
}

sub lmsg
{
   my $msg = shift;
   open(FILE,">>$temp_dir/flength");
   print FILE $msg."\n";
   close FILE;
   &logit($msg);
}

sub logit
{
   my $msg = shift;
   return unless $c->{uploads_log};
   my @t = &getTime;
   open(FILE,">>$c->{uploads_log}") || return;
   print FILE $IP." $t[0]-$t[1]-$t[2] $t[3]:$t[4]:$t[5] $msg\n";
   close FILE;
}

sub getTime
{
    my @t = localtime();
    return ( sprintf("%04d",$t[5]+1900),
             sprintf("%02d",$t[4]+1), 
             sprintf("%02d",$t[3]), 
             sprintf("%02d",$t[2]), 
             sprintf("%02d",$t[1]), 
             sprintf("%02d",$t[0]) 
           );
}

sub GetIP
{
 return $ENV{HTTP_X_FORWARDED_FOR} || $ENV{REMOTE_ADDR};
}


sub SendMail
{
my ($mail_to, $mail_from, $subject, $body) = @_;  
  
open (OUTMAIL,"|".$c->{sendmail_path} ." -t") || return;

print OUTMAIL <<EOM;
To:   $mail_to
From: $mail_from
Subject: $subject
Content-Type: text/html


$body
.
EOM
;
close OUTMAIL;
}

sub randchar
{ 
   my @range = ('0'..'9','A'..'Z');
    my $x = int scalar @range;
     join '', map $range[rand $x], 1..shift||1;
}
