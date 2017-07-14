#!/usr/bin/perl
### SibSoft.net, Jan 2008, Art Bogdanov ###
use strict;
#use CGI::Carp qw(fatalsToBrowser);
use lib '.';
use XFileConfig;
use HTML::Template;  
use CGI;
use Fcntl ':flock';
my $nbars=20; # number of bars

my $cgi = CGI->new();
my $sid=$cgi->param('uid');
my $css_name = $cgi->param('css');
my $tmpl_name = $cgi->param('tmpl');
my $ajax2 = $cgi->param('ajax2');

my $flength_file = "$c->{temp_dir}/$sid/flength";
my $fmsg_file    = "$c->{temp_dir}/$sid/fmsg";
my $temp_dir     = "$c->{temp_dir}/$sid";

print"Expires: Mon, 26 Jul 1997 05:00:00 GMT\n";
#print"Cache-Control: no-store, no-cache, must-revalidate\n";
#print"Cache-Control: post-check=0, pre-check=0\n";
print"Pragma: no-cache\n";
print"Content-type: text/html\n\n";

for(1..5){ last if -e $flength_file; sleep 1; }
&DisplayMessage($c->{msg}->{transfer_complete},'nostop') unless (-e $flength_file); # No flength file => Upload already finished

my $uploaded;
my ($str,$msgs,$num) = &getSizeInfo( $cgi->param('num') );
my ($total,$current,$time,$speed,$files) = split(/:/,$str);

my $estimate = sprintf("%.0f", ($total-$current)/$speed ) if $speed;


my $totalKB = sprintf("%.0f",$total/1024); # Total file size in Kilobytes
my $currentKB = sprintf("%.0f",$current/1024);
my $speedKB = sprintf("%.0f",$speed/1024);
my $MB;
if($totalKB>1024*10)
{
   $totalKB = sprintf("%.1f",$totalKB/1024); # Convert to Mb if > 10Mb
   $currentKB = sprintf("%.1f",$currentKB/1024);
   $MB=1;
}

unless($ajax2)
{
   &DisplayMessage($str) if $str =~ /^ERROR/;

   my $i=1;
   my @file_list = map{ {num=>$i++,name=>$_} } grep{$_} split(':', $cgi->param('files') );
   my $files_total = scalar @file_list;

   my $bars_arr = [map{{'num'=>$_}}(1..$nbars)];
   my $total_metrics = $MB ? " Mbytes" : " Kbytes";
   my $t = HTML::Template->new( filename => "Templates/progress_bar.html", die_on_bad_params => 0, );
   $t->param(( 'percent_completed' => '<font id="percent">0%</font>',
               'files_uploaded' => '<font id="files">0</font>',
               'files_total'    => '<font id="files_total">0</font>',
               'data_uploaded'  => '<font id="current">0</font>',
               'data_total'     => '<font id="data_total">0</font>',
               'time_spent'     => '<font id="time">0</font>',
               'speed'          => '<font id="speed">0</font>',
               'time_left'      => '<font id="left">0</font>',
               'inline'         => 0,
               'data_total_dgt' => $totalKB,
               'bars'           => $bars_arr,
               'nbars'          => $nbars,
               'file_list'      => \@file_list,
            ));
   
   print $t->output;
   print qq[<Script>changeValue('files_total','$files_total');changeValue('data_total','$totalKB $total_metrics');SP('$currentKB','$time',0,'$files',0);setTimeout("jah('upload_status.cgi?uid=$sid&ajax2=1&num=$num');",100);</Script>];
   exit;
}


if(grep{/^uploaded$/i}@$msgs) #finished upload
{
   $files++;
   print"SP('$totalKB','$time','$speedKB','$files',0);";
   print"if(document.getElementById('stop_btn')){document.getElementById('stop_btn').style.display='none';}";
}
else
{
   print qq{SP('$currentKB','$time','$speedKB','$files','$estimate');} unless $uploaded;
}


for my $str (@$msgs)
{
   if($str=~/^file_uploaded:(\d+):(\d+)/)
   {
      my $fsize = $2 < 1048576 ? sprintf("%.0f Kb",$2/1024) : sprintf("%.1f Mb",$2/1048576);
      print"updateFileStatus('$1','done','DONE','$fsize');";
      print"updateFileStatus('".($1+1)."','load','Uploading','');";
   }
   my ($msg) = $str=~/^MSG:(.+)$/;
   next unless $msg;
   $msg=~s/"/&quote;/g;
   print qq{Message("$msg");} if $msg;
}

my $pause = $total<1024*1024*10 ? 350 : 1000; #longer pauses if >10Mb
print qq{setTimeout("jah('upload_status.cgi?uid=$sid&ajax2=1&num=$num');",$pause);} 
   unless grep{/^DONE/}@$msgs;




#######

sub getSizeInfo
{
    my ($num_old) = @_;
    open F,$flength_file || die"Flength open error!";
    flock F, LOCK_EX;
    my @msgs = <F>;
    close F;

    chomp(@msgs);
    my $str = shift(@msgs);
    my $num = scalar @msgs;
    $num=0 if $num_old eq '';
    $uploaded=1 if grep{/^uploaded$/i}@msgs;
    shift @msgs for 1..$num_old;

    return ($str,\@msgs,$num);
}

sub DisplayMessage
{
   my ($MSG,$nostop) = @_;
   
   my $t = HTML::Template->new( filename => "Templates/progress_bar.html", die_on_bad_params => 0 );
   $t->param('data_total_dgt' => 0,
             'js_bars'    => 0,
             'nbars'      => 0,
             'message'    => $MSG,
             'nostop'     => $nostop,
            );
   print $t->output;
   exit;
}
