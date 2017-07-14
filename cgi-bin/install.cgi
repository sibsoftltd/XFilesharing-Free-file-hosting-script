#!/usr/bin/perl
use strict;
use CGI::Carp qw(fatalsToBrowser);
use lib '.';
use DBI;
use XFileConfig;
use Process;
use CGI qw(param);
my $ok = "<br><b style='background:#1a1;color:#fff;padding:2px;'>OK</b>";

my $ses = Process->new;
my $f = $ses->f;

if($f->{save_sql_settings} || $f->{site_settings})
{
   my @fields = $f->{save_sql_settings} ? qw(db_host db_login db_passwd db_name) : qw(site_url site_cgi site_path temp_dir target_dir admin_password);
   my $conf;
   open(F,"XFileConfig.pm")||$ses->message("Can't read XFileConfig");
   $conf.=$_ while <F>;
   close F;
   for my $x (@fields)
   {
      my $val = $f->{$x};
      $conf=~s/$x\s*=>\s*(\S+)\s*,/"$x => '$val',"/e;
   }
   open(F,">XFileConfig.pm")||$ses->message("Can't write XFileConfig");
   print F $conf;
   close F;
   $ses->redirect('install.cgi');
}

if($f->{create_sql})
{
   my $db = $ses->db;
   open(FILE,"install.sql")||$ses->message("Can't open create.sql");
   my $sql;
   $sql.=$_ while <FILE>;
   $sql=~s/CREATE TABLE/CREATE TABLE IF NOT EXISTS/gis;
   $db->Exec($_) for split(';',$sql);
   $ses->redirect('install.cgi');
}


print"Content-type:text/html\n\n";
print"<HTML><BODY style='font:13px Arial;'><h2>XFileSharing Installation Script</h2>";
print"<b>1) Permissions Check</b><br><br>";
my $perms = {
               'logs.txt'           => 0777,
               'upload.cgi'         => 0755,
               'upload_status.cgi'  => 0755,
               'index.cgi'          => 0755,
               'temp'               => 0777,
               'uploads'            => 0777,
               'XFileConfig.pm'     => 0777,
            };
my @arr;
for(keys %{$perms})
{
   chmod $perms->{$_}, $_;
   my $chmod = (stat($_))[2] & 07777;
   my $chmod_txt = sprintf("%04o", $chmod);
   push @arr, "<b>$_</b> : $chmod_txt : ".( $chmod == $perms->{$_} ? 'OK' : "<u>ERROR: should be ".sprintf("%04o",$perms->{$_})."</u>" );
}
chmod 0777, "$c->{site_path}/captchas" if -d "$c->{site_path}/captchas";
print join '<br>', @arr;
if( grep{/ERROR/}@arr )
{
   print"<br><br><u>Fix errors above and refresh this page</u>";
}
else
{
   print"<br><br>All permissions are correct.$ok";
}
   

print"<hr>";

print"<b>2) MySQL Settings</b><br><br>";
my $dbh=DBI->connect("DBI:mysql:database=$c->{db_name};host=$c->{db_host}",$c->{db_login},$c->{db_passwd}) if $c->{db_name} && $c->{db_host};
if($dbh)
{
   print"MySQL Settings are correct. Can connect to DB.$ok";
}
else
{
print<<EOP
Can't connect to DB with current settings<br><br>
<Form method="POST">
<input type="hidden" name="save_sql_settings" value="1">
MySQL Host:<br>
<input type="text" name="db_host" value="$c->{db_host}"><br>
MySQL DB Username:<br>
<input type="text" name="db_login" value="$c->{db_login}"><br>
MySQL DB Password:<br>
<input type="text" name="db_passwd" value="$c->{db_passwd}"><br>
MySQL DB Name:<br>
<input type="text" name="db_name" value="$c->{db_name}"><br><br>
<input type="submit" value="Save MySQL Settings">
</Form>
EOP
;
}

print"<hr>";

print"<b>3) MySQL tables create</b><br><br>";

if(!$dbh)
{
   print"Fix MySQL settings above first.";
}
else
{
   my $sth=$dbh->prepare("DESC Files");
   my $rc=$sth->execute();
   if($rc)
   {
      print"Tables created successfully.$ok";
   }
   else
   {
print<<EOP
<form method="POST">
<input type="hidden" name="create_sql" value="1">
<input type="submit" value="Create MySQL Tables & Admin Account">
</form>
EOP
;
   }
}

print"<hr><b>4) Site Initial Settings</b><br><br>";
if($c->{site_url} && 
   $c->{site_cgi} && 
   -d $c->{site_path} && 
   -d $c->{temp_dir} && 
   -d $c->{target_dir} && 
   $c->{admin_password})
{
   print"Settings are correct.$ok";
}
else
{
   my $path = $ENV{DOCUMENT_ROOT};
   my $url = 'http://'.$ENV{HTTP_HOST}.$ENV{REQUEST_URI};
   $url=~s/\/[^\/]+$//;
   my $url_cgi = $url;
   $url=~s/cgi-bin\///;
   
   $url = $c->{site_url}||$url;
   $url_cgi = $c->{site_cgi}||$url_cgi;
   my $site_path = $c->{site_path}||$path;
   my $temp_path = $c->{temp_dir}||$path.'temp';
   my $upload_path = $c->{target_dir}||$path.'uploads';
print<<EOP
<form method="POST">
<input type="hidden" name="site_settings" value="1">
htdocs folder URL:<br>
<input type="text" name="site_url" value="$url" size=48> <small>No trailing slash</small><br>
cgi-bin folder URL:<br>
<input type="text" name="site_cgi" value="$url_cgi" size=48> <small>No trailing slash</small><br>
htdocs path:<br>
<input type="text" name="site_path" value="$site_path" size=48><br>
temp folder path:<br>
<input type="text" name="temp_dir" value="$temp_path" size=48><br>
uploads folder path:<br>
<input type="text" name="target_dir" value="$upload_path" size=48><br>
Admin password:<br>
<input type="text" name="admin_password" value="$c->{admin_password}" size=12><br>
<br>
<input type="submit" value="Save site settings">
</form>
EOP
;

}

print"<hr><b>5) Manually Remove install files</b><br><br>install.cgi<br>install.sql<br>convert.cgi";
