CREATE TABLE `Files` (
  `file_id` int(10) unsigned NOT NULL auto_increment,
  `file_name` varchar(255) NOT NULL default '',
  `file_descr` text,
  `file_code` varchar(12) NOT NULL default '',
  `file_del_id` varchar(10) NOT NULL default '',
  `file_downloads` int(10) unsigned NOT NULL default '0',
  `file_size` bigint(20) unsigned NOT NULL default '0',
  `file_password` varchar(32) default '',
  `file_ip` int(20) unsigned NOT NULL default '0',
  `file_last_download` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `file_created` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`file_id`),
  KEY `code` (`file_code`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE `Secure` (
  `file_id` int(10) unsigned NOT NULL default '0',
  `ip` int(10) unsigned NOT NULL default '0',
  `rand` varchar(5) NOT NULL default '',
  `time` datetime NOT NULL default '0000-00-00 00:00:00',
  `captcha` varchar(8) default '',
  KEY `time` (`time`),
  KEY `file_ip` (`file_id`,`ip`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;