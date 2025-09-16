-- Adminer 5.3.0 MySQL 8.4.0 dump

SET NAMES utf8;
SET time_zone = '+00:00';
SET foreign_key_checks = 0;
SET sql_mode = 'NO_AUTO_VALUE_ON_ZERO';

SET NAMES utf8mb4;

DROP TABLE IF EXISTS `oc_accounts`;
CREATE TABLE `oc_accounts` (
  `uid` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `data` longtext COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_accounts` (`uid`, `data`) VALUES
('admin',	'{\"displayname\":{\"value\":\"admin\",\"scope\":\"v2-federated\",\"verified\":\"0\"},\"address\":{\"value\":\"\",\"scope\":\"v2-local\",\"verified\":\"0\"},\"website\":{\"value\":\"\",\"scope\":\"v2-local\",\"verified\":\"0\"},\"email\":{\"value\":null,\"scope\":\"v2-federated\",\"verified\":\"0\"},\"avatar\":{\"scope\":\"v2-federated\"},\"phone\":{\"value\":\"\",\"scope\":\"v2-local\",\"verified\":\"0\"},\"twitter\":{\"value\":\"\",\"scope\":\"v2-local\",\"verified\":\"0\"},\"fediverse\":{\"value\":\"\",\"scope\":\"v2-local\",\"verified\":\"0\"},\"organisation\":{\"value\":\"\",\"scope\":\"v2-local\"},\"role\":{\"value\":\"\",\"scope\":\"v2-local\"},\"headline\":{\"value\":\"\",\"scope\":\"v2-local\"},\"biography\":{\"value\":\"\",\"scope\":\"v2-local\"},\"birthdate\":{\"value\":\"\",\"scope\":\"v2-local\"},\"profile_enabled\":{\"value\":\"1\"},\"pronouns\":{\"value\":\"\",\"scope\":\"v2-federated\"}}');

DROP TABLE IF EXISTS `oc_accounts_data`;
CREATE TABLE `oc_accounts_data` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `uid` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `name` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `value` varchar(255) COLLATE utf8mb4_bin DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `accounts_data_uid` (`uid`),
  KEY `accounts_data_name` (`name`),
  KEY `accounts_data_value` (`value`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_accounts_data` (`id`, `uid`, `name`, `value`) VALUES
(1,	'admin',	'displayname',	'admin'),
(2,	'admin',	'address',	''),
(3,	'admin',	'website',	''),
(4,	'admin',	'email',	''),
(5,	'admin',	'phone',	''),
(6,	'admin',	'twitter',	''),
(7,	'admin',	'fediverse',	''),
(8,	'admin',	'organisation',	''),
(9,	'admin',	'role',	''),
(10,	'admin',	'headline',	''),
(11,	'admin',	'biography',	''),
(12,	'admin',	'birthdate',	''),
(13,	'admin',	'profile_enabled',	'1'),
(14,	'admin',	'pronouns',	'');

DROP TABLE IF EXISTS `oc_activity`;
CREATE TABLE `oc_activity` (
  `activity_id` bigint NOT NULL AUTO_INCREMENT,
  `timestamp` int NOT NULL DEFAULT '0',
  `priority` int NOT NULL DEFAULT '0',
  `type` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `user` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `affecteduser` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `app` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `subject` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `subjectparams` longtext COLLATE utf8mb4_bin NOT NULL,
  `message` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `messageparams` longtext COLLATE utf8mb4_bin,
  `file` varchar(4000) COLLATE utf8mb4_bin DEFAULT NULL,
  `link` varchar(4000) COLLATE utf8mb4_bin DEFAULT NULL,
  `object_type` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `object_id` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`activity_id`),
  KEY `activity_user_time` (`affecteduser`,`timestamp`),
  KEY `activity_filter_by` (`affecteduser`,`user`,`timestamp`),
  KEY `activity_filter` (`affecteduser`,`type`,`app`,`timestamp`),
  KEY `activity_object` (`object_type`,`object_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_activity` (`activity_id`, `timestamp`, `priority`, `type`, `user`, `affecteduser`, `app`, `subject`, `subjectparams`, `message`, `messageparams`, `file`, `link`, `object_type`, `object_id`) VALUES
(1,	1757057742,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"3\":\"\\/Templates\"}]',	'',	'[]',	'/Templates',	'http://localhost/index.php/apps/files/?dir=/',	'files',	3),
(2,	1757057742,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"4\":\"\\/Templates\\/Flowchart.odg\"}]',	'',	'[]',	'/Templates/Flowchart.odg',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	4),
(3,	1757057742,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"4\":\"\\/Templates\\/Flowchart.odg\"}]',	'',	'[]',	'/Templates/Flowchart.odg',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	4),
(4,	1757057742,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"5\":\"\\/Templates\\/Yellow idea.odp\"}]',	'',	'[]',	'/Templates/Yellow idea.odp',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	5),
(5,	1757057742,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"5\":\"\\/Templates\\/Yellow idea.odp\"}]',	'',	'[]',	'/Templates/Yellow idea.odp',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	5),
(6,	1757057742,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"6\":\"\\/Templates\\/Venn diagram.whiteboard\"}]',	'',	'[]',	'/Templates/Venn diagram.whiteboard',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	6),
(7,	1757057742,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"6\":\"\\/Templates\\/Venn diagram.whiteboard\"}]',	'',	'[]',	'/Templates/Venn diagram.whiteboard',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	6),
(8,	1757057743,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"7\":\"\\/Templates\\/Gotong royong.odp\"}]',	'',	'[]',	'/Templates/Gotong royong.odp',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	7),
(9,	1757057743,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"7\":\"\\/Templates\\/Gotong royong.odp\"}]',	'',	'[]',	'/Templates/Gotong royong.odp',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	7),
(10,	1757057743,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"8\":\"\\/Templates\\/Meeting notes.md\"}]',	'',	'[]',	'/Templates/Meeting notes.md',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	8),
(11,	1757057743,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"8\":\"\\/Templates\\/Meeting notes.md\"}]',	'',	'[]',	'/Templates/Meeting notes.md',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	8),
(12,	1757057743,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"9\":\"\\/Templates\\/Letter.odt\"}]',	'',	'[]',	'/Templates/Letter.odt',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	9),
(13,	1757057743,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"9\":\"\\/Templates\\/Letter.odt\"}]',	'',	'[]',	'/Templates/Letter.odt',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	9),
(14,	1757057743,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"10\":\"\\/Templates\\/Mindmap.odg\"}]',	'',	'[]',	'/Templates/Mindmap.odg',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	10),
(15,	1757057743,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"10\":\"\\/Templates\\/Mindmap.odg\"}]',	'',	'[]',	'/Templates/Mindmap.odg',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	10),
(16,	1757057743,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"11\":\"\\/Templates\\/Mind map.whiteboard\"}]',	'',	'[]',	'/Templates/Mind map.whiteboard',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	11),
(17,	1757057744,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"11\":\"\\/Templates\\/Mind map.whiteboard\"}]',	'',	'[]',	'/Templates/Mind map.whiteboard',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	11),
(18,	1757057744,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"12\":\"\\/Templates\\/Resume.odt\"}]',	'',	'[]',	'/Templates/Resume.odt',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	12),
(19,	1757057744,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"12\":\"\\/Templates\\/Resume.odt\"}]',	'',	'[]',	'/Templates/Resume.odt',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	12),
(20,	1757057744,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"13\":\"\\/Templates\\/Party invitation.odt\"}]',	'',	'[]',	'/Templates/Party invitation.odt',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	13),
(21,	1757057744,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"13\":\"\\/Templates\\/Party invitation.odt\"}]',	'',	'[]',	'/Templates/Party invitation.odt',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	13),
(22,	1757057744,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"14\":\"\\/Templates\\/Mother\'s day.odt\"}]',	'',	'[]',	'/Templates/Mother\'s day.odt',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	14),
(23,	1757057744,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"14\":\"\\/Templates\\/Mother\'s day.odt\"}]',	'',	'[]',	'/Templates/Mother\'s day.odt',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	14),
(24,	1757057745,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"15\":\"\\/Templates\\/Brainstorming.whiteboard\"}]',	'',	'[]',	'/Templates/Brainstorming.whiteboard',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	15),
(25,	1757057745,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"15\":\"\\/Templates\\/Brainstorming.whiteboard\"}]',	'',	'[]',	'/Templates/Brainstorming.whiteboard',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	15),
(26,	1757057745,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"16\":\"\\/Templates\\/Business model canvas.ods\"}]',	'',	'[]',	'/Templates/Business model canvas.ods',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	16),
(27,	1757057745,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"16\":\"\\/Templates\\/Business model canvas.ods\"}]',	'',	'[]',	'/Templates/Business model canvas.ods',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	16),
(28,	1757057745,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"17\":\"\\/Templates\\/Business model canvas.odg\"}]',	'',	'[]',	'/Templates/Business model canvas.odg',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	17),
(29,	1757057745,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"17\":\"\\/Templates\\/Business model canvas.odg\"}]',	'',	'[]',	'/Templates/Business model canvas.odg',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	17),
(30,	1757057745,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"18\":\"\\/Templates\\/Photo book.odt\"}]',	'',	'[]',	'/Templates/Photo book.odt',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	18),
(31,	1757057745,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"18\":\"\\/Templates\\/Photo book.odt\"}]',	'',	'[]',	'/Templates/Photo book.odt',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	18),
(32,	1757057746,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"19\":\"\\/Templates\\/Elegant.odp\"}]',	'',	'[]',	'/Templates/Elegant.odp',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	19),
(33,	1757057746,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"19\":\"\\/Templates\\/Elegant.odp\"}]',	'',	'[]',	'/Templates/Elegant.odp',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	19),
(34,	1757057746,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"20\":\"\\/Templates\\/Sticky notes.whiteboard\"}]',	'',	'[]',	'/Templates/Sticky notes.whiteboard',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	20),
(35,	1757057746,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"20\":\"\\/Templates\\/Sticky notes.whiteboard\"}]',	'',	'[]',	'/Templates/Sticky notes.whiteboard',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	20),
(36,	1757057746,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"21\":\"\\/Templates\\/Readme.md\"}]',	'',	'[]',	'/Templates/Readme.md',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	21),
(37,	1757057746,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"21\":\"\\/Templates\\/Readme.md\"}]',	'',	'[]',	'/Templates/Readme.md',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	21),
(38,	1757057746,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"22\":\"\\/Templates\\/Business model canvas.whiteboard\"}]',	'',	'[]',	'/Templates/Business model canvas.whiteboard',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	22),
(39,	1757057746,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"22\":\"\\/Templates\\/Business model canvas.whiteboard\"}]',	'',	'[]',	'/Templates/Business model canvas.whiteboard',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	22),
(40,	1757057747,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"23\":\"\\/Templates\\/Meeting agenda.whiteboard\"}]',	'',	'[]',	'/Templates/Meeting agenda.whiteboard',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	23),
(41,	1757057747,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"23\":\"\\/Templates\\/Meeting agenda.whiteboard\"}]',	'',	'[]',	'/Templates/Meeting agenda.whiteboard',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	23),
(42,	1757057747,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"24\":\"\\/Templates\\/Flowchart.whiteboard\"}]',	'',	'[]',	'/Templates/Flowchart.whiteboard',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	24),
(43,	1757057747,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"24\":\"\\/Templates\\/Flowchart.whiteboard\"}]',	'',	'[]',	'/Templates/Flowchart.whiteboard',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	24),
(44,	1757057747,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"25\":\"\\/Templates\\/Diagram & table.ods\"}]',	'',	'[]',	'/Templates/Diagram & table.ods',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	25),
(45,	1757057747,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"25\":\"\\/Templates\\/Diagram & table.ods\"}]',	'',	'[]',	'/Templates/Diagram & table.ods',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	25),
(46,	1757057747,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"26\":\"\\/Templates\\/Modern company.odp\"}]',	'',	'[]',	'/Templates/Modern company.odp',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	26),
(47,	1757057747,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"26\":\"\\/Templates\\/Modern company.odp\"}]',	'',	'[]',	'/Templates/Modern company.odp',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	26),
(48,	1757057748,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"27\":\"\\/Templates\\/Simple.odp\"}]',	'',	'[]',	'/Templates/Simple.odp',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	27),
(49,	1757057748,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"27\":\"\\/Templates\\/Simple.odp\"}]',	'',	'[]',	'/Templates/Simple.odp',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	27),
(50,	1757057748,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"28\":\"\\/Templates\\/Product plan.md\"}]',	'',	'[]',	'/Templates/Product plan.md',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	28),
(51,	1757057748,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"28\":\"\\/Templates\\/Product plan.md\"}]',	'',	'[]',	'/Templates/Product plan.md',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	28),
(52,	1757057748,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"29\":\"\\/Templates\\/Syllabus.odt\"}]',	'',	'[]',	'/Templates/Syllabus.odt',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	29),
(53,	1757057748,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"29\":\"\\/Templates\\/Syllabus.odt\"}]',	'',	'[]',	'/Templates/Syllabus.odt',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	29),
(54,	1757057748,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"30\":\"\\/Templates\\/Timeline.whiteboard\"}]',	'',	'[]',	'/Templates/Timeline.whiteboard',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	30),
(55,	1757057748,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"30\":\"\\/Templates\\/Timeline.whiteboard\"}]',	'',	'[]',	'/Templates/Timeline.whiteboard',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	30),
(56,	1757057749,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"31\":\"\\/Templates\\/Invoice.odt\"}]',	'',	'[]',	'/Templates/Invoice.odt',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	31),
(57,	1757057749,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"31\":\"\\/Templates\\/Invoice.odt\"}]',	'',	'[]',	'/Templates/Invoice.odt',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	31),
(58,	1757057749,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"32\":\"\\/Templates\\/Kanban board.whiteboard\"}]',	'',	'[]',	'/Templates/Kanban board.whiteboard',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	32),
(59,	1757057749,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"32\":\"\\/Templates\\/Kanban board.whiteboard\"}]',	'',	'[]',	'/Templates/Kanban board.whiteboard',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	32),
(60,	1757057749,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"33\":\"\\/Templates\\/Expense report.ods\"}]',	'',	'[]',	'/Templates/Expense report.ods',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	33),
(61,	1757057749,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"33\":\"\\/Templates\\/Expense report.ods\"}]',	'',	'[]',	'/Templates/Expense report.ods',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	33),
(62,	1757057749,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"34\":\"\\/Templates\\/Impact effort.whiteboard\"}]',	'',	'[]',	'/Templates/Impact effort.whiteboard',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	34),
(63,	1757057750,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"34\":\"\\/Templates\\/Impact effort.whiteboard\"}]',	'',	'[]',	'/Templates/Impact effort.whiteboard',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	34),
(64,	1757057750,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"35\":\"\\/Templates\\/Timesheet.ods\"}]',	'',	'[]',	'/Templates/Timesheet.ods',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	35),
(65,	1757057750,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"35\":\"\\/Templates\\/Timesheet.ods\"}]',	'',	'[]',	'/Templates/Timesheet.ods',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	35),
(66,	1757057750,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"36\":\"\\/Templates\\/Org chart.odg\"}]',	'',	'[]',	'/Templates/Org chart.odg',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	36),
(67,	1757057750,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"36\":\"\\/Templates\\/Org chart.odg\"}]',	'',	'[]',	'/Templates/Org chart.odg',	'http://localhost/index.php/apps/files/?dir=/Templates',	'files',	36),
(68,	1757057750,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"37\":\"\\/Documents\"}]',	'',	'[]',	'/Documents',	'http://localhost/index.php/apps/files/?dir=/',	'files',	37),
(69,	1757057750,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"38\":\"\\/Documents\\/Example.md\"}]',	'',	'[]',	'/Documents/Example.md',	'http://localhost/index.php/apps/files/?dir=/Documents',	'files',	38),
(70,	1757057750,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"38\":\"\\/Documents\\/Example.md\"}]',	'',	'[]',	'/Documents/Example.md',	'http://localhost/index.php/apps/files/?dir=/Documents',	'files',	38),
(71,	1757057751,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"39\":\"\\/Documents\\/Readme.md\"}]',	'',	'[]',	'/Documents/Readme.md',	'http://localhost/index.php/apps/files/?dir=/Documents',	'files',	39),
(72,	1757057751,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"39\":\"\\/Documents\\/Readme.md\"}]',	'',	'[]',	'/Documents/Readme.md',	'http://localhost/index.php/apps/files/?dir=/Documents',	'files',	39),
(73,	1757057751,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"40\":\"\\/Documents\\/Nextcloud flyer.pdf\"}]',	'',	'[]',	'/Documents/Nextcloud flyer.pdf',	'http://localhost/index.php/apps/files/?dir=/Documents',	'files',	40),
(74,	1757057751,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"40\":\"\\/Documents\\/Nextcloud flyer.pdf\"}]',	'',	'[]',	'/Documents/Nextcloud flyer.pdf',	'http://localhost/index.php/apps/files/?dir=/Documents',	'files',	40),
(75,	1757057751,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"41\":\"\\/Documents\\/Welcome to Nextcloud Hub.docx\"}]',	'',	'[]',	'/Documents/Welcome to Nextcloud Hub.docx',	'http://localhost/index.php/apps/files/?dir=/Documents',	'files',	41),
(76,	1757057751,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"41\":\"\\/Documents\\/Welcome to Nextcloud Hub.docx\"}]',	'',	'[]',	'/Documents/Welcome to Nextcloud Hub.docx',	'http://localhost/index.php/apps/files/?dir=/Documents',	'files',	41),
(77,	1757057751,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"42\":\"\\/Nextcloud Manual.pdf\"}]',	'',	'[]',	'/Nextcloud Manual.pdf',	'http://localhost/index.php/apps/files/?dir=/',	'files',	42),
(78,	1757057752,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"42\":\"\\/Nextcloud Manual.pdf\"}]',	'',	'[]',	'/Nextcloud Manual.pdf',	'http://localhost/index.php/apps/files/?dir=/',	'files',	42),
(79,	1757057752,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"43\":\"\\/Readme.md\"}]',	'',	'[]',	'/Readme.md',	'http://localhost/index.php/apps/files/?dir=/',	'files',	43),
(80,	1757057752,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"43\":\"\\/Readme.md\"}]',	'',	'[]',	'/Readme.md',	'http://localhost/index.php/apps/files/?dir=/',	'files',	43),
(81,	1757057752,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"44\":\"\\/Nextcloud.png\"}]',	'',	'[]',	'/Nextcloud.png',	'http://localhost/index.php/apps/files/?dir=/',	'files',	44),
(82,	1757057752,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"44\":\"\\/Nextcloud.png\"}]',	'',	'[]',	'/Nextcloud.png',	'http://localhost/index.php/apps/files/?dir=/',	'files',	44),
(83,	1757057752,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"45\":\"\\/Templates credits.md\"}]',	'',	'[]',	'/Templates credits.md',	'http://localhost/index.php/apps/files/?dir=/',	'files',	45),
(84,	1757057752,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"45\":\"\\/Templates credits.md\"}]',	'',	'[]',	'/Templates credits.md',	'http://localhost/index.php/apps/files/?dir=/',	'files',	45),
(85,	1757057752,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"46\":\"\\/Reasons to use Nextcloud.pdf\"}]',	'',	'[]',	'/Reasons to use Nextcloud.pdf',	'http://localhost/index.php/apps/files/?dir=/',	'files',	46),
(86,	1757057753,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"46\":\"\\/Reasons to use Nextcloud.pdf\"}]',	'',	'[]',	'/Reasons to use Nextcloud.pdf',	'http://localhost/index.php/apps/files/?dir=/',	'files',	46),
(87,	1757057753,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"47\":\"\\/Photos\"}]',	'',	'[]',	'/Photos',	'http://localhost/index.php/apps/files/?dir=/',	'files',	47),
(88,	1757057753,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"48\":\"\\/Photos\\/Frog.jpg\"}]',	'',	'[]',	'/Photos/Frog.jpg',	'http://localhost/index.php/apps/files/?dir=/Photos',	'files',	48),
(89,	1757057753,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"48\":\"\\/Photos\\/Frog.jpg\"}]',	'',	'[]',	'/Photos/Frog.jpg',	'http://localhost/index.php/apps/files/?dir=/Photos',	'files',	48),
(90,	1757057753,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"49\":\"\\/Photos\\/Birdie.jpg\"}]',	'',	'[]',	'/Photos/Birdie.jpg',	'http://localhost/index.php/apps/files/?dir=/Photos',	'files',	49),
(91,	1757057753,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"49\":\"\\/Photos\\/Birdie.jpg\"}]',	'',	'[]',	'/Photos/Birdie.jpg',	'http://localhost/index.php/apps/files/?dir=/Photos',	'files',	49),
(92,	1757057753,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"50\":\"\\/Photos\\/Steps.jpg\"}]',	'',	'[]',	'/Photos/Steps.jpg',	'http://localhost/index.php/apps/files/?dir=/Photos',	'files',	50),
(93,	1757057754,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"50\":\"\\/Photos\\/Steps.jpg\"}]',	'',	'[]',	'/Photos/Steps.jpg',	'http://localhost/index.php/apps/files/?dir=/Photos',	'files',	50),
(94,	1757057754,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"51\":\"\\/Photos\\/Library.jpg\"}]',	'',	'[]',	'/Photos/Library.jpg',	'http://localhost/index.php/apps/files/?dir=/Photos',	'files',	51),
(95,	1757057754,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"51\":\"\\/Photos\\/Library.jpg\"}]',	'',	'[]',	'/Photos/Library.jpg',	'http://localhost/index.php/apps/files/?dir=/Photos',	'files',	51),
(96,	1757057754,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"52\":\"\\/Photos\\/Vineyard.jpg\"}]',	'',	'[]',	'/Photos/Vineyard.jpg',	'http://localhost/index.php/apps/files/?dir=/Photos',	'files',	52),
(97,	1757057754,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"52\":\"\\/Photos\\/Vineyard.jpg\"}]',	'',	'[]',	'/Photos/Vineyard.jpg',	'http://localhost/index.php/apps/files/?dir=/Photos',	'files',	52),
(98,	1757057754,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"53\":\"\\/Photos\\/Gorilla.jpg\"}]',	'',	'[]',	'/Photos/Gorilla.jpg',	'http://localhost/index.php/apps/files/?dir=/Photos',	'files',	53),
(99,	1757057755,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"53\":\"\\/Photos\\/Gorilla.jpg\"}]',	'',	'[]',	'/Photos/Gorilla.jpg',	'http://localhost/index.php/apps/files/?dir=/Photos',	'files',	53),
(100,	1757057755,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"54\":\"\\/Photos\\/Toucan.jpg\"}]',	'',	'[]',	'/Photos/Toucan.jpg',	'http://localhost/index.php/apps/files/?dir=/Photos',	'files',	54),
(101,	1757057755,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"54\":\"\\/Photos\\/Toucan.jpg\"}]',	'',	'[]',	'/Photos/Toucan.jpg',	'http://localhost/index.php/apps/files/?dir=/Photos',	'files',	54),
(102,	1757057755,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"55\":\"\\/Photos\\/Readme.md\"}]',	'',	'[]',	'/Photos/Readme.md',	'http://localhost/index.php/apps/files/?dir=/Photos',	'files',	55),
(103,	1757057755,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"55\":\"\\/Photos\\/Readme.md\"}]',	'',	'[]',	'/Photos/Readme.md',	'http://localhost/index.php/apps/files/?dir=/Photos',	'files',	55),
(104,	1757057755,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"56\":\"\\/Photos\\/Nextcloud community.jpg\"}]',	'',	'[]',	'/Photos/Nextcloud community.jpg',	'http://localhost/index.php/apps/files/?dir=/Photos',	'files',	56),
(105,	1757057756,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"56\":\"\\/Photos\\/Nextcloud community.jpg\"}]',	'',	'[]',	'/Photos/Nextcloud community.jpg',	'http://localhost/index.php/apps/files/?dir=/Photos',	'files',	56),
(106,	1757057756,	30,	'file_created',	'admin',	'admin',	'files',	'created_self',	'[{\"57\":\"\\/Nextcloud intro.mp4\"}]',	'',	'[]',	'/Nextcloud intro.mp4',	'http://localhost/index.php/apps/files/?dir=/',	'files',	57),
(107,	1757057756,	30,	'file_changed',	'admin',	'admin',	'files',	'changed_self',	'[{\"57\":\"\\/Nextcloud intro.mp4\"}]',	'',	'[]',	'/Nextcloud intro.mp4',	'http://localhost/index.php/apps/files/?dir=/',	'files',	57),
(108,	1757057756,	30,	'calendar',	'admin',	'admin',	'dav',	'calendar_add_self',	'{\"actor\":\"admin\",\"calendar\":{\"id\":1,\"uri\":\"personal\",\"name\":\"Personal\"}}',	'',	'[]',	'',	'',	'calendar',	1),
(109,	1757057756,	30,	'contacts',	'admin',	'admin',	'dav',	'addressbook_add_self',	'{\"actor\":\"admin\",\"addressbook\":{\"id\":2,\"uri\":\"contacts\",\"name\":\"Contacts\"}}',	'',	'[]',	'',	'',	'addressbook',	2);

DROP TABLE IF EXISTS `oc_activity_mq`;
CREATE TABLE `oc_activity_mq` (
  `mail_id` bigint NOT NULL AUTO_INCREMENT,
  `amq_timestamp` int NOT NULL DEFAULT '0',
  `amq_latest_send` int NOT NULL DEFAULT '0',
  `amq_type` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `amq_affecteduser` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `amq_appid` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `amq_subject` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `amq_subjectparams` longtext COLLATE utf8mb4_bin,
  `object_type` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `object_id` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`mail_id`),
  KEY `amp_user` (`amq_affecteduser`),
  KEY `amp_latest_send_time` (`amq_latest_send`),
  KEY `amp_timestamp_time` (`amq_timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_addressbookchanges`;
CREATE TABLE `oc_addressbookchanges` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `uri` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `synctoken` int unsigned NOT NULL DEFAULT '1',
  `addressbookid` bigint NOT NULL,
  `operation` smallint NOT NULL,
  `created_at` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `addressbookid_synctoken` (`addressbookid`,`synctoken`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_addressbooks`;
CREATE TABLE `oc_addressbooks` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `principaluri` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `displayname` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `uri` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `description` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `synctoken` int unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `addressbook_index` (`principaluri`,`uri`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_addressbooks` (`id`, `principaluri`, `displayname`, `uri`, `description`, `synctoken`) VALUES
(1,	'principals/system/system',	'system',	'system',	'System addressbook which holds all users of this instance',	1),
(2,	'principals/users/admin',	'Contacts',	'contacts',	NULL,	1);

DROP TABLE IF EXISTS `oc_appconfig`;
CREATE TABLE `oc_appconfig` (
  `appid` varchar(32) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `configkey` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `configvalue` longtext COLLATE utf8mb4_bin,
  `type` int unsigned NOT NULL DEFAULT '2',
  `lazy` smallint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`appid`,`configkey`),
  KEY `ac_lazy_i` (`lazy`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_appconfig` (`appid`, `configkey`, `configvalue`, `type`, `lazy`) VALUES
('activity',	'enabled',	'yes',	2,	0),
('activity',	'installed_version',	'4.0.0',	2,	0),
('activity',	'types',	'filesystem',	2,	0),
('app_api',	'enabled',	'yes',	2,	0),
('app_api',	'installed_version',	'5.0.2',	2,	0),
('app_api',	'types',	'',	2,	0),
('backgroundjob',	'lastjob',	'6',	2,	0),
('bruteforcesettings',	'enabled',	'yes',	2,	0),
('bruteforcesettings',	'installed_version',	'4.0.0',	2,	0),
('bruteforcesettings',	'types',	'',	2,	0),
('circles',	'enabled',	'yes',	2,	0),
('circles',	'installed_version',	'31.0.0',	2,	0),
('circles',	'loopback_tmp_scheme',	'http',	2,	0),
('circles',	'types',	'filesystem,dav',	2,	0),
('cloud_federation_api',	'enabled',	'yes',	2,	0),
('cloud_federation_api',	'installed_version',	'1.14.0',	2,	0),
('cloud_federation_api',	'types',	'filesystem',	2,	0),
('comments',	'enabled',	'yes',	2,	0),
('comments',	'installed_version',	'1.21.0',	2,	0),
('comments',	'types',	'logging',	2,	0),
('contactsinteraction',	'enabled',	'yes',	2,	0),
('contactsinteraction',	'installed_version',	'1.12.0',	2,	0),
('contactsinteraction',	'types',	'dav',	2,	0),
('core',	'files_metadata',	'{\"photos-original_date_time\":{\"value\":null,\"type\":\"int\",\"etag\":\"\",\"indexed\":true,\"editPermission\":0},\"photos-size\":{\"value\":null,\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0},\"photos-exif\":{\"value\":null,\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0},\"photos-ifd0\":{\"value\":null,\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0}}',	64,	1),
('core',	'installedat',	'1757057728.2789',	2,	0),
('core',	'lastcron',	'1757058486',	8,	0),
('core',	'lastupdatedat',	'1757057728',	8,	0),
('core',	'public_files',	'files_sharing/public.php',	2,	0),
('core',	'vendor',	'nextcloud',	2,	0),
('dashboard',	'enabled',	'yes',	2,	0),
('dashboard',	'installed_version',	'7.11.0',	2,	0),
('dashboard',	'types',	'',	2,	0),
('dav',	'enabled',	'yes',	2,	0),
('dav',	'installed_version',	'1.33.0',	2,	0),
('dav',	'types',	'filesystem',	2,	0),
('federatedfilesharing',	'enabled',	'yes',	2,	0),
('federatedfilesharing',	'installed_version',	'1.21.0',	2,	0),
('federatedfilesharing',	'types',	'',	2,	0),
('federation',	'enabled',	'yes',	2,	0),
('federation',	'installed_version',	'1.21.0',	2,	0),
('federation',	'types',	'authentication',	2,	0),
('files',	'enabled',	'yes',	2,	0),
('files',	'installed_version',	'2.3.1',	2,	0),
('files',	'types',	'filesystem',	2,	0),
('files_downloadlimit',	'enabled',	'yes',	2,	0),
('files_downloadlimit',	'installed_version',	'4.0.0',	2,	0),
('files_downloadlimit',	'types',	'',	2,	0),
('files_pdfviewer',	'enabled',	'yes',	2,	0),
('files_pdfviewer',	'installed_version',	'4.0.0',	2,	0),
('files_pdfviewer',	'types',	'',	2,	0),
('files_reminders',	'enabled',	'yes',	2,	0),
('files_reminders',	'installed_version',	'1.4.0',	2,	0),
('files_reminders',	'types',	'',	2,	0),
('files_sharing',	'enabled',	'yes',	2,	0),
('files_sharing',	'installed_version',	'1.23.1',	2,	0),
('files_sharing',	'types',	'filesystem',	2,	0),
('files_trashbin',	'enabled',	'yes',	2,	0),
('files_trashbin',	'installed_version',	'1.21.0',	2,	0),
('files_trashbin',	'types',	'filesystem,dav',	2,	0),
('files_versions',	'enabled',	'yes',	2,	0),
('files_versions',	'installed_version',	'1.24.0',	2,	0),
('files_versions',	'types',	'filesystem,dav',	2,	0),
('firstrunwizard',	'enabled',	'yes',	2,	0),
('firstrunwizard',	'installed_version',	'4.0.0',	2,	0),
('firstrunwizard',	'types',	'',	2,	0),
('logreader',	'enabled',	'yes',	2,	0),
('logreader',	'installed_version',	'4.0.0',	2,	0),
('logreader',	'types',	'logging',	2,	0),
('lookup_server_connector',	'enabled',	'yes',	2,	0),
('lookup_server_connector',	'installed_version',	'1.19.0',	2,	0),
('lookup_server_connector',	'types',	'authentication',	2,	0),
('nextcloud_announcements',	'enabled',	'yes',	2,	0),
('nextcloud_announcements',	'installed_version',	'3.0.0',	2,	0),
('nextcloud_announcements',	'pub_date',	'Thu, 24 Oct 2019 00:00:00 +0200',	2,	0),
('nextcloud_announcements',	'types',	'logging',	2,	0),
('notifications',	'enabled',	'yes',	2,	0),
('notifications',	'installed_version',	'4.0.0',	2,	0),
('notifications',	'types',	'logging',	2,	0),
('oauth2',	'enabled',	'yes',	2,	0),
('oauth2',	'installed_version',	'1.19.1',	2,	0),
('oauth2',	'types',	'authentication',	2,	0),
('password_policy',	'enabled',	'yes',	2,	0),
('password_policy',	'installed_version',	'3.0.0',	2,	0),
('password_policy',	'types',	'authentication',	2,	0),
('photos',	'enabled',	'yes',	2,	0),
('photos',	'installed_version',	'4.0.0',	2,	0),
('photos',	'lastPlaceMappedUser',	'admin',	2,	0),
('photos',	'lastPlaceMappingDone',	'true',	2,	0),
('photos',	'types',	'dav,authentication',	2,	0),
('privacy',	'enabled',	'yes',	2,	0),
('privacy',	'installed_version',	'3.0.0',	2,	0),
('privacy',	'types',	'',	2,	0),
('profile',	'enabled',	'yes',	2,	0),
('profile',	'installed_version',	'1.0.0',	2,	0),
('profile',	'types',	'',	2,	0),
('provisioning_api',	'enabled',	'yes',	2,	0),
('provisioning_api',	'installed_version',	'1.21.0',	2,	0),
('provisioning_api',	'types',	'prevent_group_restriction',	2,	0),
('recommendations',	'enabled',	'yes',	2,	0),
('recommendations',	'installed_version',	'4.0.0',	2,	0),
('recommendations',	'types',	'',	2,	0),
('related_resources',	'enabled',	'yes',	2,	0),
('related_resources',	'installed_version',	'2.0.0',	2,	0),
('related_resources',	'types',	'',	2,	0),
('serverinfo',	'enabled',	'yes',	2,	0),
('serverinfo',	'installed_version',	'3.0.0',	2,	0),
('serverinfo',	'types',	'',	2,	0),
('settings',	'enabled',	'yes',	2,	0),
('settings',	'installed_version',	'1.14.0',	2,	0),
('settings',	'types',	'',	2,	0),
('sharebymail',	'enabled',	'yes',	2,	0),
('sharebymail',	'installed_version',	'1.21.0',	2,	0),
('sharebymail',	'types',	'filesystem',	2,	0),
('support',	'enabled',	'yes',	2,	0),
('support',	'installed_version',	'3.0.0',	2,	0),
('support',	'types',	'session',	2,	0),
('survey_client',	'enabled',	'yes',	2,	0),
('survey_client',	'installed_version',	'3.0.0',	2,	0),
('survey_client',	'types',	'',	2,	0),
('systemtags',	'enabled',	'yes',	2,	0),
('systemtags',	'installed_version',	'1.21.1',	2,	0),
('systemtags',	'types',	'logging',	2,	0),
('text',	'enabled',	'yes',	2,	0),
('text',	'installed_version',	'5.0.0',	2,	0),
('text',	'types',	'dav',	2,	0),
('theming',	'enabled',	'yes',	2,	0),
('theming',	'installed_version',	'2.6.1',	2,	0),
('theming',	'types',	'logging',	2,	0),
('twofactor_backupcodes',	'enabled',	'yes',	2,	0),
('twofactor_backupcodes',	'installed_version',	'1.20.0',	2,	0),
('twofactor_backupcodes',	'types',	'',	2,	0),
('updatenotification',	'enabled',	'yes',	2,	0),
('updatenotification',	'installed_version',	'1.21.0',	2,	0),
('updatenotification',	'types',	'',	2,	0),
('user_status',	'enabled',	'yes',	2,	0),
('user_status',	'installed_version',	'1.11.0',	2,	0),
('user_status',	'types',	'',	2,	0),
('viewer',	'enabled',	'yes',	2,	0),
('viewer',	'installed_version',	'4.0.0',	2,	0),
('viewer',	'types',	'',	2,	0),
('weather_status',	'enabled',	'yes',	2,	0),
('weather_status',	'installed_version',	'1.11.0',	2,	0),
('weather_status',	'types',	'',	2,	0),
('webhook_listeners',	'enabled',	'yes',	2,	0),
('webhook_listeners',	'installed_version',	'1.2.0',	2,	0),
('webhook_listeners',	'types',	'filesystem',	2,	0),
('workflowengine',	'enabled',	'yes',	2,	0),
('workflowengine',	'installed_version',	'2.13.0',	2,	0),
('workflowengine',	'types',	'filesystem',	2,	0);

DROP TABLE IF EXISTS `oc_appconfig_ex`;
CREATE TABLE `oc_appconfig_ex` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `appid` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `configkey` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `configvalue` longtext COLLATE utf8mb4_bin,
  `sensitive` smallint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `appconfig_ex__idx` (`appid`,`configkey`),
  KEY `appconfig_ex__configkey` (`configkey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_authorized_groups`;
CREATE TABLE `oc_authorized_groups` (
  `id` int NOT NULL AUTO_INCREMENT,
  `group_id` varchar(200) COLLATE utf8mb4_bin NOT NULL,
  `class` varchar(200) COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`id`),
  KEY `admindel_groupid_idx` (`group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_authtoken`;
CREATE TABLE `oc_authtoken` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `uid` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `login_name` varchar(255) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `password` longtext COLLATE utf8mb4_bin,
  `name` longtext COLLATE utf8mb4_bin NOT NULL,
  `token` varchar(200) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `type` smallint unsigned DEFAULT '0',
  `remember` smallint unsigned DEFAULT '0',
  `last_activity` int unsigned DEFAULT '0',
  `last_check` int unsigned DEFAULT '0',
  `scope` longtext COLLATE utf8mb4_bin,
  `expires` int unsigned DEFAULT NULL,
  `private_key` longtext COLLATE utf8mb4_bin,
  `public_key` longtext COLLATE utf8mb4_bin,
  `version` smallint unsigned NOT NULL DEFAULT '1',
  `password_invalid` tinyint(1) DEFAULT '0',
  `password_hash` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `authtoken_token_index` (`token`),
  KEY `authtoken_last_activity_idx` (`last_activity`),
  KEY `authtoken_uid_index` (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_authtoken` (`id`, `uid`, `login_name`, `password`, `name`, `token`, `type`, `remember`, `last_activity`, `last_check`, `scope`, `expires`, `private_key`, `public_key`, `version`, `password_invalid`, `password_hash`) VALUES
(1,	'admin',	'admin',	'DNzO4ZKUgIJx+zxXvTMndwZ6XpPZJqS5CnooCMrvsG0tY8N2KcT3PvmQ4C0khnEPBSta5PtDHgZnDF4tYWnDqzR3Ul+grtCZOMqdUQZVw+2iI3YtUUClHrV35kxcMrcyYkIsh4y5432G0ohW5c8dh3PEBL0fC0L/8nC+MQQoRZsJB9r9bCI58VMXA3IlaOxdzgRZJV9RlGmNmXqhvHMYx1KBEzn713RZJzsF+E6wPeeZx6dFbLATOh1DIg49iYjluAJnw8ivwtHywmzJqVLv5/w//HwreJZycpR8MInnMGF5em7ZDRMgRvO51RQKFmF4R4K4vfF5dLd4tKQyoHKIIA==',	'Mozilla/5.0 (X11; Linux x86_64; rv:142.0) Gecko/20100101 Firefox/142.0',	'42861cdd45f70c2db7a6998686e9f273cc7e54abea88d95560cc0c2d10efad6d6b641d3cae3bbaccf4d85ea239bfbb7e22f7cfe8d053464df7e6471c0c313d9a',	0,	1,	1757058419,	1757058419,	NULL,	NULL,	'f292eae16af18f5bd58a4d1210ceaefd240db5239262232c4fdf10c529434c5f8ba8f4c5d43a0446f9042e737753359482d29863f480cf151c4a4958dd80fb0dfd9955127726bef884cb7069217793f54dae2fb24e7c0434daac6fa1db00be7e570334e33687e714a0033e6d2fff604ca84e1a5c74008fcd1230971a0a003e3cbeb1c96fa4580f3f1a48cdb767c469775453b7f66388212d14c91e5766ba874586d70e115efb107b967bdfcd262806d0914709308ce8f9c68dbe5c249453a069f47f3679e5dd736bfb5c3ac2957c3eeca77c97764bfce44c788fda23cab086d614754ba57ba68fd294b9575e069f4675a4c1957569a3607a63c6b745b31db92e07568f3371dc6e8cc9fdd0f60f61527aec164e828c8a906428c30c8a5d4ebca79a075e0110ad9cb027d747f6bdb8c0ce178ead3c8eb9aca25fd7625cd2d2579b3a90c4d956cbbd7cbdf28b75dac7f492a867d2bcaf227ac2934b5082695296d8d113ef5140548553dd5cf4be5e9a1ab463fd78a1ee251d160b4c57c5c2026c8c649d769ec32101f71753bc1f2ac119cc922418d5451aa31d84b76fbdba9f1d82c340bdcec501ecc1f479edfb986376efa1ec42a19014e9fe370a86f2569482dc5e526eb1c4bc35538d16ed8758282d58f2d921173f85fa78ba5b494a8e504cfa318e547edf7856cbb55583513597ed33944ad1bd984483b69fdbd22e5eb042ca65d522ddb36c13bdcd97d59ab278cc12e7fdc56f4823f25598a1688b6565e1113d8fef6de8314aea7fabe31e13abf58e4d34cc64e63b0e6f046d3b50e15ac0814d2676a6cf283f3bafb5af97ca7364a2cd8d7d9b712d3fe5be8738d1685cb58a24cbced767243dca0e21a50b346a8558fbfc3e2d76c36b2d37114dc528dd51253de84db6177c0b5ce191ef67e8edeb2852aa0f52c8a4d511a16885ec41da72d54d8714dcf166085468d148257adf92e1f9baaccfa89d5e4c3f4f2e360370d93baaab69ec37660dd4f41455cb6ad5057710f917d82850a8f621b04c8dbeac8d08492bfc06441b36cc92c2533666e713fccf7655624a94d415ebd8b6f094ef6bd4fe8a80ed57b3e65d71adef5441cb2dfe5b0479903f4790eda19f836447e49fb2cbb4b34b664977293052167482b2ee3553248d1695f24e319758430feb0f1ce9aa91256ddeeaffd0febe8797fb783b693d1f88f7ed19105e2cc9736f1b0a45bab27f9dc5d0e59850dc6b49cb0c5f3a8a484ab1a599c28100c0ba9b326b6819a74ba98b5b2b2ebceda06b9e20827af55b846d403b25c4c3d9a43cc30f48b487107c30ee756194dcaa2cd295eb0f73dd172e64a121770aefc749fc4606639e4d8f74c94a983ba2b06c93d9170f240036caacf70cbf6c5a2cdbb8bb9a72c071ff72fdaedbe75a7f1034854ed4426c9309e13f28b2b5a091b1f446f41d37943155613d82194000744576d9afe0de9fa56a2ba23f73eca3f37532194fa4662820f2ec627e763e2390373ffde46da8be38d79e9ad16cb588e773f646f1eb2edaaa4c0cc998749979b5a9d192965e4d3abac8e7470d161fd1a3d3801f7dfa5f826d40e719685ad6e740d8258ca9299191bc31c9fcac51b5976053b58e18cdbaa68f387509f053e6a20bdbc273afa4720d4d24b59ed2bf6f2ea238bce554f3de4fbf1a4175ebd339d2f031f726b934c500ab0f5d6c8a70cab3d7989c3974a427c8f3c019a526e57ea70d65de2254435d15b7d81b03c86370312f85e66ec7d4d38d8a5e0b942912501e4f0fc841311e5d844ae581be7921590a04970011335bea4fe47e0011413e665202c789606333c16f348003dd938b4eae871fa9b0b1b5f94573b9c438a5a53d2897ed8a5d1590c9249211e48349d4641fb78110d82290368787f18660c376456c615cc52fea57e46092516f44e7e3d45f5a44fdca2a84cf28a4afcf0bba0feb44ea633cf5092f75f297ad7f1196a3cdec8f5228f08ad04dcea3ee48eafa65936636004ca71710c3862a1529d0fcf818928db677206fc3cbde5e1397b8b799a402ba4dc827d2df619107d98c95c10f8bfec485185297ff4719073149b10fd632940bc9c2cfb007a0eee56ec1abdd4757e4c49807f87b337351a1dcf3b76c4316e0395674a1d1d0934ebf63ff4e34d409483051217a46e81911730d5b7a961df8d546297a5c9a19d5d963c1af7c520ea37d5f6c6e2c4714975047e988ec2037484c13a63c4642577b8a70f7e45320472ca4d840b79ed3f5c5ea6344294400d85f6d79a86e889a60af6475a641bea9d92c02e2b319dfb623b402f21e96b387323a43b61dc876a541961ce25007bb89bcef68dfd045212ace6c9d0e760fba69b11a0b78c0fc70f5569b4293d794ba561c70732ebd914df380b81fe4887004d43dd10723bd973d65828393082d94|d7e8d663afcecce00551f3ff0ef7c327|c96c8a3f9fc6108af28b01c756e4eb6f4d27528455f38e2e7f54645993c6c5df57c213cefe45015afdbbf926a9f21dcedd0c1ddb327ebdd6bcbf0366345143c6|3',	'-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsjc9av407bYKs2irdXW+\nHWVmptgn1nPPLKzsFP7AV9Qqmo6nani/08nhn0qiB4bQfoGOSL4MJg2XEUWtN576\nDHoFlcy6rvWU3UMBTqQ0Ftanxo2IYIUMntKPnF8roVTvW5f1CDZiwDZwtEQWf1eF\nhhPHv+Tgv1QxQznCYpB49xq2OsfU0ZkJSYrpZ7TLa1ebqQtXBFZFSQIpX4vR79Aw\n+RLU/s/uKsXSwlaQBLWV6ajv1t2pq5S7cNmknAQ+aaSWEeqfTNW4yp41+ly4WZoG\nTwanUTr7xb7W5ohUNcCV0j6EhgRaSiUGKDgxYKr6R+/Bi9gfdBnH55uxXBPS2I/V\nTwIDAQAB\n-----END PUBLIC KEY-----\n',	2,	0,	'3|$argon2id$v=19$m=65536,t=4,p=1$cmkyNnNOUmhkVTZ1ZzZOdw$5woaBX5d/5r9RawgAjc6BpZWdjpfGWK6bFXdMSjhL64'),
(2,	'admin',	'admin',	'RRWQ7Rzh2LoG5imdwsVFJMADyVuJoJOdappyGgzRb2FzpUMvEQzwd/m5olrmFsRgfiCujjsK/dhhQDA3nnWc9cSmb6EAvtECukbfkNSGb+ZdVOv9+GVqyeovUlqRJPAhWhIoC0OIcAy0TTK6M0ddSmSm9pl9NhfAT6O1gRyvMV74gqrA3pbYVtkAYfFOTfQt1HaGO5neTA+c2HyvC3K2ZHX37ZAmRfOFjkAaa1QvvEQ+3+CV92btaFtmp8BYv991HcGntf8EsdDqG1X7D7oRMHGB4fHMtvaFptJRrTTJ7ctGKa69XUFVU9c7COhI/1YDIN6CzB6Xo/Uicb5/HkXWzw==',	'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36',	'6ba13373d364fc96b62c3ff3f2a0b2dced34d898b884987ea8161444394dd04a4e0d3c5036378fe87ba45f374fd90f385394091b7dfe154b218fe894623414f4',	0,	1,	1757058539,	1757058476,	NULL,	NULL,	'668ef06d2bc96e30a5aba833999afd9bc35187fcd0e38e262ab685ba2f0fdfd59b02561be4ef29cdb76b44f4ed64a95417b5c2321dcc8c06b9404122bed890124d60af14fe89190776f97e35378550cbbad872be14723d6b7b93bc538eb83d0820a471c9e0119830366899f1049ecebae3fef73130d8f9c572a1cbb35b4753cf05e503f300fd24f2fed61b591be8e56df36acc4bebf7ef7872547397e340664d6e2c2152c0c4cfbadff773af2aafee383cab6e323d4954940c28b65a3a5f7ac8b89bcec7edddcfef72bc1de6da0c6a63931ba74ddc443d7bb6058a567b5a554aa42236a24bfda62cb79bc2421c6e67cfdefef301acf28a8dc75d96d48d1a2b395fe9e5e02a466541bfed25de1c8df992a1e4f34f059e409f4e9a3800afc8d09d4f2df90e9ef5ba3b27f059e038918f28e2567803529efed5edc4602d9255316451ebc70c9939f10243307baf7a6b693b34085823cee8b3295d547b55daef1cf7c0932a5c88b5ed6dbf4e196a8dce180a9419fd594702f703669f45f80051d56bb08671e0c7b24923a4ded6a512828e2ce0839cff1ca220b05f18bb988b69734e7a96bbefbe55511b93ae2f5dc6fe76459af6b9c71ff84c203c4c30abb451447b8b4b3e85ef58852904e865349afcf0b3f2827c432ecbe08c3582be1296cfba23d432c440bdaac0005b6a9d4269610390b8e58c2fbf827465d0381ec7088fb8486e656e3888301ec2c3df63bf765b8be520405410c999fb9ae4d3b2464375ab5fc3446240097ecf33ab4c76ce2369ca3a1407cee7acc4e74a099647c1a2b76ccb0f3184e2fd0449c28a029afa25d456b169216fc3581ead8e5972be6e8828e364c68687a188b4645a352243fcad5984b71f10f69af90ef4c71ea0642b38527b9d54a9bf5f548501bfb2b5ed5d3b3a547bc09d226f2d083e1813e9f500a4f2782e7a2911c2b444c8313a91a0151a353e6450fd1b02c951df0ad4076152192e12ab40d0adc089935a6b5b873dbfddad305fa0611d82d04a1dc722c4668d0fdb6b5c69296f351bc45069a314d4e8e90cbb1b66a2569eafc125850a798a390673382c15ef256481bd6cca12d1ad12b94500c81a8da6c12e8cdfd7c7134cef225b7bd5c91729faf2aee40c9f7c546db05efdd6162508175803ec81496e83ffe4e6da431523dca9760cb57166ff7434a64bf6ecd007629f394a99322a439d05090a3513dbf3c0ec47165985c97ab52b904c0a8a6f953400b3247cd9dd288417e748ecb7041a230dcf03462fa295a735950c3119fbbd7d3d53796bf204973346ef7d14c6156253feeca60da7c56350b0c67d7d74fdf1977fc01167221b7b626a0818a7c22825c0f4778f6ecc428ba185f57a2f233ca612a413e5e4a7c1eb8adc1d4d951bc3fed0da4ee52764c7bf12eb5fb14770bb18b87e43692c7be2b547fbc27a7ee5959593d8cd08bb039a3e42980d58465e03ea8e05c160316fd6ce2b4b1752553a9175c7366f2528e827dd678c6e1c8325018142535f7c73fd037762f99468c9636a8ff6c4796c9c1331f9d02ae7c00964ba0878b28fa6a8043121e39e7c2ae85261368c5b3ac376c36b325971313099383f0a3655872129aa377594cbe2c66563a720916a2723b93d339986a4e937e68d9ec1c6f739d0d6687c855aad97ba79ba3995e75675dc9799989160dd4afc5bda323371b1fb14d9b7d0a28e90366c9de2ed1dec2d239c5f1e5b1c1aa56a62792600f1cad1ec3d3261bad32e6c54df5fb5567046b438b91475ed6d13853f7063b25726dc3a9633dfc56e7b764facb7e99ca005c3f55286529fa6947dcc08b4bd67974aa83b0f12c0733d01653635ff94eb6c47d9b9f4cc11ddd58224b2ef28bfbb3a19efdffe9de858b1c770b0487a11a7a26fbbd099e4be255d35b83ec3adb1d4e3257029dbc59e1f451df5829d6250de0732e935d6996422b6d2e8a5cca81dfebf45d4182842276c3aca5410489537a8e954a3758de6a0832944b247c9b7f3761d34893b99b2693aa0f53f39d79454854a3c4b51fd780e00604d3d66f52dc8c1b4e43aa232b6397b9db20c0f5e920ae2623edc7ad8bc26adcb3508bdec1a4f89bde6e7f5d6e5417e95f3cc4fcb3aae0d591625d1bf7883b7e2a0988f3a8282759e8a30a1baa83cb79fdb8cc9902fb6e34e354fb009cc3f5a4958e99de00bc22fe4596dc42cc30adfa8afcf7b0e67166dba7d6306e61cdc3386d52c7f114d78f5e38f38942be409c0150d2d447057ecbce161bebccde4594b774aed2842ac021fb61e5f907ab00019d752738b9b303966fb51a7092c9cd9f749bba452c5085aee1b74e1394228727e1ae2f7f8910317a4595347b90b1d7707481090655cf4ebfdee504ba6bc86967a47e00dcc35aa5acb5713f25288e5776e3b3056c2cbae39ef|5a80392607c364fa9aee5534bb277f00|d6634daf1085203656c0a3f875afee2176fc28da5589bb49d6589c14bd0acdf05c9ca3bdd1b998bf1fd7478ab33b9e2132ed480fea23d17102b1c7f7b193725e|3',	'-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvXDyeOncEsUjk0vo3Nx8\nGPF/mC9idilOTotz7pxa8gCnwPay2aBhGPr6R91jC1VI4jaMtVXryJBb/ss0Cy8J\nEifY5EihH02cnjk2kf9EQtQUSy2YeQTwlI0YxYaoRcwq4Em1a5/9qIRLMHIemnom\njU5uqnDFZityD1CvoVOwwI9V++01SaosagT2+AU8u5HUGTTiCvLJqHjWTdSPVdix\nnYeCvSt8DwNapDpR+aNZk77rKnZlzj8Y4k9Qrug4Jgs1ldOQMR16RF5/dSPXwGwc\nkPYkQ6VGMml21dx3zaqdMg+X2+nfcHDvJQmVQiMscHnTeAnMSm2fO9QLYq2624Vk\n+wIDAQAB\n-----END PUBLIC KEY-----\n',	2,	0,	'3|$argon2id$v=19$m=65536,t=4,p=1$cmkyNnNOUmhkVTZ1ZzZOdw$5woaBX5d/5r9RawgAjc6BpZWdjpfGWK6bFXdMSjhL64');

DROP TABLE IF EXISTS `oc_bruteforce_attempts`;
CREATE TABLE `oc_bruteforce_attempts` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `action` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `occurred` int unsigned NOT NULL DEFAULT '0',
  `ip` varchar(255) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `subnet` varchar(255) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `metadata` varchar(255) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `bruteforce_attempts_ip` (`ip`),
  KEY `bruteforce_attempts_subnet` (`subnet`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_calendar_invitations`;
CREATE TABLE `oc_calendar_invitations` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `uid` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `recurrenceid` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `attendee` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `organizer` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `sequence` bigint unsigned DEFAULT NULL,
  `token` varchar(60) COLLATE utf8mb4_bin NOT NULL,
  `expiration` bigint unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `calendar_invitation_tokens` (`token`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_calendar_reminders`;
CREATE TABLE `oc_calendar_reminders` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `calendar_id` bigint NOT NULL,
  `object_id` bigint NOT NULL,
  `is_recurring` smallint DEFAULT NULL,
  `uid` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `recurrence_id` bigint unsigned DEFAULT NULL,
  `is_recurrence_exception` smallint NOT NULL,
  `event_hash` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `alarm_hash` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `type` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `is_relative` smallint NOT NULL,
  `notification_date` bigint unsigned NOT NULL,
  `is_repeat_based` smallint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `calendar_reminder_objid` (`object_id`),
  KEY `calendar_reminder_uidrec` (`uid`,`recurrence_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_calendar_resources`;
CREATE TABLE `oc_calendar_resources` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `backend_id` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `resource_id` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `displayname` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `group_restrictions` varchar(4000) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `calendar_resources_bkdrsc` (`backend_id`,`resource_id`),
  KEY `calendar_resources_email` (`email`),
  KEY `calendar_resources_name` (`displayname`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_calendar_resources_md`;
CREATE TABLE `oc_calendar_resources_md` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `resource_id` bigint unsigned NOT NULL,
  `key` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `value` varchar(4000) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `calendar_resources_md_idk` (`resource_id`,`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_calendar_rooms`;
CREATE TABLE `oc_calendar_rooms` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `backend_id` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `resource_id` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `displayname` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `group_restrictions` varchar(4000) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `calendar_rooms_bkdrsc` (`backend_id`,`resource_id`),
  KEY `calendar_rooms_email` (`email`),
  KEY `calendar_rooms_name` (`displayname`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_calendar_rooms_md`;
CREATE TABLE `oc_calendar_rooms_md` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `room_id` bigint unsigned NOT NULL,
  `key` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `value` varchar(4000) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `calendar_rooms_md_idk` (`room_id`,`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_calendarchanges`;
CREATE TABLE `oc_calendarchanges` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `uri` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `synctoken` int unsigned NOT NULL DEFAULT '1',
  `calendarid` bigint NOT NULL,
  `operation` smallint NOT NULL,
  `calendartype` int NOT NULL DEFAULT '0',
  `created_at` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `calid_type_synctoken` (`calendarid`,`calendartype`,`synctoken`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_calendarobjects`;
CREATE TABLE `oc_calendarobjects` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `calendardata` longblob,
  `uri` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `calendarid` bigint unsigned NOT NULL,
  `lastmodified` int unsigned DEFAULT NULL,
  `etag` varchar(32) COLLATE utf8mb4_bin DEFAULT NULL,
  `size` bigint unsigned NOT NULL,
  `componenttype` varchar(8) COLLATE utf8mb4_bin DEFAULT NULL,
  `firstoccurence` bigint unsigned DEFAULT NULL,
  `lastoccurence` bigint unsigned DEFAULT NULL,
  `uid` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `classification` int DEFAULT '0',
  `calendartype` int NOT NULL DEFAULT '0',
  `deleted_at` int unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `calobjects_index` (`calendarid`,`calendartype`,`uri`),
  KEY `calobj_clssfction_index` (`classification`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_calendarobjects_props`;
CREATE TABLE `oc_calendarobjects_props` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `calendarid` bigint NOT NULL DEFAULT '0',
  `objectid` bigint unsigned NOT NULL DEFAULT '0',
  `name` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `parameter` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `value` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `calendartype` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `calendarobject_index` (`objectid`,`calendartype`),
  KEY `calendarobject_name_index` (`name`,`calendartype`),
  KEY `calendarobject_value_index` (`value`,`calendartype`),
  KEY `calendarobject_calid_index` (`calendarid`,`calendartype`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_calendars`;
CREATE TABLE `oc_calendars` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `principaluri` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `displayname` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `uri` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `synctoken` int unsigned NOT NULL DEFAULT '1',
  `description` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `calendarorder` int unsigned NOT NULL DEFAULT '0',
  `calendarcolor` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `timezone` longtext COLLATE utf8mb4_bin,
  `components` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `transparent` smallint NOT NULL DEFAULT '0',
  `deleted_at` int unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `calendars_index` (`principaluri`,`uri`),
  KEY `cals_princ_del_idx` (`principaluri`,`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_calendars` (`id`, `principaluri`, `displayname`, `uri`, `synctoken`, `description`, `calendarorder`, `calendarcolor`, `timezone`, `components`, `transparent`, `deleted_at`) VALUES
(1,	'principals/users/admin',	'Personal',	'personal',	1,	NULL,	0,	'#00679e',	NULL,	'VEVENT',	0,	NULL);

DROP TABLE IF EXISTS `oc_calendarsubscriptions`;
CREATE TABLE `oc_calendarsubscriptions` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `uri` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `principaluri` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `displayname` varchar(100) COLLATE utf8mb4_bin DEFAULT NULL,
  `refreshrate` varchar(10) COLLATE utf8mb4_bin DEFAULT NULL,
  `calendarorder` int unsigned NOT NULL DEFAULT '0',
  `calendarcolor` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `striptodos` smallint DEFAULT NULL,
  `stripalarms` smallint DEFAULT NULL,
  `stripattachments` smallint DEFAULT NULL,
  `lastmodified` int unsigned DEFAULT NULL,
  `synctoken` int unsigned NOT NULL DEFAULT '1',
  `source` longtext COLLATE utf8mb4_bin,
  PRIMARY KEY (`id`),
  UNIQUE KEY `calsub_index` (`principaluri`,`uri`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_cards`;
CREATE TABLE `oc_cards` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `addressbookid` bigint NOT NULL DEFAULT '0',
  `carddata` longblob,
  `uri` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `lastmodified` bigint unsigned DEFAULT NULL,
  `etag` varchar(32) COLLATE utf8mb4_bin DEFAULT NULL,
  `size` bigint unsigned NOT NULL,
  `uid` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `cards_abiduri` (`addressbookid`,`uri`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_cards_properties`;
CREATE TABLE `oc_cards_properties` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `addressbookid` bigint NOT NULL DEFAULT '0',
  `cardid` bigint unsigned NOT NULL DEFAULT '0',
  `name` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `value` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `preferred` int NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  KEY `card_contactid_index` (`cardid`),
  KEY `card_name_index` (`name`),
  KEY `card_value_index` (`value`),
  KEY `cards_prop_abid_name_value` (`addressbookid`,`name`,`value`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_circles_circle`;
CREATE TABLE `oc_circles_circle` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `unique_id` varchar(31) COLLATE utf8mb4_bin NOT NULL,
  `name` varchar(127) COLLATE utf8mb4_bin NOT NULL,
  `display_name` varchar(255) COLLATE utf8mb4_bin DEFAULT '',
  `sanitized_name` varchar(127) COLLATE utf8mb4_bin DEFAULT '',
  `instance` varchar(255) COLLATE utf8mb4_bin DEFAULT '',
  `config` int unsigned DEFAULT NULL,
  `source` int unsigned DEFAULT NULL,
  `settings` longtext COLLATE utf8mb4_bin,
  `description` longtext COLLATE utf8mb4_bin,
  `creation` datetime DEFAULT NULL,
  `contact_addressbook` int unsigned DEFAULT NULL,
  `contact_groupname` varchar(127) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQ_8195F548E3C68343` (`unique_id`),
  KEY `IDX_8195F548D48A2F7C` (`config`),
  KEY `IDX_8195F5484230B1DE` (`instance`),
  KEY `IDX_8195F5485F8A7F73` (`source`),
  KEY `IDX_8195F548C317B362` (`sanitized_name`),
  KEY `dname` (`display_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_circles_circle` (`id`, `unique_id`, `name`, `display_name`, `sanitized_name`, `instance`, `config`, `source`, `settings`, `description`, `creation`, `contact_addressbook`, `contact_groupname`) VALUES
(1,	'lgzejh3hCtzIn1QorgUYOzNiLlqQhZH',	'user:admin:lgzejh3hCtzIn1QorgUYOzNiLlqQhZH',	'admin',	'',	'',	1,	1,	'[]',	'',	'2025-09-05 07:35:41',	0,	''),
(2,	'hObUAx1xp8X7E1znu7Xw49EySt3J149',	'app:circles:hObUAx1xp8X7E1znu7Xw49EySt3J149',	'Circles',	'',	'',	8193,	10001,	'[]',	'',	'2025-09-05 07:35:41',	0,	'');

DROP TABLE IF EXISTS `oc_circles_event`;
CREATE TABLE `oc_circles_event` (
  `token` varchar(63) COLLATE utf8mb4_bin NOT NULL,
  `instance` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `event` longtext COLLATE utf8mb4_bin,
  `result` longtext COLLATE utf8mb4_bin,
  `interface` int NOT NULL DEFAULT '0',
  `severity` int DEFAULT NULL,
  `retry` int DEFAULT NULL,
  `status` int DEFAULT NULL,
  `updated` datetime DEFAULT NULL,
  `creation` bigint DEFAULT NULL,
  PRIMARY KEY (`token`,`instance`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_circles_member`;
CREATE TABLE `oc_circles_member` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `single_id` varchar(31) COLLATE utf8mb4_bin DEFAULT NULL,
  `circle_id` varchar(31) COLLATE utf8mb4_bin NOT NULL,
  `member_id` varchar(31) COLLATE utf8mb4_bin DEFAULT NULL,
  `user_id` varchar(127) COLLATE utf8mb4_bin NOT NULL,
  `user_type` smallint NOT NULL DEFAULT '1',
  `instance` varchar(255) COLLATE utf8mb4_bin DEFAULT '',
  `invited_by` varchar(31) COLLATE utf8mb4_bin DEFAULT NULL,
  `level` smallint NOT NULL,
  `status` varchar(15) COLLATE utf8mb4_bin DEFAULT NULL,
  `note` longtext COLLATE utf8mb4_bin,
  `cached_name` varchar(255) COLLATE utf8mb4_bin DEFAULT '',
  `cached_update` datetime DEFAULT NULL,
  `contact_id` varchar(127) COLLATE utf8mb4_bin DEFAULT NULL,
  `contact_meta` longtext COLLATE utf8mb4_bin,
  `joined` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `circles_member_cisiuiutil` (`circle_id`,`single_id`,`user_id`,`user_type`,`instance`,`level`),
  KEY `circles_member_cisi` (`circle_id`,`single_id`),
  KEY `IDX_25C66A49E7A1254A` (`contact_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_circles_member` (`id`, `single_id`, `circle_id`, `member_id`, `user_id`, `user_type`, `instance`, `invited_by`, `level`, `status`, `note`, `cached_name`, `cached_update`, `contact_id`, `contact_meta`, `joined`) VALUES
(1,	'hObUAx1xp8X7E1znu7Xw49EySt3J149',	'hObUAx1xp8X7E1znu7Xw49EySt3J149',	'hObUAx1xp8X7E1znu7Xw49EySt3J149',	'circles',	10000,	'',	NULL,	9,	'Member',	'[]',	'Circles',	'2025-09-05 07:35:41',	'',	NULL,	'2025-09-05 07:35:41'),
(2,	'lgzejh3hCtzIn1QorgUYOzNiLlqQhZH',	'lgzejh3hCtzIn1QorgUYOzNiLlqQhZH',	'lgzejh3hCtzIn1QorgUYOzNiLlqQhZH',	'admin',	1,	'',	'hObUAx1xp8X7E1znu7Xw49EySt3J149',	9,	'Member',	'[]',	'admin',	'2025-09-05 07:35:41',	'',	NULL,	'2025-09-05 07:35:41');

DROP TABLE IF EXISTS `oc_circles_membership`;
CREATE TABLE `oc_circles_membership` (
  `circle_id` varchar(31) COLLATE utf8mb4_bin NOT NULL,
  `single_id` varchar(31) COLLATE utf8mb4_bin NOT NULL,
  `level` int unsigned NOT NULL,
  `inheritance_first` varchar(31) COLLATE utf8mb4_bin NOT NULL,
  `inheritance_last` varchar(31) COLLATE utf8mb4_bin NOT NULL,
  `inheritance_depth` int unsigned NOT NULL,
  `inheritance_path` longtext COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`single_id`,`circle_id`),
  KEY `IDX_8FC816EAE7C1D92B` (`single_id`),
  KEY `circles_membership_ifilci` (`inheritance_first`,`inheritance_last`,`circle_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_circles_membership` (`circle_id`, `single_id`, `level`, `inheritance_first`, `inheritance_last`, `inheritance_depth`, `inheritance_path`) VALUES
('hObUAx1xp8X7E1znu7Xw49EySt3J149',	'hObUAx1xp8X7E1znu7Xw49EySt3J149',	9,	'hObUAx1xp8X7E1znu7Xw49EySt3J149',	'hObUAx1xp8X7E1znu7Xw49EySt3J149',	1,	'[\"hObUAx1xp8X7E1znu7Xw49EySt3J149\"]'),
('lgzejh3hCtzIn1QorgUYOzNiLlqQhZH',	'lgzejh3hCtzIn1QorgUYOzNiLlqQhZH',	9,	'lgzejh3hCtzIn1QorgUYOzNiLlqQhZH',	'lgzejh3hCtzIn1QorgUYOzNiLlqQhZH',	1,	'[\"lgzejh3hCtzIn1QorgUYOzNiLlqQhZH\"]');

DROP TABLE IF EXISTS `oc_circles_mount`;
CREATE TABLE `oc_circles_mount` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `mount_id` varchar(31) COLLATE utf8mb4_bin NOT NULL,
  `circle_id` varchar(31) COLLATE utf8mb4_bin NOT NULL,
  `single_id` varchar(31) COLLATE utf8mb4_bin NOT NULL,
  `token` varchar(63) COLLATE utf8mb4_bin DEFAULT NULL,
  `parent` int DEFAULT NULL,
  `mountpoint` longtext COLLATE utf8mb4_bin,
  `mountpoint_hash` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `circles_mount_cimipt` (`circle_id`,`mount_id`,`parent`,`token`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_circles_mountpoint`;
CREATE TABLE `oc_circles_mountpoint` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `mount_id` varchar(31) COLLATE utf8mb4_bin NOT NULL,
  `single_id` varchar(31) COLLATE utf8mb4_bin NOT NULL,
  `mountpoint` longtext COLLATE utf8mb4_bin,
  `mountpoint_hash` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `mp_sid_hash` (`single_id`,`mountpoint_hash`),
  KEY `circles_mountpoint_ms` (`mount_id`,`single_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_circles_remote`;
CREATE TABLE `oc_circles_remote` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `type` varchar(15) COLLATE utf8mb4_bin NOT NULL DEFAULT 'Unknown',
  `interface` int NOT NULL DEFAULT '0',
  `uid` varchar(20) COLLATE utf8mb4_bin DEFAULT NULL,
  `instance` varchar(127) COLLATE utf8mb4_bin DEFAULT NULL,
  `href` varchar(254) COLLATE utf8mb4_bin DEFAULT NULL,
  `item` longtext COLLATE utf8mb4_bin,
  `creation` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQ_F94EF834230B1DE` (`instance`),
  KEY `IDX_F94EF83539B0606` (`uid`),
  KEY `IDX_F94EF8334F8E741` (`href`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_circles_share_lock`;
CREATE TABLE `oc_circles_share_lock` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `item_id` varchar(31) COLLATE utf8mb4_bin NOT NULL,
  `circle_id` varchar(31) COLLATE utf8mb4_bin NOT NULL,
  `instance` varchar(127) COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UNIQ_337F52F8126F525E70EE2FF6` (`item_id`,`circle_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_circles_token`;
CREATE TABLE `oc_circles_token` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `share_id` int DEFAULT NULL,
  `circle_id` varchar(31) COLLATE utf8mb4_bin DEFAULT NULL,
  `single_id` varchar(31) COLLATE utf8mb4_bin DEFAULT NULL,
  `member_id` varchar(31) COLLATE utf8mb4_bin DEFAULT NULL,
  `token` varchar(31) COLLATE utf8mb4_bin DEFAULT NULL,
  `password` varchar(127) COLLATE utf8mb4_bin DEFAULT NULL,
  `accepted` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `sicisimit` (`share_id`,`circle_id`,`single_id`,`member_id`,`token`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_collres_accesscache`;
CREATE TABLE `oc_collres_accesscache` (
  `user_id` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `collection_id` bigint NOT NULL DEFAULT '0',
  `resource_type` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `resource_id` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `access` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`user_id`,`collection_id`,`resource_type`,`resource_id`),
  KEY `collres_user_res` (`user_id`,`resource_type`,`resource_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_collres_collections`;
CREATE TABLE `oc_collres_collections` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_collres_resources`;
CREATE TABLE `oc_collres_resources` (
  `collection_id` bigint NOT NULL,
  `resource_type` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `resource_id` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`collection_id`,`resource_type`,`resource_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_comments`;
CREATE TABLE `oc_comments` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `parent_id` bigint unsigned NOT NULL DEFAULT '0',
  `topmost_parent_id` bigint unsigned NOT NULL DEFAULT '0',
  `children_count` int unsigned NOT NULL DEFAULT '0',
  `actor_type` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `actor_id` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `message` longtext COLLATE utf8mb4_bin,
  `verb` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `creation_timestamp` datetime DEFAULT NULL,
  `latest_child_timestamp` datetime DEFAULT NULL,
  `object_type` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `object_id` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `reference_id` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `reactions` varchar(4000) COLLATE utf8mb4_bin DEFAULT NULL,
  `expire_date` datetime DEFAULT NULL,
  `meta_data` longtext COLLATE utf8mb4_bin,
  PRIMARY KEY (`id`),
  KEY `comments_parent_id_index` (`parent_id`),
  KEY `comments_topmost_parent_id_idx` (`topmost_parent_id`),
  KEY `comments_object_index` (`object_type`,`object_id`,`creation_timestamp`),
  KEY `comments_actor_index` (`actor_type`,`actor_id`),
  KEY `expire_date` (`expire_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_comments_read_markers`;
CREATE TABLE `oc_comments_read_markers` (
  `user_id` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `object_type` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `object_id` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `marker_datetime` datetime DEFAULT NULL,
  PRIMARY KEY (`user_id`,`object_type`,`object_id`),
  KEY `comments_marker_object_index` (`object_type`,`object_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_dav_absence`;
CREATE TABLE `oc_dav_absence` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `first_day` varchar(10) COLLATE utf8mb4_bin NOT NULL,
  `last_day` varchar(10) COLLATE utf8mb4_bin NOT NULL,
  `status` varchar(100) COLLATE utf8mb4_bin NOT NULL,
  `message` longtext COLLATE utf8mb4_bin NOT NULL,
  `replacement_user_id` varchar(64) COLLATE utf8mb4_bin DEFAULT '',
  `replacement_user_display_name` varchar(64) COLLATE utf8mb4_bin DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `dav_absence_uid_idx` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_dav_cal_proxy`;
CREATE TABLE `oc_dav_cal_proxy` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `owner_id` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `proxy_id` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `permissions` int unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `dav_cal_proxy_uidx` (`owner_id`,`proxy_id`,`permissions`),
  KEY `dav_cal_proxy_ipid` (`proxy_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_dav_shares`;
CREATE TABLE `oc_dav_shares` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `principaluri` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `type` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `access` smallint DEFAULT NULL,
  `resourceid` bigint unsigned NOT NULL,
  `publicuri` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `dav_shares_index` (`principaluri`,`resourceid`,`type`,`publicuri`),
  KEY `dav_shares_resourceid_type` (`resourceid`,`type`),
  KEY `dav_shares_resourceid_access` (`resourceid`,`access`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_direct_edit`;
CREATE TABLE `oc_direct_edit` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `editor_id` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `token` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `file_id` bigint NOT NULL,
  `user_id` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `share_id` bigint DEFAULT NULL,
  `timestamp` bigint unsigned NOT NULL,
  `accessed` tinyint(1) DEFAULT '0',
  `file_path` varchar(4000) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `IDX_4D5AFECA5F37A13B` (`token`),
  KEY `direct_edit_timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_directlink`;
CREATE TABLE `oc_directlink` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `file_id` bigint unsigned NOT NULL,
  `token` varchar(60) COLLATE utf8mb4_bin DEFAULT NULL,
  `expiration` bigint unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `directlink_token_idx` (`token`),
  KEY `directlink_expiration_idx` (`expiration`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_ex_apps`;
CREATE TABLE `oc_ex_apps` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `appid` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `version` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `name` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `daemon_config_name` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '0',
  `port` smallint unsigned NOT NULL,
  `secret` varchar(256) COLLATE utf8mb4_bin NOT NULL,
  `status` json NOT NULL,
  `enabled` smallint NOT NULL DEFAULT '0',
  `created_time` bigint unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ex_apps__appid` (`appid`),
  UNIQUE KEY `ex_apps_c_port__idx` (`daemon_config_name`,`port`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_ex_apps_daemons`;
CREATE TABLE `oc_ex_apps_daemons` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `display_name` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `accepts_deploy_id` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `protocol` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `host` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `deploy_config` json NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ex_apps_daemons__name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_ex_apps_routes`;
CREATE TABLE `oc_ex_apps_routes` (
  `id` int NOT NULL AUTO_INCREMENT,
  `appid` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `url` varchar(512) COLLATE utf8mb4_bin NOT NULL,
  `verb` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `access_level` int NOT NULL DEFAULT '0',
  `headers_to_exclude` varchar(512) COLLATE utf8mb4_bin DEFAULT NULL,
  `bruteforce_protection` varchar(512) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ex_apps_routes_appid` (`appid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_ex_deploy_options`;
CREATE TABLE `oc_ex_deploy_options` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `appid` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `type` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `value` json NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `deploy_options__idx` (`appid`,`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_ex_event_handlers`;
CREATE TABLE `oc_ex_event_handlers` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `appid` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `event_type` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `event_subtypes` json NOT NULL,
  `action_handler` varchar(410) COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ex_event_handlers__idx` (`appid`,`event_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_ex_occ_commands`;
CREATE TABLE `oc_ex_occ_commands` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `appid` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `name` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `description` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `hidden` smallint NOT NULL DEFAULT '0',
  `arguments` json NOT NULL,
  `options` json NOT NULL,
  `usages` json NOT NULL,
  `execute_handler` varchar(410) COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ex_occ_commands__idx` (`appid`,`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_ex_settings_forms`;
CREATE TABLE `oc_ex_settings_forms` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `appid` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `formid` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `scheme` json NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ex_settings_forms__idx` (`appid`,`formid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_ex_speech_to_text`;
CREATE TABLE `oc_ex_speech_to_text` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `appid` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `name` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `display_name` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `action_handler` varchar(410) COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `speech_to_text__idx` (`appid`,`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_ex_speech_to_text_q`;
CREATE TABLE `oc_ex_speech_to_text_q` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `result` longtext COLLATE utf8mb4_bin NOT NULL,
  `error` varchar(1024) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `finished` smallint NOT NULL DEFAULT '0',
  `created_time` bigint unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `IDX_C1E06C58A64FAB3C` (`finished`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_ex_task_processing`;
CREATE TABLE `oc_ex_task_processing` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `app_id` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `display_name` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `task_type` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `custom_task_type` longtext COLLATE utf8mb4_bin,
  `provider` longtext COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `task_processing_idx` (`app_id`,`name`,`task_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_ex_text_processing`;
CREATE TABLE `oc_ex_text_processing` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `appid` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `name` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `display_name` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `action_handler` varchar(410) COLLATE utf8mb4_bin NOT NULL,
  `task_type` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `text_processing__idx` (`appid`,`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_ex_text_processing_q`;
CREATE TABLE `oc_ex_text_processing_q` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `result` longtext COLLATE utf8mb4_bin NOT NULL,
  `error` varchar(1024) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `finished` smallint NOT NULL DEFAULT '0',
  `created_time` bigint unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `IDX_CB97986AA64FAB3C` (`finished`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_ex_translation`;
CREATE TABLE `oc_ex_translation` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `appid` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `name` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `display_name` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `from_languages` json NOT NULL,
  `to_languages` json NOT NULL,
  `action_handler` varchar(410) COLLATE utf8mb4_bin NOT NULL,
  `action_detect_lang` varchar(410) COLLATE utf8mb4_bin DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `ex_translation__idx` (`appid`,`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_ex_translation_q`;
CREATE TABLE `oc_ex_translation_q` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `result` longtext COLLATE utf8mb4_bin NOT NULL,
  `error` varchar(1024) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `finished` smallint NOT NULL DEFAULT '0',
  `created_time` bigint unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `IDX_38CE0470A64FAB3C` (`finished`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_ex_ui_files_actions`;
CREATE TABLE `oc_ex_ui_files_actions` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `appid` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `name` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `display_name` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `mime` longtext COLLATE utf8mb4_bin NOT NULL,
  `permissions` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `order` bigint NOT NULL DEFAULT '0',
  `icon` varchar(255) COLLATE utf8mb4_bin DEFAULT '',
  `action_handler` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `version` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '1.0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `ex_ui_files_actions__idx` (`appid`,`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_ex_ui_scripts`;
CREATE TABLE `oc_ex_ui_scripts` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `appid` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `type` varchar(16) COLLATE utf8mb4_bin NOT NULL,
  `name` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `path` varchar(410) COLLATE utf8mb4_bin NOT NULL,
  `after_app_id` varchar(32) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ui_script__idx` (`appid`,`type`,`name`,`path`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_ex_ui_states`;
CREATE TABLE `oc_ex_ui_states` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `appid` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `type` varchar(16) COLLATE utf8mb4_bin NOT NULL,
  `name` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `key` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `value` json NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ui_state__idx` (`appid`,`type`,`name`,`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_ex_ui_styles`;
CREATE TABLE `oc_ex_ui_styles` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `appid` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `type` varchar(16) COLLATE utf8mb4_bin NOT NULL,
  `name` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `path` varchar(410) COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ui_style__idx` (`appid`,`type`,`name`,`path`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_ex_ui_top_menu`;
CREATE TABLE `oc_ex_ui_top_menu` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `appid` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `name` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `display_name` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `icon` varchar(255) COLLATE utf8mb4_bin DEFAULT '',
  `admin_required` smallint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `ui_top_menu__idx` (`appid`,`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_federated_reshares`;
CREATE TABLE `oc_federated_reshares` (
  `share_id` bigint NOT NULL,
  `remote_id` varchar(255) COLLATE utf8mb4_bin DEFAULT '',
  PRIMARY KEY (`share_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_file_locks`;
CREATE TABLE `oc_file_locks` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `lock` int NOT NULL DEFAULT '0',
  `key` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `ttl` int NOT NULL DEFAULT '-1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `lock_key_index` (`key`),
  KEY `lock_ttl_index` (`ttl`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_file_locks` (`id`, `lock`, `key`, `ttl`) VALUES
(1,	0,	'files/8b94a2cfef8500fb64c413e6803b5745',	1757061379),
(2,	0,	'files/38d3fc13a505a341da34815c5ccc8b3d',	1757062088),
(3,	0,	'files/11f8ac6e03bdcba6f87a3c9b12ac7dec',	1757061379),
(5,	0,	'files/386c95d4f3fda0303c34297acdfc1b7e',	1757061379),
(6,	0,	'files/638e4babe104e5a5180795d176dc09ad',	1757061379),
(7,	0,	'files/fab8da471b253c4057a4bc8a66540b1b',	1757061397),
(8,	0,	'files/7d0be9b2f0b002a69cce4197fb9d6097',	1757061397),
(12,	0,	'files/057323ca663a3b54811c862ee99fbc5f',	1757061397),
(13,	0,	'files/c576e900e8244aef20aa63d3c30955e5',	1757061380),
(21,	0,	'files/94c4b41e721aa9325829fb0579e4c3c7',	1757062087),
(23,	0,	'files/81b2c42e9ef1c82ee8a401764c934f54',	1757062087),
(27,	0,	'files/a241fab67e5ef1aed4e68cc12672c793',	1757062087),
(28,	0,	'files/d022c05141e11b41ffde79ea369a592e',	1757061397),
(29,	0,	'files/8ba920530479d49f5cacbc60cb90e17b',	1757061397),
(30,	0,	'files/8ffc43abbb921970e67bf82931e27850',	1757061397),
(31,	0,	'files/202b8b3c3d5082f8e32b69051f9bbea2',	1757061397),
(32,	0,	'files/c5baa2f09e022ab04a3980db31d56c7b',	1757061397),
(33,	0,	'files/8243eb040d607561f6043565d6853349',	1757061397),
(34,	0,	'files/92f9cd41b8113ee6bf4edce65edff49a',	1757061397),
(35,	0,	'files/21dc7dc2dbdf3f47f6ea2d93e21abdcb',	1757061397),
(36,	0,	'files/03d0f63efb6d2e4aba7674b5d1ccf035',	1757061397),
(37,	0,	'files/8e6c5fbcca2d5123a0297a600fb72879',	1757061397),
(38,	0,	'files/bc3e52a9bab04521b828924e3e252b32',	1757061397),
(39,	0,	'files/89930176ca968fbaa161a8eec84b1435',	1757061397),
(40,	0,	'files/e5c049e2224be7e3aac8066ba8382341',	1757061397),
(41,	0,	'files/ca910fd6160d853588bbe00cc23a97ba',	1757061397),
(42,	0,	'files/ea10b662a972f580a526a386076cd917',	1757061397),
(43,	0,	'files/4459be322b70be63d7425b1cacab7eb3',	1757061397),
(44,	0,	'files/6d9bf6b25808525e396726e65c075966',	1757061397),
(45,	0,	'files/53686fd3d02eda33585bad579c5653a9',	1757061397),
(46,	0,	'files/ac2b9b608cbc1cc1cd25013cb30b76b4',	1757061397),
(47,	0,	'files/4308233770b22946352ff4f10fa3846b',	1757061397),
(48,	0,	'files/e5d248df1b3d4b9d4869de55a9b6bf91',	1757062087),
(49,	0,	'files/69721e6ee550b6811a21f7d5ffd7ef97',	1757061397),
(50,	0,	'files/a80ab164aa7c14794d1ad3b8eefe5806',	1757062087),
(51,	0,	'files/4eec412805fafb7fae10d11e4fbd1dea',	1757061397),
(52,	0,	'files/0dee7dfc306e2dff66fe42eb1e2595b1',	1757061397),
(54,	0,	'files/a64c50383c131b576880b99b36e61d7c',	1757061397),
(56,	0,	'files/8d3127f3ff008aef7c464ae59a8a0d7a',	1757062087),
(61,	0,	'files/84fc6d08ed3bd071bcdab33a99d2d7d9',	1757061414),
(64,	0,	'files/595ffcc2c45ea54b59cca2423657decd',	1757061397),
(65,	0,	'files/b6ef755cfc70b5eb94f5d3aad8ba833d',	1757062088),
(66,	0,	'files/809d34be61ac40ea4b7a56b5b537e968',	1757061397),
(67,	0,	'files/3513aba8aa4305d3ad33fc7122d4af30',	1757061414),
(68,	0,	'files/74ea8bd8da49bd6b99c0ad9b91b8df8b',	1757061397),
(69,	0,	'files/7363e5dcbb375180f9df531a8b8227bb',	1757061397),
(70,	0,	'files/624cf56b9c08c94ed558a8b4b96b501f',	1757061397),
(71,	0,	'files/1b0bb202805ec5a66b194b8d58f9510d',	1757061397),
(72,	0,	'files/54c73357fddb1c889704b5386b1b21e1',	1757061397),
(73,	0,	'files/b636ece69e2c929a737a784c8be0cc5c',	1757061397),
(74,	0,	'files/610cd451d576554d88c8ddae972b53ef',	1757061397),
(75,	0,	'files/fa2f2895ce1452e73ef3b6c8e16c1369',	1757061397),
(76,	0,	'files/907707901f54136949acd84fce4bcbdd',	1757062087),
(77,	0,	'files/9744bd3f3b2d212d7553fb07181814e0',	1757061397),
(78,	0,	'files/9177154f18b8b2975b401576c076ef60',	1757061397),
(86,	0,	'files/73c8818786e0574daaf3254b69ae5c8e',	1757061413),
(88,	0,	'files/a81d3ce5a4893974b90d6f004386b1e3',	1757061413),
(89,	0,	'files/2912486ce1f8b00c8bd341881b5a9af3',	1757061413),
(90,	0,	'files/041fdfd64233b4ae26b27db1ac01da0e',	1757061413),
(92,	0,	'files/604eaeb7dc9980cefdb6df78c979195d',	1757061413),
(94,	0,	'files/e63f410c2fda3cc6e26929c1252168eb',	1757061413),
(95,	0,	'files/fc3a5df1731f97907cf93577b7435221',	1757061413),
(96,	0,	'files/7d341465f34efbc9170ea3dc6ab8c0b2',	1757062087),
(97,	0,	'files/aa0e5d871e8f3348e77ef9d641953343',	1757061413),
(98,	0,	'files/2eb8c01c66871bb4e3427334494ede6c',	1757061413),
(100,	0,	'files/2a090aab72d07602bd5a883ab5228e20',	1757061413),
(101,	0,	'files/d34502b8f8073bf15dd151f7c367f85b',	1757061413),
(102,	0,	'files/0cd871196268a40d1b62f91b8c0073b2',	1757062087),
(104,	0,	'files/7521c52139a59ce1f86852f33eab913c',	1757061413),
(108,	0,	'files/9237ff40a17e55d9c1b30b51ac196dd8',	1757061413),
(109,	0,	'files/5a601f89f3f8a6ce06f084cc02827558',	1757061413),
(110,	0,	'files/04ed57eaf27d0b36ef7dfd53f8e256d7',	1757061413),
(111,	0,	'files/614d18b38ae12f8358939bd190302ab4',	1757061413),
(112,	0,	'files/5c6761aafdd15e99e20396f6cee64fb6',	1757061413),
(113,	0,	'files/f102d617b1a05c944b7c94c9d82d09de',	1757061414),
(114,	0,	'files/f42817e509c0085d3795cc922355b4db',	1757062087),
(119,	0,	'files/e97784e1e14afedb983e1645f6e0eff1',	1757061568),
(121,	0,	'files/847f07f2d74093f443288a9961e7e5d4',	1757061568),
(124,	0,	'files/1b8356c922fdc52446bfada43f9a669a',	1757061568),
(125,	0,	'files/e34f26773ba151b5d6483f933765f986',	1757061568),
(127,	0,	'files/6b2de085d9b53fa93fa74433933ff37f',	1757062088),
(130,	0,	'files/cbc6f4e337332b94c2e02444d64b1c16',	1757062086),
(131,	0,	'files/2c7eaecb9090bd89cef1dcd4d0d5881a',	1757062086),
(132,	0,	'files/585273f764f7401d20c06a646f408e8a',	1757062086),
(133,	0,	'files/2b7e5de9afe8b3f7b056c0ba2a04af46',	1757062086),
(138,	0,	'files/00b0bdc0b8327ba18e6b017fd16de84f',	1757062087),
(139,	0,	'files/873c80580ba31b5876bf8ab7c25a9257',	1757062087),
(140,	0,	'files/d5c7c62a71629477ace89a2599432547',	1757062087),
(141,	0,	'files/105c1834e941a03c929cf3a55d4fe3d5',	1757062087),
(142,	0,	'files/371b8665a7ee3eec20d062c7ea9be2df',	1757062087),
(143,	0,	'files/716e79d0a411bd5288b668fdd436b41e',	1757062087),
(144,	0,	'files/50267ccdac2685df367bcf3880023942',	1757062087),
(146,	0,	'files/c11e74da3d98de6929b1a3a7d2801b23',	1757062087),
(147,	0,	'files/019dc39ba4f9515037ffb2d80e2e427d',	1757062087),
(149,	0,	'files/7f1f4cfacd3fe4877ee67f429de48fd2',	1757062087),
(151,	0,	'files/9affa94d6800cbb694880c5dc25985e2',	1757062087),
(154,	0,	'files/b293cb9933c8ba665d9937f7e39f88b0',	1757062087),
(156,	0,	'files/5d35c3d17fffd83276fe37ec7df07a75',	1757062087),
(160,	0,	'files/be9dcc7aa2c247d4e4f6a4048b0cd837',	1757062087),
(161,	0,	'files/36daa807f368205206612f891d487b4a',	1757062087),
(162,	0,	'files/2dae283d5a54e6260ef62f723de6ede8',	1757062087),
(163,	0,	'files/130d6e1fbfdb29cbfeb92a30e6a280cc',	1757062087),
(164,	0,	'files/ece5dcde973b7f59412d764e4144f102',	1757062087),
(165,	0,	'files/6b2a298305b86387b0838869b93e3d76',	1757062087),
(166,	0,	'files/cecfa4eb5a3277d2b93f3c58256f99d8',	1757062087);

DROP TABLE IF EXISTS `oc_filecache`;
CREATE TABLE `oc_filecache` (
  `fileid` bigint NOT NULL AUTO_INCREMENT,
  `storage` bigint NOT NULL DEFAULT '0',
  `path` varchar(4000) COLLATE utf8mb4_bin DEFAULT NULL,
  `path_hash` varchar(32) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `parent` bigint NOT NULL DEFAULT '0',
  `name` varchar(250) COLLATE utf8mb4_bin DEFAULT NULL,
  `mimetype` bigint NOT NULL DEFAULT '0',
  `mimepart` bigint NOT NULL DEFAULT '0',
  `size` bigint NOT NULL DEFAULT '0',
  `mtime` bigint NOT NULL DEFAULT '0',
  `storage_mtime` bigint NOT NULL DEFAULT '0',
  `encrypted` int NOT NULL DEFAULT '0',
  `unencrypted_size` bigint NOT NULL DEFAULT '0',
  `etag` varchar(40) COLLATE utf8mb4_bin DEFAULT NULL,
  `permissions` int DEFAULT '0',
  `checksum` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`fileid`),
  UNIQUE KEY `fs_storage_path_hash` (`storage`,`path_hash`),
  KEY `fs_parent_name_hash` (`parent`,`name`),
  KEY `fs_storage_mimetype` (`storage`,`mimetype`),
  KEY `fs_storage_mimepart` (`storage`,`mimepart`),
  KEY `fs_storage_size` (`storage`,`size`,`fileid`),
  KEY `fs_parent` (`parent`),
  KEY `fs_name_hash` (`name`),
  KEY `fs_mtime` (`mtime`),
  KEY `fs_size` (`size`),
  KEY `fs_storage_path_prefix` (`storage`,`path`(64))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_filecache` (`fileid`, `storage`, `path`, `path_hash`, `parent`, `name`, `mimetype`, `mimepart`, `size`, `mtime`, `storage_mtime`, `encrypted`, `unencrypted_size`, `etag`, `permissions`, `checksum`) VALUES
(1,	1,	'',	'd41d8cd98f00b204e9800998ecf8427e',	-1,	'',	2,	1,	36654063,	1757057794,	1757057794,	0,	0,	'68ba93020c2e9',	23,	''),
(2,	1,	'files',	'45b963397aa40d4a0063e0d85e4fe7a1',	1,	'files',	2,	1,	36654063,	1757057756,	1757057756,	0,	0,	'68ba92dc5a524',	31,	''),
(3,	1,	'files/Templates',	'530b342d0b8164ff3b4754c2273a453e',	2,	'Templates',	2,	1,	10942115,	1757057750,	1757057750,	0,	0,	'68ba92d67ae54',	31,	''),
(4,	1,	'files/Templates/Flowchart.odg',	'832942849155883ceddc6f3cede21867',	3,	'Flowchart.odg',	4,	3,	11836,	1757057742,	1757057742,	0,	0,	'79e04fbaa9c51fa3e0326f7216ddbdef',	27,	''),
(5,	1,	'files/Templates/Yellow idea.odp',	'3a57051288d7b81bef3196a2123f4af5',	3,	'Yellow idea.odp',	5,	3,	81196,	1757057742,	1757057742,	0,	0,	'dc141e2e9b0c69b977094935ff010243',	27,	''),
(6,	1,	'files/Templates/Venn diagram.whiteboard',	'71d9f77ebd2c126375fa7170a1c86509',	3,	'Venn diagram.whiteboard',	6,	3,	23359,	1757057742,	1757057742,	0,	0,	'620eea4af5a8c58c61718a4b403f36aa',	27,	''),
(7,	1,	'files/Templates/Gotong royong.odp',	'14b958f5aafb7cfd703090226f3cbd1b',	3,	'Gotong royong.odp',	5,	3,	3509628,	1757057743,	1757057743,	0,	0,	'e484b0a694898dbe038175e3b7ced3ad',	27,	''),
(8,	1,	'files/Templates/Meeting notes.md',	'c0279758bb570afdcdbc2471b2f16285',	3,	'Meeting notes.md',	8,	7,	326,	1757057743,	1757057743,	0,	0,	'75770b8b3385e14edadc85633c0873ac',	27,	''),
(9,	1,	'files/Templates/Letter.odt',	'15545ade0e9863c98f3a5cc0fbf2836a',	3,	'Letter.odt',	9,	3,	15961,	1757057743,	1757057743,	0,	0,	'39acdba2bdb38cefd57e07a41d63be8d',	27,	''),
(10,	1,	'files/Templates/Mindmap.odg',	'74cff798fc1b9634ee45380599b2a6da',	3,	'Mindmap.odg',	4,	3,	13653,	1757057743,	1757057743,	0,	0,	'e9bd12d4ce8b89ff3c9abed883712f65',	27,	''),
(11,	1,	'files/Templates/Mind map.whiteboard',	'27c7b4d83fd3526a42122bcacf5dfbe9',	3,	'Mind map.whiteboard',	6,	3,	35657,	1757057744,	1757057744,	0,	0,	'6d0a73f655e30f421e13665acc251cb4',	27,	''),
(12,	1,	'files/Templates/Resume.odt',	'ace8f81202eadb2f0c15ba6ecc2539f5',	3,	'Resume.odt',	9,	3,	39404,	1757057744,	1757057744,	0,	0,	'1e0ce55ab5d6e401d034eb974916901e',	27,	''),
(13,	1,	'files/Templates/Party invitation.odt',	'439f95f734be87868374b1a5a312c550',	3,	'Party invitation.odt',	9,	3,	868111,	1757057744,	1757057744,	0,	0,	'0a70abe06ed352e15b0f4a9cc3e4cc4a',	27,	''),
(14,	1,	'files/Templates/Mother\'s day.odt',	'cb66c617dbb4acc9b534ec095c400b53',	3,	'Mother\'s day.odt',	9,	3,	340061,	1757057744,	1757057744,	0,	0,	'd7c7fb9dc4d1abc9c24b328487d1a4d0',	27,	''),
(15,	1,	'files/Templates/Brainstorming.whiteboard',	'aa2d36938cf5c1f41813d1e8bbd3ae00',	3,	'Brainstorming.whiteboard',	6,	3,	30780,	1757057745,	1757057745,	0,	0,	'8b2acb7c6990b5dec07a236d6f0704a2',	27,	''),
(16,	1,	'files/Templates/Business model canvas.ods',	'86c10a47dedf156bf4431cb75e0f76ec',	3,	'Business model canvas.ods',	10,	3,	52843,	1757057745,	1757057745,	0,	0,	'e70a725ad267cfc5641228df8330bb86',	27,	''),
(17,	1,	'files/Templates/Business model canvas.odg',	'6a8f3e02bdf45c8b0671967969393bcb',	3,	'Business model canvas.odg',	4,	3,	16988,	1757057745,	1757057745,	0,	0,	'3efb6e0f071bc8e4b987ce1372d1ebda',	27,	''),
(18,	1,	'files/Templates/Photo book.odt',	'ea35993988e2799424fef3ff4f420c24',	3,	'Photo book.odt',	9,	3,	5155877,	1757057745,	1757057745,	0,	0,	'4dd3dd58892b4761799a8d7a1e2d6341',	27,	''),
(19,	1,	'files/Templates/Elegant.odp',	'f3ec70ed694c0ca215f094b98eb046a7',	3,	'Elegant.odp',	5,	3,	14316,	1757057746,	1757057746,	0,	0,	'38d0a4f8e2bce1bcbed508f24bc6d24a',	27,	''),
(20,	1,	'files/Templates/Sticky notes.whiteboard',	'72309dacd55c6de379c738caf18d84c4',	3,	'Sticky notes.whiteboard',	6,	3,	45778,	1757057746,	1757057746,	0,	0,	'ed8ecce362925e22950aa50262d80433',	27,	''),
(21,	1,	'files/Templates/Readme.md',	'71fa2e74ab30f39eed525572ccc3bbec',	3,	'Readme.md',	8,	7,	554,	1757057746,	1757057746,	0,	0,	'c698154feedc6f1cbbb465f607b0d84a',	27,	''),
(22,	1,	'files/Templates/Business model canvas.whiteboard',	'1c4e5432621502fa9a668c49b25b81d9',	3,	'Business model canvas.whiteboard',	6,	3,	30290,	1757057746,	1757057746,	0,	0,	'091f3cfe9c87f25d602005d66ca65ebe',	27,	''),
(23,	1,	'files/Templates/Meeting agenda.whiteboard',	'be213da59b99766ceae11e80093803a9',	3,	'Meeting agenda.whiteboard',	6,	3,	27629,	1757057747,	1757057747,	0,	0,	'050a3a160695484d5b54151b17d1769d',	27,	''),
(24,	1,	'files/Templates/Flowchart.whiteboard',	'b944a25f1ef13e8e256107178bb28141',	3,	'Flowchart.whiteboard',	6,	3,	31132,	1757057747,	1757057747,	0,	0,	'63e155ee7d24883c566b61555d7b5053',	27,	''),
(25,	1,	'files/Templates/Diagram & table.ods',	'0a89f154655f6d4a0098bc4e6ca87367',	3,	'Diagram & table.ods',	10,	3,	13378,	1757057747,	1757057747,	0,	0,	'655c80974e5348e0fcfecc44c1227a5d',	27,	''),
(26,	1,	'files/Templates/Modern company.odp',	'96ad2c06ebb6a79bcdf2f4030421dee3',	3,	'Modern company.odp',	5,	3,	317015,	1757057747,	1757057747,	0,	0,	'af024561f3258099664108847db4ae8e',	27,	''),
(27,	1,	'files/Templates/Simple.odp',	'a2c90ff606d31419d699b0b437969c61',	3,	'Simple.odp',	5,	3,	14810,	1757057748,	1757057748,	0,	0,	'61255b61b2b331113fb489cbfe88c5a6',	27,	''),
(28,	1,	'files/Templates/Product plan.md',	'a9fbf58bf31cebb8143f7ad3a5205633',	3,	'Product plan.md',	8,	7,	573,	1757057748,	1757057748,	0,	0,	'56e970fe29f142f95028010944d49ba5',	27,	''),
(29,	1,	'files/Templates/Syllabus.odt',	'03b3147e6dae00674c1d50fe22bb8496',	3,	'Syllabus.odt',	9,	3,	30354,	1757057748,	1757057748,	0,	0,	'2ad7d65ed2011ef33f131a7891719b6d',	27,	''),
(30,	1,	'files/Templates/Timeline.whiteboard',	'a009a1620252b19a9307d35de49311e9',	3,	'Timeline.whiteboard',	6,	3,	31325,	1757057748,	1757057748,	0,	0,	'7639065ee7bc1d4f04ad133efc34bfc0',	27,	''),
(31,	1,	'files/Templates/Invoice.odt',	'40fdccb51b6c3e3cf20532e06ed5016e',	3,	'Invoice.odt',	9,	3,	17276,	1757057749,	1757057749,	0,	0,	'579873a367f531a445283e8fbb00575e',	27,	''),
(32,	1,	'files/Templates/Kanban board.whiteboard',	'174b2766514fef9a88cbb3076e362b4a',	3,	'Kanban board.whiteboard',	6,	3,	25621,	1757057749,	1757057749,	0,	0,	'd5094d8a35a849b9f88d33ce9078a009',	27,	''),
(33,	1,	'files/Templates/Expense report.ods',	'd0a4025621279b95d2f94ff4ec09eab3',	3,	'Expense report.ods',	10,	3,	13441,	1757057749,	1757057749,	0,	0,	'841a3759cfa0dfdd857dea69e1d2d27f',	27,	''),
(34,	1,	'files/Templates/Impact effort.whiteboard',	'071dbd5231cfcb493fa2fcc4a763be05',	3,	'Impact effort.whiteboard',	6,	3,	30671,	1757057749,	1757057749,	0,	0,	'c99e5d78d7dfa474396848c39a2ecd15',	27,	''),
(35,	1,	'files/Templates/Timesheet.ods',	'cb79c81e41d3c3c77cd31576dc7f1a3a',	3,	'Timesheet.ods',	10,	3,	88394,	1757057750,	1757057750,	0,	0,	'bd05c6298a8a37a9be6306ef807a30b1',	27,	''),
(36,	1,	'files/Templates/Org chart.odg',	'fd846bc062b158abb99a75a5b33b53e7',	3,	'Org chart.odg',	4,	3,	13878,	1757057750,	1757057750,	0,	0,	'6a1f64391b377b50ee96359a2cfc4d89',	27,	''),
(37,	1,	'files/Documents',	'0ad78ba05b6961d92f7970b2b3922eca',	2,	'Documents',	2,	1,	1108446,	1757057751,	1757057751,	0,	0,	'68ba92d7b77fc',	31,	''),
(38,	1,	'files/Documents/Example.md',	'efe0853470dd0663db34818b444328dd',	37,	'Example.md',	8,	7,	1095,	1757057750,	1757057750,	0,	0,	'2475050bc793ed81924d1c8c9b9a7e09',	27,	''),
(39,	1,	'files/Documents/Readme.md',	'51ec9e44357d147dd5c212b850f6910f',	37,	'Readme.md',	8,	7,	136,	1757057751,	1757057751,	0,	0,	'066167e55fd47de9ce10e80841cf6909',	27,	''),
(40,	1,	'files/Documents/Nextcloud flyer.pdf',	'9c5b4dc7182a7435767708ac3e8d126c',	37,	'Nextcloud flyer.pdf',	11,	3,	1083339,	1757057751,	1757057751,	0,	0,	'bbca82bb2ee3fa04e9562bf6634c83b7',	27,	''),
(41,	1,	'files/Documents/Welcome to Nextcloud Hub.docx',	'b44cb84f22ceddc4ca2826e026038091',	37,	'Welcome to Nextcloud Hub.docx',	12,	3,	23876,	1757057751,	1757057751,	0,	0,	'f936b2a946c09a4799bbab81e056d078',	27,	''),
(42,	1,	'files/Nextcloud Manual.pdf',	'2bc58a43566a8edde804a4a97a9c7469',	2,	'Nextcloud Manual.pdf',	11,	3,	13954180,	1757057751,	1757057751,	0,	0,	'142cbbdb683db896cf8da025442d86fe',	27,	''),
(43,	1,	'files/Readme.md',	'49af83716f8dcbfa89aaf835241c0b9f',	2,	'Readme.md',	8,	7,	197,	1757057752,	1757057752,	0,	0,	'679eda22c8471c8ec5fdb745123b13ef',	27,	''),
(44,	1,	'files/Nextcloud.png',	'2bcc0ff06465ef1bfc4a868efde1e485',	2,	'Nextcloud.png',	14,	13,	50598,	1757057752,	1757057752,	0,	0,	'71d4b8e126d89e66d68a910b62fb20d7',	27,	''),
(45,	1,	'files/Templates credits.md',	'f7c01e3e0b55bb895e09dc08d19375b3',	2,	'Templates credits.md',	8,	7,	2403,	1757057752,	1757057752,	0,	0,	'8a7bce0a22521dfb790a47ceaf547511',	27,	''),
(46,	1,	'files/Reasons to use Nextcloud.pdf',	'418b19142a61c5bef296ea56ee144ca3',	2,	'Reasons to use Nextcloud.pdf',	11,	3,	976625,	1757057753,	1757057753,	0,	0,	'685ac10cf8e6b88b5a6e34461af14db0',	27,	''),
(47,	1,	'files/Photos',	'd01bb67e7b71dd49fd06bad922f521c9',	2,	'Photos',	2,	1,	5656463,	1757057755,	1757057755,	0,	0,	'68ba92dc04197',	31,	''),
(48,	1,	'files/Photos/Frog.jpg',	'd6219add1a9129ed0c1513af985e2081',	47,	'Frog.jpg',	15,	13,	457744,	1757057753,	1757057753,	0,	0,	'b2419299ee91c83144cb849377268a49',	27,	''),
(49,	1,	'files/Photos/Birdie.jpg',	'cd31c7af3a0ec6e15782b5edd2774549',	47,	'Birdie.jpg',	15,	13,	593508,	1757057753,	1757057753,	0,	0,	'3fbadca4c02482a191a6b601793ba8bc',	27,	''),
(50,	1,	'files/Photos/Steps.jpg',	'7b2ca8d05bbad97e00cbf5833d43e912',	47,	'Steps.jpg',	15,	13,	567689,	1757057754,	1757057754,	0,	0,	'027e01a08ba0f82b14b4e1ea4f072eb1',	27,	''),
(51,	1,	'files/Photos/Library.jpg',	'0b785d02a19fc00979f82f6b54a05805',	47,	'Library.jpg',	15,	13,	2170375,	1757057754,	1757057754,	0,	0,	'd0c63564cc2a9725a7340fc56f30562a',	27,	''),
(52,	1,	'files/Photos/Vineyard.jpg',	'14e5f2670b0817614acd52269d971db8',	47,	'Vineyard.jpg',	15,	13,	427030,	1757057754,	1757057754,	0,	0,	'e0988c2f4f366b75dce47c8e73b6c0a3',	27,	''),
(53,	1,	'files/Photos/Gorilla.jpg',	'6d5f5956d8ff76a5f290cebb56402789',	47,	'Gorilla.jpg',	15,	13,	474653,	1757057755,	1757057755,	0,	0,	'd5248e01de18db7e320409f251bea427',	27,	''),
(54,	1,	'files/Photos/Toucan.jpg',	'681d1e78f46a233e12ecfa722cbc2aef',	47,	'Toucan.jpg',	15,	13,	167989,	1757057755,	1757057755,	0,	0,	'5bc71c7b5cfbe84d193bd15123db6d7d',	27,	''),
(55,	1,	'files/Photos/Readme.md',	'2a4ac36bb841d25d06d164f291ee97db',	47,	'Readme.md',	8,	7,	150,	1757057755,	1757057755,	0,	0,	'ac22a4b219f0cd83b7917dcd44c3ec37',	27,	''),
(56,	1,	'files/Photos/Nextcloud community.jpg',	'b9b3caef83a2a1c20354b98df6bcd9d0',	47,	'Nextcloud community.jpg',	15,	13,	797325,	1757057755,	1757057755,	0,	0,	'80869292a44f1cc7e194724bc960d907',	27,	''),
(57,	1,	'files/Nextcloud intro.mp4',	'e4919345bcc87d4585a5525daaad99c0',	2,	'Nextcloud intro.mp4',	17,	16,	3963036,	1757057756,	1757057756,	0,	0,	'daaf5854bbe1e423f9dcd418de7616cf',	27,	''),
(58,	2,	'',	'd41d8cd98f00b204e9800998ecf8427e',	-1,	'',	2,	1,	-1,	1757057779,	1757057779,	0,	0,	'68ba92f3dabe9',	23,	''),
(59,	2,	'appdata_ocls225bjeq5',	'35d761c9e8a6b8dba3c3fd4586e0f2f0',	58,	'appdata_ocls225bjeq5',	2,	1,	0,	1757057965,	1757057965,	0,	0,	'68ba92f3d4b67',	31,	''),
(61,	2,	'appdata_ocls225bjeq5/theming',	'02d10f91c769a775e68c35ce06942ca7',	59,	'theming',	2,	1,	0,	1757057779,	1757057779,	0,	0,	'68ba92f3e9d73',	31,	''),
(62,	2,	'appdata_ocls225bjeq5/theming/global',	'e39c1eb4cd3fee1f81d2a4bbc2b533b0',	61,	'global',	2,	1,	0,	1757057780,	1757057780,	0,	0,	'68ba930512766',	31,	''),
(64,	2,	'appdata_ocls225bjeq5/theming/global/0',	'8a81720a9b25f9d9b9152510b4790586',	62,	'0',	2,	1,	0,	1757057967,	1757057967,	0,	0,	'68ba92f4177eb',	31,	''),
(66,	2,	'appdata_ocls225bjeq5/theming/global/0/favIcon-core#00679e',	'441a4e5c694fe4f50ba8974630b4fa22',	64,	'favIcon-core#00679e',	18,	3,	90022,	1757057780,	1757057780,	0,	0,	'44e33e76f04b48e71b1d39446c3946f7',	27,	''),
(67,	2,	'appdata_ocls225bjeq5/theming/global/0/touchIcon-core#00679e',	'c0bccb3c8fc60e4fc504cafb86c77a14',	64,	'touchIcon-core#00679e',	18,	3,	24889,	1757057780,	1757057780,	0,	0,	'a207e2a8c4dbc88350fd56673018464e',	27,	''),
(68,	1,	'cache',	'0fea6a13c52b4d4725368f24b045ca84',	1,	'cache',	2,	1,	0,	1757057794,	1757057794,	0,	0,	'68ba930200bf9',	31,	''),
(69,	2,	'appdata_ocls225bjeq5/js',	'58b55d4a19e39763ba084138e56b8e06',	59,	'js',	2,	1,	0,	1757057795,	1757057795,	0,	0,	'68ba930346fbb',	31,	''),
(70,	2,	'appdata_ocls225bjeq5/js/core',	'6d2b3e8eac81282bb3ff72b3fda96a91',	69,	'core',	2,	1,	0,	1757057795,	1757057795,	0,	0,	'68ba930350f27',	31,	''),
(71,	2,	'appdata_ocls225bjeq5/js/core/merged-template-prepend.js',	'31f9bdc1acb67e51485066dcef1653a9',	70,	'merged-template-prepend.js',	20,	3,	11773,	1757057795,	1757057795,	0,	0,	'8ce58cb4b656d0634fe3f72100428e5b',	27,	''),
(72,	2,	'appdata_ocls225bjeq5/js/core/merged-template-prepend.js.deps',	'97292e9ce69ee65be5a01a9dac4a2c2d',	70,	'merged-template-prepend.js.deps',	18,	3,	246,	1757057795,	1757057795,	0,	0,	'7499420a944b3853e684531a27e01e60',	27,	''),
(73,	2,	'appdata_ocls225bjeq5/js/core/merged-template-prepend.js.gzip',	'7c262e8b3229009b3d678864f39f85a1',	70,	'merged-template-prepend.js.gzip',	21,	3,	2812,	1757057795,	1757057795,	0,	0,	'e2830858c03204477b5261849902f406',	27,	''),
(74,	2,	'appdata_ocls225bjeq5/avatar',	'7e43ca6d180a9c92ac768fb816f712f3',	59,	'avatar',	2,	1,	0,	1757057796,	1757057796,	0,	0,	'68ba9304d8762',	31,	''),
(75,	2,	'appdata_ocls225bjeq5/avatar/admin',	'59058a7c35f0e5fc346c2609b79674c0',	74,	'admin',	2,	1,	0,	1757057797,	1757057797,	0,	0,	'68ba9304e122c',	31,	''),
(76,	2,	'appdata_ocls225bjeq5/theming/global/0/favIcon-dashboard#00679e',	'dc4436c5a33e9e18e24cb0023b658213',	64,	'favIcon-dashboard#00679e',	18,	3,	90022,	1757057797,	1757057797,	0,	0,	'9a757c71c52408abb697f4c1f034a686',	27,	''),
(77,	2,	'appdata_ocls225bjeq5/avatar/admin/avatar.png',	'43b708faf100f1d3669bf4ed97c6a555',	75,	'avatar.png',	14,	13,	18276,	1757057797,	1757057797,	0,	0,	'8b54a5d9008afb9886c6d0c6b27cb25e',	27,	''),
(78,	2,	'appdata_ocls225bjeq5/avatar/admin/generated',	'be98eac35772032eabdf25e738cdfc46',	75,	'generated',	18,	3,	0,	1757057797,	1757057797,	0,	0,	'aa5ea1c185ede395ad2bbaa7b180dbdf',	27,	''),
(79,	2,	'appdata_ocls225bjeq5/theming/global/0/touchIcon-dashboard#00679e',	'c0b1e7bb42a46b467a762353e6521c3e',	64,	'touchIcon-dashboard#00679e',	18,	3,	11421,	1757057797,	1757057797,	0,	0,	'8ed6bebfd5d46993b081597b581c885a',	27,	''),
(80,	2,	'appdata_ocls225bjeq5/avatar/admin/avatar.64.png',	'bf0f2b35d8f1b7c374954ae07158005b',	75,	'avatar.64.png',	14,	13,	884,	1757057797,	1757057797,	0,	0,	'3d1dc2201ae150319891c590138e98ff',	27,	''),
(81,	2,	'appdata_ocls225bjeq5/preview',	'afbda1533541c5a0419aa40e1c99e0e9',	59,	'preview',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b73e6e3',	31,	''),
(82,	2,	'appdata_ocls225bjeq5/preview/b',	'fbdcd7b61ebf2f8df527912879297158',	81,	'b',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba95b72c979',	31,	''),
(83,	2,	'appdata_ocls225bjeq5/theming/global/0/icon-core-#00679efiletypes_video.svg',	'55a1e7bac2582a5901efa7f92f1d4393',	64,	'icon-core-#00679efiletypes_video.svg',	22,	13,	277,	1757057797,	1757057797,	0,	0,	'e07fe1d9f52cce6c629cbac9bb441c7c',	27,	''),
(84,	2,	'appdata_ocls225bjeq5/theming/global/0/icon-core-#00679efiletypes_image.svg',	'232716d70eefede61e51e608e27040c7',	64,	'icon-core-#00679efiletypes_image.svg',	22,	13,	705,	1757057797,	1757057797,	0,	0,	'4d3c0c4dce803fd737da7d8a20479ef2',	27,	''),
(85,	2,	'appdata_ocls225bjeq5/preview/b/5',	'afacfdb5f5a93da2754d0c0183216cfe',	82,	'5',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305a0607',	31,	''),
(86,	2,	'appdata_ocls225bjeq5/preview/d',	'02d7b4bb93cf8567f19e7538f54cd574',	81,	'd',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba95b72c9e1',	31,	''),
(87,	2,	'appdata_ocls225bjeq5/preview/b/5/3',	'9a886095385550fa748c50d02bd147b7',	85,	'3',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba93059d3ec',	31,	''),
(88,	2,	'appdata_ocls225bjeq5/preview/9',	'78fb630b74a95ba2dcaf25ccce494607',	81,	'9',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba95b72c9f2',	31,	''),
(89,	2,	'appdata_ocls225bjeq5/preview/d/8',	'92c02d34faa753205a1104c8e6ab504d',	86,	'8',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305a0c62',	31,	''),
(90,	2,	'appdata_ocls225bjeq5/preview/b/5/3/b',	'3deb76d15d2c2a9044641be392cac297',	87,	'b',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305982af',	31,	''),
(91,	2,	'appdata_ocls225bjeq5/preview/9/f',	'9f1524c9940aedcafd5d7141eee92443',	88,	'f',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305a0e55',	31,	''),
(92,	2,	'appdata_ocls225bjeq5/theming/global/0/icon-core-#00679efiletypes_text.svg',	'a8d4f609c26f95a785c30ef59a789a6c',	64,	'icon-core-#00679efiletypes_text.svg',	22,	13,	299,	1757057797,	1757057797,	0,	0,	'1ab82d45f8f8d59a6c22053d57dbf709',	27,	''),
(93,	2,	'appdata_ocls225bjeq5/preview/d/8/2',	'a6a3964688b9f3263d7ffca9103c9308',	89,	'2',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba93059d7bc',	31,	''),
(94,	2,	'appdata_ocls225bjeq5/preview/b/5/3/b/3',	'8e7c4167439d165e09137ba12ce0da95',	90,	'3',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba930594137',	31,	''),
(95,	2,	'appdata_ocls225bjeq5/preview/9/f/6',	'2f9bad8bd9cde97cbe455c7a5f873625',	91,	'6',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba93059d9cf',	31,	''),
(96,	2,	'appdata_ocls225bjeq5/preview/d/8/2/c',	'490504b01443e37fe1eb476e9f51e325',	93,	'c',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba93059932a',	31,	''),
(97,	2,	'appdata_ocls225bjeq5/preview/b/5/3/b/3/a',	'd964ed75e23460ff0bf222a63f7664a5',	94,	'a',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba930591058',	31,	''),
(98,	2,	'appdata_ocls225bjeq5/preview/9/f/6/1',	'5bdccde1920155f5282ca4def89052b7',	95,	'1',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba93059af18',	31,	''),
(99,	2,	'appdata_ocls225bjeq5/preview/d/8/2/c/8',	'f48584f590808e141ee267f56c1c783e',	96,	'8',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba930595c1e',	31,	''),
(100,	2,	'appdata_ocls225bjeq5/preview/b/5/3/b/3/a/3',	'04b4ca386e954b5995c8b61ec539c8c1',	97,	'3',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba93058b8cb',	31,	''),
(101,	2,	'appdata_ocls225bjeq5/preview/9/f/6/1/4',	'ab21aca0c0741ccfe15df594b243f75c',	98,	'4',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba930596cc9',	31,	''),
(102,	2,	'appdata_ocls225bjeq5/preview/d/8/2/c/8/d',	'077843a3921fbff364bd28112e4aa9bd',	99,	'd',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305922ba',	31,	''),
(103,	2,	'appdata_ocls225bjeq5/preview/a',	'38cb42ef14541461cced1ddd80e01b34',	81,	'a',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba95b72c95f',	31,	''),
(104,	2,	'appdata_ocls225bjeq5/preview/b/5/3/b/3/a/3/55',	'85ee431dc2a81997cba9ce3e70de14de',	100,	'55',	2,	1,	0,	1757057813,	1757057813,	0,	0,	'68ba9305863e8',	31,	''),
(105,	2,	'appdata_ocls225bjeq5/preview/9/f/6/1/4/0',	'922832c0cd6d78aab95c76eccad94bb7',	101,	'0',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba93059252d',	31,	''),
(106,	2,	'appdata_ocls225bjeq5/preview/d/8/2/c/8/d/1',	'35603202e211ade8f71e62b0b39d12ec',	102,	'1',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba93058da1e',	31,	''),
(107,	2,	'appdata_ocls225bjeq5/preview/a/6',	'47e0e9ba8ddb3d262a808731626cacdb',	103,	'6',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305b30b0',	31,	''),
(108,	2,	'appdata_ocls225bjeq5/preview/9/f/6/1/4/0/8',	'8149a3a814a3778b17b497d9e1f83e36',	105,	'8',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba93058f56d',	31,	''),
(109,	2,	'appdata_ocls225bjeq5/preview/d/8/2/c/8/d/1/53',	'3edc3f13608b9b6526a08e9616968b1a',	106,	'53',	2,	1,	0,	1757057813,	1757057813,	0,	0,	'68ba93058843d',	31,	''),
(110,	2,	'appdata_ocls225bjeq5/preview/a/6/8',	'b8255ea070a2c67a2632849e5eba9d87',	107,	'8',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305adef4',	31,	''),
(111,	2,	'appdata_ocls225bjeq5/preview/9/f/6/1/4/0/8/56',	'2cf46b4d64b0e6b5f9d959f2ece72fda',	108,	'56',	2,	1,	0,	1757057813,	1757057813,	0,	0,	'68ba93058b0f8',	31,	''),
(112,	2,	'appdata_ocls225bjeq5/preview/a/6/8/4',	'98818d697cb22b923e9b36f6d2127fa0',	110,	'4',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305a7e46',	31,	''),
(113,	2,	'appdata_ocls225bjeq5/preview/a/6/8/4/e',	'8bd382d48c3a917d37c0046ef04882c1',	112,	'e',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305a4cff',	31,	''),
(114,	2,	'appdata_ocls225bjeq5/preview/a/6/8/4/e/c',	'd50105d0369b4fca66e24b4278c5d9c6',	113,	'c',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305a090a',	31,	''),
(115,	2,	'appdata_ocls225bjeq5/preview/a/6/8/4/e/c/e',	'6ba6826dceb6c3ac389c245bf713942b',	114,	'e',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba93059d603',	31,	''),
(116,	2,	'appdata_ocls225bjeq5/preview/a/6/8/4/e/c/e/54',	'a68dda698523c4b13ab98f2dd8419e36',	115,	'54',	2,	1,	0,	1757057813,	1757057813,	0,	0,	'68ba930598d73',	31,	''),
(117,	2,	'appdata_ocls225bjeq5/preview/d/8/2/c/8/d/1/53/1600-1067-max.jpg',	'4853f2acbf55672f4c9e9b5f6121a7fa',	109,	'1600-1067-max.jpg',	15,	13,	232378,	1757057797,	1757057797,	0,	0,	'8264eb8ee9f742e2de37d848f6fc1720',	27,	''),
(118,	2,	'appdata_ocls225bjeq5/preview/c',	'8c244594ec38ea1a9343ab0d9723bfe3',	81,	'c',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba95b72c9ab',	31,	''),
(119,	2,	'appdata_ocls225bjeq5/preview/c/0',	'bd6f4655973131478f70ca8c64503cd3',	118,	'0',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305ebf7c',	31,	''),
(120,	2,	'appdata_ocls225bjeq5/preview/9/a',	'c4e995ec9106beef9a30fd3b7d10fca7',	88,	'a',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305f1095',	31,	''),
(121,	2,	'appdata_ocls225bjeq5/preview/c/0/c',	'0e3afffc0ac80b6bbcf046bdc0ff7772',	119,	'c',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305ea36a',	31,	''),
(122,	2,	'appdata_ocls225bjeq5/preview/b/5/3/b/3/a/3/55/4096-4096-max.png',	'faa97a1a0827cea77c6768d31530047e',	104,	'4096-4096-max.png',	14,	13,	36192,	1757057797,	1757057797,	0,	0,	'fa760ea040ed362c94dfdf3f5c56eee5',	27,	''),
(123,	2,	'appdata_ocls225bjeq5/preview/9/a/1',	'da413070084a07f407534678e03c3bf2',	120,	'1',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305eecad',	31,	''),
(124,	2,	'appdata_ocls225bjeq5/preview/c/0/c/7',	'6c930283b5ff473436ae1afc7dea1ad0',	121,	'7',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305e4dc3',	31,	''),
(125,	2,	'appdata_ocls225bjeq5/preview/a/6/8/4/e/c/e/54/1600-1067-max.jpg',	'291779219c2a8f7d17f684f523cf9a04',	116,	'1600-1067-max.jpg',	15,	13,	137923,	1757057798,	1757057798,	0,	0,	'9670c9787201acd80f6973d07d949201',	27,	''),
(126,	2,	'appdata_ocls225bjeq5/preview/9/a/1/1',	'6aef4dcff7742f2380b4cb29aa61ac28',	123,	'1',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305ecf41',	31,	''),
(127,	2,	'appdata_ocls225bjeq5/preview/c/0/c/7/c',	'22f9180a73949f643ad2192845ba2806',	124,	'c',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305df494',	31,	''),
(128,	2,	'appdata_ocls225bjeq5/preview/d/8/2/c/8/d/1/53/256-256-crop.jpg',	'474888884352c6710dfc744e8e1c7b1b',	109,	'256-256-crop.jpg',	15,	13,	13880,	1757057798,	1757057798,	0,	0,	'2e65e7ed9c1ad502606a6e4b6c2a2231',	27,	''),
(129,	2,	'appdata_ocls225bjeq5/preview/9/a/1/1/5',	'4382a6c83e344a779ec21606a0246c61',	126,	'5',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305ea745',	31,	''),
(130,	2,	'appdata_ocls225bjeq5/preview/c/0/c/7/c/7',	'44e2e32a40abb6906c3ffc43f5be30ad',	127,	'7',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305dcacb',	31,	''),
(131,	2,	'appdata_ocls225bjeq5/preview/c/0/c/7/c/7/6',	'1479c167e1190b4ee9082faae5511e91',	130,	'6',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305d69ed',	31,	''),
(132,	2,	'appdata_ocls225bjeq5/preview/9/a/1/1/5/8',	'9bbf80b308524d1aeeb9a426584837ac',	129,	'8',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305e5cfb',	31,	''),
(133,	2,	'appdata_ocls225bjeq5/preview/c/0/c/7/c/7/6/50',	'b9272bdf47a7d595a30b5c0f45ad63f1',	131,	'50',	2,	1,	0,	1757057814,	1757057814,	0,	0,	'68ba9305d0c98',	31,	''),
(134,	2,	'appdata_ocls225bjeq5/preview/9/a/1/1/5/8/1',	'880f5f20b67604f207a60e449e621877',	132,	'1',	2,	1,	-1,	1757057797,	1757057797,	0,	0,	'68ba9305e21b4',	31,	''),
(135,	2,	'appdata_ocls225bjeq5/preview/9/a/1/1/5/8/1/52',	'dbc9aacf2ef41eef5d39fde40aee922e',	134,	'52',	2,	1,	0,	1757057814,	1757057814,	0,	0,	'68ba9305de150',	31,	''),
(136,	2,	'appdata_ocls225bjeq5/preview/9/f/6/1/4/0/8/56/3000-2000-max.jpg',	'd90c2e5b4c49e50510a2d49e62ba2d1f',	111,	'3000-2000-max.jpg',	15,	13,	808212,	1757057798,	1757057798,	0,	0,	'5def1e51038879c24814b2c3ff0d88bb',	27,	''),
(137,	2,	'appdata_ocls225bjeq5/preview/a/6/8/4/e/c/e/54/256-256-crop.jpg',	'39dea292e009926f50ac5927d0c4b8fe',	116,	'256-256-crop.jpg',	15,	13,	13785,	1757057798,	1757057798,	0,	0,	'97e0766e41f6534bfee77fab564265c5',	27,	''),
(138,	2,	'appdata_ocls225bjeq5/preview/c/0/c/7/c/7/6/50/1200-1800-max.jpg',	'bcb1a013ebaef311e1f5378d24d979c3',	133,	'1200-1800-max.jpg',	15,	13,	207095,	1757057798,	1757057798,	0,	0,	'cfd8607f832f6f19283e2e7e3e864444',	27,	''),
(139,	2,	'appdata_ocls225bjeq5/preview/9/a/1/1/5/8/1/52/1920-1281-max.jpg',	'ad3b2b54718ed99ea49c6f8a1e2cafa2',	135,	'1920-1281-max.jpg',	15,	13,	294390,	1757057798,	1757057798,	0,	0,	'ef782e8d177bbe2875ba34a44b8fbf1a',	27,	''),
(140,	2,	'appdata_ocls225bjeq5/preview/c/0/c/7/c/7/6/50/256-256-crop.jpg',	'cb36e7438078f76aa5d7c8bdd98b43af',	133,	'256-256-crop.jpg',	15,	13,	8544,	1757057798,	1757057798,	0,	0,	'98c0b397056493ad4fd8e997217030dd',	27,	''),
(141,	2,	'appdata_ocls225bjeq5/preview/9/f/6/1/4/0/8/56/256-256-crop.jpg',	'4dbd4e7a9e978d88282354d05e1d61c3',	111,	'256-256-crop.jpg',	15,	13,	21315,	1757057798,	1757057798,	0,	0,	'7a0a57082fb0fed9ded824778c59f655',	27,	''),
(142,	2,	'appdata_ocls225bjeq5/preview/9/a/1/1/5/8/1/52/256-256-crop.jpg',	'3a77e933d97af3d6d54731fa1f867329',	135,	'256-256-crop.jpg',	15,	13,	15761,	1757057798,	1757057798,	0,	0,	'859729372df9103a526bdc43c4256fb9',	27,	''),
(143,	2,	'appdata_ocls225bjeq5/preview/b/5/3/b/3/a/3/55/256-256-crop.png',	'03876ac15b2bc95d2913103819cd22d8',	104,	'256-256-crop.png',	14,	13,	6477,	1757057798,	1757057798,	0,	0,	'00a374727971b8fd8fd08f18f76c2aec',	27,	''),
(144,	2,	'appdata_ocls225bjeq5/theming/global/0/favIcon-files#00679e',	'f089a3ec63e917416aebcf4e0e482e11',	64,	'favIcon-files#00679e',	18,	3,	90022,	1757057812,	1757057812,	0,	0,	'6e1a25e2249cd2de390a4e549ba1c1bb',	27,	''),
(145,	2,	'appdata_ocls225bjeq5/theming/global/0/touchIcon-files#00679e',	'448c438d56d2865f0bd3123facd91fdf',	64,	'touchIcon-files#00679e',	18,	3,	9414,	1757057812,	1757057812,	0,	0,	'69883abd130860fd96d67cabcf80a6ad',	27,	''),
(146,	2,	'appdata_ocls225bjeq5/preview/a/6/8/4/e/c/e/54/64-64-crop.jpg',	'942bb47b8d7e12c31ff7a584e600fcce',	116,	'64-64-crop.jpg',	15,	13,	2099,	1757057813,	1757057813,	0,	0,	'070ea39c88389e92a5af25e2f736568e',	27,	''),
(147,	2,	'appdata_ocls225bjeq5/preview/c/0/c/7/c/7/6/50/64-64-crop.jpg',	'985eddf3c423936cce7edb1aedc4e1ea',	133,	'64-64-crop.jpg',	15,	13,	1313,	1757057813,	1757057813,	0,	0,	'f218d87f8e337f10fc0b47ce71a122ed',	27,	''),
(148,	2,	'appdata_ocls225bjeq5/preview/9/a/1/1/5/8/1/52/64-64-crop.jpg',	'8b818b386ca01b1990682e082cfea9ba',	135,	'64-64-crop.jpg',	15,	13,	1936,	1757057813,	1757057813,	0,	0,	'34304a83c8b80ee1939347c240fd1841',	27,	''),
(149,	2,	'appdata_ocls225bjeq5/preview/9/f/6/1/4/0/8/56/64-64-crop.jpg',	'b8de35e86866cced511c6bf01e1e370e',	111,	'64-64-crop.jpg',	15,	13,	2201,	1757057813,	1757057813,	0,	0,	'd77826f2d8eed3cc17fcb7126d898491',	27,	''),
(150,	2,	'appdata_ocls225bjeq5/preview/b/5/3/b/3/a/3/55/64-64-crop.png',	'41f376a4f24ed2539da2e871b600ea63',	104,	'64-64-crop.png',	14,	13,	903,	1757057813,	1757057813,	0,	0,	'ea930212d27797a604f185bf4ca8f592',	27,	''),
(151,	2,	'appdata_ocls225bjeq5/preview/d/8/2/c/8/d/1/53/64-64-crop.jpg',	'69ffbed59391acb642f4e75fc0f23135',	109,	'64-64-crop.jpg',	15,	13,	1613,	1757057813,	1757057813,	0,	0,	'7bcfa4de6c94d0b79f22c559fc4ee183',	27,	''),
(152,	2,	'appdata_ocls225bjeq5/preview/f',	'24adf0624c72b1f3e4d561022f1e13cc',	81,	'f',	2,	1,	-1,	1757057813,	1757057813,	0,	0,	'68ba95b72c989',	31,	''),
(153,	2,	'appdata_ocls225bjeq5/preview/2',	'f94eefeea43d128b0148585e7322017e',	81,	'2',	2,	1,	-1,	1757057813,	1757057813,	0,	0,	'68ba95b72c9be',	31,	''),
(156,	2,	'appdata_ocls225bjeq5/preview/f/4',	'ded8e30a2466c16af372723d9920da55',	152,	'4',	2,	1,	-1,	1757057813,	1757057813,	0,	0,	'68ba9315d9a84',	31,	''),
(157,	2,	'appdata_ocls225bjeq5/preview/2/8',	'89a17bfa369979e6ec6602a784b37f61',	153,	'8',	2,	1,	-1,	1757057813,	1757057813,	0,	0,	'68ba9315d7690',	31,	''),
(158,	2,	'appdata_ocls225bjeq5/preview/f/4/5',	'3cc5e8caca7d7689bc5605ce6d68ea88',	156,	'5',	2,	1,	-1,	1757057813,	1757057813,	0,	0,	'68ba9315d6cce',	31,	''),
(159,	2,	'appdata_ocls225bjeq5/preview/2/8/3',	'85b64259f4ced074b4bc7957e7bf8879',	157,	'3',	2,	1,	-1,	1757057813,	1757057813,	0,	0,	'68ba9315d42c4',	31,	''),
(160,	2,	'appdata_ocls225bjeq5/preview/a/6/8/4/e/c/e/54/1536-1024.jpg',	'726e33276095ef773bc27a3366549e4f',	116,	'1536-1024.jpg',	15,	13,	158333,	1757057813,	1757057813,	0,	0,	'f61725a1bd6e74382a0091ae74b09f1a',	27,	''),
(161,	2,	'appdata_ocls225bjeq5/preview/f/4/5/7',	'6a68427f6e9f3aa737770bbe3b2e90cc',	158,	'7',	2,	1,	-1,	1757057813,	1757057813,	0,	0,	'68ba9315d3360',	31,	''),
(162,	2,	'appdata_ocls225bjeq5/preview/2/8/3/8',	'e207bd5d7fadebc32b5ac6ed98a8817d',	159,	'8',	2,	1,	-1,	1757057813,	1757057813,	0,	0,	'68ba9315d0c85',	31,	''),
(163,	2,	'appdata_ocls225bjeq5/preview/f/4/5/7/c',	'56fce7cb6b3b5de9b98523439d8c2a0b',	161,	'c',	2,	1,	-1,	1757057813,	1757057813,	0,	0,	'68ba9315cfcb0',	31,	''),
(164,	2,	'appdata_ocls225bjeq5/preview/2/8/3/8/0',	'ab0ce12f20092bd3e2a4f36da89fabc5',	162,	'0',	2,	1,	-1,	1757057813,	1757057813,	0,	0,	'68ba9315cd303',	31,	''),
(165,	2,	'appdata_ocls225bjeq5/text',	'f72dd1bb8bdf54db5d43533adfa0c4c9',	59,	'text',	2,	1,	0,	1757057814,	1757057814,	0,	0,	'68ba931604baa',	31,	''),
(166,	2,	'appdata_ocls225bjeq5/preview/f/4/5/7/c/5',	'5f7d9f642a4ed4e59e45737cd3f6b8a8',	163,	'5',	2,	1,	-1,	1757057813,	1757057813,	0,	0,	'68ba9315cc0e4',	31,	''),
(167,	2,	'appdata_ocls225bjeq5/preview/2/8/3/8/0/2',	'ffbd33d0488bfeedad61fa40450def26',	164,	'2',	2,	1,	-1,	1757057813,	1757057813,	0,	0,	'68ba9315c9c5d',	31,	''),
(168,	2,	'appdata_ocls225bjeq5/preview/6',	'59a227663e1a4d7d8e5341948e5cfa8b',	81,	'6',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b72c99b',	31,	''),
(169,	2,	'appdata_ocls225bjeq5/preview/f/4/5/7/c/5/4',	'8b771d95c8f4107fa3c73d453b39fe6d',	166,	'4',	2,	1,	-1,	1757057813,	1757057813,	0,	0,	'68ba9315c8b5c',	31,	''),
(170,	2,	'appdata_ocls225bjeq5/preview/2/8/3/8/0/2/3',	'b63ea75ad2702ce3ad261cac880f2587',	167,	'3',	2,	1,	-1,	1757057813,	1757057813,	0,	0,	'68ba9315c5e3c',	31,	''),
(171,	2,	'appdata_ocls225bjeq5/preview/6/4',	'c0a709fc147a6133aa429a788dcc343f',	168,	'4',	2,	1,	-1,	1757057813,	1757057813,	0,	0,	'68ba9316053e4',	31,	''),
(172,	2,	'appdata_ocls225bjeq5/preview/f/4/5/7/c/5/4/49',	'eca9f3e7f80a7053ad625762d4860b35',	169,	'49',	2,	1,	0,	1757057814,	1757057814,	0,	0,	'68ba9315c581d',	31,	''),
(173,	2,	'appdata_ocls225bjeq5/preview/2/8/3/8/0/2/3/51',	'd78ea4c7434011ffa2a71247c24a8d86',	170,	'51',	2,	1,	0,	1757057814,	1757057814,	0,	0,	'68ba9315bc664',	31,	''),
(174,	2,	'appdata_ocls225bjeq5/preview/6/4/2',	'd37fd2a1a6422b8f884b5ab0d4baff34',	171,	'2',	2,	1,	-1,	1757057813,	1757057813,	0,	0,	'68ba9316020c6',	31,	''),
(175,	2,	'appdata_ocls225bjeq5/text/documents',	'18b3cfd1095cbf15247ed8fe8a75414c',	165,	'documents',	2,	1,	0,	1757057814,	1757057814,	0,	0,	'68ba9316136eb',	31,	''),
(176,	2,	'appdata_ocls225bjeq5/preview/6/4/2/e',	'5020dd5fc0e2c1a53419f4039c179e01',	174,	'e',	2,	1,	-1,	1757057813,	1757057813,	0,	0,	'68ba9315f2914',	31,	''),
(177,	2,	'appdata_ocls225bjeq5/preview/6/4/2/e/9',	'32070d0833b9245831c469375b0f88e8',	176,	'9',	2,	1,	-1,	1757057813,	1757057813,	0,	0,	'68ba9315ee559',	31,	''),
(178,	2,	'appdata_ocls225bjeq5/preview/6/4/2/e/9/2',	'6067409640d0611ada9605b492ccc565',	177,	'2',	2,	1,	-1,	1757057813,	1757057813,	0,	0,	'68ba9315e9ff7',	31,	''),
(179,	2,	'appdata_ocls225bjeq5/preview/6/4/2/e/9/2/e',	'2bcd164b7cc5f8d3e72d2d5da53b2cc0',	178,	'e',	2,	1,	-1,	1757057813,	1757057813,	0,	0,	'68ba9315e716e',	31,	''),
(180,	2,	'appdata_ocls225bjeq5/preview/6/4/2/e/9/2/e/48',	'ddc030fafc061cc533448cb74a532332',	179,	'48',	2,	1,	0,	1757057814,	1757057814,	0,	0,	'68ba9315e5005',	31,	''),
(181,	2,	'appdata_ocls225bjeq5/preview/c/0/c/7/c/7/6/50/683-1024.jpg',	'5ecdd465a5ee56400636d1214ff31686',	133,	'683-1024.jpg',	15,	13,	67033,	1757057814,	1757057814,	0,	0,	'600ca1d34ba6a7d6c9a59e7e6c6e487f',	27,	''),
(182,	2,	'appdata_ocls225bjeq5/preview/f/4/5/7/c/5/4/49/1600-1067-max.jpg',	'e4c1face7a3417b877dea764bec04d00',	172,	'1600-1067-max.jpg',	15,	13,	165982,	1757057814,	1757057814,	0,	0,	'db7fa2c2eedb3f42d9caf3668dba0434',	27,	''),
(183,	2,	'appdata_ocls225bjeq5/preview/6/4/2/e/9/2/e/48/1600-1067-max.jpg',	'daa8e6981934a7001b6f7772ab5b26a1',	180,	'1600-1067-max.jpg',	15,	13,	147631,	1757057814,	1757057814,	0,	0,	'ae08328e7ab272846927db142d3fe035',	27,	''),
(184,	2,	'appdata_ocls225bjeq5/preview/2/8/3/8/0/2/3/51/1600-1066-max.jpg',	'dc79d78d82cdd84e2414ecc6017e1569',	173,	'1600-1066-max.jpg',	15,	13,	351167,	1757057814,	1757057814,	0,	0,	'b1c5f83de73ce455cb9e8f92ef7a22a1',	27,	''),
(185,	2,	'appdata_ocls225bjeq5/preview/f/4/5/7/c/5/4/49/64-64-crop.jpg',	'a8d3831c214185536eda678563cf3fd3',	172,	'64-64-crop.jpg',	15,	13,	1823,	1757057814,	1757057814,	0,	0,	'f2cbdd7c38b82fd9d7f67c937b914893',	27,	''),
(186,	2,	'appdata_ocls225bjeq5/preview/9/a/1/1/5/8/1/52/1535-1024.jpg',	'1fce6a64c553476ba77e91ed1b1128c1',	135,	'1535-1024.jpg',	15,	13,	190974,	1757057814,	1757057814,	0,	0,	'0fc44fae560da67be670dde46192b841',	27,	''),
(187,	2,	'appdata_ocls225bjeq5/preview/6/4/2/e/9/2/e/48/64-64-crop.jpg',	'b5eada23a100b404f49c7794667b989e',	180,	'64-64-crop.jpg',	15,	13,	1492,	1757057814,	1757057814,	0,	0,	'0806edab651205e8c3fa438f53e4f1bc',	27,	''),
(188,	2,	'appdata_ocls225bjeq5/preview/2/8/3/8/0/2/3/51/64-64-crop.jpg',	'5f516e5b68c08173b9a85c879e1e8121',	173,	'64-64-crop.jpg',	15,	13,	1901,	1757057814,	1757057814,	0,	0,	'2317de056fe61bb7bac31f171059c8d0',	27,	''),
(189,	2,	'appdata_ocls225bjeq5/appstore',	'a3307f6b8b928372dd06747015919a35',	59,	'appstore',	2,	1,	0,	1757057968,	1757057968,	0,	0,	'68ba93ad6f47c',	31,	''),
(190,	2,	'appdata_ocls225bjeq5/appstore/apps.json',	'5008ec157963b0dbbce926f416129d0a',	189,	'apps.json',	24,	3,	2922416,	1757057966,	1757057966,	0,	0,	'848581664139708a05125de41d13623f',	27,	''),
(191,	2,	'appdata_ocls225bjeq5/appstore/appapi_apps.json',	'081e670255ad329adf206a697b17678d',	189,	'appapi_apps.json',	24,	3,	82779,	1757057966,	1757057966,	0,	0,	'b3a5afca1521302b9449aeb141e124ad',	27,	''),
(192,	2,	'appdata_ocls225bjeq5/theming/global/0/favIcon-settings#00679e',	'8fac5241d4eeccfd3fdfc846a0c4956a',	64,	'favIcon-settings#00679e',	18,	3,	90022,	1757057967,	1757057967,	0,	0,	'c6d15e27547d9f90551a8a15de2c86f3',	27,	''),
(193,	2,	'appdata_ocls225bjeq5/theming/global/0/touchIcon-settings#00679e',	'bcbcda83a6d3296b98310fa60a9a6234',	64,	'touchIcon-settings#00679e',	18,	3,	8354,	1757057967,	1757057967,	0,	0,	'9115a8ed54162bfb0ebf01bc613ed12c',	27,	''),
(194,	2,	'appdata_ocls225bjeq5/appstore/categories.json',	'b9a1583dda3875c0d3b9a97f39d1d601',	189,	'categories.json',	24,	3,	170863,	1757057967,	1757057967,	0,	0,	'13362d6cd05347315115271db592dca4',	27,	''),
(195,	2,	'appdata_ocls225bjeq5/appstore/discover.json',	'aa73e7de384f635deba517eafcb54220',	189,	'discover.json',	24,	3,	7272,	1757057967,	1757057967,	0,	0,	'a3f20334d92a0ad48617ed91ba5df79c',	27,	''),
(196,	2,	'appdata_ocls225bjeq5/appstore/app-discover-cache',	'557dd2be64f022f388bbc6188a6eafad',	189,	'app-discover-cache',	2,	1,	-1,	1757057968,	1757057968,	0,	0,	'68ba93b0a0e92',	31,	''),
(197,	2,	'appdata_ocls225bjeq5/appstore/app-discover-cache/68ba9179-92a',	'ff8f47334b18a46e8210235b5fc3cf18',	196,	'68ba9179-92a',	2,	1,	0,	1757057968,	1757057968,	0,	0,	'68ba93b09eb96',	31,	''),
(198,	2,	'appdata_ocls225bjeq5/appstore/app-discover-cache/68ba9179-92a/3289725285460e73018ab98c443beb37.aW1hZ2UvcG5n.png',	'009bfa644f8ea7d4a31edf75149d8a44',	197,	'3289725285460e73018ab98c443beb37.aW1hZ2UvcG5n.png',	14,	13,	314506,	1757057968,	1757057968,	0,	0,	'ad96f5063e35a45cc398e755b6b0a568',	27,	''),
(199,	2,	'appdata_ocls225bjeq5/appstore/app-discover-cache/68ba9179-92a/acffabdbe5148794e282887781da1988.aW1hZ2UvcG5n.png',	'f52a7a3b3a22a5d924bfe33256af8bea',	197,	'acffabdbe5148794e282887781da1988.aW1hZ2UvcG5n.png',	14,	13,	1150887,	1757057968,	1757057968,	0,	0,	'0cffb460b6f9cf6bebca1371418ad068',	27,	''),
(200,	2,	'appdata_ocls225bjeq5/appstore/app-discover-cache/68ba9179-92a/a65457f45bd7facd2a91f6927e8dce6c.YXVkaW8vd2VibQ==.webm',	'd1106fc2077bdcc80c42e49f8dafdf52',	197,	'a65457f45bd7facd2a91f6927e8dce6c.YXVkaW8vd2VibQ==.webm',	25,	16,	821961,	1757057968,	1757057968,	0,	0,	'18426e218824f50e07e48e2b170c0bb5',	27,	''),
(201,	2,	'appdata_ocls225bjeq5/preview/1',	'7c5284c72226c77e51072ff8fc887b96',	81,	'1',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b73863f',	31,	''),
(203,	2,	'appdata_ocls225bjeq5/preview/6/c',	'69a7f623c95c2ecb2f035d6888027fae',	168,	'c',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b73eabb',	31,	''),
(204,	2,	'appdata_ocls225bjeq5/preview/6/c/8',	'7538319e8be92a0890be9de134902f4f',	203,	'8',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b7319ca',	31,	''),
(205,	2,	'appdata_ocls225bjeq5/preview/1/7',	'478dba83358188e677b5253c45f312be',	201,	'7',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b736012',	31,	''),
(206,	2,	'appdata_ocls225bjeq5/preview/6/c/8/3',	'eecddea671c58efe14a9b2793ca6ee36',	204,	'3',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b72e283',	31,	''),
(207,	2,	'appdata_ocls225bjeq5/preview/1/7/e',	'08123aebf732faa71152f04dc2bbc861',	205,	'e',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b733c80',	31,	''),
(208,	2,	'appdata_ocls225bjeq5/preview/6/c/8/3/4',	'3177533965577f5315aa4fcfa732299d',	206,	'4',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b72b77a',	31,	''),
(209,	2,	'appdata_ocls225bjeq5/preview/1/7/e/6',	'8a904dedb23e7d203649b36d4b84bee1',	207,	'6',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b72f77d',	31,	''),
(210,	2,	'appdata_ocls225bjeq5/preview/6/c/8/3/4/9',	'087c7d5b45ba2c5e7783f146383af9a2',	208,	'9',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b729f2d',	31,	''),
(211,	2,	'appdata_ocls225bjeq5/preview/1/7/e/6/2',	'99f87d82250698be829ce1dded981006',	209,	'2',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b72d1e8',	31,	''),
(212,	2,	'appdata_ocls225bjeq5/preview/6/c/8/3/4/9/c',	'59a73f263291650e3820bfdc4a031434',	210,	'c',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b7270fe',	31,	''),
(213,	2,	'appdata_ocls225bjeq5/preview/1/7/e/6/2/1',	'b66586cd33319d68efc0caad281c0f22',	211,	'1',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b72a8c8',	31,	''),
(214,	2,	'appdata_ocls225bjeq5/preview/6/c/8/3/4/9/c/45',	'b00d921a4fbf44bf4d3cba1ea18cf747',	212,	'45',	2,	1,	0,	1757058487,	1757058487,	0,	0,	'68ba95b723a50',	31,	''),
(215,	2,	'appdata_ocls225bjeq5/preview/1/7/e/6/2/1/6',	'991a03743c93fc799b08ff2b5d8df74b',	213,	'6',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b7273b3',	31,	''),
(216,	2,	'appdata_ocls225bjeq5/preview/1/7/e/6/2/1/6/43',	'46b7b0ff0e0539a10f2ac9bc8fc1091c',	215,	'43',	2,	1,	0,	1757058487,	1757058487,	0,	0,	'68ba95b72405a',	31,	''),
(217,	2,	'appdata_ocls225bjeq5/preview/f/7',	'd5ee8db6c636fc900c3c6aaec4177433',	152,	'7',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b756c88',	31,	''),
(218,	2,	'appdata_ocls225bjeq5/preview/f/7/1',	'b53cfe6c69d4f4425a2d62f1d36adc8a',	217,	'1',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b753f56',	31,	''),
(219,	2,	'appdata_ocls225bjeq5/preview/f/7/1/7',	'03aba94378d97ee8104b54c84cfbda8c',	218,	'7',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b751846',	31,	''),
(220,	2,	'appdata_ocls225bjeq5/preview/f/7/1/7/7',	'fe6ba7516bac1c9fee3eea4c883d3d74',	219,	'7',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b74e5bc',	31,	''),
(221,	2,	'appdata_ocls225bjeq5/preview/f/7/1/7/7/1',	'3dc4da221388dcbe2cc2627649f0185d',	220,	'1',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b74acc2',	31,	''),
(222,	2,	'appdata_ocls225bjeq5/preview/f/7/1/7/7/1/6',	'1b287cb49ac627e7166eff8ee65bd005',	221,	'6',	2,	1,	-1,	1757058487,	1757058487,	0,	0,	'68ba95b748356',	31,	''),
(223,	2,	'appdata_ocls225bjeq5/preview/f/7/1/7/7/1/6/44',	'2ea649c2baab985ba177e2533bff0045',	222,	'44',	2,	1,	0,	1757058487,	1757058487,	0,	0,	'68ba95b744212',	31,	''),
(224,	2,	'appdata_ocls225bjeq5/preview/f/7/1/7/7/1/6/44/500-500-max.png',	'a5499b7c7c4a0db7689dac7982c604f2',	223,	'500-500-max.png',	14,	13,	50545,	1757058487,	1757058487,	0,	0,	'a33b218c57017b8455d54d7aba6633f0',	27,	''),
(225,	2,	'appdata_ocls225bjeq5/preview/f/7/1/7/7/1/6/44/64-64-crop.png',	'5ded6580afe63c321042786f8c2ba05a',	223,	'64-64-crop.png',	14,	13,	3895,	1757058487,	1757058487,	0,	0,	'5ee1102f15bf2bcf77463910c97a1ad0',	27,	''),
(226,	2,	'appdata_ocls225bjeq5/preview/1/7/e/6/2/1/6/43/4096-4096-max.png',	'91d4bd01a70526cd749e4f20927c92b7',	216,	'4096-4096-max.png',	14,	13,	49132,	1757058487,	1757058487,	0,	0,	'dd28a88080266b0b8cb113860235f0af',	27,	''),
(227,	2,	'appdata_ocls225bjeq5/preview/6/c/8/3/4/9/c/45/4096-4096-max.png',	'b41dca049f05d952cfc38daf84d027cd',	214,	'4096-4096-max.png',	14,	13,	185668,	1757058487,	1757058487,	0,	0,	'0d01465ef8120c4ec9de370602e612c9',	27,	''),
(228,	2,	'appdata_ocls225bjeq5/preview/1/7/e/6/2/1/6/43/64-64-crop.png',	'f5aad8085a4950c6fcb6b76ca613735f',	216,	'64-64-crop.png',	14,	13,	1243,	1757058487,	1757058487,	0,	0,	'a9f5a7b5b305ae873cca9fc741dce111',	27,	''),
(229,	2,	'appdata_ocls225bjeq5/preview/6/c/8/3/4/9/c/45/64-64-crop.png',	'6b1131b548f27c1dbe2dc4ab850ef9b4',	214,	'64-64-crop.png',	14,	13,	3102,	1757058487,	1757058487,	0,	0,	'2bdbd3076516a066757bf6f22cd60d15',	27,	'');

DROP TABLE IF EXISTS `oc_filecache_extended`;
CREATE TABLE `oc_filecache_extended` (
  `fileid` bigint unsigned NOT NULL,
  `metadata_etag` varchar(40) COLLATE utf8mb4_bin DEFAULT NULL,
  `creation_time` bigint NOT NULL DEFAULT '0',
  `upload_time` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`fileid`),
  KEY `fce_ctime_idx` (`creation_time`),
  KEY `fce_utime_idx` (`upload_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_files_metadata`;
CREATE TABLE `oc_files_metadata` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `file_id` bigint NOT NULL,
  `json` longtext COLLATE utf8mb4_bin NOT NULL,
  `sync_token` varchar(15) COLLATE utf8mb4_bin NOT NULL,
  `last_update` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `files_meta_fileid` (`file_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_files_metadata` (`id`, `file_id`, `json`, `sync_token`, `last_update`) VALUES
(1,	44,	'{\"photos-original_date_time\":{\"value\":1757057752,\"type\":\"int\",\"etag\":\"\",\"indexed\":true,\"editPermission\":0},\"photos-size\":{\"value\":{\"width\":500,\"height\":500},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0}}',	'uz5mBpI',	'2025-09-05 07:35:52'),
(2,	48,	'{\"photos-original_date_time\":{\"value\":1341072915,\"type\":\"int\",\"etag\":\"\",\"indexed\":true,\"editPermission\":0},\"photos-exif\":{\"value\":{\"ExposureTime\":\"1\\/500\",\"FNumber\":\"28\\/5\",\"ExposureProgram\":1,\"ISOSpeedRatings\":8000,\"ExifVersion\":\"0230\",\"DateTimeOriginal\":\"2012:06:30 16:15:15\",\"DateTimeDigitized\":\"2012:06:30 16:15:15\",\"ComponentsConfiguration\":\"\",\"ShutterSpeedValue\":\"9\\/1\",\"ApertureValue\":\"5\\/1\",\"ExposureBiasValue\":\"0\\/1\",\"MaxApertureValue\":\"6149\\/1087\",\"MeteringMode\":5,\"Flash\":16,\"FocalLength\":\"280\\/1\",\"SubSecTime\":\"00\",\"SubSecTimeOriginal\":\"00\",\"SubSecTimeDigitized\":\"00\",\"FlashPixVersion\":\"0100\",\"ColorSpace\":1,\"ExifImageWidth\":1600,\"ExifImageLength\":1067,\"FocalPlaneXResolution\":\"382423\\/97\",\"FocalPlaneYResolution\":\"134321\\/34\",\"FocalPlaneResolutionUnit\":2,\"CustomRendered\":0,\"ExposureMode\":1,\"WhiteBalance\":0,\"SceneCaptureType\":0},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0},\"photos-ifd0\":{\"value\":{\"Make\":\"Canon\",\"Model\":\"Canon EOS 5D Mark III\",\"Orientation\":1,\"XResolution\":\"72\\/1\",\"YResolution\":\"72\\/1\",\"ResolutionUnit\":2,\"Software\":\"Aperture 3.3.1\",\"DateTime\":\"2012:06:30 16:15:15\",\"Exif_IFD_Pointer\":202},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0},\"photos-size\":{\"value\":{\"width\":1600,\"height\":1067},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0}}',	'EP4X5J4',	'2025-09-05 07:35:53'),
(3,	49,	'{\"photos-original_date_time\":{\"value\":1341059531,\"type\":\"int\",\"etag\":\"\",\"indexed\":true,\"editPermission\":0},\"photos-exif\":{\"value\":{\"ExposureTime\":\"1\\/125\",\"FNumber\":\"28\\/5\",\"ExposureProgram\":3,\"ISOSpeedRatings\":320,\"UndefinedTag__x____\":320,\"ExifVersion\":\"0230\",\"DateTimeOriginal\":\"2012:06:30 12:32:11\",\"DateTimeDigitized\":\"2012:06:30 12:32:11\",\"ComponentsConfiguration\":\"\",\"ShutterSpeedValue\":\"7\\/1\",\"ApertureValue\":\"5\\/1\",\"ExposureBiasValue\":\"0\\/1\",\"MaxApertureValue\":\"189284\\/33461\",\"MeteringMode\":5,\"Flash\":16,\"FocalLength\":\"280\\/1\",\"SubSecTime\":\"83\",\"SubSecTimeOriginal\":\"83\",\"SubSecTimeDigitized\":\"83\",\"FlashPixVersion\":\"0100\",\"ColorSpace\":1,\"ExifImageWidth\":1600,\"ExifImageLength\":1067,\"FocalPlaneXResolution\":\"1920000\\/487\",\"FocalPlaneYResolution\":\"320000\\/81\",\"FocalPlaneResolutionUnit\":2,\"CustomRendered\":0,\"ExposureMode\":0,\"WhiteBalance\":0,\"SceneCaptureType\":0,\"UndefinedTag__xA___\":\"0000000000\"},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0},\"photos-ifd0\":{\"value\":{\"Make\":\"Canon\",\"Model\":\"Canon EOS 5D Mark III\",\"Orientation\":1,\"XResolution\":\"72\\/1\",\"YResolution\":\"72\\/1\",\"ResolutionUnit\":2,\"DateTime\":\"2012:06:30 12:32:11\",\"Exif_IFD_Pointer\":174},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0},\"photos-size\":{\"value\":{\"width\":1600,\"height\":1067},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0}}',	'qsO5Z2x',	'2025-09-05 07:35:53'),
(4,	50,	'{\"photos-original_date_time\":{\"value\":1372319469,\"type\":\"int\",\"etag\":\"\",\"indexed\":true,\"editPermission\":0},\"photos-exif\":{\"value\":{\"ExposureTime\":\"1\\/160\",\"FNumber\":\"4\\/1\",\"ExposureProgram\":3,\"ISOSpeedRatings\":100,\"ExifVersion\":\"0230\",\"DateTimeOriginal\":\"2013:06:27 07:51:09\",\"DateTimeDigitized\":\"2013:06:27 07:51:09\",\"ComponentsConfiguration\":\"\",\"ShutterSpeedValue\":\"59\\/8\",\"ApertureValue\":\"4\\/1\",\"ExposureBiasValue\":\"2\\/3\",\"MaxApertureValue\":\"4\\/1\",\"MeteringMode\":5,\"Flash\":16,\"FocalLength\":\"45\\/1\",\"SubSecTime\":\"00\",\"SubSecTimeOriginal\":\"00\",\"SubSecTimeDigitized\":\"00\",\"FlashPixVersion\":\"0100\",\"ColorSpace\":1,\"ExifImageWidth\":1200,\"ExifImageLength\":1800,\"FocalPlaneXResolution\":\"382423\\/97\",\"FocalPlaneYResolution\":\"185679\\/47\",\"FocalPlaneResolutionUnit\":2,\"CustomRendered\":0,\"ExposureMode\":0,\"WhiteBalance\":0,\"SceneCaptureType\":0,\"UndefinedTag__xA___\":\"000052602c\"},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0},\"photos-ifd0\":{\"value\":{\"Make\":\"Canon\",\"Model\":\"Canon EOS 5D Mark III\",\"Orientation\":1,\"XResolution\":\"72\\/1\",\"YResolution\":\"72\\/1\",\"ResolutionUnit\":2,\"Software\":\"Aperture 3.4.5\",\"DateTime\":\"2013:06:27 07:51:09\",\"Exif_IFD_Pointer\":202},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0},\"photos-size\":{\"value\":{\"width\":1200,\"height\":1800},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0}}',	'vN2VwXx',	'2025-09-05 07:35:54'),
(5,	51,	'{\"photos-original_date_time\":{\"value\":1341258636,\"type\":\"int\",\"etag\":\"\",\"indexed\":true,\"editPermission\":0},\"photos-exif\":{\"value\":{\"ExposureTime\":\"1\\/80\",\"FNumber\":\"4\\/1\",\"ExposureProgram\":3,\"ISOSpeedRatings\":400,\"ExifVersion\":\"0230\",\"DateTimeOriginal\":\"2012:07:02 19:50:36\",\"DateTimeDigitized\":\"2012:07:02 19:50:36\",\"ComponentsConfiguration\":\"\",\"ShutterSpeedValue\":\"51\\/8\",\"ApertureValue\":\"4\\/1\",\"ExposureBiasValue\":\"0\\/1\",\"MaxApertureValue\":\"4\\/1\",\"MeteringMode\":5,\"Flash\":16,\"FocalLength\":\"32\\/1\",\"SubSecTime\":\"00\",\"SubSecTimeOriginal\":\"00\",\"SubSecTimeDigitized\":\"00\",\"FlashPixVersion\":\"0100\",\"ColorSpace\":1,\"ExifImageWidth\":1600,\"ExifImageLength\":1066,\"FocalPlaneXResolution\":\"382423\\/97\",\"FocalPlaneYResolution\":\"185679\\/47\",\"FocalPlaneResolutionUnit\":2,\"CustomRendered\":0,\"ExposureMode\":0,\"WhiteBalance\":0,\"SceneCaptureType\":0},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0},\"photos-ifd0\":{\"value\":{\"Make\":\"Canon\",\"Model\":\"Canon EOS 5D Mark III\",\"Orientation\":1,\"XResolution\":\"72\\/1\",\"YResolution\":\"72\\/1\",\"ResolutionUnit\":2,\"Software\":\"GIMP 2.8.0\",\"DateTime\":\"2012:07:02 22:06:14\",\"Exif_IFD_Pointer\":198},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0},\"photos-size\":{\"value\":{\"width\":1600,\"height\":1066},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0}}',	'SJVcIqM',	'2025-09-05 07:35:54'),
(6,	52,	'{\"photos-original_date_time\":{\"value\":1526500980,\"type\":\"int\",\"etag\":\"\",\"indexed\":true,\"editPermission\":0},\"photos-exif\":{\"value\":{\"ExposureTime\":\"10\\/12500\",\"FNumber\":\"35\\/10\",\"ExposureProgram\":3,\"ISOSpeedRatings\":100,\"DateTimeOriginal\":\"2018:05:16 20:03:00\",\"DateTimeDigitized\":\"2018:05:16 20:03:00\",\"ExposureBiasValue\":\"0\\/6\",\"MaxApertureValue\":\"30\\/10\",\"MeteringMode\":5,\"LightSource\":0,\"Flash\":16,\"FocalLength\":\"700\\/10\",\"MakerNote\":\"Nikon\",\"UserComment\":\"Christoph WurstCC-SA 4.0\",\"SubSecTime\":\"30\",\"SubSecTimeOriginal\":\"30\",\"SubSecTimeDigitized\":\"30\",\"ColorSpace\":1,\"SensingMethod\":2,\"FileSource\":\"\",\"SceneType\":\"\",\"CustomRendered\":0,\"ExposureMode\":0,\"WhiteBalance\":0,\"DigitalZoomRatio\":\"1\\/1\",\"FocalLengthIn__mmFilm\":70,\"SceneCaptureType\":0,\"GainControl\":0,\"Contrast\":1,\"Saturation\":0,\"Sharpness\":1,\"SubjectDistanceRange\":0},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0},\"photos-ifd0\":{\"value\":{\"ImageDescription\":\"Christoph WurstCC-SA 4.0\",\"Make\":\"NIKON CORPORATION\",\"Model\":\"NIKON D610\",\"Orientation\":1,\"XResolution\":\"72\\/1\",\"YResolution\":\"72\\/1\",\"ResolutionUnit\":2,\"Software\":\"GIMP 2.10.14\",\"DateTime\":\"2019:12:10 08:51:16\",\"Artist\":\"Christoph Wurst                     \",\"Copyright\":\"Christoph Wurst                                       \",\"Exif_IFD_Pointer\":402,\"GPS_IFD_Pointer\":13738,\"DateTimeOriginal\":\"2018:05:16 20:03:00\"},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0},\"photos-size\":{\"value\":{\"width\":1920,\"height\":1281},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0}}',	'O2MoN4c',	'2025-09-05 07:35:54'),
(7,	53,	'{\"photos-original_date_time\":{\"value\":1341064060,\"type\":\"int\",\"etag\":\"\",\"indexed\":true,\"editPermission\":0},\"photos-exif\":{\"value\":{\"ExposureTime\":\"1\\/640\",\"FNumber\":\"28\\/5\",\"ExposureProgram\":1,\"ISOSpeedRatings\":12800,\"ExifVersion\":\"0230\",\"DateTimeOriginal\":\"2012:06:30 13:47:40\",\"DateTimeDigitized\":\"2012:06:30 13:47:40\",\"ComponentsConfiguration\":\"\",\"ShutterSpeedValue\":\"75\\/8\",\"ApertureValue\":\"5\\/1\",\"ExposureBiasValue\":\"0\\/1\",\"MaxApertureValue\":\"6149\\/1087\",\"MeteringMode\":5,\"Flash\":16,\"FocalLength\":\"235\\/1\",\"SubSecTime\":\"00\",\"SubSecTimeOriginal\":\"00\",\"SubSecTimeDigitized\":\"00\",\"FlashPixVersion\":\"0100\",\"ExifImageWidth\":1600,\"ExifImageLength\":1067,\"FocalPlaneXResolution\":\"382423\\/97\",\"FocalPlaneYResolution\":\"134321\\/34\",\"FocalPlaneResolutionUnit\":2,\"CustomRendered\":0,\"ExposureMode\":1,\"WhiteBalance\":0,\"SceneCaptureType\":0},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0},\"photos-ifd0\":{\"value\":{\"Make\":\"Canon\",\"Model\":\"Canon EOS 5D Mark III\",\"Orientation\":1,\"XResolution\":\"72\\/1\",\"YResolution\":\"72\\/1\",\"ResolutionUnit\":2,\"Software\":\"Aperture 3.3.1\",\"DateTime\":\"2012:06:30 13:47:40\",\"Exif_IFD_Pointer\":202},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0},\"photos-size\":{\"value\":{\"width\":1600,\"height\":1067},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0}}',	'2kn5o4p',	'2025-09-05 07:35:55'),
(8,	54,	'{\"photos-original_date_time\":{\"value\":1444907264,\"type\":\"int\",\"etag\":\"\",\"indexed\":true,\"editPermission\":0},\"photos-exif\":{\"value\":{\"ExposureTime\":\"1\\/320\",\"FNumber\":\"4\\/1\",\"ExposureProgram\":3,\"ISOSpeedRatings\":640,\"UndefinedTag__x____\":640,\"ExifVersion\":\"0230\",\"DateTimeOriginal\":\"2015:10:15 11:07:44\",\"DateTimeDigitized\":\"2015:10:15 11:07:44\",\"ShutterSpeedValue\":\"27970\\/3361\",\"ApertureValue\":\"4\\/1\",\"ExposureBiasValue\":\"1\\/3\",\"MaxApertureValue\":\"4\\/1\",\"MeteringMode\":5,\"Flash\":16,\"FocalLength\":\"200\\/1\",\"SubSecTimeOriginal\":\"63\",\"SubSecTimeDigitized\":\"63\",\"ColorSpace\":1,\"ExifImageWidth\":1600,\"ExifImageLength\":1067,\"FocalPlaneXResolution\":\"1600\\/1\",\"FocalPlaneYResolution\":\"1600\\/1\",\"FocalPlaneResolutionUnit\":3,\"CustomRendered\":0,\"ExposureMode\":0,\"WhiteBalance\":0,\"SceneCaptureType\":0,\"UndefinedTag__xA___\":\"000084121f\"},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0},\"photos-ifd0\":{\"value\":{\"Make\":\"Canon\",\"Model\":\"Canon EOS 5D Mark III\",\"Orientation\":1,\"XResolution\":\"240\\/1\",\"YResolution\":\"240\\/1\",\"ResolutionUnit\":2,\"Software\":\"Adobe Photoshop Lightroom 6.2.1 (Macintosh)\",\"DateTime\":\"2015:10:16 14:40:21\",\"Exif_IFD_Pointer\":230},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0},\"photos-size\":{\"value\":{\"width\":1600,\"height\":1067},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0}}',	'Opa6u5t',	'2025-09-05 07:35:55'),
(9,	56,	'{\"photos-original_date_time\":{\"value\":1757057755,\"type\":\"int\",\"etag\":\"\",\"indexed\":true,\"editPermission\":0},\"photos-size\":{\"value\":{\"width\":3000,\"height\":2000},\"type\":\"array\",\"etag\":\"\",\"indexed\":false,\"editPermission\":0}}',	'W8YuBCV',	'2025-09-05 07:35:56'),
(10,	57,	'{\"photos-original_date_time\":{\"value\":1757057756,\"type\":\"int\",\"etag\":\"\",\"indexed\":true,\"editPermission\":0}}',	'ytzoHxN',	'2025-09-05 07:35:56');

DROP TABLE IF EXISTS `oc_files_metadata_index`;
CREATE TABLE `oc_files_metadata_index` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `file_id` bigint NOT NULL,
  `meta_key` varchar(31) COLLATE utf8mb4_bin DEFAULT NULL,
  `meta_value_string` varchar(63) COLLATE utf8mb4_bin DEFAULT NULL,
  `meta_value_int` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `f_meta_index` (`file_id`,`meta_key`,`meta_value_string`),
  KEY `f_meta_index_i` (`file_id`,`meta_key`,`meta_value_int`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_files_metadata_index` (`id`, `file_id`, `meta_key`, `meta_value_string`, `meta_value_int`) VALUES
(2,	44,	'photos-original_date_time',	NULL,	1757057752),
(4,	48,	'photos-original_date_time',	NULL,	1341072915),
(6,	49,	'photos-original_date_time',	NULL,	1341059531),
(8,	50,	'photos-original_date_time',	NULL,	1372319469),
(10,	51,	'photos-original_date_time',	NULL,	1341258636),
(12,	52,	'photos-original_date_time',	NULL,	1526500980),
(14,	53,	'photos-original_date_time',	NULL,	1341064060),
(16,	54,	'photos-original_date_time',	NULL,	1444907264),
(18,	56,	'photos-original_date_time',	NULL,	1757057755),
(19,	57,	'photos-original_date_time',	NULL,	1757057756);

DROP TABLE IF EXISTS `oc_files_reminders`;
CREATE TABLE `oc_files_reminders` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `file_id` bigint unsigned NOT NULL,
  `due_date` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `created_at` datetime NOT NULL,
  `notified` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `reminders_uniq_idx` (`user_id`,`file_id`,`due_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_files_trash`;
CREATE TABLE `oc_files_trash` (
  `auto_id` bigint NOT NULL AUTO_INCREMENT,
  `id` varchar(250) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `user` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `timestamp` varchar(12) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `location` varchar(512) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `type` varchar(4) COLLATE utf8mb4_bin DEFAULT NULL,
  `mime` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `deleted_by` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`auto_id`),
  KEY `id_index` (`id`),
  KEY `timestamp_index` (`timestamp`),
  KEY `user_index` (`user`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_files_versions`;
CREATE TABLE `oc_files_versions` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `file_id` bigint NOT NULL,
  `timestamp` bigint NOT NULL,
  `size` bigint NOT NULL,
  `mimetype` bigint NOT NULL,
  `metadata` json NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `files_versions_uniq_index` (`file_id`,`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_files_versions` (`id`, `file_id`, `timestamp`, `size`, `mimetype`, `metadata`) VALUES
(1,	4,	1757057742,	11836,	4,	'{\"author\": \"admin\"}'),
(2,	5,	1757057742,	81196,	5,	'{\"author\": \"admin\"}'),
(3,	6,	1757057742,	23359,	6,	'{\"author\": \"admin\"}'),
(4,	7,	1757057743,	3509628,	5,	'{\"author\": \"admin\"}'),
(5,	8,	1757057743,	326,	8,	'{\"author\": \"admin\"}'),
(6,	9,	1757057743,	15961,	9,	'{\"author\": \"admin\"}'),
(7,	10,	1757057743,	13653,	4,	'{\"author\": \"admin\"}'),
(8,	11,	1757057744,	35657,	6,	'{\"author\": \"admin\"}'),
(9,	12,	1757057744,	39404,	9,	'{\"author\": \"admin\"}'),
(10,	13,	1757057744,	868111,	9,	'{\"author\": \"admin\"}'),
(11,	14,	1757057744,	340061,	9,	'{\"author\": \"admin\"}'),
(12,	15,	1757057745,	30780,	6,	'{\"author\": \"admin\"}'),
(13,	16,	1757057745,	52843,	10,	'{\"author\": \"admin\"}'),
(14,	17,	1757057745,	16988,	4,	'{\"author\": \"admin\"}'),
(15,	18,	1757057745,	5155877,	9,	'{\"author\": \"admin\"}'),
(16,	19,	1757057746,	14316,	5,	'{\"author\": \"admin\"}'),
(17,	20,	1757057746,	45778,	6,	'{\"author\": \"admin\"}'),
(18,	21,	1757057746,	554,	8,	'{\"author\": \"admin\"}'),
(19,	22,	1757057746,	30290,	6,	'{\"author\": \"admin\"}'),
(20,	23,	1757057747,	27629,	6,	'{\"author\": \"admin\"}'),
(21,	24,	1757057747,	31132,	6,	'{\"author\": \"admin\"}'),
(22,	25,	1757057747,	13378,	10,	'{\"author\": \"admin\"}'),
(23,	26,	1757057747,	317015,	5,	'{\"author\": \"admin\"}'),
(24,	27,	1757057748,	14810,	5,	'{\"author\": \"admin\"}'),
(25,	28,	1757057748,	573,	8,	'{\"author\": \"admin\"}'),
(26,	29,	1757057748,	30354,	9,	'{\"author\": \"admin\"}'),
(27,	30,	1757057748,	31325,	6,	'{\"author\": \"admin\"}'),
(28,	31,	1757057749,	17276,	9,	'{\"author\": \"admin\"}'),
(29,	32,	1757057749,	25621,	6,	'{\"author\": \"admin\"}'),
(30,	33,	1757057749,	13441,	10,	'{\"author\": \"admin\"}'),
(31,	34,	1757057749,	30671,	6,	'{\"author\": \"admin\"}'),
(32,	35,	1757057750,	88394,	10,	'{\"author\": \"admin\"}'),
(33,	36,	1757057750,	13878,	4,	'{\"author\": \"admin\"}'),
(34,	38,	1757057750,	1095,	8,	'{\"author\": \"admin\"}'),
(35,	39,	1757057751,	136,	8,	'{\"author\": \"admin\"}'),
(36,	40,	1757057751,	1083339,	11,	'{\"author\": \"admin\"}'),
(37,	41,	1757057751,	23876,	12,	'{\"author\": \"admin\"}'),
(38,	42,	1757057751,	13954180,	11,	'{\"author\": \"admin\"}'),
(39,	43,	1757057752,	197,	8,	'{\"author\": \"admin\"}'),
(40,	44,	1757057752,	50598,	14,	'{\"author\": \"admin\"}'),
(41,	45,	1757057752,	2403,	8,	'{\"author\": \"admin\"}'),
(42,	46,	1757057753,	976625,	11,	'{\"author\": \"admin\"}'),
(43,	48,	1757057753,	457744,	15,	'{\"author\": \"admin\"}'),
(44,	49,	1757057753,	593508,	15,	'{\"author\": \"admin\"}'),
(45,	50,	1757057754,	567689,	15,	'{\"author\": \"admin\"}'),
(46,	51,	1757057754,	2170375,	15,	'{\"author\": \"admin\"}'),
(47,	52,	1757057754,	427030,	15,	'{\"author\": \"admin\"}'),
(48,	53,	1757057755,	474653,	15,	'{\"author\": \"admin\"}'),
(49,	54,	1757057755,	167989,	15,	'{\"author\": \"admin\"}'),
(50,	55,	1757057755,	150,	8,	'{\"author\": \"admin\"}'),
(51,	56,	1757057755,	797325,	15,	'{\"author\": \"admin\"}'),
(52,	57,	1757057756,	3963036,	17,	'{\"author\": \"admin\"}');

DROP TABLE IF EXISTS `oc_flow_checks`;
CREATE TABLE `oc_flow_checks` (
  `id` int NOT NULL AUTO_INCREMENT,
  `class` varchar(256) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `operator` varchar(16) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `value` longtext COLLATE utf8mb4_bin,
  `hash` varchar(32) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `flow_unique_hash` (`hash`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_flow_operations`;
CREATE TABLE `oc_flow_operations` (
  `id` int NOT NULL AUTO_INCREMENT,
  `class` varchar(256) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `name` varchar(256) COLLATE utf8mb4_bin DEFAULT '',
  `checks` longtext COLLATE utf8mb4_bin,
  `operation` longtext COLLATE utf8mb4_bin,
  `entity` varchar(256) COLLATE utf8mb4_bin NOT NULL DEFAULT 'OCA\\WorkflowEngine\\Entity\\File',
  `events` longtext COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_flow_operations_scope`;
CREATE TABLE `oc_flow_operations_scope` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `operation_id` int NOT NULL DEFAULT '0',
  `type` int NOT NULL DEFAULT '0',
  `value` varchar(64) COLLATE utf8mb4_bin DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `flow_unique_scope` (`operation_id`,`type`,`value`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_group_admin`;
CREATE TABLE `oc_group_admin` (
  `gid` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `uid` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  PRIMARY KEY (`gid`,`uid`),
  KEY `group_admin_uid` (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_group_user`;
CREATE TABLE `oc_group_user` (
  `gid` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `uid` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  PRIMARY KEY (`gid`,`uid`),
  KEY `gu_uid_index` (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_group_user` (`gid`, `uid`) VALUES
('admin',	'admin');

DROP TABLE IF EXISTS `oc_groups`;
CREATE TABLE `oc_groups` (
  `gid` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `displayname` varchar(255) COLLATE utf8mb4_bin NOT NULL DEFAULT 'name',
  PRIMARY KEY (`gid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_groups` (`gid`, `displayname`) VALUES
('admin',	'admin');

DROP TABLE IF EXISTS `oc_jobs`;
CREATE TABLE `oc_jobs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `class` varchar(255) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `argument` varchar(4000) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `last_run` int DEFAULT '0',
  `last_checked` int DEFAULT '0',
  `reserved_at` int DEFAULT '0',
  `execution_duration` int DEFAULT '0',
  `argument_hash` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `time_sensitive` smallint NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  KEY `job_class_index` (`class`),
  KEY `job_lastcheck_reserved` (`last_checked`,`reserved_at`),
  KEY `job_argument_hash` (`class`,`argument_hash`),
  KEY `jobs_time_sensitive` (`time_sensitive`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_jobs` (`id`, `class`, `argument`, `last_run`, `last_checked`, `reserved_at`, `execution_duration`, `argument_hash`, `time_sensitive`) VALUES
(1,	'OCA\\Federation\\SyncJob',	'null',	1757057796,	1757057796,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	0),
(2,	'OCA\\OAuth2\\BackgroundJob\\CleanupExpiredAuthorizationCode',	'null',	1757057812,	1757057812,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	0),
(3,	'OCA\\UpdateNotification\\BackgroundJob\\UpdateAvailableNotifications',	'null',	1757057967,	1757057967,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	0),
(4,	'OCA\\UserStatus\\BackgroundJob\\ClearOldStatusesBackgroundJob',	'null',	1757058330,	1757058330,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(5,	'OCA\\NextcloudAnnouncements\\Cron\\Crawler',	'null',	1757058478,	1757058478,	0,	1,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(6,	'OCA\\Photos\\Jobs\\AutomaticPlaceMapperJob',	'null',	1757058486,	1757058486,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	0),
(7,	'OCA\\FilesReminders\\BackgroundJob\\CleanUpReminders',	'null',	0,	1757057730,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(8,	'OCA\\FilesReminders\\BackgroundJob\\ScheduledNotifications',	'null',	0,	1757057730,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(9,	'OCA\\Files_Sharing\\DeleteOrphanedSharesJob',	'null',	0,	1757057731,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(10,	'OCA\\Files_Sharing\\ExpireSharesJob',	'null',	0,	1757057731,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(11,	'OCA\\Files_Sharing\\SharesReminderJob',	'null',	0,	1757057731,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(12,	'OCA\\Files_Sharing\\BackgroundJob\\FederatedSharesDiscoverJob',	'null',	0,	1757057731,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(13,	'OCA\\Files_Versions\\BackgroundJob\\ExpireVersions',	'null',	0,	1757057731,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(14,	'OCA\\Files\\BackgroundJob\\ScanFiles',	'null',	0,	1757057732,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(15,	'OCA\\Files\\BackgroundJob\\DeleteOrphanedItems',	'null',	0,	1757057732,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(16,	'OCA\\Files\\BackgroundJob\\CleanupFileLocks',	'null',	0,	1757057732,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(17,	'OCA\\Files\\BackgroundJob\\CleanupDirectEditingTokens',	'null',	0,	1757057732,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(18,	'OCA\\Files\\BackgroundJob\\DeleteExpiredOpenLocalEditor',	'null',	0,	1757057732,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(19,	'OCA\\DAV\\BackgroundJob\\CleanupDirectLinksJob',	'null',	0,	1757057734,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(20,	'OCA\\DAV\\BackgroundJob\\UpdateCalendarResourcesRoomsBackgroundJob',	'null',	0,	1757057734,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(21,	'OCA\\DAV\\BackgroundJob\\CleanupInvitationTokenJob',	'null',	0,	1757057734,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(22,	'OCA\\DAV\\BackgroundJob\\EventReminderJob',	'null',	0,	1757057734,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(23,	'OCA\\DAV\\BackgroundJob\\CalendarRetentionJob',	'null',	0,	1757057734,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(24,	'OCA\\DAV\\BackgroundJob\\PruneOutdatedSyncTokensJob',	'null',	0,	1757057734,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(25,	'OCA\\AppAPI\\BackgroundJob\\ExAppInitStatusCheckJob',	'null',	0,	1757057735,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(26,	'OCA\\AppAPI\\BackgroundJob\\ProvidersAICleanUpJob',	'null',	0,	1757057735,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(27,	'OCA\\Text\\Cron\\Cleanup',	'null',	0,	1757057736,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(28,	'OCA\\ContactsInteraction\\BackgroundJob\\CleanupJob',	'null',	0,	1757057736,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(29,	'OCA\\Notifications\\BackgroundJob\\GenerateUserSettings',	'null',	0,	1757057737,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(30,	'OCA\\Notifications\\BackgroundJob\\SendNotificationMails',	'null',	0,	1757057737,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(31,	'OCA\\Circles\\Cron\\Maintenance',	'null',	0,	1757057738,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(32,	'OCA\\ServerInfo\\Jobs\\UpdateStorageStats',	'null',	0,	1757057738,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(33,	'OCA\\WorkflowEngine\\BackgroundJobs\\Rotate',	'null',	0,	1757057739,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(34,	'OCA\\Files_Trashbin\\BackgroundJob\\ExpireTrash',	'null',	0,	1757057740,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(35,	'OCA\\Activity\\BackgroundJob\\EmailNotification',	'null',	0,	1757057740,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(36,	'OCA\\Activity\\BackgroundJob\\ExpireActivities',	'null',	0,	1757057740,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(37,	'OCA\\Activity\\BackgroundJob\\DigestMail',	'null',	0,	1757057740,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(38,	'OCA\\Activity\\BackgroundJob\\RemoveFormerActivitySettings',	'null',	0,	1757057740,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(39,	'OCA\\Support\\BackgroundJobs\\CheckSubscription',	'null',	0,	1757057740,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(40,	'OC\\Authentication\\Token\\TokenCleanupJob',	'null',	0,	1757057740,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(41,	'OC\\Log\\Rotate',	'null',	0,	1757057741,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(42,	'OC\\Preview\\BackgroundCleanupJob',	'null',	0,	1757057741,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(43,	'OC\\TextProcessing\\RemoveOldTasksBackgroundJob',	'null',	0,	1757057741,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(44,	'OC\\User\\BackgroundJobs\\CleanupDeletedUsers',	'null',	0,	1757057741,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(45,	'OC\\Core\\BackgroundJobs\\GenerateMetadataJob',	'null',	0,	1757057741,	0,	0,	'74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b',	1),
(46,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",4]',	0,	1757057742,	0,	0,	'4956793059d80398b3d78ea2215ebb860a2e0c724aefa0ce04b1a8bbb5a70f46',	1),
(47,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",5]',	0,	1757057742,	0,	0,	'bab5ba2238ecad63141db6c5f1608efc3b0efecc909f4f8d8e111e0d5c23edad',	1),
(48,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",6]',	0,	1757057742,	0,	0,	'0d840fcf4d96c36eb80b922e14ca2b7aa5acaba8f61b45e2d8bd832199fe8c9d',	1),
(49,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",7]',	0,	1757057743,	0,	0,	'5889fec72259069bfcddd1167dbbf1c854234eb06614dd8fd894eff7956192a7',	1),
(50,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",8]',	0,	1757057743,	0,	0,	'075228ca5e1ab3f24fd39c1402e41a206a4afd78fc71b52f0021faaa6121c260',	1),
(51,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",9]',	0,	1757057743,	0,	0,	'6aeb888c4dfdca1c745d4f2367a7386cf490285b3d961db0382c594a54c400a0',	1),
(52,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",10]',	0,	1757057743,	0,	0,	'9e79a1d0a821264f3aa6269c1d3dba0f52274f57ff2819cc5c70f60300c2ec6c',	1),
(53,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",11]',	0,	1757057744,	0,	0,	'32ea4cc1f86ec7aba234f815b18136b6eab27615e67f71a4f752e863214b3b22',	1),
(54,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",12]',	0,	1757057744,	0,	0,	'2f60738088dd89b5b25465a7c6c482de073a21ffe62c3b8a3ec59ad5a1f4c15f',	1),
(55,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",13]',	0,	1757057744,	0,	0,	'05b302cbd33b86157c9981f8eb4ab72466e203421a1a8d2b9d504b7ec7e17ea7',	1),
(56,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",14]',	0,	1757057744,	0,	0,	'70e10015f10fbd6d13870e3908314ad4de673976fc3075d2eda0d7d4b2681dc6',	1),
(57,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",15]',	0,	1757057745,	0,	0,	'22aa486f345e5794cae46ce5def4dd3810bcc6c191e1190594fcdcbfaf05c65f',	1),
(58,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",16]',	0,	1757057745,	0,	0,	'cdf77c66ee9dc02019f56d1e8999668d813066995c75ab4c48ce506c209fe0f6',	1),
(59,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",17]',	0,	1757057745,	0,	0,	'50c3dc17edc7103fd33d90ad8c17fabaa4ab920310c26f5a1209a75cf06ff91c',	1),
(60,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",18]',	0,	1757057745,	0,	0,	'd6f63b0735f2a90b0ce0af8891b0398880b7399b786f84b0818adeeba359f1bb',	1),
(61,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",19]',	0,	1757057746,	0,	0,	'27a2cbe5b547b14f49ab72b681e53a8a1e74f549192ae8898bb4c2f4f88555fd',	1),
(62,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",20]',	0,	1757057746,	0,	0,	'876775feb13959831d8c7753e2a4abd552e03b394d84939656bb5dce9ce4f8f6',	1),
(63,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",21]',	0,	1757057746,	0,	0,	'79363e541ba12589811d7a0d3403d97d4d60a73c91e92db043322e5ca990c8fb',	1),
(64,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",22]',	0,	1757057746,	0,	0,	'830acf7a8ef52afbe08fc2713df540bc14c79f1a0f95c854da5e26b0386477f7',	1),
(65,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",23]',	0,	1757057747,	0,	0,	'9cea6ce18595672d882c9d89a3acfbcf7958a0839bc4a5abaa9ef02d88aebaf1',	1),
(66,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",24]',	0,	1757057747,	0,	0,	'727ef905962bfe27b36d943813e028d0e3664c929d5a714f0d7ac0d000ffa5fd',	1),
(67,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",25]',	0,	1757057747,	0,	0,	'529311c9ad07ba8de6b18178dbcf95b582b72597ade6c56cf1d41d7c6d7397c9',	1),
(68,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",26]',	0,	1757057747,	0,	0,	'003cfb4d3aba0fde31ba26c3b3a820a3d150ea868d5ee2c37c1a33771ef8e8b8',	1),
(69,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",27]',	0,	1757057748,	0,	0,	'b0cc502625f847e1481b6d24d1eb94752736146434df36043a153c9b1ee284c5',	1),
(70,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",28]',	0,	1757057748,	0,	0,	'2e1a9923add930564317a65c0bfc12ca3daa3e2530c1accdaf2277732f6ad934',	1),
(71,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",29]',	0,	1757057748,	0,	0,	'128fb9e5163de0bb1da6d975fed7b8c360a97ec2b9fee149f4bb8aaa9598d2b4',	1),
(72,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",30]',	0,	1757057748,	0,	0,	'e782f2107c9202401ac95b15d443e8da595c6bd92e26e8c5a086a268967794c9',	1),
(73,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",31]',	0,	1757057749,	0,	0,	'86924dbd7b48f415fbf674a2669f36ccb651e936cda773d270e5342bc467d53b',	1),
(74,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",32]',	0,	1757057749,	0,	0,	'ee02ec2ee4e390442f92c13e988ac867bb67074f52aecb22a05bdeee504d6e5f',	1),
(75,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",33]',	0,	1757057749,	0,	0,	'd2fc6457a2d723b580d9219ce144539740f68beea42d1a1379b60ea972699109',	1),
(76,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",34]',	0,	1757057750,	0,	0,	'154b723aa40ccca0c4ef5a72218d14f10a6618261e58095632eca79ecef12329',	1),
(77,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",35]',	0,	1757057750,	0,	0,	'a0ef7cdcb39b887087357a25bd2c1da932604ad5db4388671a25dd4a8bd0317a',	1),
(78,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",36]',	0,	1757057750,	0,	0,	'16df61184ae9e35c363a154732c7351c493d2a3ac34cdf8697fdfbc2da04f191',	1),
(79,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",38]',	0,	1757057751,	0,	0,	'57471075f497d1a8eadd28685fbd9bbf6da61a6c9440d215d823c6ffbd54d4e7',	1),
(80,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",39]',	0,	1757057751,	0,	0,	'5ca6ac67eac9782f6f7a0b7771f087a2584e0241fb44c99c4743984285097b2e',	1),
(81,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",40]',	0,	1757057751,	0,	0,	'07ba9c6a76e9b0c3a72981be352527e6b36975e7b0976a4fcb3bbc0559d2b542',	1),
(82,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",41]',	0,	1757057751,	0,	0,	'4c14497df884240ef37196f1f3e78f9ecb5715d4e5e8155f4c866e4d45d1a9b2',	1),
(83,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",42]',	0,	1757057752,	0,	0,	'd5a6a27596364bdb824290d1d838e04ef81f732a54d4af8b01a3ff7e4765c99c',	1),
(84,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",43]',	0,	1757057752,	0,	0,	'b7e10b61bf98d5f2376b308c483713cefc1dde08cc62fa9525d280283ac00634',	1),
(85,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",44]',	0,	1757057752,	0,	0,	'7f449813b099905192fcaeb5607970d09c4d8d0998bd58dd3621979f8cd11cb0',	1),
(86,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",45]',	0,	1757057752,	0,	0,	'ba2ef4e3cfbade663cfae1431113a10c4d523728ac0ad237af333b584375ddb4',	1),
(87,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",46]',	0,	1757057753,	0,	0,	'80ff70d0c920a046219b03ff7d3ad47cb1bf4a6208c3200dacf769b3fa6c748c',	1),
(88,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",48]',	0,	1757057753,	0,	0,	'37b98ebdecc5f0658741278c00b9b39e585ef51a5528ec2849a1f22fc65e6a68',	1),
(89,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",49]',	0,	1757057753,	0,	0,	'e1d9319ef784d6e2697941e9c9b806eff09802f8c8b88681164e1fad8a195a2c',	1),
(90,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",50]',	0,	1757057754,	0,	0,	'8737a4a10f2493722aef7c2c8e88401b265cddd3be46f68449a98ec3e63f972a',	1),
(91,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",51]',	0,	1757057754,	0,	0,	'c7cc806c5e0ef963d164ac8ddbd45a0d07c20632a814374beba02523041e6366',	1),
(92,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",52]',	0,	1757057754,	0,	0,	'fd7e2f45366cbfaa56418e9f66de32b1152ceff0b9e2a95c35f8ab9cf14e9ab3',	1),
(93,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",53]',	0,	1757057755,	0,	0,	'8b5b90195e90aaf9fb390893dd50cec8b0b5c9291bfc906502ca69130ec3d4b8',	1),
(94,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",54]',	0,	1757057755,	0,	0,	'377bbca9da63af8ce04de552dedba2ec51ab03dedabd1720fd8af9044500ec08',	1),
(95,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",55]',	0,	1757057755,	0,	0,	'c0b05087e2b5a15f9e2889da4e63410fc313358d668337a87e0012a7d4a49abb',	1),
(96,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",56]',	0,	1757057756,	0,	0,	'7c8bf950975a947a8c9ac0c21b5d220c756e025a71ae33a74845207900dfd749',	1),
(97,	'OC\\FilesMetadata\\Job\\UpdateSingleMetadata',	'[\"admin\",57]',	0,	1757057756,	0,	0,	'56a538f0d0beb9c2a8fdea0f875b6ce62c5eaf8879ed9984caab1a5dec150bc5',	1),
(98,	'OCA\\FirstRunWizard\\Notification\\BackgroundJob',	'{\"uid\":\"admin\"}',	0,	1757057795,	0,	0,	'70071f2985a39d9762e53229dd5125d134cd7601939c1a4d69cd99aa90057e8a',	1);

DROP TABLE IF EXISTS `oc_known_users`;
CREATE TABLE `oc_known_users` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `known_to` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `known_user` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`id`),
  KEY `ku_known_to` (`known_to`),
  KEY `ku_known_user` (`known_user`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_login_flow_v2`;
CREATE TABLE `oc_login_flow_v2` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `timestamp` bigint unsigned NOT NULL,
  `started` smallint unsigned NOT NULL DEFAULT '0',
  `poll_token` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `login_token` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `public_key` text COLLATE utf8mb4_bin NOT NULL,
  `private_key` text COLLATE utf8mb4_bin NOT NULL,
  `client_name` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `login_name` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `server` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `app_password` varchar(1024) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `poll_token` (`poll_token`),
  UNIQUE KEY `login_token` (`login_token`),
  KEY `timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_migrations`;
CREATE TABLE `oc_migrations` (
  `app` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `version` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`app`,`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_migrations` (`app`, `version`) VALUES
('activity',	'2006Date20170808154933'),
('activity',	'2006Date20170808155040'),
('activity',	'2006Date20170919095939'),
('activity',	'2007Date20181107114613'),
('activity',	'2008Date20181011095117'),
('activity',	'2010Date20190416112817'),
('activity',	'2011Date20201006132544'),
('activity',	'2011Date20201006132545'),
('activity',	'2011Date20201006132546'),
('activity',	'2011Date20201006132547'),
('activity',	'2011Date20201207091915'),
('app_api',	'032001Date20250115164140'),
('app_api',	'1000Date202305221555'),
('app_api',	'1004Date202311061844'),
('app_api',	'1005Date202312271744'),
('app_api',	'1006Date202401011308'),
('app_api',	'1007Date202401111030'),
('app_api',	'1008Date202401121205'),
('app_api',	'2000Date20240120094952'),
('app_api',	'2005Date20240209094951'),
('app_api',	'2200Date20240216164351'),
('app_api',	'2201Date20240221124152'),
('app_api',	'2203Date20240325124149'),
('app_api',	'2204Date20240401104001'),
('app_api',	'2204Date20240403125002'),
('app_api',	'2205Date20240411124836'),
('app_api',	'2206Date20240502145029'),
('app_api',	'2207Date20240502145029'),
('app_api',	'2700Date20240515092246'),
('app_api',	'2800Date20240710220000'),
('app_api',	'2800Date20240711080316'),
('app_api',	'3000Date20240715170800'),
('app_api',	'3000Date20240807085759'),
('app_api',	'3100Date20240822080316'),
('app_api',	'3200Date20240905080316'),
('app_api',	'5000Date20241120135411'),
('app_api',	'5000Date20250109163201'),
('circles',	'0022Date20220526111723'),
('circles',	'0022Date20220526113601'),
('circles',	'0022Date20220703115023'),
('circles',	'0023Date20211216113101'),
('circles',	'0024Date20220203123901'),
('circles',	'0024Date20220203123902'),
('circles',	'0024Date20220317190331'),
('circles',	'0028Date20230705222601'),
('circles',	'0031Date20241105133904'),
('contactsinteraction',	'010000Date20200304152605'),
('core',	'13000Date20170705121758'),
('core',	'13000Date20170718121200'),
('core',	'13000Date20170814074715'),
('core',	'13000Date20170919121250'),
('core',	'13000Date20170926101637'),
('core',	'14000Date20180129121024'),
('core',	'14000Date20180404140050'),
('core',	'14000Date20180516101403'),
('core',	'14000Date20180518120534'),
('core',	'14000Date20180522074438'),
('core',	'14000Date20180626223656'),
('core',	'14000Date20180710092004'),
('core',	'14000Date20180712153140'),
('core',	'15000Date20180926101451'),
('core',	'15000Date20181015062942'),
('core',	'15000Date20181029084625'),
('core',	'16000Date20190207141427'),
('core',	'16000Date20190212081545'),
('core',	'16000Date20190427105638'),
('core',	'16000Date20190428150708'),
('core',	'17000Date20190514105811'),
('core',	'18000Date20190920085628'),
('core',	'18000Date20191014105105'),
('core',	'18000Date20191204114856'),
('core',	'19000Date20200211083441'),
('core',	'20000Date20201109081915'),
('core',	'20000Date20201109081918'),
('core',	'20000Date20201109081919'),
('core',	'20000Date20201111081915'),
('core',	'21000Date20201120141228'),
('core',	'21000Date20201202095923'),
('core',	'21000Date20210119195004'),
('core',	'21000Date20210309185126'),
('core',	'21000Date20210309185127'),
('core',	'22000Date20210216080825'),
('core',	'23000Date20210721100600'),
('core',	'23000Date20210906132259'),
('core',	'23000Date20210930122352'),
('core',	'23000Date20211203110726'),
('core',	'23000Date20211213203940'),
('core',	'24000Date20211210141942'),
('core',	'24000Date20211213081506'),
('core',	'24000Date20211213081604'),
('core',	'24000Date20211222112246'),
('core',	'24000Date20211230140012'),
('core',	'24000Date20220131153041'),
('core',	'24000Date20220202150027'),
('core',	'24000Date20220404230027'),
('core',	'24000Date20220425072957'),
('core',	'25000Date20220515204012'),
('core',	'25000Date20220602190540'),
('core',	'25000Date20220905140840'),
('core',	'25000Date20221007010957'),
('core',	'27000Date20220613163520'),
('core',	'27000Date20230309104325'),
('core',	'27000Date20230309104802'),
('core',	'28000Date20230616104802'),
('core',	'28000Date20230728104802'),
('core',	'28000Date20230803221055'),
('core',	'28000Date20230906104802'),
('core',	'28000Date20231004103301'),
('core',	'28000Date20231103104802'),
('core',	'28000Date20231126110901'),
('core',	'28000Date20240828142927'),
('core',	'29000Date20231126110901'),
('core',	'29000Date20231213104850'),
('core',	'29000Date20240124132201'),
('core',	'29000Date20240124132202'),
('core',	'29000Date20240131122720'),
('core',	'30000Date20240429122720'),
('core',	'30000Date20240708160048'),
('core',	'30000Date20240717111406'),
('core',	'30000Date20240814180800'),
('core',	'30000Date20240815080800'),
('core',	'30000Date20240906095113'),
('core',	'31000Date20240101084401'),
('core',	'31000Date20240814184402'),
('core',	'31000Date20250213102442'),
('core',	'31000Date20250731062008'),
('core',	'32000Date20250620081925'),
('dav',	'1004Date20170825134824'),
('dav',	'1004Date20170919104507'),
('dav',	'1004Date20170924124212'),
('dav',	'1004Date20170926103422'),
('dav',	'1005Date20180413093149'),
('dav',	'1005Date20180530124431'),
('dav',	'1006Date20180619154313'),
('dav',	'1006Date20180628111625'),
('dav',	'1008Date20181030113700'),
('dav',	'1008Date20181105104826'),
('dav',	'1008Date20181105104833'),
('dav',	'1008Date20181105110300'),
('dav',	'1008Date20181105112049'),
('dav',	'1008Date20181114084440'),
('dav',	'1011Date20190725113607'),
('dav',	'1011Date20190806104428'),
('dav',	'1012Date20190808122342'),
('dav',	'1016Date20201109085907'),
('dav',	'1017Date20210216083742'),
('dav',	'1018Date20210312100735'),
('dav',	'1024Date20211221144219'),
('dav',	'1025Date20240308063933'),
('dav',	'1027Date20230504122946'),
('dav',	'1029Date20221114151721'),
('dav',	'1029Date20231004091403'),
('dav',	'1030Date20240205103243'),
('dav',	'1031Date20240610134258'),
('federatedfilesharing',	'1010Date20200630191755'),
('federatedfilesharing',	'1011Date20201120125158'),
('federation',	'1010Date20200630191302'),
('files',	'11301Date20191205150729'),
('files',	'12101Date20221011153334'),
('files',	'2003Date20241021095629'),
('files_downloadlimit',	'000000Date20210910094923'),
('files_reminders',	'10000Date20230725162149'),
('files_sharing',	'11300Date20201120141438'),
('files_sharing',	'21000Date20201223143245'),
('files_sharing',	'22000Date20210216084241'),
('files_sharing',	'24000Date20220208195521'),
('files_sharing',	'24000Date20220404142216'),
('files_sharing',	'31000Date20240821142813'),
('files_trashbin',	'1010Date20200630192639'),
('files_trashbin',	'1020Date20240403003535'),
('files_versions',	'1020Date20221114144058'),
('notifications',	'2004Date20190107135757'),
('notifications',	'2010Date20210218082811'),
('notifications',	'2010Date20210218082855'),
('notifications',	'2011Date20210930134607'),
('notifications',	'2011Date20220826074907'),
('oauth2',	'010401Date20181207190718'),
('oauth2',	'010402Date20190107124745'),
('oauth2',	'011601Date20230522143227'),
('oauth2',	'011602Date20230613160650'),
('oauth2',	'011603Date20230620111039'),
('oauth2',	'011901Date20240829164356'),
('photos',	'20000Date20220727125801'),
('photos',	'20001Date20220830131446'),
('photos',	'20003Date20221102170153'),
('photos',	'20003Date20221103094628'),
('photos',	'30000Date20240417075405'),
('photos',	'40000Date20250624085327'),
('privacy',	'100Date20190217131943'),
('systemtags',	'31000Date20241018063111'),
('systemtags',	'31000Date20241114171300'),
('text',	'010000Date20190617184535'),
('text',	'030001Date20200402075029'),
('text',	'030201Date20201116110353'),
('text',	'030201Date20201116123153'),
('text',	'030501Date20220202101853'),
('text',	'030701Date20230207131313'),
('text',	'030901Date20231114150437'),
('text',	'040100Date20240611165300'),
('theming',	'2006Date20240905111627'),
('twofactor_backupcodes',	'1002Date20170607104347'),
('twofactor_backupcodes',	'1002Date20170607113030'),
('twofactor_backupcodes',	'1002Date20170919123342'),
('twofactor_backupcodes',	'1002Date20170926101419'),
('twofactor_backupcodes',	'1002Date20180821043638'),
('updatenotification',	'011901Date20240305120000'),
('user_status',	'0001Date20200602134824'),
('user_status',	'0002Date20200902144824'),
('user_status',	'1000Date20201111130204'),
('user_status',	'1003Date20210809144824'),
('user_status',	'1008Date20230921144701'),
('webhook_listeners',	'1000Date20240527153425'),
('webhook_listeners',	'1001Date20240716184935'),
('workflowengine',	'2000Date20190808074233'),
('workflowengine',	'2200Date20210805101925');

DROP TABLE IF EXISTS `oc_mimetypes`;
CREATE TABLE `oc_mimetypes` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `mimetype` varchar(255) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `mimetype_id_index` (`mimetype`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_mimetypes` (`id`, `mimetype`) VALUES
(3,	'application'),
(21,	'application/gzip'),
(20,	'application/javascript'),
(24,	'application/json'),
(18,	'application/octet-stream'),
(11,	'application/pdf'),
(6,	'application/vnd.excalidraw+json'),
(4,	'application/vnd.oasis.opendocument.graphics'),
(5,	'application/vnd.oasis.opendocument.presentation'),
(10,	'application/vnd.oasis.opendocument.spreadsheet'),
(9,	'application/vnd.oasis.opendocument.text'),
(12,	'application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
(1,	'httpd'),
(2,	'httpd/unix-directory'),
(13,	'image'),
(15,	'image/jpeg'),
(14,	'image/png'),
(22,	'image/svg+xml'),
(7,	'text'),
(8,	'text/markdown'),
(16,	'video'),
(17,	'video/mp4'),
(25,	'video/webm');

DROP TABLE IF EXISTS `oc_mounts`;
CREATE TABLE `oc_mounts` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `storage_id` bigint NOT NULL,
  `root_id` bigint NOT NULL,
  `user_id` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `mount_point` varchar(4000) COLLATE utf8mb4_bin NOT NULL,
  `mount_id` bigint DEFAULT NULL,
  `mount_provider_class` varchar(128) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `mounts_storage_index` (`storage_id`),
  KEY `mounts_root_index` (`root_id`),
  KEY `mounts_mount_id_index` (`mount_id`),
  KEY `mounts_user_root_path_index` (`user_id`,`root_id`,`mount_point`(128)),
  KEY `mounts_class_index` (`mount_provider_class`),
  KEY `mount_user_storage` (`storage_id`,`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_mounts` (`id`, `storage_id`, `root_id`, `user_id`, `mount_point`, `mount_id`, `mount_provider_class`) VALUES
(1,	1,	1,	'admin',	'/admin/',	NULL,	'OC\\Files\\Mount\\LocalHomeMountProvider');

DROP TABLE IF EXISTS `oc_notifications`;
CREATE TABLE `oc_notifications` (
  `notification_id` int NOT NULL AUTO_INCREMENT,
  `app` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `user` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `timestamp` int NOT NULL DEFAULT '0',
  `object_type` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `object_id` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `subject` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `subject_parameters` longtext COLLATE utf8mb4_bin,
  `message` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `message_parameters` longtext COLLATE utf8mb4_bin,
  `link` varchar(4000) COLLATE utf8mb4_bin DEFAULT NULL,
  `icon` varchar(4000) COLLATE utf8mb4_bin DEFAULT NULL,
  `actions` longtext COLLATE utf8mb4_bin,
  PRIMARY KEY (`notification_id`),
  KEY `oc_notifications_app` (`app`),
  KEY `oc_notifications_user` (`user`),
  KEY `oc_notifications_timestamp` (`timestamp`),
  KEY `oc_notifications_object` (`object_type`,`object_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_notifications` (`notification_id`, `app`, `user`, `timestamp`, `object_type`, `object_id`, `subject`, `subject_parameters`, `message`, `message_parameters`, `link`, `icon`, `actions`) VALUES
(1,	'firstrunwizard',	'admin',	1757057795,	'app',	'recognize',	'apphint-recognize',	'[]',	'',	'[]',	'',	'',	'[]'),
(2,	'firstrunwizard',	'admin',	1757057795,	'app',	'groupfolders',	'apphint-groupfolders',	'[]',	'',	'[]',	'',	'',	'[]'),
(3,	'firstrunwizard',	'admin',	1757057795,	'app',	'forms',	'apphint-forms',	'[]',	'',	'[]',	'',	'',	'[]'),
(4,	'firstrunwizard',	'admin',	1757057795,	'app',	'deck',	'apphint-deck',	'[]',	'',	'[]',	'',	'',	'[]'),
(5,	'firstrunwizard',	'admin',	1757057795,	'app',	'tasks',	'apphint-tasks',	'[]',	'',	'[]',	'',	'',	'[]'),
(6,	'firstrunwizard',	'admin',	1757057795,	'app',	'whiteboard',	'apphint-whiteboard',	'[]',	'',	'[]',	'',	'',	'[]');

DROP TABLE IF EXISTS `oc_notifications_pushhash`;
CREATE TABLE `oc_notifications_pushhash` (
  `id` int NOT NULL AUTO_INCREMENT,
  `uid` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `token` int NOT NULL DEFAULT '0',
  `deviceidentifier` varchar(128) COLLATE utf8mb4_bin NOT NULL,
  `devicepublickey` varchar(512) COLLATE utf8mb4_bin NOT NULL,
  `devicepublickeyhash` varchar(128) COLLATE utf8mb4_bin NOT NULL,
  `pushtokenhash` varchar(128) COLLATE utf8mb4_bin NOT NULL,
  `proxyserver` varchar(256) COLLATE utf8mb4_bin NOT NULL,
  `apptype` varchar(32) COLLATE utf8mb4_bin NOT NULL DEFAULT 'unknown',
  PRIMARY KEY (`id`),
  UNIQUE KEY `oc_npushhash_uid` (`uid`,`token`),
  KEY `oc_npushhash_di` (`deviceidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_notifications_settings`;
CREATE TABLE `oc_notifications_settings` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `batch_time` int NOT NULL DEFAULT '0',
  `last_send_id` bigint NOT NULL DEFAULT '0',
  `next_send_time` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `notset_user` (`user_id`),
  KEY `notset_nextsend` (`next_send_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_notifications_settings` (`id`, `user_id`, `batch_time`, `last_send_id`, `next_send_time`) VALUES
(1,	'admin',	0,	0,	0);

DROP TABLE IF EXISTS `oc_oauth2_access_tokens`;
CREATE TABLE `oc_oauth2_access_tokens` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `token_id` int NOT NULL,
  `client_id` int NOT NULL,
  `hashed_code` varchar(128) COLLATE utf8mb4_bin NOT NULL,
  `encrypted_token` varchar(786) COLLATE utf8mb4_bin NOT NULL,
  `code_created_at` bigint unsigned NOT NULL DEFAULT '0',
  `token_count` bigint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `oauth2_access_hash_idx` (`hashed_code`),
  KEY `oauth2_access_client_id_idx` (`client_id`),
  KEY `oauth2_tk_c_created_idx` (`token_count`,`code_created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_oauth2_clients`;
CREATE TABLE `oc_oauth2_clients` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `redirect_uri` varchar(2000) COLLATE utf8mb4_bin NOT NULL,
  `client_identifier` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `secret` varchar(512) COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `oauth2_client_id_idx` (`client_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_open_local_editor`;
CREATE TABLE `oc_open_local_editor` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `path_hash` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `expiration_time` bigint unsigned NOT NULL,
  `token` varchar(128) COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `openlocal_user_path_token` (`user_id`,`path_hash`,`token`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_photos_albums`;
CREATE TABLE `oc_photos_albums` (
  `album_id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `user` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `created` bigint NOT NULL,
  `location` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `last_added_photo` bigint NOT NULL,
  PRIMARY KEY (`album_id`),
  KEY `pa_user` (`user`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_photos_albums_collabs`;
CREATE TABLE `oc_photos_albums_collabs` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `album_id` bigint NOT NULL,
  `collaborator_id` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `collaborator_type` int NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `album_collabs_uniq_collab` (`album_id`,`collaborator_id`,`collaborator_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_photos_albums_files`;
CREATE TABLE `oc_photos_albums_files` (
  `album_file_id` bigint NOT NULL AUTO_INCREMENT,
  `album_id` bigint NOT NULL,
  `file_id` bigint NOT NULL,
  `added` bigint NOT NULL,
  `owner` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`album_file_id`),
  UNIQUE KEY `paf_album_file` (`album_id`,`file_id`),
  KEY `paf_folder` (`album_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_preferences`;
CREATE TABLE `oc_preferences` (
  `userid` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `appid` varchar(32) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `configkey` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `configvalue` longtext COLLATE utf8mb4_bin,
  `lazy` smallint unsigned NOT NULL DEFAULT '0',
  `type` smallint unsigned NOT NULL DEFAULT '0',
  `flags` int unsigned NOT NULL DEFAULT '0',
  `indexed` varchar(64) COLLATE utf8mb4_bin DEFAULT '',
  PRIMARY KEY (`userid`,`appid`,`configkey`),
  KEY `prefs_uid_lazy_i` (`userid`,`lazy`),
  KEY `prefs_app_key_ind_fl_i` (`appid`,`configkey`,`indexed`,`flags`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_preferences` (`userid`, `appid`, `configkey`, `configvalue`, `lazy`, `type`, `flags`, `indexed`) VALUES
('admin',	'activity',	'configured',	'yes',	0,	0,	0,	''),
('admin',	'avatar',	'generated',	'true',	0,	0,	0,	''),
('admin',	'core',	'lang',	'en',	0,	1,	0,	''),
('admin',	'core',	'templateDirectory',	'Templates/',	0,	0,	0,	''),
('admin',	'core',	'timezone',	'Europe/Amsterdam',	0,	0,	0,	''),
('admin',	'dashboard',	'firstRun',	'0',	0,	0,	0,	''),
('admin',	'files',	'lastSeenQuotaUsage',	'0.07',	0,	0,	0,	''),
('admin',	'firstrunwizard',	'apphint',	'19',	0,	0,	0,	''),
('admin',	'firstrunwizard',	'show',	'31.0.8',	0,	0,	0,	''),
('admin',	'login',	'firstLogin',	'1757057741',	0,	0,	0,	''),
('admin',	'login',	'lastLogin',	'1757058475',	0,	0,	0,	''),
('admin',	'login_token',	'k5OGwykDLgMn2M6rD3mYbvAmHR30li52',	'1757057794',	0,	0,	0,	''),
('admin',	'login_token',	'zxa2vA7J5txcbjxNCFChH+W68UKT94A+',	'1757058476',	0,	0,	0,	''),
('admin',	'notifications',	'sound_notification',	'no',	0,	0,	0,	''),
('admin',	'notifications',	'sound_talk',	'no',	0,	0,	0,	''),
('admin',	'password_policy',	'failedLoginAttempts',	'0',	0,	0,	0,	'');

DROP TABLE IF EXISTS `oc_preferences_ex`;
CREATE TABLE `oc_preferences_ex` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `userid` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `appid` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `configkey` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `configvalue` longtext COLLATE utf8mb4_bin,
  PRIMARY KEY (`id`),
  UNIQUE KEY `preferences_ex__idx` (`userid`,`appid`,`configkey`),
  KEY `preferences_ex__configkey` (`configkey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_privacy_admins`;
CREATE TABLE `oc_privacy_admins` (
  `id` int NOT NULL AUTO_INCREMENT,
  `displayname` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_profile_config`;
CREATE TABLE `oc_profile_config` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `config` longtext COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `profile_config_user_id_idx` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_properties`;
CREATE TABLE `oc_properties` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `userid` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `propertypath` varchar(255) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `propertyname` varchar(255) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `propertyvalue` longtext COLLATE utf8mb4_bin NOT NULL,
  `valuetype` smallint DEFAULT '1',
  PRIMARY KEY (`id`),
  KEY `properties_path_index` (`userid`,`propertypath`),
  KEY `properties_pathonly_index` (`propertypath`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_ratelimit_entries`;
CREATE TABLE `oc_ratelimit_entries` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `hash` varchar(128) COLLATE utf8mb4_bin NOT NULL,
  `delete_after` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `ratelimit_hash` (`hash`),
  KEY `ratelimit_delete_after` (`delete_after`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_ratelimit_entries` (`id`, `hash`, `delete_after`) VALUES
(1,	'8aa76ceb1bdc7fee532a4ad34b1e15f8fc94f84c55677348b88eeb838a2642b901bbf44be97d792ce4d25d38d1145da022f1bfb9a2f33dde7d8fbd8153ce9d94',	'2025-09-05 08:39:28'),
(2,	'8aa76ceb1bdc7fee532a4ad34b1e15f8fc94f84c55677348b88eeb838a2642b901bbf44be97d792ce4d25d38d1145da022f1bfb9a2f33dde7d8fbd8153ce9d94',	'2025-09-05 08:39:28'),
(3,	'8aa76ceb1bdc7fee532a4ad34b1e15f8fc94f84c55677348b88eeb838a2642b901bbf44be97d792ce4d25d38d1145da022f1bfb9a2f33dde7d8fbd8153ce9d94',	'2025-09-05 08:39:28');

DROP TABLE IF EXISTS `oc_reactions`;
CREATE TABLE `oc_reactions` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `parent_id` bigint unsigned NOT NULL,
  `message_id` bigint unsigned NOT NULL,
  `actor_type` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `actor_id` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `reaction` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `comment_reaction_unique` (`parent_id`,`actor_type`,`actor_id`,`reaction`),
  KEY `comment_reaction` (`reaction`),
  KEY `comment_reaction_parent_id` (`parent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_recent_contact`;
CREATE TABLE `oc_recent_contact` (
  `id` int NOT NULL AUTO_INCREMENT,
  `actor_uid` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `uid` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `federated_cloud_id` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `card` longblob NOT NULL,
  `last_contact` int NOT NULL,
  PRIMARY KEY (`id`),
  KEY `recent_contact_actor_uid` (`actor_uid`),
  KEY `recent_contact_id_uid` (`id`,`actor_uid`),
  KEY `recent_contact_uid` (`uid`),
  KEY `recent_contact_email` (`email`),
  KEY `recent_contact_fed_id` (`federated_cloud_id`),
  KEY `recent_contact_last_contact` (`last_contact`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_schedulingobjects`;
CREATE TABLE `oc_schedulingobjects` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `principaluri` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `calendardata` longblob,
  `uri` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `lastmodified` int unsigned DEFAULT NULL,
  `etag` varchar(32) COLLATE utf8mb4_bin DEFAULT NULL,
  `size` bigint unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `schedulobj_principuri_index` (`principaluri`),
  KEY `schedulobj_lastmodified_idx` (`lastmodified`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_sec_signatory`;
CREATE TABLE `oc_sec_signatory` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `key_id_sum` varchar(127) COLLATE utf8mb4_bin NOT NULL,
  `key_id` varchar(512) COLLATE utf8mb4_bin NOT NULL,
  `host` varchar(512) COLLATE utf8mb4_bin NOT NULL,
  `provider_id` varchar(31) COLLATE utf8mb4_bin NOT NULL,
  `account` varchar(127) COLLATE utf8mb4_bin DEFAULT '',
  `public_key` longtext COLLATE utf8mb4_bin NOT NULL,
  `metadata` longtext COLLATE utf8mb4_bin NOT NULL,
  `type` smallint NOT NULL DEFAULT '9',
  `status` smallint NOT NULL DEFAULT '0',
  `creation` int unsigned DEFAULT '0',
  `last_updated` int unsigned DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `sec_sig_unic` (`provider_id`,`host`,`account`),
  KEY `sec_sig_key` (`key_id_sum`,`provider_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_share`;
CREATE TABLE `oc_share` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `share_type` smallint NOT NULL DEFAULT '0',
  `share_with` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `password` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `uid_owner` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `uid_initiator` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `parent` bigint DEFAULT NULL,
  `item_type` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `item_source` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `item_target` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `file_source` bigint DEFAULT NULL,
  `file_target` varchar(512) COLLATE utf8mb4_bin DEFAULT NULL,
  `permissions` smallint NOT NULL DEFAULT '0',
  `stime` bigint NOT NULL DEFAULT '0',
  `accepted` smallint NOT NULL DEFAULT '0',
  `expiration` datetime DEFAULT NULL,
  `token` varchar(32) COLLATE utf8mb4_bin DEFAULT NULL,
  `mail_send` smallint NOT NULL DEFAULT '0',
  `share_name` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `password_by_talk` tinyint(1) DEFAULT '0',
  `note` longtext COLLATE utf8mb4_bin,
  `hide_download` smallint DEFAULT '0',
  `label` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `attributes` json DEFAULT NULL,
  `password_expiration_time` datetime DEFAULT NULL,
  `reminder_sent` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `item_share_type_index` (`item_type`,`share_type`),
  KEY `file_source_index` (`file_source`),
  KEY `token_index` (`token`),
  KEY `share_with_index` (`share_with`),
  KEY `parent_index` (`parent`),
  KEY `owner_index` (`uid_owner`),
  KEY `initiator_index` (`uid_initiator`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_share_external`;
CREATE TABLE `oc_share_external` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `parent` bigint DEFAULT '-1',
  `share_type` int DEFAULT NULL,
  `remote` varchar(512) COLLATE utf8mb4_bin NOT NULL,
  `remote_id` varchar(255) COLLATE utf8mb4_bin DEFAULT '',
  `share_token` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `password` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `name` varchar(4000) COLLATE utf8mb4_bin NOT NULL,
  `owner` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `user` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `mountpoint` varchar(4000) COLLATE utf8mb4_bin NOT NULL,
  `mountpoint_hash` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `accepted` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `sh_external_mp` (`user`,`mountpoint_hash`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_shares_limits`;
CREATE TABLE `oc_shares_limits` (
  `id` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `limit` bigint NOT NULL,
  `downloads` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_storages`;
CREATE TABLE `oc_storages` (
  `numeric_id` bigint NOT NULL AUTO_INCREMENT,
  `id` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `available` int NOT NULL DEFAULT '1',
  `last_checked` int DEFAULT NULL,
  PRIMARY KEY (`numeric_id`),
  UNIQUE KEY `storages_id_index` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_storages` (`numeric_id`, `id`, `available`, `last_checked`) VALUES
(1,	'home::admin',	1,	NULL),
(2,	'local::/var/www/html/data/',	1,	NULL);

DROP TABLE IF EXISTS `oc_storages_credentials`;
CREATE TABLE `oc_storages_credentials` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `identifier` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `credentials` longtext COLLATE utf8mb4_bin,
  PRIMARY KEY (`id`),
  UNIQUE KEY `stocred_ui` (`user`,`identifier`),
  KEY `stocred_user` (`user`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_systemtag`;
CREATE TABLE `oc_systemtag` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `visibility` smallint NOT NULL DEFAULT '1',
  `editable` smallint NOT NULL DEFAULT '1',
  `etag` varchar(32) COLLATE utf8mb4_bin DEFAULT NULL,
  `color` varchar(6) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `tag_ident` (`name`,`visibility`,`editable`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_systemtag_group`;
CREATE TABLE `oc_systemtag_group` (
  `systemtagid` bigint unsigned NOT NULL DEFAULT '0',
  `gid` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`gid`,`systemtagid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_systemtag_object_mapping`;
CREATE TABLE `oc_systemtag_object_mapping` (
  `objectid` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `objecttype` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `systemtagid` bigint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`objecttype`,`objectid`,`systemtagid`),
  KEY `systag_by_tagid` (`systemtagid`,`objecttype`),
  KEY `systag_by_objectid` (`objectid`),
  KEY `systag_objecttype` (`objecttype`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_taskprocessing_tasks`;
CREATE TABLE `oc_taskprocessing_tasks` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `type` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `input` longtext COLLATE utf8mb4_bin NOT NULL,
  `output` longtext COLLATE utf8mb4_bin,
  `status` int DEFAULT '0',
  `user_id` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `app_id` varchar(32) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `custom_id` varchar(255) COLLATE utf8mb4_bin DEFAULT '',
  `last_updated` int unsigned DEFAULT '0',
  `completion_expected_at` datetime DEFAULT NULL,
  `progress` double DEFAULT '0',
  `error_message` varchar(4000) COLLATE utf8mb4_bin DEFAULT NULL,
  `scheduled_at` int unsigned DEFAULT NULL,
  `started_at` int unsigned DEFAULT NULL,
  `ended_at` int unsigned DEFAULT NULL,
  `webhook_uri` varchar(4000) COLLATE utf8mb4_bin DEFAULT NULL,
  `webhook_method` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `taskp_tasks_status_type` (`status`,`type`),
  KEY `taskp_tasks_updated` (`last_updated`),
  KEY `taskp_tasks_uid_appid_cid` (`user_id`,`app_id`,`custom_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_text2image_tasks`;
CREATE TABLE `oc_text2image_tasks` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `input` longtext COLLATE utf8mb4_bin NOT NULL,
  `status` int DEFAULT '0',
  `number_of_images` int NOT NULL DEFAULT '1',
  `user_id` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `app_id` varchar(32) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `identifier` varchar(255) COLLATE utf8mb4_bin DEFAULT '',
  `last_updated` datetime DEFAULT NULL,
  `completion_expected_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `t2i_tasks_updated` (`last_updated`),
  KEY `t2i_tasks_status` (`status`),
  KEY `t2i_tasks_uid_appid_ident` (`user_id`,`app_id`,`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_text_documents`;
CREATE TABLE `oc_text_documents` (
  `id` bigint unsigned NOT NULL,
  `current_version` bigint unsigned DEFAULT '0',
  `last_saved_version` bigint unsigned DEFAULT '0',
  `last_saved_version_time` bigint unsigned NOT NULL,
  `last_saved_version_etag` varchar(64) COLLATE utf8mb4_bin DEFAULT '',
  `base_version_etag` varchar(64) COLLATE utf8mb4_bin DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_text_documents` (`id`, `current_version`, `last_saved_version`, `last_saved_version_time`, `last_saved_version_etag`, `base_version_etag`) VALUES
(43,	0,	0,	1757057752,	'679eda22c8471c8ec5fdb745123b13ef',	'68ba95b81815d'),
(55,	0,	0,	1757057755,	'ac22a4b219f0cd83b7917dcd44c3ec37',	'68ba93161e6db');

DROP TABLE IF EXISTS `oc_text_sessions`;
CREATE TABLE `oc_text_sessions` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `guest_name` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `color` varchar(7) COLLATE utf8mb4_bin DEFAULT NULL,
  `token` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `document_id` bigint NOT NULL,
  `last_contact` bigint unsigned NOT NULL,
  `last_awareness_message` longtext COLLATE utf8mb4_bin,
  PRIMARY KEY (`id`),
  KEY `rd_session_token_idx` (`token`),
  KEY `ts_lastcontact` (`last_contact`),
  KEY `ts_docid_lastcontact` (`document_id`,`last_contact`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_text_sessions` (`id`, `user_id`, `guest_name`, `color`, `token`, `document_id`, `last_contact`, `last_awareness_message`) VALUES
(1,	'admin',	NULL,	'#248eb5',	'M3EucghNlfFXP8BFk/7bAfIMnRuG5H0MkH7va9b6Vz1sCHIw6RdNLE4SbSNxZeTs',	55,	1757057938,	'AWEB3NL22A0KWXsidXNlciI6eyJuYW1lIjoiYWRtaW4iLCJjbGllbnRJZCI6MzY3NjE1NDIwNCwiY29sb3IiOiIjMjQ4ZWI1IiwibGFzdFVwZGF0ZSI6MTc1NzA1NzgxM319'),
(2,	'admin',	NULL,	'#5b64b3',	'e0WhtTioS+GUIt7170Hee4J2gkHlZcAABPXSkoAuUYDOZeo2cQYY4fVf3ZLvj3hT',	43,	1757058549,	'AWABp7LDkAMFWHsidXNlciI6eyJuYW1lIjoiYWRtaW4iLCJjbGllbnRJZCI6ODM5OTY0OTY3LCJjb2xvciI6IiM1YjY0YjMiLCJsYXN0VXBkYXRlIjoxNzU3MDU4NDg3fX0=');

DROP TABLE IF EXISTS `oc_text_steps`;
CREATE TABLE `oc_text_steps` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `document_id` bigint unsigned NOT NULL,
  `session_id` bigint unsigned NOT NULL,
  `data` longtext COLLATE utf8mb4_bin NOT NULL,
  `version` bigint unsigned DEFAULT '0',
  `timestamp` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `rd_steps_did_idx` (`document_id`),
  KEY `rd_steps_version_idx` (`version`),
  KEY `textstep_session` (`session_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_textprocessing_tasks`;
CREATE TABLE `oc_textprocessing_tasks` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `type` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `input` longtext COLLATE utf8mb4_bin NOT NULL,
  `output` longtext COLLATE utf8mb4_bin,
  `status` int DEFAULT '0',
  `user_id` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `app_id` varchar(32) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `identifier` varchar(255) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `last_updated` int unsigned DEFAULT '0',
  `completion_expected_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `tp_tasks_updated` (`last_updated`),
  KEY `tp_tasks_status_type_nonunique` (`status`,`type`),
  KEY `tp_tasks_uid_appid_ident` (`user_id`,`app_id`,`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_trusted_servers`;
CREATE TABLE `oc_trusted_servers` (
  `id` int NOT NULL AUTO_INCREMENT,
  `url` varchar(512) COLLATE utf8mb4_bin NOT NULL,
  `url_hash` varchar(255) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `token` varchar(128) COLLATE utf8mb4_bin DEFAULT NULL,
  `shared_secret` varchar(256) COLLATE utf8mb4_bin DEFAULT NULL,
  `status` int NOT NULL DEFAULT '2',
  `sync_token` varchar(512) COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `url_hash` (`url_hash`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_twofactor_backupcodes`;
CREATE TABLE `oc_twofactor_backupcodes` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `code` varchar(128) COLLATE utf8mb4_bin NOT NULL,
  `used` smallint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `twofactor_backupcodes_uid` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_twofactor_providers`;
CREATE TABLE `oc_twofactor_providers` (
  `provider_id` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `uid` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `enabled` smallint NOT NULL,
  PRIMARY KEY (`provider_id`,`uid`),
  KEY `twofactor_providers_uid` (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_twofactor_providers` (`provider_id`, `uid`, `enabled`) VALUES
('backup_codes',	'admin',	0);

DROP TABLE IF EXISTS `oc_user_status`;
CREATE TABLE `oc_user_status` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `status` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `status_timestamp` int unsigned NOT NULL,
  `is_user_defined` tinyint(1) DEFAULT NULL,
  `message_id` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `custom_icon` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `custom_message` longtext COLLATE utf8mb4_bin,
  `clear_at` int unsigned DEFAULT NULL,
  `is_backup` tinyint(1) DEFAULT '0',
  `status_message_timestamp` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_status_uid_ix` (`user_id`),
  KEY `user_status_clr_ix` (`clear_at`),
  KEY `user_status_tstmp_ix` (`status_timestamp`),
  KEY `user_status_iud_ix` (`is_user_defined`,`status`),
  KEY `user_status_mtstmp_ix` (`status_message_timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_user_status` (`id`, `user_id`, `status`, `status_timestamp`, `is_user_defined`, `message_id`, `custom_icon`, `custom_message`, `clear_at`, `is_backup`, `status_message_timestamp`) VALUES
(1,	'admin',	'online',	1757057796,	0,	NULL,	NULL,	NULL,	NULL,	0,	0);

DROP TABLE IF EXISTS `oc_user_transfer_owner`;
CREATE TABLE `oc_user_transfer_owner` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `source_user` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `target_user` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `file_id` bigint NOT NULL,
  `node_name` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_users`;
CREATE TABLE `oc_users` (
  `uid` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `displayname` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `password` varchar(255) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `uid_lower` varchar(64) COLLATE utf8mb4_bin DEFAULT '',
  PRIMARY KEY (`uid`),
  KEY `user_uid_lower` (`uid_lower`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `oc_users` (`uid`, `displayname`, `password`, `uid_lower`) VALUES
('admin',	NULL,	'3|$argon2id$v=19$m=65536,t=4,p=1$ZUQwYjlXY01rdUNGNmpuQQ$5/KMWdb0sX8h6To094eXVAuZk/cU2g30Hxa3DPcG54M',	'admin');

DROP TABLE IF EXISTS `oc_vcategory`;
CREATE TABLE `oc_vcategory` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `uid` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `type` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `category` varchar(255) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_category_per_user` (`uid`,`type`,`category`),
  KEY `uid_index` (`uid`),
  KEY `type_index` (`type`),
  KEY `category_index` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_vcategory_to_object`;
CREATE TABLE `oc_vcategory_to_object` (
  `objid` bigint unsigned NOT NULL DEFAULT '0',
  `categoryid` bigint unsigned NOT NULL DEFAULT '0',
  `type` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  PRIMARY KEY (`categoryid`,`objid`,`type`),
  KEY `vcategory_objectd_index` (`objid`,`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_webauthn`;
CREATE TABLE `oc_webauthn` (
  `id` int NOT NULL AUTO_INCREMENT,
  `uid` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `name` varchar(64) COLLATE utf8mb4_bin NOT NULL,
  `public_key_credential_id` varchar(512) COLLATE utf8mb4_bin NOT NULL,
  `data` longtext COLLATE utf8mb4_bin NOT NULL,
  `user_verification` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `webauthn_uid` (`uid`),
  KEY `webauthn_publicKeyCredentialId` (`public_key_credential_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_webhook_listeners`;
CREATE TABLE `oc_webhook_listeners` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `app_id` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `user_id` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `http_method` varchar(32) COLLATE utf8mb4_bin NOT NULL,
  `uri` varchar(4000) COLLATE utf8mb4_bin NOT NULL,
  `event` varchar(4000) COLLATE utf8mb4_bin NOT NULL,
  `event_filter` longtext COLLATE utf8mb4_bin,
  `user_id_filter` varchar(64) COLLATE utf8mb4_bin DEFAULT NULL,
  `headers` longtext COLLATE utf8mb4_bin,
  `auth_method` varchar(16) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `auth_data` longtext COLLATE utf8mb4_bin,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


DROP TABLE IF EXISTS `oc_whats_new`;
CREATE TABLE `oc_whats_new` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `version` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '11',
  `etag` varchar(64) COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `last_check` int unsigned NOT NULL DEFAULT '0',
  `data` longtext COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `version` (`version`),
  KEY `version_etag_idx` (`version`,`etag`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


-- 2025-09-05 07:50:19 UTC
