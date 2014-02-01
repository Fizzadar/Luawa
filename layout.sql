# ************************************************************
# Sequel Pro SQL dump
# Version 4096
#
# http://www.sequelpro.com/
# http://code.google.com/p/sequel-pro/
#
# Host: localhost (MySQL 5.5.32-MariaDB)
# Database: oxypanel
# Generation Time: 2014-02-01 16:57:52 +0000
# ************************************************************


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


# Dump of table log
# ------------------------------------------------------------

CREATE TABLE `log` (
  `object_type` varchar(16) NOT NULL DEFAULT '',
  `object_id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned NOT NULL,
  `time` int(10) unsigned NOT NULL,
  `action` varchar(128) NOT NULL DEFAULT '',
  `data` text NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8;



# Dump of table user
# ------------------------------------------------------------

CREATE TABLE `user` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `email` varchar(128) NOT NULL DEFAULT '' COMMENT 'used to identify',
  `password` varchar(255) NOT NULL DEFAULT '' COMMENT 'hashed pw',
  `salt` varchar(255) NOT NULL DEFAULT '' COMMENT 'salt for hash',
  `group` tinyint(3) unsigned NOT NULL DEFAULT '2' COMMENT '0=admin;1=user;1>=custom',
  `name` varchar(255) NOT NULL DEFAULT '' COMMENT 'name/display only',
  `login_time` int(10) unsigned NOT NULL DEFAULT '0',
  `register_time` int(10) unsigned NOT NULL DEFAULT '0',
  `password_reset_key` varchar(255) NOT NULL DEFAULT '' COMMENT 'pwreset temp key',
  `password_reset_time` int(10) unsigned NOT NULL DEFAULT '0' COMMENT 'expire time on pwreset',
  `key1` varchar(255) NOT NULL DEFAULT '',
  `key2` varchar(255) NOT NULL DEFAULT '',
  `key3` varchar(255) NOT NULL DEFAULT '',
  `real_name` varchar(255) NOT NULL DEFAULT '',
  `address` text NOT NULL,
  `country` varchar(3) NOT NULL DEFAULT '',
  `phone` int(10) unsigned NOT NULL DEFAULT '0',
  `credit` int(10) unsigned NOT NULL DEFAULT '0',
  `two_factor` tinyint(1) unsigned NOT NULL DEFAULT '0',
  `pubkey` text NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table user_groups
# ------------------------------------------------------------

CREATE TABLE `user_groups` (
  `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table user_messages
# ------------------------------------------------------------

CREATE TABLE `user_messages` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;



# Dump of table user_permissions
# ------------------------------------------------------------

CREATE TABLE `user_permissions` (
  `group` tinyint(3) unsigned NOT NULL,
  `permission` varchar(64) NOT NULL DEFAULT '',
  UNIQUE KEY `group_id` (`group`,`permission`),
  CONSTRAINT `permissions-user_groups_id` FOREIGN KEY (`group`) REFERENCES `user_groups` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=utf8;




/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
