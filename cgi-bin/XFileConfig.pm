package XFileConfig;
use strict;
use Exporter ();
use lib 'Modules';
@XFileConfig::ISA    = qw(Exporter);
@XFileConfig::EXPORT = qw($c);
use vars qw( $c );

$c=
{
 # MySQL settings
 db_host => 'localhost',
 db_login => '',
 db_passwd => '',
 db_name => '',

 # Your site name that will appear in all templates
 site_name => 'XFileSharing',

 # Your site URL, witout trailing /
 site_url => '',

 # Your site cgi-bin URL, witout trailing /
 site_cgi => '',

 # Path to your site htdocs folder
 site_path => '',

 # Password to admin area
 admin_password => '',

 # Expire files after X days after upload
 # 0 to disable
 files_expire_created => '90', #days

 # Expire files after Y days after last download of these files
 # 0 to disable
 files_expire_access => '90', #days

 # Directory for temporary using files
 temp_dir        => '',

 # Directory for uploaded files
 target_dir      => '',

 # Max number of upload fields
 max_upload_files => '3',

 # Maximum Total upload size in Mbytes (0 to disable)
 max_upload_size => '700',

 # Maximum upload Filesize in Mbytes (0 to disable)
 max_upload_filesize => '700',

 # Maximum number of downloads for single file (0 to disable)
 max_downloads_number => '0',

 # Allowed file extensions delimited with '|'
 # Leave blank to allow all extensions
 # Sample: ext_allowed => '',
 ext_allowed     => '',

 # Not Allowed file extensions delimited with '|'
 # Leave it blank to disable this filter
 # Sample: ext_not_allowed => 'exe|com',
 ext_not_allowed => 'exe|com|php|cgi|pl|sh|py',

 # Allowed IPs ONLY
 # Examples: '^(10.0.0.182)$' - allow only 10.0.0.182, '^(10.0.1.125|10.0.0.\d+)$' - allow 10.0.1.125 & 10.0.0.*
 # Use \d+ for wildcard *
 # Use blank for no restrictions
 ip_allowed => '',

 # Banned IPs
 # Use \d+ for wildcard *
 ip_not_allowed => '^(127.0.0.123|127.0.0.124)$',

 # Logfile name
 uploads_log => 'logs.txt',

 # Use captcha verification to avoid robots
 # 0 - disable captcha, 1 - image captcha (requires GD perl module installed), 2 - text captha
 use_captcha => '0',

 # Specify number of seconds users have to wait before download, 0 to disable
 download_countdown => '0',

 # Enable users to add descriptions to files
 enable_file_descr => '1',

 # Enable scanning file for viruses with ClamAV after upload (Experimental)
 # You need ClamAV installed on your server
 enable_clamav_virus_scan => '0',

 #Files per dir, do not touch since server start
 files_per_folder => 5000,

##### Email settings #####

 # Path to sendmail
 sendmail_path      => '/usr/sbin/sendmail',

 # Admin Email where upload notifications will be sent To
 # Leave blank to disable admin notifications
 confirm_email => '',

 # This email will be in "From:" field in confirmation & contact emails
 confirm_email_from => '',

 # Subject for email notification
 email_subject      => "XFileSharing: new file(s) uploaded",


 # Email that Contact messages will be sent to
 contact_email => '',

 # Your site abuse email
 abuse_email => '',

##### Custom error messages #####

 msg => { upload_size_big   => "Maximum total upload size exceeded<br>Please stop transfer right now.<br>Max total upload size is: ",
          file_size_big     => "exceeded Max filesize limit! Skipped.",
          no_temp_dir       => "No temp dir exist! Please fix your temp_dir variable in config.",
          no_target_dir     => "No target dir exist! Please fix your target_dir variable in config.",
          no_templates_dir  => "No Templates dir exist! Please fix your templates_dir variable in config.",
          transfer_complete => "Transfer complete!",
          transfer_failed   => "Upload failed!",
          null_filesize     => "have null filesize or wrong file path",
          bad_filename      => "is not acceptable filename! Skipped.",
          bad_extension     => "have unallowed extension! Skipped.",
          too_many_files    => "wasn't saved! Number of files limit exceeded.",
          saved_ok          => "saved successfully.",
          wrong_password    => "You've entered wrong password.<br>Authorization required.",
          ip_not_allowed    => "You are not allowed to upload files",
        },
};

1;
