--
-- Table structure for table `factoids`
--

CREATE TABLE `factoids` (
  `factoid_key` varchar(64) NOT NULL,
  `requested_by` varchar(100) NOT NULL default 'nobody',
  `requested_time` int(11) NOT NULL default '0',
  `requested_count` smallint(5) unsigned NOT NULL default '0',
  `created_by` varchar(100) default NULL,
  `created_time` int(11) NOT NULL default '0',
  `modified_by` varchar(100) default NULL,
  `modified_time` int(11) NOT NULL default '0',
  `locked_by` varchar(100) default NULL,
  `locked_time` int(11) NOT NULL default '0',
  `factoid_value` text NOT NULL,
  PRIMARY KEY  (`factoid_key`)
) TYPE=MyISAM;
