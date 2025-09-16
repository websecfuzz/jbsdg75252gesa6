-- Adminer 5.3.0 MariaDB 10.11.14-MariaDB-ubu2204 dump

SET NAMES utf8;
SET time_zone = '+00:00';
SET foreign_key_checks = 0;
SET sql_mode = 'NO_AUTO_VALUE_ON_ZERO';

SET NAMES utf8mb4;

DROP TABLE IF EXISTS `logsV1_stats`;
CREATE TABLE `logsV1_stats` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `metric` varchar(255) DEFAULT NULL,
  `region` varchar(255) DEFAULT NULL,
  `value` bigint(20) DEFAULT NULL,
  `time` datetime(3) DEFAULT NULL,
  `period` varchar(4) DEFAULT NULL,
  `_tenant` int(11) unsigned DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_key_metric_period_time` (`_tenant`,`metric` DESC,`period`,`time`),
  UNIQUE KEY `_uid` (`_uid`,`_tenant`),
  KEY `_key_time` (`_tenant`,`time` DESC),
  KEY `_key_period_time` (`_tenant`,`period`,`time`),
  KEY `_created_at` (`_tenant`,`_createdAt`),
  KEY `_updated_at` (`_tenant`,`_updatedAt`),
  KEY `_tenant_id` (`_tenant`,`_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `logsV1_stats` (`_id`, `_uid`, `_createdAt`, `_updatedAt`, `_permissions`, `metric`, `region`, `value`, `time`, `period`, `_tenant`) VALUES
(1,	'ccd369fcc1744bbc12a904febe1a4376',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'databases',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(2,	'f7661dcf118e51b9b44c6644b17d63bd',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'databases',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(3,	'832d39b64fa34b0cf0aad82308f4d33b',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'databases',	'default',	0,	NULL,	'inf',	1),
(4,	'337741f85ba24175e8e3235fdbbfdbd0',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'buckets',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(5,	'0a7d10776032d1c54edf4de4b90e397a',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'buckets',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(6,	'207f9e5f969d4e0fe18414edaff36936',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'buckets',	'default',	0,	NULL,	'inf',	1),
(7,	'04daa425d953d944897e1ff405d9e19b',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'users',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(8,	'aaa1b2f22a1a42b03b31089346f77b3a',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'users',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(9,	'bfa95da1ed6387963075bceead2e955d',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'users',	'default',	0,	NULL,	'inf',	1),
(10,	'808459d471e18f2a78bd647b0a062bcf',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'functions',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(11,	'6cd445304fb9caf0520e4922f7a5c0d4',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'functions',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(12,	'9ab26daaff52f8e8164044d6b7cb3a06',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'functions',	'default',	0,	NULL,	'inf',	1),
(13,	'37023142e664568679f94298c5cd1496',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'teams',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(14,	'6466028fca1b8a0376441f825d883c82',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'teams',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(15,	'5187567d5608d4c8005d4951749efc1f',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'teams',	'default',	0,	NULL,	'inf',	1),
(16,	'360fa144e13648293808b6d6e9432d66',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'messages',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(17,	'4ba64abf2a323a47ff9331e77397156c',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'messages',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(18,	'b7a1ed03750b0929e85cc772f51ab889',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'messages',	'default',	0,	NULL,	'inf',	1),
(19,	'b55bd4289267b808f46c48e5ae4b6f2d',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'users.mau',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(20,	'4006f1e1263f0343d73b7201cb9ba63d',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'users.mau',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(21,	'5c847516d99e25d0b1b71524f3d94543',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'users.mau',	'default',	0,	NULL,	'inf',	1),
(22,	'18b2494de73a01436371c64699199b62',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'users.dau',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(23,	'8334e9393fd878e7419d9a1faf8acc01',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'users.dau',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(24,	'b5dbaa6946e0f7dd78fdd0591931e96e',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'users.dau',	'default',	0,	NULL,	'inf',	1),
(25,	'6252cdb3bab69f3b88d1f08591f7c515',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'users.wau',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(26,	'd148b5602aaf40692ffdb76bdde88376',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'users.wau',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(27,	'ca4a91309bc2cb66627124e61ddb368c',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'users.wau',	'default',	0,	NULL,	'inf',	1),
(28,	'ddcdb66754df5b42aab1eecc1a0de7c4',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'webhooks',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(29,	'daeed2ea5b322e1cf03691d5e610865d',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'webhooks',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(30,	'e5d966fb5af2890e58fce9740d5542c2',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'webhooks',	'default',	0,	NULL,	'inf',	1),
(31,	'57bbb4f0877752f1362bfb03806d9ace',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'platforms',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(32,	'd507721eddd3c5c94b25d1b41cd9204d',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'platforms',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(33,	'ee727eefdd1cd62a9155246507b2e5de',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'platforms',	'default',	0,	NULL,	'inf',	1),
(34,	'e92622ac18fb61e05749ddaf7c7e0873',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'providers',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(35,	'66b6f4c7ced7eea0c9c29d7f2e874f8b',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'providers',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(36,	'0fc7179f85364cbd53539900ded554d5',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'providers',	'default',	0,	NULL,	'inf',	1),
(37,	'c4161230bdf92c0bcb5848cf502a66ba',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'topics',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(38,	'4f59c850ba266b825ffc99481b1f4a67',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'topics',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(39,	'8d351cfa3f15bf90fe0a12b399291489',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'topics',	'default',	0,	NULL,	'inf',	1),
(40,	'f00578992b9e4bd5c2e325d3244e3460',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'keys',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(41,	'16c5c585c8c536287c8d2a9220748d37',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'keys',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(42,	'214056aa132facb9481359a2cf579724',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'keys',	'default',	0,	NULL,	'inf',	1),
(43,	'fbe108f7c5266244424eb645ae2a16bc',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'domains',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(44,	'a6ace6c2a4a754f5331e766d182a87f2',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'domains',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(45,	'd15ed200e94da8c41f565f599a2131e4',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'domains',	'default',	0,	NULL,	'inf',	1),
(46,	'2548eadbc3b6b0e1058bdc283d2ca88b',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'targets',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(47,	'47aa4f40cbecae8f4ee29b98c05bd5b0',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'targets',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(48,	'c0e50d4088527fc90df1e7ecf292699b',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'targets',	'default',	0,	NULL,	'inf',	1),
(49,	'f47c7bb9a863e08a5bbfaec727dcd1e8',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'email.targets',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(50,	'bd4a62e425b1ee7f66076b3b75151945',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'email.targets',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(51,	'a6e525aa4b4c6cb9d9976a4708986494',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'email.targets',	'default',	0,	NULL,	'inf',	1),
(52,	'62361db5f88db9b2c317710c8590bb35',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'push.targets',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(53,	'17715edf3859d6eed670fb181d1f712a',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'push.targets',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(54,	'9f338e31ab86ecafd528880f99af0337',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'push.targets',	'default',	0,	NULL,	'inf',	1),
(55,	'4269bda71f06fe026235eac3615167a7',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'sms.targets',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(56,	'9bd1e9440f84b309a5847905e6380bba',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'sms.targets',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(57,	'293ac2d4fdcab8ca92005e70610ee534',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'sms.targets',	'default',	0,	NULL,	'inf',	1),
(58,	'a59c7afdb68430199bf8111325338064',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'files',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(59,	'7a23fa113ea11574a540563e93b66383',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'files',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(60,	'2a79fd78beec85c9b0ccd185f61ae72a',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'files',	'default',	0,	NULL,	'inf',	1),
(61,	'bd3052d927e83071129d620a8502680e',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'files.storage',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(62,	'385345c6227a841070d93a6b517a85d4',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'files.storage',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(63,	'abb1b54ededd64ac933f20f4fce07bea',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'files.storage',	'default',	0,	NULL,	'inf',	1),
(64,	'b746f51f130ef18ebd8f88ede94b4c87',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'files.imagesTransformed',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(65,	'4e2bc9117f8a09fcb20c8df484a5cee8',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'files.imagesTransformed',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(66,	'6a0eec2ed6d852d7436ee2c44d31a635',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'files.imagesTransformed',	'default',	0,	NULL,	'inf',	1),
(67,	'0920377f574a4a1810e61e1a2bdd3700',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'collections',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(68,	'4217aed3e6e064bebc5099cdb7afb59a',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'collections',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(69,	'830f9b7b9ac01c0a2ec1781e53ea1aaa',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'collections',	'default',	0,	NULL,	'inf',	1),
(70,	'3b52add7daf756b588fcfac1040cf307',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'documents',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(71,	'06abbe778030d897224ae8c7e5782176',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'documents',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(72,	'569f0bc87e0ce030599495ca6fa15950',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'documents',	'default',	0,	NULL,	'inf',	1),
(73,	'd441c77fe1fcff1afac9d1a20425d5da',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'databases.storage',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(74,	'c73235df7e52120be6b3cbe2ecfa63c7',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'databases.storage',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(75,	'7a562704abf5a89784d93474e7b5eca8',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'databases.storage',	'default',	0,	NULL,	'inf',	1),
(76,	'f6ccfeaef96280e235364e26a4b4c3cc',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'deployments.storage',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(77,	'5f7ee8e037d5e28887bec63409bf4cfe',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'deployments.storage',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(78,	'c5a9a17b77cdcdf88bda49db5978ce65',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'deployments.storage',	'default',	0,	NULL,	'inf',	1),
(79,	'b6d64a90f86d1646eb688806195e6e6c',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'builds.storage',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(80,	'49f6152dd23c0c3f62fb9b39838a2120',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'builds.storage',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(81,	'845da6066683f7750f8c0865da4b368a',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'builds.storage',	'default',	0,	NULL,	'inf',	1),
(82,	'2bf9ccc55a9a4dc92149f0a96e922404',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'deployments',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(83,	'7892b2be71f533e61d4d43327bfc8405',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'deployments',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(84,	'997a1bd8517acfd8ecf1cf3c7e68e75d',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'deployments',	'default',	0,	NULL,	'inf',	1),
(85,	'99504261875636e6c3e8fe998d8f5028',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'builds',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(86,	'aa9684b45d2897d9fa1c94a0badffa87',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'builds',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(87,	'2b78ab404c0aeecbc68d9fd233e25d5d',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'builds',	'default',	0,	NULL,	'inf',	1),
(88,	'64ad6f47567ace30fbaee1e0fe5b0858',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'functions.deployments.storage',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(89,	'7e6445b585e404d5396ba73d01a435b6',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'functions.deployments.storage',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(90,	'5131c88dae31c54997fbf9a59dbb9f4c',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'functions.deployments.storage',	'default',	0,	NULL,	'inf',	1),
(91,	'e934ab5eeb144dfe4b7b24a29b776481',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'functions.builds.storage',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(92,	'223014e3130105b52674ceb0fa879e62',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'functions.builds.storage',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(93,	'a8cd5723083731b29bdacabac467e00b',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'functions.builds.storage',	'default',	0,	NULL,	'inf',	1),
(94,	'978f15131d948a97889604ae1baf2308',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'functions.deployments',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(95,	'2a4839fc44ecdee3546d5d0cc90f5c55',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'functions.deployments',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(96,	'91fd1857c5a09ceefdfb9cacbed6e8ba',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'functions.deployments',	'default',	0,	NULL,	'inf',	1),
(97,	'de51e2809012e23280d8f2d471962da0',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'functions.builds',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(98,	'efa18c13790a5edff9adb24adf55adbd',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'functions.builds',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(99,	'b1c13050e0d8a44571a2037e6701e57e',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'functions.builds',	'default',	0,	NULL,	'inf',	1),
(100,	'cdbe155c9bcf04b5e770e0f9505491cd',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'sites.deployments.storage',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(101,	'4df909756ebbf9ac1eab8168d24b423c',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'sites.deployments.storage',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(102,	'7d628b19cde9928f3ad8a0aa83643124',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'sites.deployments.storage',	'default',	0,	NULL,	'inf',	1),
(103,	'86630780c049f823245f7b2ec0412ea9',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'sites.builds.storage',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(104,	'98eb2960d05e0c13fb308befb0e8a90f',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'sites.builds.storage',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(105,	'bc9fb01b6efeeed144f0bf19803bebbe',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'sites.builds.storage',	'default',	0,	NULL,	'inf',	1),
(106,	'6d3d350d987219aef4270f9763f9bab6',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'sites.deployments',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(107,	'e4ce2e3e96c43d5df913c6d224e935d2',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'sites.deployments',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(108,	'1933431f379a3324f7f2104b8a10f91b',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'sites.deployments',	'default',	0,	NULL,	'inf',	1),
(109,	'c1536c04039cd3148c3a4f93adb5760a',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'sites.builds',	'default',	0,	'2025-08-19 13:00:00.000',	'1h',	1),
(110,	'b33cf03a10f1b13a3b63aad150dd7986',	'2025-08-19 13:41:48.547',	'2025-08-19 13:43:48.615',	'[]',	'sites.builds',	'default',	0,	'2025-08-19 00:00:00.000',	'1d',	1),
(111,	'06a508d3ecbac4b1042a8f2316402654',	'2025-08-19 13:41:48.547',	'2025-08-19 13:41:48.547',	'[]',	'sites.builds',	'default',	0,	NULL,	'inf',	1);

DROP TABLE IF EXISTS `logsV1_stats_perms`;
CREATE TABLE `logsV1_stats_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  `_tenant` int(11) unsigned DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_tenant`,`_type`,`_permission`),
  KEY `_permission` (`_tenant`,`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `logsV1__metadata`;
CREATE TABLE `logsV1__metadata` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `name` varchar(256) DEFAULT NULL,
  `attributes` mediumtext DEFAULT NULL,
  `indexes` mediumtext DEFAULT NULL,
  `documentSecurity` tinyint(1) DEFAULT NULL,
  `_tenant` int(11) unsigned DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`,`_tenant`),
  KEY `_created_at` (`_tenant`,`_createdAt`),
  KEY `_updated_at` (`_tenant`,`_updatedAt`),
  KEY `_tenant_id` (`_tenant`,`_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `logsV1__metadata` (`_id`, `_uid`, `_createdAt`, `_updatedAt`, `_permissions`, `name`, `attributes`, `indexes`, `documentSecurity`, `_tenant`) VALUES
(1,	'stats',	'2025-08-19 13:17:46.951',	'2025-08-19 13:17:46.951',	'[\"create(\\\"any\\\")\"]',	'stats',	'[{\"$id\":\"metric\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"region\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"value\",\"type\":\"integer\",\"size\":8,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"time\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"period\",\"type\":\"string\",\"size\":4,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_time\",\"type\":\"key\",\"attributes\":[\"time\"],\"lengths\":[],\"orders\":[\"DESC\"]},{\"$id\":\"_key_period_time\",\"type\":\"key\",\"attributes\":[\"period\",\"time\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_metric_period_time\",\"type\":\"unique\",\"attributes\":[\"metric\",\"period\",\"time\"],\"lengths\":[],\"orders\":[\"DESC\"]}]',	1,	NULL);

DROP TABLE IF EXISTS `logsV1__metadata_perms`;
CREATE TABLE `logsV1__metadata_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  `_tenant` int(11) unsigned DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_tenant`,`_type`,`_permission`),
  KEY `_permission` (`_tenant`,`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `logsV1__metadata_perms` (`_id`, `_type`, `_permission`, `_document`, `_tenant`) VALUES
(1,	'create',	'any',	'stats',	NULL);

DROP TABLE IF EXISTS `_1_attributes`;
CREATE TABLE `_1_attributes` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `databaseInternalId` varchar(255) DEFAULT NULL,
  `databaseId` varchar(255) DEFAULT NULL,
  `collectionInternalId` varchar(255) DEFAULT NULL,
  `collectionId` varchar(255) DEFAULT NULL,
  `key` varchar(255) DEFAULT NULL,
  `type` varchar(256) DEFAULT NULL,
  `status` varchar(16) DEFAULT NULL,
  `error` varchar(2048) DEFAULT NULL,
  `size` int(11) DEFAULT NULL,
  `required` tinyint(1) DEFAULT NULL,
  `default` text DEFAULT NULL,
  `signed` tinyint(1) DEFAULT NULL,
  `array` tinyint(1) DEFAULT NULL,
  `format` varchar(64) DEFAULT NULL,
  `formatOptions` text DEFAULT NULL,
  `filters` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`filters`)),
  `options` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_db_collection` (`databaseInternalId`,`collectionInternalId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_attributes_perms`;
CREATE TABLE `_1_attributes_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_audit`;
CREATE TABLE `_1_audit` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `event` varchar(255) DEFAULT NULL,
  `resource` varchar(255) DEFAULT NULL,
  `userAgent` text DEFAULT NULL,
  `ip` varchar(45) DEFAULT NULL,
  `location` varchar(45) DEFAULT NULL,
  `time` datetime(3) DEFAULT NULL,
  `data` longtext DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `index2` (`event`),
  KEY `index4` (`userId`,`event`),
  KEY `index5` (`resource`,`event`),
  KEY `index-time` (`time` DESC),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_audit_perms`;
CREATE TABLE `_1_audit_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_authenticators`;
CREATE TABLE `_1_authenticators` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `userInternalId` varchar(255) DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `type` varchar(255) DEFAULT NULL,
  `verified` tinyint(1) DEFAULT NULL,
  `data` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_userInternalId` (`userInternalId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_authenticators_perms`;
CREATE TABLE `_1_authenticators_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_buckets`;
CREATE TABLE `_1_buckets` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `name` varchar(128) DEFAULT NULL,
  `fileSecurity` tinyint(1) DEFAULT NULL,
  `maximumFileSize` bigint(20) unsigned DEFAULT NULL,
  `allowedFileExtensions` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`allowedFileExtensions`)),
  `compression` varchar(10) DEFAULT NULL,
  `encryption` tinyint(1) DEFAULT NULL,
  `antivirus` tinyint(1) DEFAULT NULL,
  `search` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_enabled` (`enabled`),
  KEY `_key_name` (`name`),
  KEY `_key_fileSecurity` (`fileSecurity`),
  KEY `_key_maximumFileSize` (`maximumFileSize`),
  KEY `_key_encryption` (`encryption`),
  KEY `_key_antivirus` (`antivirus`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_fulltext_name` (`name`),
  FULLTEXT KEY `_key_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_buckets_perms`;
CREATE TABLE `_1_buckets_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_cache`;
CREATE TABLE `_1_cache` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `resource` varchar(255) DEFAULT NULL,
  `resourceType` varchar(255) DEFAULT NULL,
  `mimeType` varchar(255) DEFAULT NULL,
  `accessedAt` datetime(3) DEFAULT NULL,
  `signature` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_accessedAt` (`accessedAt`),
  KEY `_key_resource` (`resource`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_cache_perms`;
CREATE TABLE `_1_cache_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_challenges`;
CREATE TABLE `_1_challenges` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `userInternalId` varchar(255) DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `type` varchar(255) DEFAULT NULL,
  `token` varchar(512) DEFAULT NULL,
  `code` varchar(512) DEFAULT NULL,
  `expire` datetime(3) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_user` (`userInternalId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_challenges_perms`;
CREATE TABLE `_1_challenges_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_databases`;
CREATE TABLE `_1_databases` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `name` varchar(256) DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `search` text DEFAULT NULL,
  `originalId` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_name` (`name`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_fulltext_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_databases_perms`;
CREATE TABLE `_1_databases_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_deployments`;
CREATE TABLE `_1_deployments` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `resourceInternalId` varchar(255) DEFAULT NULL,
  `resourceId` varchar(255) DEFAULT NULL,
  `resourceType` varchar(255) DEFAULT NULL,
  `entrypoint` varchar(2048) DEFAULT NULL,
  `buildCommands` text DEFAULT NULL,
  `buildOutput` text DEFAULT NULL,
  `sourcePath` text DEFAULT NULL,
  `type` varchar(2048) DEFAULT NULL,
  `installationId` varchar(255) DEFAULT NULL,
  `installationInternalId` varchar(255) DEFAULT NULL,
  `providerRepositoryId` varchar(255) DEFAULT NULL,
  `repositoryId` varchar(255) DEFAULT NULL,
  `repositoryInternalId` varchar(255) DEFAULT NULL,
  `providerRepositoryName` varchar(255) DEFAULT NULL,
  `providerRepositoryOwner` varchar(255) DEFAULT NULL,
  `providerRepositoryUrl` varchar(255) DEFAULT NULL,
  `providerCommitHash` varchar(255) DEFAULT NULL,
  `providerCommitAuthorUrl` varchar(255) DEFAULT NULL,
  `providerCommitAuthor` varchar(255) DEFAULT NULL,
  `providerCommitMessage` varchar(255) DEFAULT NULL,
  `providerCommitUrl` varchar(255) DEFAULT NULL,
  `providerBranch` varchar(255) DEFAULT NULL,
  `providerBranchUrl` varchar(255) DEFAULT NULL,
  `providerRootDirectory` varchar(255) DEFAULT NULL,
  `providerCommentId` varchar(2048) DEFAULT NULL,
  `sourceSize` bigint(20) unsigned DEFAULT NULL,
  `sourceMetadata` text DEFAULT NULL,
  `sourceChunksTotal` int(10) unsigned DEFAULT NULL,
  `sourceChunksUploaded` int(10) unsigned DEFAULT NULL,
  `activate` tinyint(1) DEFAULT NULL,
  `screenshotLight` varchar(32) DEFAULT NULL,
  `screenshotDark` varchar(32) DEFAULT NULL,
  `buildStartedAt` datetime(3) DEFAULT NULL,
  `buildEndedAt` datetime(3) DEFAULT NULL,
  `buildDuration` int(10) unsigned DEFAULT NULL,
  `buildSize` bigint(20) unsigned DEFAULT NULL,
  `totalSize` bigint(20) unsigned DEFAULT NULL,
  `status` varchar(16) DEFAULT NULL,
  `buildPath` text DEFAULT NULL,
  `buildLogs` mediumtext DEFAULT NULL,
  `adapter` varchar(16) DEFAULT NULL,
  `fallbackFile` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_resource` (`resourceId`),
  KEY `_key_resource_type` (`resourceType`),
  KEY `_key_sourceSize` (`sourceSize`),
  KEY `_key_buildSize` (`buildSize`),
  KEY `_key_totalSize` (`totalSize`),
  KEY `_key_buildDuration` (`buildDuration`),
  KEY `_key_activate` (`activate`),
  KEY `_key_type` (`type`(32)),
  KEY `_key_status` (`status`),
  KEY `_key_resourceId_resourceType` (`resourceId`,`resourceType`),
  KEY `_key_resource_internal_id` (`resourceInternalId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_deployments_perms`;
CREATE TABLE `_1_deployments_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_executions`;
CREATE TABLE `_1_executions` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `resourceInternalId` varchar(255) DEFAULT NULL,
  `resourceId` varchar(255) DEFAULT NULL,
  `resourceType` varchar(255) DEFAULT NULL,
  `deploymentInternalId` varchar(255) DEFAULT NULL,
  `deploymentId` varchar(255) DEFAULT NULL,
  `trigger` varchar(128) DEFAULT NULL,
  `status` varchar(128) DEFAULT NULL,
  `duration` double DEFAULT NULL,
  `errors` mediumtext DEFAULT NULL,
  `logs` mediumtext DEFAULT NULL,
  `requestMethod` varchar(128) DEFAULT NULL,
  `requestPath` varchar(2048) DEFAULT NULL,
  `requestHeaders` text DEFAULT NULL,
  `responseStatusCode` int(11) DEFAULT NULL,
  `responseHeaders` text DEFAULT NULL,
  `scheduledAt` datetime(3) DEFAULT NULL,
  `scheduleInternalId` varchar(255) DEFAULT NULL,
  `scheduleId` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_resource` (`resourceInternalId`,`resourceType`,`resourceId`),
  KEY `_key_trigger` (`trigger`(32)),
  KEY `_key_status` (`status`(32)),
  KEY `_key_requestMethod` (`requestMethod`),
  KEY `_key_requestPath` (`requestPath`(255)),
  KEY `_key_deployment` (`deploymentId`),
  KEY `_key_responseStatusCode` (`responseStatusCode`),
  KEY `_key_duration` (`duration`),
  KEY `_key_function_internal_id` (`resourceInternalId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_executions_perms`;
CREATE TABLE `_1_executions_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_functions`;
CREATE TABLE `_1_functions` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `execute` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`execute`)),
  `name` varchar(2048) DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `live` tinyint(1) DEFAULT NULL,
  `installationId` varchar(255) DEFAULT NULL,
  `installationInternalId` varchar(255) DEFAULT NULL,
  `providerRepositoryId` varchar(255) DEFAULT NULL,
  `repositoryId` varchar(255) DEFAULT NULL,
  `repositoryInternalId` varchar(255) DEFAULT NULL,
  `providerBranch` varchar(255) DEFAULT NULL,
  `providerRootDirectory` varchar(255) DEFAULT NULL,
  `providerSilentMode` tinyint(1) DEFAULT NULL,
  `logging` tinyint(1) DEFAULT NULL,
  `runtime` varchar(2048) DEFAULT NULL,
  `deploymentInternalId` varchar(255) DEFAULT NULL,
  `deploymentId` varchar(255) DEFAULT NULL,
  `deploymentCreatedAt` datetime(3) DEFAULT NULL,
  `latestDeploymentId` varchar(255) DEFAULT NULL,
  `latestDeploymentInternalId` varchar(255) DEFAULT NULL,
  `latestDeploymentCreatedAt` datetime(3) DEFAULT NULL,
  `latestDeploymentStatus` varchar(16) DEFAULT NULL,
  `vars` text DEFAULT NULL,
  `varsProject` text DEFAULT NULL,
  `events` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`events`)),
  `scheduleInternalId` varchar(255) DEFAULT NULL,
  `scheduleId` varchar(255) DEFAULT NULL,
  `schedule` varchar(128) DEFAULT NULL,
  `timeout` int(11) DEFAULT NULL,
  `search` text DEFAULT NULL,
  `version` varchar(8) DEFAULT NULL,
  `entrypoint` text DEFAULT NULL,
  `commands` text DEFAULT NULL,
  `specification` varchar(128) DEFAULT NULL,
  `scopes` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`scopes`)),
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_name` (`name`(256)),
  KEY `_key_enabled` (`enabled`),
  KEY `_key_installationId` (`installationId`),
  KEY `_key_installationInternalId` (`installationInternalId`),
  KEY `_key_providerRepositoryId` (`providerRepositoryId`),
  KEY `_key_repositoryId` (`repositoryId`),
  KEY `_key_repositoryInternalId` (`repositoryInternalId`),
  KEY `_key_runtime` (`runtime`(64)),
  KEY `_key_deploymentId` (`deploymentId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_key_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_functions_perms`;
CREATE TABLE `_1_functions_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_identities`;
CREATE TABLE `_1_identities` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `userInternalId` varchar(255) DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `provider` varchar(128) DEFAULT NULL,
  `providerUid` varchar(2048) DEFAULT NULL,
  `providerEmail` varchar(320) DEFAULT NULL,
  `providerAccessToken` text DEFAULT NULL,
  `providerAccessTokenExpiry` datetime(3) DEFAULT NULL,
  `providerRefreshToken` text DEFAULT NULL,
  `secrets` text DEFAULT NULL,
  `scopes` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`scopes`)),
  `expire` datetime(3) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  UNIQUE KEY `_key_userInternalId_provider_providerUid` (`userInternalId`(11),`provider`,`providerUid`(128)),
  UNIQUE KEY `_key_provider_providerUid` (`provider`,`providerUid`(128)),
  KEY `_key_userId` (`userId`),
  KEY `_key_userInternalId` (`userInternalId`),
  KEY `_key_provider` (`provider`),
  KEY `_key_providerUid` (`providerUid`(255)),
  KEY `_key_providerEmail` (`providerEmail`(255)),
  KEY `_key_providerAccessTokenExpiry` (`providerAccessTokenExpiry`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_identities_perms`;
CREATE TABLE `_1_identities_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_indexes`;
CREATE TABLE `_1_indexes` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `databaseInternalId` varchar(255) DEFAULT NULL,
  `databaseId` varchar(255) DEFAULT NULL,
  `collectionInternalId` varchar(255) DEFAULT NULL,
  `collectionId` varchar(255) DEFAULT NULL,
  `key` varchar(255) DEFAULT NULL,
  `type` varchar(16) DEFAULT NULL,
  `status` varchar(16) DEFAULT NULL,
  `error` varchar(2048) DEFAULT NULL,
  `attributes` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`attributes`)),
  `lengths` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`lengths`)),
  `orders` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`orders`)),
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_db_collection` (`databaseInternalId`,`collectionInternalId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_indexes_perms`;
CREATE TABLE `_1_indexes_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_memberships`;
CREATE TABLE `_1_memberships` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `userInternalId` varchar(255) DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `teamInternalId` varchar(255) DEFAULT NULL,
  `teamId` varchar(255) DEFAULT NULL,
  `roles` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`roles`)),
  `invited` datetime(3) DEFAULT NULL,
  `joined` datetime(3) DEFAULT NULL,
  `confirm` tinyint(1) DEFAULT NULL,
  `secret` varchar(256) DEFAULT NULL,
  `search` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  UNIQUE KEY `_key_unique` (`teamInternalId`,`userInternalId`),
  KEY `_key_user` (`userInternalId`),
  KEY `_key_team` (`teamInternalId`),
  KEY `_key_userId` (`userId`),
  KEY `_key_teamId` (`teamId`),
  KEY `_key_invited` (`invited`),
  KEY `_key_joined` (`joined`),
  KEY `_key_confirm` (`confirm`),
  KEY `_key_roles` (`roles`(255)),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_key_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_memberships_perms`;
CREATE TABLE `_1_memberships_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_messages`;
CREATE TABLE `_1_messages` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `providerType` varchar(255) DEFAULT NULL,
  `status` varchar(255) DEFAULT NULL,
  `data` text DEFAULT NULL,
  `topics` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`topics`)),
  `users` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`users`)),
  `targets` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`targets`)),
  `scheduledAt` datetime(3) DEFAULT NULL,
  `scheduleInternalId` varchar(255) DEFAULT NULL,
  `scheduleId` varchar(255) DEFAULT NULL,
  `deliveredAt` datetime(3) DEFAULT NULL,
  `deliveryErrors` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`deliveryErrors`)),
  `deliveredTotal` int(11) DEFAULT NULL,
  `search` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_key_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_messages_perms`;
CREATE TABLE `_1_messages_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_migrations`;
CREATE TABLE `_1_migrations` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `status` varchar(255) DEFAULT NULL,
  `stage` varchar(255) DEFAULT NULL,
  `source` varchar(8192) DEFAULT NULL,
  `destination` varchar(255) DEFAULT NULL,
  `credentials` mediumtext DEFAULT NULL,
  `options` mediumtext DEFAULT NULL,
  `resources` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`resources`)),
  `statusCounters` varchar(3000) DEFAULT NULL,
  `resourceData` mediumtext DEFAULT NULL,
  `errors` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`errors`)),
  `search` text DEFAULT NULL,
  `resourceId` varchar(255) DEFAULT NULL,
  `resourceType` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_status` (`status`),
  KEY `_key_stage` (`stage`),
  KEY `_key_source` (`source`(255)),
  KEY `_key_resource_id` (`resourceId` DESC),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_fulltext_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_migrations_perms`;
CREATE TABLE `_1_migrations_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_providers`;
CREATE TABLE `_1_providers` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `name` varchar(128) DEFAULT NULL,
  `provider` varchar(255) DEFAULT NULL,
  `type` varchar(128) DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `credentials` text DEFAULT NULL,
  `options` text DEFAULT NULL,
  `search` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_provider` (`provider`),
  KEY `_key_type` (`type`),
  KEY `_key_enabled_type` (`enabled`,`type`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_key_name` (`name`),
  FULLTEXT KEY `_key_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_providers_perms`;
CREATE TABLE `_1_providers_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_resourceTokens`;
CREATE TABLE `_1_resourceTokens` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `resourceId` varchar(255) DEFAULT NULL,
  `resourceInternalId` varchar(255) DEFAULT NULL,
  `resourceType` varchar(100) DEFAULT NULL,
  `secret` varchar(512) DEFAULT NULL,
  `expire` datetime(3) DEFAULT NULL,
  `accessedAt` datetime(3) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_expiry_date` (`expire`),
  KEY `_key_accessedAt` (`accessedAt`),
  KEY `_key_resourceInternalId_resourceType` (`resourceInternalId`,`resourceType`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_resourceTokens_perms`;
CREATE TABLE `_1_resourceTokens_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_sessions`;
CREATE TABLE `_1_sessions` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `userInternalId` varchar(255) DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `provider` varchar(128) DEFAULT NULL,
  `providerUid` varchar(2048) DEFAULT NULL,
  `providerAccessToken` text DEFAULT NULL,
  `providerAccessTokenExpiry` datetime(3) DEFAULT NULL,
  `providerRefreshToken` text DEFAULT NULL,
  `secret` varchar(512) DEFAULT NULL,
  `userAgent` text DEFAULT NULL,
  `ip` varchar(45) DEFAULT NULL,
  `countryCode` varchar(2) DEFAULT NULL,
  `osCode` varchar(256) DEFAULT NULL,
  `osName` varchar(256) DEFAULT NULL,
  `osVersion` varchar(256) DEFAULT NULL,
  `clientType` varchar(256) DEFAULT NULL,
  `clientCode` varchar(256) DEFAULT NULL,
  `clientName` varchar(256) DEFAULT NULL,
  `clientVersion` varchar(256) DEFAULT NULL,
  `clientEngine` varchar(256) DEFAULT NULL,
  `clientEngineVersion` varchar(256) DEFAULT NULL,
  `deviceName` varchar(256) DEFAULT NULL,
  `deviceBrand` varchar(256) DEFAULT NULL,
  `deviceModel` varchar(256) DEFAULT NULL,
  `factors` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`factors`)),
  `expire` datetime(3) DEFAULT NULL,
  `mfaUpdatedAt` datetime(3) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_provider_providerUid` (`provider`,`providerUid`(128)),
  KEY `_key_user` (`userInternalId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_sessions_perms`;
CREATE TABLE `_1_sessions_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_sites`;
CREATE TABLE `_1_sites` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `name` varchar(2048) DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `live` tinyint(1) DEFAULT NULL,
  `installationId` varchar(255) DEFAULT NULL,
  `installationInternalId` varchar(255) DEFAULT NULL,
  `providerRepositoryId` varchar(255) DEFAULT NULL,
  `repositoryId` varchar(255) DEFAULT NULL,
  `repositoryInternalId` varchar(255) DEFAULT NULL,
  `providerBranch` varchar(255) DEFAULT NULL,
  `providerRootDirectory` varchar(255) DEFAULT NULL,
  `providerSilentMode` tinyint(1) DEFAULT NULL,
  `logging` tinyint(1) DEFAULT NULL,
  `framework` varchar(2048) DEFAULT NULL,
  `outputDirectory` text DEFAULT NULL,
  `buildCommand` text DEFAULT NULL,
  `installCommand` text DEFAULT NULL,
  `fallbackFile` text DEFAULT NULL,
  `deploymentInternalId` varchar(255) DEFAULT NULL,
  `deploymentId` varchar(255) DEFAULT NULL,
  `deploymentCreatedAt` datetime(3) DEFAULT NULL,
  `deploymentScreenshotLight` varchar(32) DEFAULT NULL,
  `deploymentScreenshotDark` varchar(32) DEFAULT NULL,
  `latestDeploymentId` varchar(255) DEFAULT NULL,
  `latestDeploymentInternalId` varchar(255) DEFAULT NULL,
  `latestDeploymentCreatedAt` datetime(3) DEFAULT NULL,
  `latestDeploymentStatus` varchar(16) DEFAULT NULL,
  `vars` text DEFAULT NULL,
  `varsProject` text DEFAULT NULL,
  `timeout` int(11) DEFAULT NULL,
  `search` text DEFAULT NULL,
  `specification` varchar(128) DEFAULT NULL,
  `buildRuntime` varchar(2048) DEFAULT NULL,
  `adapter` varchar(16) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_name` (`name`(256)),
  KEY `_key_enabled` (`enabled`),
  KEY `_key_installationId` (`installationId`),
  KEY `_key_installationInternalId` (`installationInternalId`),
  KEY `_key_providerRepositoryId` (`providerRepositoryId`),
  KEY `_key_repositoryId` (`repositoryId`),
  KEY `_key_repositoryInternalId` (`repositoryInternalId`),
  KEY `_key_framework` (`framework`(64)),
  KEY `_key_deploymentId` (`deploymentId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_key_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_sites_perms`;
CREATE TABLE `_1_sites_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_stats`;
CREATE TABLE `_1_stats` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `metric` varchar(255) DEFAULT NULL,
  `region` varchar(255) DEFAULT NULL,
  `value` bigint(20) DEFAULT NULL,
  `time` datetime(3) DEFAULT NULL,
  `period` varchar(4) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  UNIQUE KEY `_key_metric_period_time` (`metric` DESC,`period`,`time`),
  KEY `_key_time` (`time` DESC),
  KEY `_key_period_time` (`period`,`time`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_stats_perms`;
CREATE TABLE `_1_stats_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_subscribers`;
CREATE TABLE `_1_subscribers` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `targetId` varchar(255) DEFAULT NULL,
  `targetInternalId` varchar(255) DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `userInternalId` varchar(255) DEFAULT NULL,
  `topicId` varchar(255) DEFAULT NULL,
  `topicInternalId` varchar(255) DEFAULT NULL,
  `providerType` varchar(128) DEFAULT NULL,
  `search` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  UNIQUE KEY `_unique_target_topic` (`targetInternalId`,`topicInternalId`),
  KEY `_key_targetId` (`targetId`),
  KEY `_key_targetInternalId` (`targetInternalId`),
  KEY `_key_userId` (`userId`),
  KEY `_key_userInternalId` (`userInternalId`),
  KEY `_key_topicId` (`topicId`),
  KEY `_key_topicInternalId` (`topicInternalId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_fulltext_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_subscribers_perms`;
CREATE TABLE `_1_subscribers_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_targets`;
CREATE TABLE `_1_targets` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `userInternalId` varchar(255) DEFAULT NULL,
  `sessionId` varchar(255) DEFAULT NULL,
  `sessionInternalId` varchar(255) DEFAULT NULL,
  `providerType` varchar(255) DEFAULT NULL,
  `providerId` varchar(255) DEFAULT NULL,
  `providerInternalId` varchar(255) DEFAULT NULL,
  `identifier` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `expired` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  UNIQUE KEY `_key_identifier` (`identifier`),
  KEY `_key_userId` (`userId`),
  KEY `_key_userInternalId` (`userInternalId`),
  KEY `_key_providerId` (`providerId`),
  KEY `_key_providerInternalId` (`providerInternalId`),
  KEY `_key_expired` (`expired`),
  KEY `_key_session_internal_id` (`sessionInternalId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_targets_perms`;
CREATE TABLE `_1_targets_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_teams`;
CREATE TABLE `_1_teams` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `name` varchar(128) DEFAULT NULL,
  `total` int(11) DEFAULT NULL,
  `search` text DEFAULT NULL,
  `prefs` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_name` (`name`),
  KEY `_key_total` (`total`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_key_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_teams_perms`;
CREATE TABLE `_1_teams_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_tokens`;
CREATE TABLE `_1_tokens` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `userInternalId` varchar(255) DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `type` int(11) DEFAULT NULL,
  `secret` varchar(512) DEFAULT NULL,
  `expire` datetime(3) DEFAULT NULL,
  `userAgent` text DEFAULT NULL,
  `ip` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_user` (`userInternalId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_tokens_perms`;
CREATE TABLE `_1_tokens_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_topics`;
CREATE TABLE `_1_topics` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `name` varchar(128) DEFAULT NULL,
  `subscribe` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`subscribe`)),
  `emailTotal` int(11) DEFAULT NULL,
  `smsTotal` int(11) DEFAULT NULL,
  `pushTotal` int(11) DEFAULT NULL,
  `targets` text DEFAULT NULL,
  `search` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_key_name` (`name`),
  FULLTEXT KEY `_key_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_topics_perms`;
CREATE TABLE `_1_topics_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_users`;
CREATE TABLE `_1_users` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `name` varchar(256) DEFAULT NULL,
  `email` varchar(320) DEFAULT NULL,
  `phone` varchar(16) DEFAULT NULL,
  `status` tinyint(1) DEFAULT NULL,
  `labels` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`labels`)),
  `passwordHistory` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`passwordHistory`)),
  `password` text DEFAULT NULL,
  `hash` varchar(256) DEFAULT NULL,
  `hashOptions` text DEFAULT NULL,
  `passwordUpdate` datetime(3) DEFAULT NULL,
  `prefs` text DEFAULT NULL,
  `registration` datetime(3) DEFAULT NULL,
  `emailVerification` tinyint(1) DEFAULT NULL,
  `phoneVerification` tinyint(1) DEFAULT NULL,
  `reset` tinyint(1) DEFAULT NULL,
  `mfa` tinyint(1) DEFAULT NULL,
  `mfaRecoveryCodes` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`mfaRecoveryCodes`)),
  `authenticators` text DEFAULT NULL,
  `sessions` text DEFAULT NULL,
  `tokens` text DEFAULT NULL,
  `challenges` text DEFAULT NULL,
  `memberships` text DEFAULT NULL,
  `targets` text DEFAULT NULL,
  `search` text DEFAULT NULL,
  `accessedAt` datetime(3) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  UNIQUE KEY `_key_phone` (`phone`),
  UNIQUE KEY `_key_email` (`email`(256)),
  KEY `_key_name` (`name`),
  KEY `_key_status` (`status`),
  KEY `_key_passwordUpdate` (`passwordUpdate`),
  KEY `_key_registration` (`registration`),
  KEY `_key_emailVerification` (`emailVerification`),
  KEY `_key_phoneVerification` (`phoneVerification`),
  KEY `_key_accessedAt` (`accessedAt`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_key_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_users_perms`;
CREATE TABLE `_1_users_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_variables`;
CREATE TABLE `_1_variables` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `resourceType` varchar(100) DEFAULT NULL,
  `resourceInternalId` varchar(255) DEFAULT NULL,
  `resourceId` varchar(255) DEFAULT NULL,
  `key` varchar(255) DEFAULT NULL,
  `value` varchar(8192) DEFAULT NULL,
  `secret` tinyint(1) DEFAULT NULL,
  `search` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  UNIQUE KEY `_key_uniqueKey` (`resourceId`,`key`,`resourceType`),
  KEY `_key_resourceInternalId` (`resourceInternalId`),
  KEY `_key_resourceType` (`resourceType`),
  KEY `_key_resourceId_resourceType` (`resourceId`,`resourceType`),
  KEY `_key_key` (`key`),
  KEY `_key_resource_internal_id_resource_type` (`resourceInternalId`,`resourceType`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_fulltext_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1_variables_perms`;
CREATE TABLE `_1_variables_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_1__metadata`;
CREATE TABLE `_1__metadata` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `name` varchar(256) DEFAULT NULL,
  `attributes` mediumtext DEFAULT NULL,
  `indexes` mediumtext DEFAULT NULL,
  `documentSecurity` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `_1__metadata` (`_id`, `_uid`, `_createdAt`, `_updatedAt`, `_permissions`, `name`, `attributes`, `indexes`, `documentSecurity`) VALUES
(1,	'audit',	'2025-08-19 13:41:37.459',	'2025-08-19 13:41:37.459',	'[\"create(\\\"any\\\")\"]',	'audit',	'[{\"$id\":\"userId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[]},{\"$id\":\"event\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[]},{\"$id\":\"resource\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[]},{\"$id\":\"userAgent\",\"type\":\"string\",\"size\":65534,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[]},{\"$id\":\"ip\",\"type\":\"string\",\"size\":45,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[]},{\"$id\":\"location\",\"type\":\"string\",\"size\":45,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[]},{\"$id\":\"time\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"data\",\"type\":\"string\",\"size\":16777216,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"json\"]}]',	'[{\"$id\":\"index2\",\"type\":\"key\",\"attributes\":[\"event\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"index4\",\"type\":\"key\",\"attributes\":[\"userId\",\"event\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"index5\",\"type\":\"key\",\"attributes\":[\"resource\",\"event\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"index-time\",\"type\":\"key\",\"attributes\":[\"time\"],\"lengths\":[],\"orders\":[\"DESC\"]}]',	1),
(2,	'databases',	'2025-08-19 13:41:37.539',	'2025-08-19 13:41:37.539',	'[\"create(\\\"any\\\")\"]',	'databases',	'[{\"$id\":\"name\",\"type\":\"string\",\"size\":256,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[]},{\"$id\":\"enabled\",\"type\":\"boolean\",\"signed\":true,\"size\":0,\"format\":\"\",\"filters\":[],\"required\":false,\"default\":true,\"array\":false},{\"$id\":\"search\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"originalId\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"default\":null,\"array\":false}]',	'[{\"$id\":\"_fulltext_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_name\",\"type\":\"key\",\"attributes\":[\"name\"],\"lengths\":[null],\"orders\":[\"ASC\"]}]',	1),
(3,	'attributes',	'2025-08-19 13:41:37.596',	'2025-08-19 13:41:37.596',	'[\"create(\\\"any\\\")\"]',	'attributes',	'[{\"$id\":\"databaseInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"databaseId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":false,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"collectionInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"collectionId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"key\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"type\",\"type\":\"string\",\"format\":\"\",\"size\":256,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"status\",\"type\":\"string\",\"format\":\"\",\"size\":16,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"error\",\"type\":\"string\",\"format\":\"\",\"size\":2048,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"size\",\"type\":\"integer\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"required\",\"type\":\"boolean\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"default\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"casting\"]},{\"$id\":\"signed\",\"type\":\"boolean\",\"size\":0,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"array\",\"type\":\"boolean\",\"size\":0,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"format\",\"type\":\"string\",\"size\":64,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"formatOptions\",\"type\":\"string\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":{},\"array\":false,\"filters\":[\"json\",\"range\",\"enum\"]},{\"$id\":\"filters\",\"type\":\"string\",\"size\":64,\"signed\":true,\"required\":false,\"default\":null,\"array\":true,\"filters\":[]},{\"$id\":\"options\",\"type\":\"string\",\"size\":16384,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"json\"]}]',	'[{\"$id\":\"_key_db_collection\",\"type\":\"key\",\"attributes\":[\"databaseInternalId\",\"collectionInternalId\"],\"lengths\":[null,null],\"orders\":[\"ASC\",\"ASC\"]}]',	1),
(4,	'indexes',	'2025-08-19 13:41:37.654',	'2025-08-19 13:41:37.654',	'[\"create(\\\"any\\\")\"]',	'indexes',	'[{\"$id\":\"databaseInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"databaseId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":false,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"collectionInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"collectionId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"key\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"type\",\"type\":\"string\",\"format\":\"\",\"size\":16,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"status\",\"type\":\"string\",\"format\":\"\",\"size\":16,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"error\",\"type\":\"string\",\"format\":\"\",\"size\":2048,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"attributes\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":true,\"filters\":[]},{\"$id\":\"lengths\",\"type\":\"integer\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":null,\"array\":true,\"filters\":[]},{\"$id\":\"orders\",\"type\":\"string\",\"format\":\"\",\"size\":4,\"signed\":true,\"required\":false,\"default\":null,\"array\":true,\"filters\":[]}]',	'[{\"$id\":\"_key_db_collection\",\"type\":\"key\",\"attributes\":[\"databaseInternalId\",\"collectionInternalId\"],\"lengths\":[null,null],\"orders\":[\"ASC\",\"ASC\"]}]',	1),
(5,	'functions',	'2025-08-19 13:41:37.758',	'2025-08-19 13:41:37.758',	'[\"create(\\\"any\\\")\"]',	'functions',	'[{\"$id\":\"execute\",\"type\":\"string\",\"format\":\"\",\"size\":128,\"signed\":true,\"required\":false,\"default\":null,\"array\":true,\"filters\":[]},{\"$id\":\"name\",\"type\":\"string\",\"format\":\"\",\"size\":2048,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"enabled\",\"type\":\"boolean\",\"signed\":true,\"size\":0,\"format\":\"\",\"filters\":[],\"required\":true,\"array\":false},{\"$id\":\"live\",\"type\":\"boolean\",\"signed\":true,\"size\":0,\"format\":\"\",\"filters\":[],\"required\":true,\"array\":false},{\"$id\":\"installationId\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"installationInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"providerRepositoryId\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"repositoryId\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"repositoryInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"providerBranch\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"providerRootDirectory\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"providerSilentMode\",\"type\":\"boolean\",\"signed\":true,\"size\":0,\"format\":\"\",\"filters\":[],\"required\":false,\"default\":false,\"array\":false},{\"$id\":\"logging\",\"type\":\"boolean\",\"signed\":true,\"size\":0,\"format\":\"\",\"filters\":[],\"required\":true,\"array\":false},{\"$id\":\"runtime\",\"type\":\"string\",\"format\":\"\",\"size\":2048,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"deploymentInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"deploymentId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"deploymentCreatedAt\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"latestDeploymentId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"latestDeploymentInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"latestDeploymentCreatedAt\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"latestDeploymentStatus\",\"type\":\"string\",\"format\":\"\",\"size\":16,\"signed\":true,\"required\":false,\"default\":\"\",\"array\":false,\"filters\":[]},{\"$id\":\"vars\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"subQueryVariables\"]},{\"$id\":\"varsProject\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"subQueryProjectVariables\"]},{\"$id\":\"events\",\"type\":\"string\",\"format\":\"\",\"size\":256,\"signed\":true,\"required\":false,\"default\":null,\"array\":true,\"filters\":[]},{\"$id\":\"scheduleInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"scheduleId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"schedule\",\"type\":\"string\",\"format\":\"\",\"size\":128,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"timeout\",\"type\":\"integer\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"search\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"version\",\"type\":\"string\",\"format\":\"\",\"size\":8,\"signed\":true,\"required\":false,\"default\":\"v5\",\"array\":false,\"filters\":[]},{\"array\":false,\"$id\":\"entrypoint\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"filters\":[]},{\"array\":false,\"$id\":\"commands\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"filters\":[]},{\"array\":false,\"$id\":\"specification\",\"type\":\"string\",\"format\":\"\",\"size\":128,\"signed\":false,\"required\":false,\"default\":\"s-1vcpu-512mb\",\"filters\":[]},{\"$id\":\"scopes\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":[],\"array\":true,\"filters\":[]}]',	'[{\"$id\":\"_key_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_name\",\"type\":\"key\",\"attributes\":[\"name\"],\"lengths\":[256],\"orders\":[\"ASC\"]},{\"$id\":\"_key_enabled\",\"type\":\"key\",\"attributes\":[\"enabled\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_installationId\",\"type\":\"key\",\"attributes\":[\"installationId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_installationInternalId\",\"type\":\"key\",\"attributes\":[\"installationInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_providerRepositoryId\",\"type\":\"key\",\"attributes\":[\"providerRepositoryId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_repositoryId\",\"type\":\"key\",\"attributes\":[\"repositoryId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_repositoryInternalId\",\"type\":\"key\",\"attributes\":[\"repositoryInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_runtime\",\"type\":\"key\",\"attributes\":[\"runtime\"],\"lengths\":[64],\"orders\":[\"ASC\"]},{\"$id\":\"_key_deploymentId\",\"type\":\"key\",\"attributes\":[\"deploymentId\"],\"lengths\":[],\"orders\":[\"ASC\"]}]',	1),
(6,	'sites',	'2025-08-19 13:41:37.856',	'2025-08-19 13:41:37.856',	'[\"create(\\\"any\\\")\"]',	'sites',	'[{\"$id\":\"name\",\"type\":\"string\",\"format\":\"\",\"size\":2048,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"enabled\",\"type\":\"boolean\",\"signed\":true,\"size\":0,\"format\":\"\",\"filters\":[],\"required\":true,\"array\":false},{\"$id\":\"live\",\"type\":\"boolean\",\"signed\":true,\"size\":0,\"format\":\"\",\"filters\":[],\"required\":true,\"array\":false},{\"$id\":\"installationId\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"installationInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"providerRepositoryId\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"repositoryId\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"repositoryInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"providerBranch\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"providerRootDirectory\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"providerSilentMode\",\"type\":\"boolean\",\"signed\":true,\"size\":0,\"format\":\"\",\"filters\":[],\"required\":false,\"default\":false,\"array\":false},{\"$id\":\"logging\",\"type\":\"boolean\",\"signed\":true,\"size\":0,\"format\":\"\",\"filters\":[],\"required\":true,\"array\":false},{\"$id\":\"framework\",\"type\":\"string\",\"format\":\"\",\"size\":2048,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"array\":false,\"$id\":\"outputDirectory\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"filters\":[]},{\"array\":false,\"$id\":\"buildCommand\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"filters\":[]},{\"array\":false,\"$id\":\"installCommand\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"filters\":[]},{\"$id\":\"fallbackFile\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"deploymentInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"deploymentId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"deploymentCreatedAt\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"deploymentScreenshotLight\",\"type\":\"string\",\"format\":\"\",\"size\":32,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"deploymentScreenshotDark\",\"type\":\"string\",\"format\":\"\",\"size\":32,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"latestDeploymentId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"latestDeploymentInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"latestDeploymentCreatedAt\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"latestDeploymentStatus\",\"type\":\"string\",\"format\":\"\",\"size\":16,\"signed\":true,\"required\":false,\"default\":\"\",\"array\":false,\"filters\":[]},{\"$id\":\"vars\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"subQueryVariables\"]},{\"$id\":\"varsProject\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"subQueryProjectVariables\"]},{\"$id\":\"timeout\",\"type\":\"integer\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"search\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"array\":false,\"$id\":\"specification\",\"type\":\"string\",\"format\":\"\",\"size\":128,\"signed\":false,\"required\":false,\"default\":\"s-1vcpu-512mb\",\"filters\":[]},{\"$id\":\"buildRuntime\",\"type\":\"string\",\"format\":\"\",\"size\":2048,\"signed\":true,\"required\":true,\"default\":\"\",\"array\":false,\"filters\":[]},{\"$id\":\"adapter\",\"type\":\"string\",\"format\":\"\",\"size\":16,\"signed\":true,\"required\":false,\"default\":\"\",\"array\":false,\"filters\":[]}]',	'[{\"$id\":\"_key_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_name\",\"type\":\"key\",\"attributes\":[\"name\"],\"lengths\":[256],\"orders\":[\"ASC\"]},{\"$id\":\"_key_enabled\",\"type\":\"key\",\"attributes\":[\"enabled\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_installationId\",\"type\":\"key\",\"attributes\":[\"installationId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_installationInternalId\",\"type\":\"key\",\"attributes\":[\"installationInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_providerRepositoryId\",\"type\":\"key\",\"attributes\":[\"providerRepositoryId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_repositoryId\",\"type\":\"key\",\"attributes\":[\"repositoryId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_repositoryInternalId\",\"type\":\"key\",\"attributes\":[\"repositoryInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_framework\",\"type\":\"key\",\"attributes\":[\"framework\"],\"lengths\":[64],\"orders\":[\"ASC\"]},{\"$id\":\"_key_deploymentId\",\"type\":\"key\",\"attributes\":[\"deploymentId\"],\"lengths\":[],\"orders\":[\"ASC\"]}]',	1),
(7,	'deployments',	'2025-08-19 13:41:37.937',	'2025-08-19 13:41:37.937',	'[\"create(\\\"any\\\")\"]',	'deployments',	'[{\"$id\":\"resourceInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"resourceId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"resourceType\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"array\":false,\"$id\":\"entrypoint\",\"type\":\"string\",\"format\":\"\",\"size\":2048,\"signed\":true,\"required\":false,\"default\":null,\"filters\":[]},{\"array\":false,\"$id\":\"buildCommands\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"filters\":[]},{\"array\":false,\"$id\":\"buildOutput\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"filters\":[]},{\"$id\":\"sourcePath\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"type\",\"type\":\"string\",\"format\":\"\",\"size\":2048,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"installationId\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"installationInternalId\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"providerRepositoryId\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"repositoryId\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"repositoryInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"providerRepositoryName\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"providerRepositoryOwner\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"providerRepositoryUrl\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"providerCommitHash\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"providerCommitAuthorUrl\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"providerCommitAuthor\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"providerCommitMessage\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"providerCommitUrl\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"providerBranch\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"providerBranchUrl\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"providerRootDirectory\",\"type\":\"string\",\"signed\":true,\"size\":255,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"providerCommentId\",\"type\":\"string\",\"signed\":true,\"size\":2048,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"sourceSize\",\"type\":\"integer\",\"format\":\"\",\"size\":8,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"sourceMetadata\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"json\"]},{\"$id\":\"sourceChunksTotal\",\"type\":\"integer\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"sourceChunksUploaded\",\"type\":\"integer\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"activate\",\"type\":\"boolean\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":false,\"array\":false,\"filters\":[]},{\"$id\":\"screenshotLight\",\"type\":\"string\",\"format\":\"\",\"size\":32,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"screenshotDark\",\"type\":\"string\",\"format\":\"\",\"size\":32,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"buildStartedAt\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"buildEndedAt\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"buildDuration\",\"type\":\"integer\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"buildSize\",\"type\":\"integer\",\"format\":\"\",\"size\":8,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"totalSize\",\"type\":\"integer\",\"format\":\"\",\"size\":8,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"status\",\"type\":\"string\",\"format\":\"\",\"size\":16,\"signed\":true,\"required\":false,\"default\":\"waiting\",\"array\":false,\"filters\":[]},{\"$id\":\"buildPath\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":\"\",\"array\":false,\"filters\":[]},{\"$id\":\"buildLogs\",\"type\":\"string\",\"format\":\"\",\"size\":1000000,\"signed\":true,\"required\":false,\"default\":\"\",\"array\":false,\"filters\":[]},{\"$id\":\"adapter\",\"type\":\"string\",\"format\":\"\",\"size\":16,\"signed\":true,\"required\":false,\"default\":\"\",\"array\":false,\"filters\":[]},{\"$id\":\"fallbackFile\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]}]',	'[{\"$id\":\"_key_resource\",\"type\":\"key\",\"attributes\":[\"resourceId\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_resource_type\",\"type\":\"key\",\"attributes\":[\"resourceType\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_sourceSize\",\"type\":\"key\",\"attributes\":[\"sourceSize\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_buildSize\",\"type\":\"key\",\"attributes\":[\"buildSize\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_totalSize\",\"type\":\"key\",\"attributes\":[\"totalSize\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_buildDuration\",\"type\":\"key\",\"attributes\":[\"buildDuration\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_activate\",\"type\":\"key\",\"attributes\":[\"activate\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_type\",\"type\":\"key\",\"attributes\":[\"type\"],\"lengths\":[32],\"orders\":[\"ASC\"]},{\"$id\":\"_key_status\",\"type\":\"key\",\"attributes\":[\"status\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_resourceId_resourceType\",\"type\":\"key\",\"attributes\":[\"resourceId\",\"resourceType\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_resource_internal_id\",\"type\":\"key\",\"attributes\":[\"resourceInternalId\"],\"lengths\":[],\"orders\":[]}]',	1),
(8,	'executions',	'2025-08-19 13:41:38.010',	'2025-08-19 13:41:38.010',	'[\"create(\\\"any\\\")\"]',	'executions',	'[{\"$id\":\"resourceInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"resourceId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"resourceType\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"deploymentInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"deploymentId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"array\":false,\"$id\":\"trigger\",\"type\":\"string\",\"format\":\"\",\"size\":128,\"signed\":true,\"required\":false,\"default\":null,\"filters\":[]},{\"$id\":\"status\",\"type\":\"string\",\"format\":\"\",\"size\":128,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"duration\",\"type\":\"double\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"errors\",\"type\":\"string\",\"format\":\"\",\"size\":1000000,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"logs\",\"type\":\"string\",\"format\":\"\",\"size\":1000000,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"array\":false,\"$id\":\"requestMethod\",\"type\":\"string\",\"format\":\"\",\"size\":128,\"signed\":true,\"required\":false,\"default\":null,\"filters\":[]},{\"array\":false,\"$id\":\"requestPath\",\"type\":\"string\",\"format\":\"\",\"size\":2048,\"signed\":true,\"required\":false,\"default\":null,\"filters\":[]},{\"$id\":\"requestHeaders\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"json\"]},{\"$id\":\"responseStatusCode\",\"type\":\"integer\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"responseHeaders\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"json\"]},{\"$id\":\"scheduledAt\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"scheduleInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"scheduleId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]}]',	'[{\"$id\":\"_key_resource\",\"type\":\"key\",\"attributes\":[\"resourceInternalId\",\"resourceType\",\"resourceId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_trigger\",\"type\":\"key\",\"attributes\":[\"trigger\"],\"lengths\":[32],\"orders\":[\"ASC\"]},{\"$id\":\"_key_status\",\"type\":\"key\",\"attributes\":[\"status\"],\"lengths\":[32],\"orders\":[\"ASC\"]},{\"$id\":\"_key_requestMethod\",\"type\":\"key\",\"attributes\":[\"requestMethod\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_requestPath\",\"type\":\"key\",\"attributes\":[\"requestPath\"],\"lengths\":[255],\"orders\":[\"ASC\"]},{\"$id\":\"_key_deployment\",\"type\":\"key\",\"attributes\":[\"deploymentId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_responseStatusCode\",\"type\":\"key\",\"attributes\":[\"responseStatusCode\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_duration\",\"type\":\"key\",\"attributes\":[\"duration\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_function_internal_id\",\"type\":\"key\",\"attributes\":[\"resourceInternalId\"],\"lengths\":[],\"orders\":[]}]',	1),
(9,	'variables',	'2025-08-19 13:41:38.098',	'2025-08-19 13:41:38.098',	'[\"create(\\\"any\\\")\"]',	'variables',	'[{\"$id\":\"resourceType\",\"type\":\"string\",\"format\":\"\",\"size\":100,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"resourceInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"resourceId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"key\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"value\",\"type\":\"string\",\"format\":\"\",\"size\":8192,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[\"encrypt\"]},{\"$id\":\"secret\",\"type\":\"boolean\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":false,\"array\":false,\"filters\":[]},{\"$id\":\"search\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]}]',	'[{\"$id\":\"_key_resourceInternalId\",\"type\":\"key\",\"attributes\":[\"resourceInternalId\"],\"lengths\":[null],\"orders\":[]},{\"$id\":\"_key_resourceType\",\"type\":\"key\",\"attributes\":[\"resourceType\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_resourceId_resourceType\",\"type\":\"key\",\"attributes\":[\"resourceId\",\"resourceType\"],\"lengths\":[null,null],\"orders\":[\"ASC\",\"ASC\"]},{\"$id\":\"_key_uniqueKey\",\"type\":\"unique\",\"attributes\":[\"resourceId\",\"key\",\"resourceType\"],\"lengths\":[null,null,null],\"orders\":[\"ASC\",\"ASC\",\"ASC\"]},{\"$id\":\"_key_key\",\"type\":\"key\",\"attributes\":[\"key\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_fulltext_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_resource_internal_id_resource_type\",\"type\":\"key\",\"attributes\":[\"resourceInternalId\",\"resourceType\"],\"lengths\":[],\"orders\":[]}]',	1),
(10,	'migrations',	'2025-08-19 13:41:38.184',	'2025-08-19 13:41:38.184',	'[\"create(\\\"any\\\")\"]',	'migrations',	'[{\"$id\":\"status\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"stage\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"source\",\"type\":\"string\",\"format\":\"\",\"size\":8192,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"destination\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"credentials\",\"type\":\"string\",\"format\":\"\",\"size\":65536,\"signed\":true,\"required\":false,\"default\":[],\"array\":false,\"filters\":[\"json\",\"encrypt\"]},{\"$id\":\"options\",\"type\":\"string\",\"format\":\"\",\"size\":65536,\"signed\":true,\"required\":false,\"default\":[],\"array\":false,\"filters\":[\"json\"]},{\"$id\":\"resources\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":[],\"array\":true,\"filters\":[]},{\"$id\":\"statusCounters\",\"type\":\"string\",\"format\":\"\",\"size\":3000,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[\"json\"]},{\"$id\":\"resourceData\",\"type\":\"string\",\"format\":\"\",\"size\":131070,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[\"json\"]},{\"$id\":\"errors\",\"type\":\"string\",\"format\":\"\",\"size\":65535,\"signed\":true,\"required\":true,\"default\":null,\"array\":true,\"filters\":[]},{\"$id\":\"search\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"resourceId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"resourceType\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]}]',	'[{\"$id\":\"_key_status\",\"type\":\"key\",\"attributes\":[\"status\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_stage\",\"type\":\"key\",\"attributes\":[\"stage\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_source\",\"type\":\"key\",\"attributes\":[\"source\"],\"lengths\":[255],\"orders\":[\"ASC\"]},{\"$id\":\"_key_resource_id\",\"type\":\"key\",\"attributes\":[\"resourceId\"],\"lengths\":[null],\"orders\":[\"DESC\"]},{\"$id\":\"_fulltext_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]}]',	1),
(11,	'resourceTokens',	'2025-08-19 13:41:38.244',	'2025-08-19 13:41:38.244',	'[\"create(\\\"any\\\")\"]',	'resourceTokens',	'[{\"$id\":\"resourceId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"resourceInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"resourceType\",\"type\":\"string\",\"format\":\"\",\"size\":100,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"secret\",\"type\":\"string\",\"format\":\"\",\"size\":512,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[\"encrypt\"]},{\"$id\":\"expire\",\"type\":\"datetime\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"accessedAt\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]}]',	'[{\"$id\":\"_key_expiry_date\",\"type\":\"key\",\"attributes\":[\"expire\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_accessedAt\",\"type\":\"key\",\"attributes\":[\"accessedAt\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_resourceInternalId_resourceType\",\"type\":\"key\",\"attributes\":[\"resourceInternalId\",\"resourceType\"],\"lengths\":[],\"orders\":[]}]',	1),
(12,	'cache',	'2025-08-19 13:41:38.304',	'2025-08-19 13:41:38.304',	'[\"create(\\\"any\\\")\"]',	'cache',	'[{\"$id\":\"resource\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"resourceType\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"mimeType\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"accessedAt\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"signature\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]}]',	'[{\"$id\":\"_key_accessedAt\",\"type\":\"key\",\"attributes\":[\"accessedAt\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_resource\",\"type\":\"key\",\"attributes\":[\"resource\"],\"lengths\":[],\"orders\":[]}]',	1),
(13,	'users',	'2025-08-19 13:41:38.401',	'2025-08-19 13:41:38.401',	'[\"create(\\\"any\\\")\"]',	'users',	'[{\"$id\":\"name\",\"type\":\"string\",\"format\":\"\",\"size\":256,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"email\",\"type\":\"string\",\"format\":\"\",\"size\":320,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"phone\",\"type\":\"string\",\"format\":\"\",\"size\":16,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"status\",\"type\":\"boolean\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"labels\",\"type\":\"string\",\"format\":\"\",\"size\":128,\"signed\":true,\"required\":false,\"default\":null,\"array\":true,\"filters\":[]},{\"$id\":\"passwordHistory\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":true,\"filters\":[]},{\"$id\":\"password\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"encrypt\"]},{\"$id\":\"hash\",\"type\":\"string\",\"format\":\"\",\"size\":256,\"signed\":true,\"required\":false,\"default\":\"argon2\",\"array\":false,\"filters\":[]},{\"$id\":\"hashOptions\",\"type\":\"string\",\"format\":\"\",\"size\":65535,\"signed\":true,\"required\":false,\"default\":{\"type\":\"argon2\",\"memoryCost\":2048,\"timeCost\":4,\"threads\":3},\"array\":false,\"filters\":[\"json\"]},{\"$id\":\"passwordUpdate\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"prefs\",\"type\":\"string\",\"format\":\"\",\"size\":65535,\"signed\":true,\"required\":false,\"default\":{},\"array\":false,\"filters\":[\"json\"]},{\"$id\":\"registration\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"emailVerification\",\"type\":\"boolean\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"phoneVerification\",\"type\":\"boolean\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"reset\",\"type\":\"boolean\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"mfa\",\"type\":\"boolean\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"mfaRecoveryCodes\",\"type\":\"string\",\"format\":\"\",\"size\":256,\"signed\":true,\"required\":false,\"default\":[],\"array\":true,\"filters\":[\"encrypt\"]},{\"$id\":\"authenticators\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"subQueryAuthenticators\"]},{\"$id\":\"sessions\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"subQuerySessions\"]},{\"$id\":\"tokens\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"subQueryTokens\"]},{\"$id\":\"challenges\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"subQueryChallenges\"]},{\"$id\":\"memberships\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"subQueryMemberships\"]},{\"$id\":\"targets\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"subQueryTargets\"]},{\"$id\":\"search\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"userSearch\"]},{\"$id\":\"accessedAt\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]}]',	'[{\"$id\":\"_key_name\",\"type\":\"key\",\"attributes\":[\"name\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_email\",\"type\":\"unique\",\"attributes\":[\"email\"],\"lengths\":[256],\"orders\":[\"ASC\"]},{\"$id\":\"_key_phone\",\"type\":\"unique\",\"attributes\":[\"phone\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_status\",\"type\":\"key\",\"attributes\":[\"status\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_passwordUpdate\",\"type\":\"key\",\"attributes\":[\"passwordUpdate\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_registration\",\"type\":\"key\",\"attributes\":[\"registration\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_emailVerification\",\"type\":\"key\",\"attributes\":[\"emailVerification\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_phoneVerification\",\"type\":\"key\",\"attributes\":[\"phoneVerification\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_accessedAt\",\"type\":\"key\",\"attributes\":[\"accessedAt\"],\"lengths\":[],\"orders\":[]}]',	1),
(14,	'tokens',	'2025-08-19 13:41:38.465',	'2025-08-19 13:41:38.465',	'[\"create(\\\"any\\\")\"]',	'tokens',	'[{\"$id\":\"userInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"userId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"type\",\"type\":\"integer\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"secret\",\"type\":\"string\",\"format\":\"\",\"size\":512,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"encrypt\"]},{\"$id\":\"expire\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"userAgent\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"ip\",\"type\":\"string\",\"format\":\"\",\"size\":45,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]}]',	'[{\"$id\":\"_key_user\",\"type\":\"key\",\"attributes\":[\"userInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]}]',	1),
(15,	'authenticators',	'2025-08-19 13:41:38.516',	'2025-08-19 13:41:38.516',	'[\"create(\\\"any\\\")\"]',	'authenticators',	'[{\"$id\":\"userInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"userId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"type\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"verified\",\"type\":\"boolean\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":false,\"array\":false,\"filters\":[]},{\"$id\":\"data\",\"type\":\"string\",\"format\":\"\",\"size\":65535,\"signed\":true,\"required\":false,\"default\":[],\"array\":false,\"filters\":[\"json\",\"encrypt\"]}]',	'[{\"$id\":\"_key_userInternalId\",\"type\":\"key\",\"attributes\":[\"userInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]}]',	1),
(16,	'challenges',	'2025-08-19 13:41:38.564',	'2025-08-19 13:41:38.564',	'[\"create(\\\"any\\\")\"]',	'challenges',	'[{\"$id\":\"userInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"userId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"type\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"token\",\"type\":\"string\",\"format\":\"\",\"size\":512,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"encrypt\"]},{\"$id\":\"code\",\"type\":\"string\",\"format\":\"\",\"size\":512,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"encrypt\"]},{\"$id\":\"expire\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]}]',	'[{\"$id\":\"_key_user\",\"type\":\"key\",\"attributes\":[\"userInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]}]',	1),
(17,	'sessions',	'2025-08-19 13:41:38.620',	'2025-08-19 13:41:38.620',	'[\"create(\\\"any\\\")\"]',	'sessions',	'[{\"$id\":\"userInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"userId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"provider\",\"type\":\"string\",\"format\":\"\",\"size\":128,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"providerUid\",\"type\":\"string\",\"format\":\"\",\"size\":2048,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"providerAccessToken\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"encrypt\"]},{\"$id\":\"providerAccessTokenExpiry\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"providerRefreshToken\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"encrypt\"]},{\"$id\":\"secret\",\"type\":\"string\",\"format\":\"\",\"size\":512,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"encrypt\"]},{\"$id\":\"userAgent\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"ip\",\"type\":\"string\",\"format\":\"\",\"size\":45,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"countryCode\",\"type\":\"string\",\"format\":\"\",\"size\":2,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"osCode\",\"type\":\"string\",\"format\":\"\",\"size\":256,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"osName\",\"type\":\"string\",\"format\":\"\",\"size\":256,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"osVersion\",\"type\":\"string\",\"format\":\"\",\"size\":256,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"clientType\",\"type\":\"string\",\"format\":\"\",\"size\":256,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"clientCode\",\"type\":\"string\",\"format\":\"\",\"size\":256,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"clientName\",\"type\":\"string\",\"format\":\"\",\"size\":256,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"clientVersion\",\"type\":\"string\",\"format\":\"\",\"size\":256,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"clientEngine\",\"type\":\"string\",\"format\":\"\",\"size\":256,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"clientEngineVersion\",\"type\":\"string\",\"format\":\"\",\"size\":256,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"deviceName\",\"type\":\"string\",\"format\":\"\",\"size\":256,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"deviceBrand\",\"type\":\"string\",\"format\":\"\",\"size\":256,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"deviceModel\",\"type\":\"string\",\"format\":\"\",\"size\":256,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"factors\",\"type\":\"string\",\"format\":\"\",\"size\":256,\"signed\":true,\"required\":false,\"default\":[],\"array\":true,\"filters\":[]},{\"$id\":\"expire\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":true,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"mfaUpdatedAt\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]}]',	'[{\"$id\":\"_key_provider_providerUid\",\"type\":\"key\",\"attributes\":[\"provider\",\"providerUid\"],\"lengths\":[null,128],\"orders\":[\"ASC\",\"ASC\"]},{\"$id\":\"_key_user\",\"type\":\"key\",\"attributes\":[\"userInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]}]',	1),
(18,	'identities',	'2025-08-19 13:41:38.689',	'2025-08-19 13:41:38.689',	'[\"create(\\\"any\\\")\"]',	'identities',	'[{\"$id\":\"userInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"userId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"provider\",\"type\":\"string\",\"format\":\"\",\"size\":128,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"providerUid\",\"type\":\"string\",\"format\":\"\",\"size\":2048,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"providerEmail\",\"type\":\"string\",\"format\":\"\",\"size\":320,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"providerAccessToken\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"encrypt\"]},{\"$id\":\"providerAccessTokenExpiry\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"providerRefreshToken\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"encrypt\"]},{\"$id\":\"secrets\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":[],\"array\":false,\"filters\":[\"json\",\"encrypt\"]},{\"$id\":\"scopes\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":true,\"filters\":[]},{\"$id\":\"expire\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"required\":false,\"signed\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]}]',	'[{\"$id\":\"_key_userInternalId_provider_providerUid\",\"type\":\"unique\",\"attributes\":[\"userInternalId\",\"provider\",\"providerUid\"],\"lengths\":[11,null,128],\"orders\":[\"ASC\",\"ASC\"]},{\"$id\":\"_key_provider_providerUid\",\"type\":\"unique\",\"attributes\":[\"provider\",\"providerUid\"],\"lengths\":[null,128],\"orders\":[\"ASC\",\"ASC\"]},{\"$id\":\"_key_userId\",\"type\":\"key\",\"attributes\":[\"userId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_userInternalId\",\"type\":\"key\",\"attributes\":[\"userInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_provider\",\"type\":\"key\",\"attributes\":[\"provider\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_providerUid\",\"type\":\"key\",\"attributes\":[\"providerUid\"],\"lengths\":[255],\"orders\":[\"ASC\"]},{\"$id\":\"_key_providerEmail\",\"type\":\"key\",\"attributes\":[\"providerEmail\"],\"lengths\":[255],\"orders\":[\"ASC\"]},{\"$id\":\"_key_providerAccessTokenExpiry\",\"type\":\"key\",\"attributes\":[\"providerAccessTokenExpiry\"],\"lengths\":[],\"orders\":[\"ASC\"]}]',	1),
(19,	'teams',	'2025-08-19 13:41:38.774',	'2025-08-19 13:41:38.774',	'[\"create(\\\"any\\\")\"]',	'teams',	'[{\"$id\":\"name\",\"type\":\"string\",\"format\":\"\",\"size\":128,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"total\",\"type\":\"integer\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"search\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"prefs\",\"type\":\"string\",\"format\":\"\",\"size\":65535,\"signed\":true,\"required\":false,\"default\":{},\"array\":false,\"filters\":[\"json\"]}]',	'[{\"$id\":\"_key_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_name\",\"type\":\"key\",\"attributes\":[\"name\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_total\",\"type\":\"key\",\"attributes\":[\"total\"],\"lengths\":[],\"orders\":[\"ASC\"]}]',	1),
(20,	'memberships',	'2025-08-19 13:41:38.865',	'2025-08-19 13:41:38.865',	'[\"create(\\\"any\\\")\"]',	'memberships',	'[{\"$id\":\"userInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"userId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"teamInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"teamId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"roles\",\"type\":\"string\",\"format\":\"\",\"size\":128,\"signed\":true,\"required\":false,\"default\":null,\"array\":true,\"filters\":[]},{\"$id\":\"invited\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"joined\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"confirm\",\"type\":\"boolean\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"secret\",\"type\":\"string\",\"format\":\"\",\"size\":256,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"encrypt\"]},{\"$id\":\"search\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]}]',	'[{\"$id\":\"_key_unique\",\"type\":\"unique\",\"attributes\":[\"teamInternalId\",\"userInternalId\"],\"lengths\":[null,null],\"orders\":[\"ASC\",\"ASC\"]},{\"$id\":\"_key_user\",\"type\":\"key\",\"attributes\":[\"userInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_team\",\"type\":\"key\",\"attributes\":[\"teamInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_userId\",\"type\":\"key\",\"attributes\":[\"userId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_teamId\",\"type\":\"key\",\"attributes\":[\"teamId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_invited\",\"type\":\"key\",\"attributes\":[\"invited\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_joined\",\"type\":\"key\",\"attributes\":[\"joined\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_confirm\",\"type\":\"key\",\"attributes\":[\"confirm\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_roles\",\"type\":\"key\",\"attributes\":[\"roles\"],\"lengths\":[255],\"orders\":[null]}]',	1),
(21,	'buckets',	'2025-08-19 13:41:38.962',	'2025-08-19 13:41:38.962',	'[\"create(\\\"any\\\")\"]',	'buckets',	'[{\"$id\":\"enabled\",\"type\":\"boolean\",\"signed\":true,\"size\":0,\"format\":\"\",\"filters\":[],\"required\":true,\"array\":false},{\"$id\":\"name\",\"type\":\"string\",\"signed\":true,\"size\":128,\"format\":\"\",\"filters\":[],\"required\":true,\"array\":false},{\"$id\":\"fileSecurity\",\"type\":\"boolean\",\"signed\":true,\"size\":1,\"format\":\"\",\"filters\":[],\"required\":false,\"array\":false},{\"$id\":\"maximumFileSize\",\"type\":\"integer\",\"signed\":false,\"size\":8,\"format\":\"\",\"filters\":[],\"required\":true,\"array\":false},{\"$id\":\"allowedFileExtensions\",\"type\":\"string\",\"signed\":true,\"size\":64,\"format\":\"\",\"filters\":[],\"required\":true,\"array\":true},{\"$id\":\"compression\",\"type\":\"string\",\"signed\":true,\"size\":10,\"format\":\"\",\"filters\":[],\"required\":true,\"array\":false},{\"$id\":\"encryption\",\"type\":\"boolean\",\"signed\":true,\"size\":0,\"format\":\"\",\"filters\":[],\"required\":true,\"array\":false},{\"$id\":\"antivirus\",\"type\":\"boolean\",\"signed\":true,\"size\":0,\"format\":\"\",\"filters\":[],\"required\":true,\"array\":false},{\"$id\":\"search\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]}]',	'[{\"$id\":\"_fulltext_name\",\"type\":\"fulltext\",\"attributes\":[\"name\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_enabled\",\"type\":\"key\",\"attributes\":[\"enabled\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_name\",\"type\":\"key\",\"attributes\":[\"name\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_fileSecurity\",\"type\":\"key\",\"attributes\":[\"fileSecurity\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_maximumFileSize\",\"type\":\"key\",\"attributes\":[\"maximumFileSize\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_encryption\",\"type\":\"key\",\"attributes\":[\"encryption\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_antivirus\",\"type\":\"key\",\"attributes\":[\"antivirus\"],\"lengths\":[],\"orders\":[\"ASC\"]}]',	1),
(22,	'stats',	'2025-08-19 13:41:39.022',	'2025-08-19 13:41:39.022',	'[\"create(\\\"any\\\")\"]',	'stats',	'[{\"$id\":\"metric\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"region\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"value\",\"type\":\"integer\",\"format\":\"\",\"size\":8,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"time\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"period\",\"type\":\"string\",\"format\":\"\",\"size\":4,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]}]',	'[{\"$id\":\"_key_time\",\"type\":\"key\",\"attributes\":[\"time\"],\"lengths\":[],\"orders\":[\"DESC\"]},{\"$id\":\"_key_period_time\",\"type\":\"key\",\"attributes\":[\"period\",\"time\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_metric_period_time\",\"type\":\"unique\",\"attributes\":[\"metric\",\"period\",\"time\"],\"lengths\":[],\"orders\":[\"DESC\"]}]',	1),
(23,	'providers',	'2025-08-19 13:41:39.113',	'2025-08-19 13:41:39.113',	'[\"create(\\\"any\\\")\"]',	'providers',	'[{\"$id\":\"name\",\"type\":\"string\",\"format\":\"\",\"size\":128,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"provider\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"type\",\"type\":\"string\",\"format\":\"\",\"size\":128,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"enabled\",\"type\":\"boolean\",\"signed\":true,\"size\":0,\"format\":\"\",\"filters\":[],\"required\":true,\"default\":true,\"array\":false},{\"$id\":\"credentials\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[\"json\",\"encrypt\"]},{\"$id\":\"options\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":[],\"array\":false,\"filters\":[\"json\"]},{\"$id\":\"search\",\"type\":\"string\",\"format\":\"\",\"size\":65535,\"signed\":true,\"required\":false,\"default\":\"\",\"array\":false,\"filters\":[\"providerSearch\"]}]',	'[{\"$id\":\"_key_provider\",\"type\":\"key\",\"attributes\":[\"provider\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_name\",\"type\":\"fulltext\",\"attributes\":[\"name\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_type\",\"type\":\"key\",\"attributes\":[\"type\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_enabled_type\",\"type\":\"key\",\"attributes\":[\"enabled\",\"type\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]}]',	1),
(24,	'messages',	'2025-08-19 13:41:39.183',	'2025-08-19 13:41:39.183',	'[\"create(\\\"any\\\")\"]',	'messages',	'[{\"$id\":\"providerType\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"status\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":\"processing\",\"array\":false,\"filters\":[]},{\"$id\":\"data\",\"type\":\"string\",\"format\":\"\",\"size\":65535,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[\"json\"]},{\"$id\":\"topics\",\"type\":\"string\",\"format\":\"\",\"size\":21845,\"signed\":true,\"required\":false,\"default\":[],\"array\":true,\"filters\":[]},{\"$id\":\"users\",\"type\":\"string\",\"format\":\"\",\"size\":21845,\"signed\":true,\"required\":false,\"default\":[],\"array\":true,\"filters\":[]},{\"$id\":\"targets\",\"type\":\"string\",\"format\":\"\",\"size\":21845,\"signed\":true,\"required\":false,\"default\":[],\"array\":true,\"filters\":[]},{\"$id\":\"scheduledAt\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"scheduleInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"scheduleId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"deliveredAt\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":false,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"deliveryErrors\",\"type\":\"string\",\"format\":\"\",\"size\":65535,\"signed\":true,\"required\":false,\"default\":null,\"array\":true,\"filters\":[]},{\"$id\":\"deliveredTotal\",\"type\":\"integer\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":0,\"array\":false,\"filters\":[]},{\"$id\":\"search\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":\"\",\"array\":false,\"filters\":[\"messageSearch\"]}]',	'[{\"$id\":\"_key_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]}]',	1),
(25,	'topics',	'2025-08-19 13:41:39.265',	'2025-08-19 13:41:39.265',	'[\"create(\\\"any\\\")\"]',	'topics',	'[{\"$id\":\"name\",\"type\":\"string\",\"format\":\"\",\"size\":128,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"subscribe\",\"type\":\"string\",\"format\":\"\",\"size\":128,\"signed\":true,\"required\":false,\"default\":null,\"array\":true,\"filters\":[]},{\"$id\":\"emailTotal\",\"type\":\"integer\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":0,\"array\":false,\"filters\":[]},{\"$id\":\"smsTotal\",\"type\":\"integer\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":0,\"array\":false,\"filters\":[]},{\"$id\":\"pushTotal\",\"type\":\"integer\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":0,\"array\":false,\"filters\":[]},{\"$id\":\"targets\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[\"subQueryTopicTargets\"]},{\"$id\":\"search\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":\"\",\"array\":false,\"filters\":[\"topicSearch\"]}]',	'[{\"$id\":\"_key_name\",\"type\":\"fulltext\",\"attributes\":[\"name\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[\"ASC\"]}]',	1),
(26,	'subscribers',	'2025-08-19 13:41:39.352',	'2025-08-19 13:41:39.352',	'[\"create(\\\"any\\\")\"]',	'subscribers',	'[{\"$id\":\"targetId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"targetInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"userId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"userInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"topicId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"topicInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"providerType\",\"type\":\"string\",\"format\":\"\",\"size\":128,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"search\",\"type\":\"string\",\"format\":\"\",\"size\":16384,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]}]',	'[{\"$id\":\"_key_targetId\",\"type\":\"key\",\"attributes\":[\"targetId\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_targetInternalId\",\"type\":\"key\",\"attributes\":[\"targetInternalId\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_userId\",\"type\":\"key\",\"attributes\":[\"userId\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_userInternalId\",\"type\":\"key\",\"attributes\":[\"userInternalId\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_topicId\",\"type\":\"key\",\"attributes\":[\"topicId\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_topicInternalId\",\"type\":\"key\",\"attributes\":[\"topicInternalId\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_unique_target_topic\",\"type\":\"unique\",\"attributes\":[\"targetInternalId\",\"topicInternalId\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_fulltext_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]}]',	1),
(27,	'targets',	'2025-08-19 13:41:39.421',	'2025-08-19 13:41:39.421',	'[\"create(\\\"any\\\")\"]',	'targets',	'[{\"$id\":\"userId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"userInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"sessionId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"sessionInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"providerType\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"providerId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"providerInternalId\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"identifier\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":true,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"name\",\"type\":\"string\",\"format\":\"\",\"size\":255,\"signed\":true,\"required\":false,\"default\":null,\"array\":false,\"filters\":[]},{\"$id\":\"expired\",\"type\":\"boolean\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"default\":false,\"array\":false,\"filters\":[]}]',	'[{\"$id\":\"_key_userId\",\"type\":\"key\",\"attributes\":[\"userId\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_userInternalId\",\"type\":\"key\",\"attributes\":[\"userInternalId\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_providerId\",\"type\":\"key\",\"attributes\":[\"providerId\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_providerInternalId\",\"type\":\"key\",\"attributes\":[\"providerInternalId\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_identifier\",\"type\":\"unique\",\"attributes\":[\"identifier\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_expired\",\"type\":\"key\",\"attributes\":[\"expired\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_session_internal_id\",\"type\":\"key\",\"attributes\":[\"sessionInternalId\"],\"lengths\":[],\"orders\":[]}]',	1);

DROP TABLE IF EXISTS `_1__metadata_perms`;
CREATE TABLE `_1__metadata_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `_1__metadata_perms` (`_id`, `_type`, `_permission`, `_document`) VALUES
(3,	'create',	'any',	'attributes'),
(1,	'create',	'any',	'audit'),
(15,	'create',	'any',	'authenticators'),
(21,	'create',	'any',	'buckets'),
(12,	'create',	'any',	'cache'),
(16,	'create',	'any',	'challenges'),
(2,	'create',	'any',	'databases'),
(7,	'create',	'any',	'deployments'),
(8,	'create',	'any',	'executions'),
(5,	'create',	'any',	'functions'),
(18,	'create',	'any',	'identities'),
(4,	'create',	'any',	'indexes'),
(20,	'create',	'any',	'memberships'),
(24,	'create',	'any',	'messages'),
(10,	'create',	'any',	'migrations'),
(23,	'create',	'any',	'providers'),
(11,	'create',	'any',	'resourceTokens'),
(17,	'create',	'any',	'sessions'),
(6,	'create',	'any',	'sites'),
(22,	'create',	'any',	'stats'),
(26,	'create',	'any',	'subscribers'),
(27,	'create',	'any',	'targets'),
(19,	'create',	'any',	'teams'),
(14,	'create',	'any',	'tokens'),
(25,	'create',	'any',	'topics'),
(13,	'create',	'any',	'users'),
(9,	'create',	'any',	'variables');

DROP TABLE IF EXISTS `_console_audit`;
CREATE TABLE `_console_audit` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `event` varchar(255) DEFAULT NULL,
  `resource` varchar(255) DEFAULT NULL,
  `userAgent` text DEFAULT NULL,
  `ip` varchar(45) DEFAULT NULL,
  `location` varchar(45) DEFAULT NULL,
  `time` datetime(3) DEFAULT NULL,
  `data` longtext DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `index2` (`event`),
  KEY `index4` (`userId`,`event`),
  KEY `index5` (`resource`,`event`),
  KEY `index-time` (`time` DESC),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `_console_audit` (`_id`, `_uid`, `_createdAt`, `_updatedAt`, `_permissions`, `userId`, `event`, `resource`, `userAgent`, `ip`, `location`, `time`, `data`) VALUES
(1,	'68a47f0b1748f2c1dcc8',	'2025-08-19 13:41:31.095',	'2025-08-19 13:41:31.095',	'[]',	'1',	'user.create',	'user/68a47f0a002bba8f8df7',	'Mozilla/5.0 (X11; Linux x86_64; rv:141.0) Gecko/20100101 Firefox/141.0',	'192.168.192.1',	'',	'2025-08-19 13:41:31.000',	'{\"userId\":\"68a47f0a002bba8f8df7\",\"userName\":\"Fuzzer\",\"userEmail\":\"fuzzer@local.co\",\"userType\":\"user\",\"mode\":\"default\",\"data\":{\"$id\":\"68a47f0a002bba8f8df7\",\"$createdAt\":\"2025-08-19T13:41:30.962+00:00\",\"$updatedAt\":\"2025-08-19T13:41:30.962+00:00\",\"name\":\"Fuzzer\",\"registration\":\"2025-08-19T13:41:30.961+00:00\",\"status\":true,\"labels\":[],\"passwordUpdate\":\"2025-08-19T13:41:30.961+00:00\",\"email\":\"fuzzer@local.co\",\"phone\":\"\",\"emailVerification\":false,\"phoneVerification\":false,\"mfa\":false,\"prefs\":[],\"targets\":[{\"$id\":\"68a47f0b0cb00ed13f98\",\"$createdAt\":\"2025-08-19T13:41:31.051+00:00\",\"$updatedAt\":\"2025-08-19T13:41:31.051+00:00\",\"name\":\"\",\"userId\":\"68a47f0a002bba8f8df7\",\"providerId\":null,\"providerType\":\"email\",\"identifier\":\"fuzzer@local.co\",\"expired\":false}],\"accessedAt\":\"2025-08-19T13:41:30.961+00:00\"}}'),
(2,	'68a47f0b5610121e010b',	'2025-08-19 13:41:31.352',	'2025-08-19 13:41:31.352',	'[]',	'1',	'session.create',	'user/68a47f0a002bba8f8df7',	'Mozilla/5.0 (X11; Linux x86_64; rv:141.0) Gecko/20100101 Firefox/141.0',	'192.168.192.1',	'',	'2025-08-19 13:41:31.000',	'{\"userId\":\"68a47f0a002bba8f8df7\",\"userName\":\"Fuzzer\",\"userEmail\":\"fuzzer@local.co\",\"userType\":\"user\",\"mode\":\"default\",\"data\":{\"$id\":\"68a47f0b4126e60b0dac\",\"$createdAt\":\"2025-08-19T13:41:31.328+00:00\",\"$updatedAt\":\"2025-08-19T13:41:31.328+00:00\",\"userId\":\"68a47f0a002bba8f8df7\",\"expire\":\"2026-08-19T13:41:31.266+00:00\",\"provider\":\"email\",\"providerUid\":\"fuzzer@local.co\",\"providerAccessToken\":\"\",\"providerAccessTokenExpiry\":\"\",\"providerRefreshToken\":\"\",\"ip\":\"192.168.192.1\",\"osCode\":\"LIN\",\"osName\":\"GNU\\/Linux\",\"osVersion\":\"\",\"clientType\":\"browser\",\"clientCode\":\"FF\",\"clientName\":\"Firefox\",\"clientVersion\":\"141.0\",\"clientEngine\":\"Gecko\",\"clientEngineVersion\":\"141.0\",\"deviceName\":\"desktop\",\"deviceBrand\":\"\",\"deviceModel\":\"\",\"countryCode\":\"--\",\"countryName\":\"Unknown\",\"current\":true,\"factors\":[\"password\"],\"secret\":\"\",\"mfaUpdatedAt\":\"\"}}'),
(3,	'68a47f0bddea76baa323',	'2025-08-19 13:41:31.908',	'2025-08-19 13:41:31.908',	'[]',	'1',	'team.create',	'team/68a47f0b0035e5179e3b',	'Mozilla/5.0 (X11; Linux x86_64; rv:141.0) Gecko/20100101 Firefox/141.0',	'192.168.192.1',	'',	'2025-08-19 13:41:31.000',	'{\"userId\":\"68a47f0a002bba8f8df7\",\"userName\":\"Fuzzer\",\"userEmail\":\"fuzzer@local.co\",\"userType\":\"user\",\"mode\":\"default\",\"data\":{\"$id\":\"68a47f0b0035e5179e3b\",\"$createdAt\":\"2025-08-19T13:41:31.874+00:00\",\"$updatedAt\":\"2025-08-19T13:41:31.874+00:00\",\"name\":\"Personal projects\",\"total\":1,\"prefs\":[]}}'),
(4,	'68a47f136c0e20406b3d',	'2025-08-19 13:41:39.442',	'2025-08-19 13:41:39.442',	'[]',	'1',	'projects.create',	'project/68a47f110011949a91b0',	'Mozilla/5.0 (X11; Linux x86_64; rv:141.0) Gecko/20100101 Firefox/141.0',	'192.168.192.1',	'',	'2025-08-19 13:41:39.000',	'{\"userId\":\"68a47f0a002bba8f8df7\",\"userName\":\"Fuzzer\",\"userEmail\":\"fuzzer@local.co\",\"userType\":\"user\",\"mode\":\"default\",\"data\":{\"$id\":\"68a47f110011949a91b0\",\"$createdAt\":\"2025-08-19T13:41:37.305+00:00\",\"$updatedAt\":\"2025-08-19T13:41:37.305+00:00\",\"name\":\"Appwrite project\",\"description\":\"\",\"teamId\":\"68a47f0b0035e5179e3b\",\"logo\":\"\",\"url\":\"\",\"legalName\":\"\",\"legalCountry\":\"\",\"legalState\":\"\",\"legalCity\":\"\",\"legalAddress\":\"\",\"legalTaxId\":\"\",\"authDuration\":31536000,\"authLimit\":0,\"authSessionsLimit\":10,\"authPasswordHistory\":0,\"authPasswordDictionary\":false,\"authPersonalDataCheck\":false,\"authMockNumbers\":[],\"authSessionAlerts\":false,\"authMembershipsUserName\":false,\"authMembershipsUserEmail\":false,\"authMembershipsMfa\":false,\"oAuthProviders\":[{\"key\":\"amazon\",\"name\":\"Amazon\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"apple\",\"name\":\"Apple\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"auth0\",\"name\":\"Auth0\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"authentik\",\"name\":\"Authentik\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"autodesk\",\"name\":\"Autodesk\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"bitbucket\",\"name\":\"BitBucket\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"bitly\",\"name\":\"Bitly\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"box\",\"name\":\"Box\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"dailymotion\",\"name\":\"Dailymotion\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"discord\",\"name\":\"Discord\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"disqus\",\"name\":\"Disqus\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"dropbox\",\"name\":\"Dropbox\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"etsy\",\"name\":\"Etsy\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"facebook\",\"name\":\"Facebook\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"figma\",\"name\":\"Figma\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"github\",\"name\":\"GitHub\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"gitlab\",\"name\":\"GitLab\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"google\",\"name\":\"Google\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"linkedin\",\"name\":\"LinkedIn\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"microsoft\",\"name\":\"Microsoft\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"notion\",\"name\":\"Notion\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"oidc\",\"name\":\"OpenID Connect\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"okta\",\"name\":\"Okta\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"paypal\",\"name\":\"PayPal\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"paypalSandbox\",\"name\":\"PayPal Sandbox\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"podio\",\"name\":\"Podio\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"salesforce\",\"name\":\"Salesforce\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"slack\",\"name\":\"Slack\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"spotify\",\"name\":\"Spotify\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"stripe\",\"name\":\"Stripe\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"tradeshift\",\"name\":\"Tradeshift\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"tradeshiftBox\",\"name\":\"Tradeshift Sandbox\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"twitch\",\"name\":\"Twitch\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"wordpress\",\"name\":\"WordPress\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"yahoo\",\"name\":\"Yahoo\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"yammer\",\"name\":\"Yammer\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"yandex\",\"name\":\"Yandex\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"zoho\",\"name\":\"Zoho\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"zoom\",\"name\":\"Zoom\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false},{\"key\":\"mock\",\"name\":\"Mock\",\"appId\":\"\",\"secret\":\"\",\"enabled\":false}],\"platforms\":[],\"webhooks\":[],\"keys\":[],\"devKeys\":[],\"smtpEnabled\":false,\"smtpSenderName\":\"\",\"smtpSenderEmail\":\"\",\"smtpReplyTo\":\"\",\"smtpHost\":\"\",\"smtpPort\":\"\",\"smtpUsername\":\"\",\"smtpPassword\":\"\",\"smtpSecure\":\"\",\"pingCount\":0,\"pingedAt\":\"\",\"authEmailPassword\":true,\"authUsersAuthMagicURL\":true,\"authEmailOtp\":true,\"authAnonymous\":true,\"authInvites\":true,\"authJWT\":true,\"authPhone\":true,\"serviceStatusForAccount\":true,\"serviceStatusForAvatars\":true,\"serviceStatusForDatabases\":true,\"serviceStatusForLocale\":true,\"serviceStatusForHealth\":true,\"serviceStatusForStorage\":true,\"serviceStatusForTeams\":true,\"serviceStatusForUsers\":true,\"serviceStatusForSites\":true,\"serviceStatusForFunctions\":true,\"serviceStatusForGraphql\":true,\"serviceStatusForMessaging\":true}}'),
(5,	'68a47f16ceafa95ba857',	'2025-08-19 13:41:42.846',	'2025-08-19 13:41:42.846',	'[]',	'1',	'user.update',	'user/68a47f0a002bba8f8df7',	'Mozilla/5.0 (X11; Linux x86_64; rv:141.0) Gecko/20100101 Firefox/141.0',	'192.168.192.1',	'',	'2025-08-19 13:41:42.000',	'{\"userId\":\"68a47f0a002bba8f8df7\",\"userName\":\"Fuzzer\",\"userEmail\":\"fuzzer@local.co\",\"userType\":\"user\",\"mode\":\"default\",\"data\":{\"$id\":\"68a47f0a002bba8f8df7\",\"$createdAt\":\"2025-08-19T13:41:30.962+00:00\",\"$updatedAt\":\"2025-08-19T13:41:42.819+00:00\",\"name\":\"Fuzzer\",\"registration\":\"2025-08-19T13:41:30.961+00:00\",\"status\":true,\"labels\":[],\"passwordUpdate\":\"2025-08-19T13:41:30.961+00:00\",\"email\":\"fuzzer@local.co\",\"phone\":\"\",\"emailVerification\":false,\"phoneVerification\":false,\"mfa\":false,\"prefs\":{\"organization\":\"68a47f0b0035e5179e3b\"},\"targets\":[{\"$id\":\"68a47f0b0cb00ed13f98\",\"$createdAt\":\"2025-08-19T13:41:31.051+00:00\",\"$updatedAt\":\"2025-08-19T13:41:31.051+00:00\",\"name\":\"\",\"userId\":\"68a47f0a002bba8f8df7\",\"providerId\":null,\"providerType\":\"email\",\"identifier\":\"fuzzer@local.co\",\"expired\":false}],\"accessedAt\":\"2025-08-19T13:41:30.961+00:00\"}}');

DROP TABLE IF EXISTS `_console_audit_perms`;
CREATE TABLE `_console_audit_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_authenticators`;
CREATE TABLE `_console_authenticators` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `userInternalId` varchar(255) DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `type` varchar(255) DEFAULT NULL,
  `verified` tinyint(1) DEFAULT NULL,
  `data` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_userInternalId` (`userInternalId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_authenticators_perms`;
CREATE TABLE `_console_authenticators_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_buckets`;
CREATE TABLE `_console_buckets` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `name` varchar(128) DEFAULT NULL,
  `fileSecurity` tinyint(1) DEFAULT NULL,
  `maximumFileSize` bigint(20) unsigned DEFAULT NULL,
  `allowedFileExtensions` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`allowedFileExtensions`)),
  `compression` varchar(10) DEFAULT NULL,
  `encryption` tinyint(1) DEFAULT NULL,
  `antivirus` tinyint(1) DEFAULT NULL,
  `search` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_enabled` (`enabled`),
  KEY `_key_name` (`name`),
  KEY `_key_fileSecurity` (`fileSecurity`),
  KEY `_key_maximumFileSize` (`maximumFileSize`),
  KEY `_key_encryption` (`encryption`),
  KEY `_key_antivirus` (`antivirus`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_fulltext_name` (`name`),
  FULLTEXT KEY `_key_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `_console_buckets` (`_id`, `_uid`, `_createdAt`, `_updatedAt`, `_permissions`, `enabled`, `name`, `fileSecurity`, `maximumFileSize`, `allowedFileExtensions`, `compression`, `encryption`, `antivirus`, `search`) VALUES
(1,	'default',	'2025-08-19 13:17:48.901',	'2025-08-19 13:17:48.901',	'[\"create(\\\"any\\\")\",\"read(\\\"any\\\")\",\"update(\\\"any\\\")\",\"delete(\\\"any\\\")\"]',	1,	'Default',	1,	30000000,	'[]',	'gzip',	1,	1,	'buckets Default'),
(2,	'screenshots',	'2025-08-19 13:17:49.022',	'2025-08-19 13:17:49.022',	'[]',	1,	'Screenshots',	1,	20000000,	'[\"png\"]',	'gzip',	0,	0,	'buckets Screenshots');

DROP TABLE IF EXISTS `_console_buckets_perms`;
CREATE TABLE `_console_buckets_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `_console_buckets_perms` (`_id`, `_type`, `_permission`, `_document`) VALUES
(1,	'create',	'any',	'default'),
(4,	'delete',	'any',	'default'),
(2,	'read',	'any',	'default'),
(3,	'update',	'any',	'default');

DROP TABLE IF EXISTS `_console_bucket_1`;
CREATE TABLE `_console_bucket_1` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `bucketId` varchar(255) DEFAULT NULL,
  `bucketInternalId` varchar(255) DEFAULT NULL,
  `name` varchar(2048) DEFAULT NULL,
  `path` varchar(2048) DEFAULT NULL,
  `signature` varchar(2048) DEFAULT NULL,
  `mimeType` varchar(255) DEFAULT NULL,
  `metadata` mediumtext DEFAULT NULL,
  `sizeOriginal` bigint(20) unsigned DEFAULT NULL,
  `sizeActual` bigint(20) unsigned DEFAULT NULL,
  `algorithm` varchar(255) DEFAULT NULL,
  `comment` varchar(2048) DEFAULT NULL,
  `openSSLVersion` varchar(64) DEFAULT NULL,
  `openSSLCipher` varchar(64) DEFAULT NULL,
  `openSSLTag` varchar(2048) DEFAULT NULL,
  `openSSLIV` varchar(2048) DEFAULT NULL,
  `chunksTotal` int(10) unsigned DEFAULT NULL,
  `chunksUploaded` int(10) unsigned DEFAULT NULL,
  `transformedAt` datetime(3) DEFAULT NULL,
  `search` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_bucket` (`bucketId`),
  KEY `_key_name` (`name`(256)),
  KEY `_key_signature` (`signature`(256)),
  KEY `_key_mimeType` (`mimeType`),
  KEY `_key_sizeOriginal` (`sizeOriginal`),
  KEY `_key_chunksTotal` (`chunksTotal`),
  KEY `_key_chunksUploaded` (`chunksUploaded`),
  KEY `_key_transformedAt` (`transformedAt`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_key_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_bucket_1_perms`;
CREATE TABLE `_console_bucket_1_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_bucket_2`;
CREATE TABLE `_console_bucket_2` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `bucketId` varchar(255) DEFAULT NULL,
  `bucketInternalId` varchar(255) DEFAULT NULL,
  `name` varchar(2048) DEFAULT NULL,
  `path` varchar(2048) DEFAULT NULL,
  `signature` varchar(2048) DEFAULT NULL,
  `mimeType` varchar(255) DEFAULT NULL,
  `metadata` mediumtext DEFAULT NULL,
  `sizeOriginal` bigint(20) unsigned DEFAULT NULL,
  `sizeActual` bigint(20) unsigned DEFAULT NULL,
  `algorithm` varchar(255) DEFAULT NULL,
  `comment` varchar(2048) DEFAULT NULL,
  `openSSLVersion` varchar(64) DEFAULT NULL,
  `openSSLCipher` varchar(64) DEFAULT NULL,
  `openSSLTag` varchar(2048) DEFAULT NULL,
  `openSSLIV` varchar(2048) DEFAULT NULL,
  `chunksTotal` int(10) unsigned DEFAULT NULL,
  `chunksUploaded` int(10) unsigned DEFAULT NULL,
  `transformedAt` datetime(3) DEFAULT NULL,
  `search` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_bucket` (`bucketId`),
  KEY `_key_name` (`name`(256)),
  KEY `_key_signature` (`signature`(256)),
  KEY `_key_mimeType` (`mimeType`),
  KEY `_key_sizeOriginal` (`sizeOriginal`),
  KEY `_key_chunksTotal` (`chunksTotal`),
  KEY `_key_chunksUploaded` (`chunksUploaded`),
  KEY `_key_transformedAt` (`transformedAt`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_key_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_bucket_2_perms`;
CREATE TABLE `_console_bucket_2_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_cache`;
CREATE TABLE `_console_cache` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `resource` varchar(255) DEFAULT NULL,
  `resourceType` varchar(255) DEFAULT NULL,
  `mimeType` varchar(255) DEFAULT NULL,
  `accessedAt` datetime(3) DEFAULT NULL,
  `signature` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_accessedAt` (`accessedAt`),
  KEY `_key_resource` (`resource`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_cache_perms`;
CREATE TABLE `_console_cache_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_certificates`;
CREATE TABLE `_console_certificates` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `domain` varchar(255) DEFAULT NULL,
  `issueDate` datetime(3) DEFAULT NULL,
  `renewDate` datetime(3) DEFAULT NULL,
  `attempts` int(11) DEFAULT NULL,
  `logs` mediumtext DEFAULT NULL,
  `updated` datetime(3) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_domain` (`domain`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_certificates_perms`;
CREATE TABLE `_console_certificates_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_challenges`;
CREATE TABLE `_console_challenges` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `userInternalId` varchar(255) DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `type` varchar(255) DEFAULT NULL,
  `token` varchar(512) DEFAULT NULL,
  `code` varchar(512) DEFAULT NULL,
  `expire` datetime(3) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_user` (`userInternalId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_challenges_perms`;
CREATE TABLE `_console_challenges_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_devKeys`;
CREATE TABLE `_console_devKeys` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `projectInternalId` varchar(255) DEFAULT NULL,
  `projectId` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `secret` varchar(512) DEFAULT NULL,
  `expire` datetime(3) DEFAULT NULL,
  `accessedAt` datetime(3) DEFAULT NULL,
  `sdks` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`sdks`)),
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_project` (`projectInternalId`),
  KEY `_key_accessedAt` (`accessedAt`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_devKeys_perms`;
CREATE TABLE `_console_devKeys_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_identities`;
CREATE TABLE `_console_identities` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `userInternalId` varchar(255) DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `provider` varchar(128) DEFAULT NULL,
  `providerUid` varchar(2048) DEFAULT NULL,
  `providerEmail` varchar(320) DEFAULT NULL,
  `providerAccessToken` text DEFAULT NULL,
  `providerAccessTokenExpiry` datetime(3) DEFAULT NULL,
  `providerRefreshToken` text DEFAULT NULL,
  `secrets` text DEFAULT NULL,
  `scopes` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`scopes`)),
  `expire` datetime(3) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  UNIQUE KEY `_key_userInternalId_provider_providerUid` (`userInternalId`(11),`provider`,`providerUid`(128)),
  UNIQUE KEY `_key_provider_providerUid` (`provider`,`providerUid`(128)),
  KEY `_key_userId` (`userId`),
  KEY `_key_userInternalId` (`userInternalId`),
  KEY `_key_provider` (`provider`),
  KEY `_key_providerUid` (`providerUid`(255)),
  KEY `_key_providerEmail` (`providerEmail`(255)),
  KEY `_key_providerAccessTokenExpiry` (`providerAccessTokenExpiry`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_identities_perms`;
CREATE TABLE `_console_identities_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_installations`;
CREATE TABLE `_console_installations` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `projectId` varchar(255) DEFAULT NULL,
  `projectInternalId` varchar(255) DEFAULT NULL,
  `providerInstallationId` varchar(255) DEFAULT NULL,
  `organization` varchar(255) DEFAULT NULL,
  `provider` varchar(255) DEFAULT NULL,
  `personal` tinyint(1) DEFAULT NULL,
  `personalAccessToken` varchar(256) DEFAULT NULL,
  `personalAccessTokenExpiry` datetime(3) DEFAULT NULL,
  `personalRefreshToken` varchar(256) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_projectInternalId` (`projectInternalId`),
  KEY `_key_projectId` (`projectId`),
  KEY `_key_providerInstallationId` (`providerInstallationId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_installations_perms`;
CREATE TABLE `_console_installations_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_keys`;
CREATE TABLE `_console_keys` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `projectInternalId` varchar(255) DEFAULT NULL,
  `projectId` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `scopes` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`scopes`)),
  `secret` varchar(512) DEFAULT NULL,
  `expire` datetime(3) DEFAULT NULL,
  `accessedAt` datetime(3) DEFAULT NULL,
  `sdks` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`sdks`)),
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_project` (`projectInternalId`),
  KEY `_key_accessedAt` (`accessedAt`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_keys_perms`;
CREATE TABLE `_console_keys_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_memberships`;
CREATE TABLE `_console_memberships` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `userInternalId` varchar(255) DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `teamInternalId` varchar(255) DEFAULT NULL,
  `teamId` varchar(255) DEFAULT NULL,
  `roles` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`roles`)),
  `invited` datetime(3) DEFAULT NULL,
  `joined` datetime(3) DEFAULT NULL,
  `confirm` tinyint(1) DEFAULT NULL,
  `secret` varchar(256) DEFAULT NULL,
  `search` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  UNIQUE KEY `_key_unique` (`teamInternalId`,`userInternalId`),
  KEY `_key_user` (`userInternalId`),
  KEY `_key_team` (`teamInternalId`),
  KEY `_key_userId` (`userId`),
  KEY `_key_teamId` (`teamId`),
  KEY `_key_invited` (`invited`),
  KEY `_key_joined` (`joined`),
  KEY `_key_confirm` (`confirm`),
  KEY `_key_roles` (`roles`(255)),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_key_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `_console_memberships` (`_id`, `_uid`, `_createdAt`, `_updatedAt`, `_permissions`, `userInternalId`, `userId`, `teamInternalId`, `teamId`, `roles`, `invited`, `joined`, `confirm`, `secret`, `search`) VALUES
(1,	'68a47f0bd88cd8c708c9',	'2025-08-19 13:41:31.887',	'2025-08-19 13:41:31.887',	'[\"read(\\\"user:68a47f0a002bba8f8df7\\\")\",\"read(\\\"team:68a47f0b0035e5179e3b\\\")\",\"update(\\\"user:68a47f0a002bba8f8df7\\\")\",\"update(\\\"team:68a47f0b0035e5179e3b\\/owner\\\")\",\"delete(\\\"user:68a47f0a002bba8f8df7\\\")\",\"delete(\\\"team:68a47f0b0035e5179e3b\\/owner\\\")\"]',	'1',	'68a47f0a002bba8f8df7',	'1',	'68a47f0b0035e5179e3b',	'[\"owner\"]',	'2025-08-19 13:41:31.887',	'2025-08-19 13:41:31.887',	1,	'{\"data\":\"\",\"method\":\"aes-128-gcm\",\"iv\":\"6f9a5b2e1c83fe9bac23bdff\",\"tag\":\"cd054a66543cfb95613ab9eb18288222\",\"version\":\"1\"}',	'68a47f0bd88cd8c708c9 68a47f0a002bba8f8df7');

DROP TABLE IF EXISTS `_console_memberships_perms`;
CREATE TABLE `_console_memberships_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `_console_memberships_perms` (`_id`, `_type`, `_permission`, `_document`) VALUES
(6,	'delete',	'team:68a47f0b0035e5179e3b/owner',	'68a47f0bd88cd8c708c9'),
(5,	'delete',	'user:68a47f0a002bba8f8df7',	'68a47f0bd88cd8c708c9'),
(2,	'read',	'team:68a47f0b0035e5179e3b',	'68a47f0bd88cd8c708c9'),
(1,	'read',	'user:68a47f0a002bba8f8df7',	'68a47f0bd88cd8c708c9'),
(4,	'update',	'team:68a47f0b0035e5179e3b/owner',	'68a47f0bd88cd8c708c9'),
(3,	'update',	'user:68a47f0a002bba8f8df7',	'68a47f0bd88cd8c708c9');

DROP TABLE IF EXISTS `_console_messages`;
CREATE TABLE `_console_messages` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `providerType` varchar(255) DEFAULT NULL,
  `status` varchar(255) DEFAULT NULL,
  `data` text DEFAULT NULL,
  `topics` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`topics`)),
  `users` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`users`)),
  `targets` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`targets`)),
  `scheduledAt` datetime(3) DEFAULT NULL,
  `scheduleInternalId` varchar(255) DEFAULT NULL,
  `scheduleId` varchar(255) DEFAULT NULL,
  `deliveredAt` datetime(3) DEFAULT NULL,
  `deliveryErrors` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`deliveryErrors`)),
  `deliveredTotal` int(11) DEFAULT NULL,
  `search` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_key_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_messages_perms`;
CREATE TABLE `_console_messages_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_platforms`;
CREATE TABLE `_console_platforms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `projectInternalId` varchar(255) DEFAULT NULL,
  `projectId` varchar(255) DEFAULT NULL,
  `type` varchar(255) DEFAULT NULL,
  `name` varchar(256) DEFAULT NULL,
  `key` varchar(255) DEFAULT NULL,
  `store` varchar(256) DEFAULT NULL,
  `hostname` varchar(256) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_project` (`projectInternalId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_platforms_perms`;
CREATE TABLE `_console_platforms_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_projects`;
CREATE TABLE `_console_projects` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `teamInternalId` varchar(255) DEFAULT NULL,
  `teamId` varchar(255) DEFAULT NULL,
  `name` varchar(128) DEFAULT NULL,
  `region` varchar(128) DEFAULT NULL,
  `description` varchar(256) DEFAULT NULL,
  `database` varchar(256) DEFAULT NULL,
  `logo` varchar(255) DEFAULT NULL,
  `url` text DEFAULT NULL,
  `version` varchar(16) DEFAULT NULL,
  `legalName` varchar(256) DEFAULT NULL,
  `legalCountry` varchar(256) DEFAULT NULL,
  `legalState` varchar(256) DEFAULT NULL,
  `legalCity` varchar(256) DEFAULT NULL,
  `legalAddress` varchar(256) DEFAULT NULL,
  `legalTaxId` varchar(256) DEFAULT NULL,
  `accessedAt` datetime(3) DEFAULT NULL,
  `services` text DEFAULT NULL,
  `apis` text DEFAULT NULL,
  `smtp` text DEFAULT NULL,
  `templates` mediumtext DEFAULT NULL,
  `auths` text DEFAULT NULL,
  `oAuthProviders` text DEFAULT NULL,
  `platforms` text DEFAULT NULL,
  `webhooks` text DEFAULT NULL,
  `keys` text DEFAULT NULL,
  `devKeys` text DEFAULT NULL,
  `search` text DEFAULT NULL,
  `pingCount` int(10) unsigned DEFAULT NULL,
  `pingedAt` datetime(3) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_name` (`name`),
  KEY `_key_team` (`teamId`),
  KEY `_key_pingCount` (`pingCount`),
  KEY `_key_pingedAt` (`pingedAt`),
  KEY `_key_database` (`database`),
  KEY `_key_region_accessed_at` (`region`,`accessedAt`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_key_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `_console_projects` (`_id`, `_uid`, `_createdAt`, `_updatedAt`, `_permissions`, `teamInternalId`, `teamId`, `name`, `region`, `description`, `database`, `logo`, `url`, `version`, `legalName`, `legalCountry`, `legalState`, `legalCity`, `legalAddress`, `legalTaxId`, `accessedAt`, `services`, `apis`, `smtp`, `templates`, `auths`, `oAuthProviders`, `platforms`, `webhooks`, `keys`, `devKeys`, `search`, `pingCount`, `pingedAt`) VALUES
(1,	'68a47f110011949a91b0',	'2025-08-19 13:41:37.305',	'2025-08-19 13:41:37.305',	'[\"read(\\\"team:68a47f0b0035e5179e3b\\\")\",\"update(\\\"team:68a47f0b0035e5179e3b\\/owner\\\")\",\"update(\\\"team:68a47f0b0035e5179e3b\\/developer\\\")\",\"delete(\\\"team:68a47f0b0035e5179e3b\\/owner\\\")\",\"delete(\\\"team:68a47f0b0035e5179e3b\\/developer\\\")\"]',	'1',	'68a47f0b0035e5179e3b',	'Appwrite project',	'default',	'',	'database_db_main',	'',	'',	'1.7.4',	'',	'',	'',	'',	'',	'',	'2025-08-19 13:41:37.305',	'{}',	'[]',	'{\"data\":\"Qmc=\",\"method\":\"aes-128-gcm\",\"iv\":\"63bb04ba074cae6704a127cd\",\"tag\":\"14d77a478fbd8f1ad8f60f266284707a\",\"version\":\"1\"}',	'[]',	'{\"limit\":0,\"maxSessions\":10,\"passwordHistory\":0,\"passwordDictionary\":false,\"duration\":31536000,\"personalDataCheck\":false,\"mockNumbers\":[],\"sessionAlerts\":false,\"membershipsUserName\":false,\"membershipsUserEmail\":false,\"membershipsMfa\":false,\"emailPassword\":true,\"usersAuthMagicURL\":true,\"emailOtp\":true,\"anonymous\":true,\"invites\":true,\"JWT\":true,\"phone\":true}',	'{\"data\":\"8aM=\",\"method\":\"aes-128-gcm\",\"iv\":\"b437eac0630b3fe1b67f405e\",\"tag\":\"306fab692b7e16a92d07a6e4582e3205\",\"version\":\"1\"}',	NULL,	NULL,	NULL,	NULL,	'68a47f110011949a91b0 Appwrite project',	0,	NULL);

DROP TABLE IF EXISTS `_console_projects_perms`;
CREATE TABLE `_console_projects_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `_console_projects_perms` (`_id`, `_type`, `_permission`, `_document`) VALUES
(5,	'delete',	'team:68a47f0b0035e5179e3b/developer',	'68a47f110011949a91b0'),
(4,	'delete',	'team:68a47f0b0035e5179e3b/owner',	'68a47f110011949a91b0'),
(1,	'read',	'team:68a47f0b0035e5179e3b',	'68a47f110011949a91b0'),
(3,	'update',	'team:68a47f0b0035e5179e3b/developer',	'68a47f110011949a91b0'),
(2,	'update',	'team:68a47f0b0035e5179e3b/owner',	'68a47f110011949a91b0');

DROP TABLE IF EXISTS `_console_providers`;
CREATE TABLE `_console_providers` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `name` varchar(128) DEFAULT NULL,
  `provider` varchar(255) DEFAULT NULL,
  `type` varchar(128) DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `credentials` text DEFAULT NULL,
  `options` text DEFAULT NULL,
  `search` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_provider` (`provider`),
  KEY `_key_type` (`type`),
  KEY `_key_enabled_type` (`enabled`,`type`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_key_name` (`name`),
  FULLTEXT KEY `_key_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_providers_perms`;
CREATE TABLE `_console_providers_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_realtime`;
CREATE TABLE `_console_realtime` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `container` varchar(255) DEFAULT NULL,
  `timestamp` datetime(3) DEFAULT NULL,
  `value` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_timestamp` (`timestamp` DESC),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `_console_realtime` (`_id`, `_uid`, `_createdAt`, `_updatedAt`, `_permissions`, `container`, `timestamp`, `value`) VALUES
(1,	'68a4797ee7e7fc34d95d',	'2025-08-19 13:17:50.957',	'2025-08-19 13:17:50.957',	'[]',	'68a47979e0c86',	'2025-08-19 13:17:50.950',	'{}'),
(2,	'68a47e4e995e45097eb7',	'2025-08-19 13:38:22.629',	'2025-08-19 13:44:02.626',	'[]',	'68a47e4995664',	'2025-08-19 13:44:02.623',	'{\"console\":2}');

DROP TABLE IF EXISTS `_console_realtime_perms`;
CREATE TABLE `_console_realtime_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_repositories`;
CREATE TABLE `_console_repositories` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `installationId` varchar(255) DEFAULT NULL,
  `installationInternalId` varchar(255) DEFAULT NULL,
  `projectId` varchar(255) DEFAULT NULL,
  `projectInternalId` varchar(255) DEFAULT NULL,
  `providerRepositoryId` varchar(255) DEFAULT NULL,
  `resourceId` varchar(255) DEFAULT NULL,
  `resourceInternalId` varchar(255) DEFAULT NULL,
  `resourceType` varchar(255) DEFAULT NULL,
  `providerPullRequestIds` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`providerPullRequestIds`)),
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_installationId` (`installationId`),
  KEY `_key_installationInternalId` (`installationInternalId`),
  KEY `_key_projectInternalId` (`projectInternalId`),
  KEY `_key_projectId` (`projectId`),
  KEY `_key_providerRepositoryId` (`providerRepositoryId`),
  KEY `_key_resourceId` (`resourceId`),
  KEY `_key_resourceInternalId` (`resourceInternalId`),
  KEY `_key_resourceType` (`resourceType`),
  KEY `_key_piid_riid_rt` (`projectInternalId`,`resourceInternalId`,`resourceType`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_repositories_perms`;
CREATE TABLE `_console_repositories_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_rules`;
CREATE TABLE `_console_rules` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `projectId` varchar(255) DEFAULT NULL,
  `projectInternalId` varchar(255) DEFAULT NULL,
  `domain` varchar(255) DEFAULT NULL,
  `type` varchar(32) DEFAULT NULL,
  `trigger` varchar(32) DEFAULT NULL,
  `redirectUrl` varchar(2048) DEFAULT NULL,
  `redirectStatusCode` int(11) DEFAULT NULL,
  `deploymentResourceType` varchar(32) DEFAULT NULL,
  `deploymentId` varchar(255) DEFAULT NULL,
  `deploymentInternalId` varchar(255) DEFAULT NULL,
  `deploymentResourceId` varchar(255) DEFAULT NULL,
  `deploymentResourceInternalId` varchar(255) DEFAULT NULL,
  `deploymentVcsProviderBranch` varchar(255) DEFAULT NULL,
  `status` varchar(255) DEFAULT NULL,
  `certificateId` varchar(255) DEFAULT NULL,
  `search` text DEFAULT NULL,
  `owner` varchar(16) DEFAULT NULL,
  `region` varchar(16) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  UNIQUE KEY `_key_domain` (`domain`),
  KEY `_key_projectInternalId` (`projectInternalId`),
  KEY `_key_projectId` (`projectId`),
  KEY `_key_type` (`type`),
  KEY `_key_trigger` (`trigger`),
  KEY `_key_deploymentResourceType` (`deploymentResourceType`),
  KEY `_key_deploymentResourceId` (`deploymentResourceId`),
  KEY `_key_deploymentResourceInternalId` (`deploymentResourceInternalId`),
  KEY `_key_deploymentId` (`deploymentId`),
  KEY `_key_deploymentInternalId` (`deploymentInternalId`),
  KEY `_key_deploymentVcsProviderBranch` (`deploymentVcsProviderBranch`),
  KEY `_key_owner` (`owner`),
  KEY `_key_region` (`region`),
  KEY `_key_piid_riid_rt` (`projectInternalId`,`deploymentInternalId`,`deploymentResourceType`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_key_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_rules_perms`;
CREATE TABLE `_console_rules_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_schedules`;
CREATE TABLE `_console_schedules` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `resourceType` varchar(100) DEFAULT NULL,
  `resourceInternalId` varchar(255) DEFAULT NULL,
  `resourceId` varchar(255) DEFAULT NULL,
  `resourceUpdatedAt` datetime(3) DEFAULT NULL,
  `projectId` varchar(255) DEFAULT NULL,
  `schedule` varchar(100) DEFAULT NULL,
  `data` text DEFAULT NULL,
  `active` tinyint(1) DEFAULT NULL,
  `region` varchar(10) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_region_resourceType_resourceUpdatedAt` (`region`,`resourceType`,`resourceUpdatedAt`),
  KEY `_key_region_resourceType_projectId_resourceId` (`region`,`resourceType`,`projectId`,`resourceId`),
  KEY `_key_project_id_region` (`projectId`,`region`),
  KEY `_key_region_rt_active` (`region`,`resourceType`,`active`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_schedules_perms`;
CREATE TABLE `_console_schedules_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_sessions`;
CREATE TABLE `_console_sessions` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `userInternalId` varchar(255) DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `provider` varchar(128) DEFAULT NULL,
  `providerUid` varchar(2048) DEFAULT NULL,
  `providerAccessToken` text DEFAULT NULL,
  `providerAccessTokenExpiry` datetime(3) DEFAULT NULL,
  `providerRefreshToken` text DEFAULT NULL,
  `secret` varchar(512) DEFAULT NULL,
  `userAgent` text DEFAULT NULL,
  `ip` varchar(45) DEFAULT NULL,
  `countryCode` varchar(2) DEFAULT NULL,
  `osCode` varchar(256) DEFAULT NULL,
  `osName` varchar(256) DEFAULT NULL,
  `osVersion` varchar(256) DEFAULT NULL,
  `clientType` varchar(256) DEFAULT NULL,
  `clientCode` varchar(256) DEFAULT NULL,
  `clientName` varchar(256) DEFAULT NULL,
  `clientVersion` varchar(256) DEFAULT NULL,
  `clientEngine` varchar(256) DEFAULT NULL,
  `clientEngineVersion` varchar(256) DEFAULT NULL,
  `deviceName` varchar(256) DEFAULT NULL,
  `deviceBrand` varchar(256) DEFAULT NULL,
  `deviceModel` varchar(256) DEFAULT NULL,
  `factors` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`factors`)),
  `expire` datetime(3) DEFAULT NULL,
  `mfaUpdatedAt` datetime(3) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_provider_providerUid` (`provider`,`providerUid`(128)),
  KEY `_key_user` (`userInternalId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `_console_sessions` (`_id`, `_uid`, `_createdAt`, `_updatedAt`, `_permissions`, `userInternalId`, `userId`, `provider`, `providerUid`, `providerAccessToken`, `providerAccessTokenExpiry`, `providerRefreshToken`, `secret`, `userAgent`, `ip`, `countryCode`, `osCode`, `osName`, `osVersion`, `clientType`, `clientCode`, `clientName`, `clientVersion`, `clientEngine`, `clientEngineVersion`, `deviceName`, `deviceBrand`, `deviceModel`, `factors`, `expire`, `mfaUpdatedAt`) VALUES
(1,	'68a47f0b4126e60b0dac',	'2025-08-19 13:41:31.328',	'2025-08-19 13:41:31.328',	'[\"read(\\\"user:68a47f0a002bba8f8df7\\\")\",\"update(\\\"user:68a47f0a002bba8f8df7\\\")\",\"delete(\\\"user:68a47f0a002bba8f8df7\\\")\"]',	'1',	'68a47f0a002bba8f8df7',	'email',	'fuzzer@local.co',	NULL,	NULL,	NULL,	'{\"data\":\"NEI8O9s1iJQ7bs5A5cAoyInNYa4xFFwg8k0uBqvJCkYusiPae4kvEiDa1ZscZNwHisloRYTFp9H3LvCD9YRSLA==\",\"method\":\"aes-128-gcm\",\"iv\":\"0793760a5f3a0bd139d1cfef\",\"tag\":\"808f2c478c3c35d0152101fe17381c81\",\"version\":\"1\"}',	'Mozilla/5.0 (X11; Linux x86_64; rv:141.0) Gecko/20100101 Firefox/141.0',	'192.168.192.1',	'--',	'LIN',	'GNU/Linux',	'',	'browser',	'FF',	'Firefox',	'141.0',	'Gecko',	'141.0',	'desktop',	NULL,	NULL,	'[\"password\"]',	'2026-08-19 13:41:31.266',	NULL);

DROP TABLE IF EXISTS `_console_sessions_perms`;
CREATE TABLE `_console_sessions_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `_console_sessions_perms` (`_id`, `_type`, `_permission`, `_document`) VALUES
(3,	'delete',	'user:68a47f0a002bba8f8df7',	'68a47f0b4126e60b0dac'),
(1,	'read',	'user:68a47f0a002bba8f8df7',	'68a47f0b4126e60b0dac'),
(2,	'update',	'user:68a47f0a002bba8f8df7',	'68a47f0b4126e60b0dac');

DROP TABLE IF EXISTS `_console_stats`;
CREATE TABLE `_console_stats` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `metric` varchar(255) DEFAULT NULL,
  `region` varchar(255) DEFAULT NULL,
  `value` bigint(20) DEFAULT NULL,
  `time` datetime(3) DEFAULT NULL,
  `period` varchar(4) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  UNIQUE KEY `_key_metric_period_time` (`metric` DESC,`period`,`time`),
  KEY `_key_time` (`time` DESC),
  KEY `_key_period_time` (`period`,`time`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_stats_perms`;
CREATE TABLE `_console_stats_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_subscribers`;
CREATE TABLE `_console_subscribers` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `targetId` varchar(255) DEFAULT NULL,
  `targetInternalId` varchar(255) DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `userInternalId` varchar(255) DEFAULT NULL,
  `topicId` varchar(255) DEFAULT NULL,
  `topicInternalId` varchar(255) DEFAULT NULL,
  `providerType` varchar(128) DEFAULT NULL,
  `search` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  UNIQUE KEY `_unique_target_topic` (`targetInternalId`,`topicInternalId`),
  KEY `_key_targetId` (`targetId`),
  KEY `_key_targetInternalId` (`targetInternalId`),
  KEY `_key_userId` (`userId`),
  KEY `_key_userInternalId` (`userInternalId`),
  KEY `_key_topicId` (`topicId`),
  KEY `_key_topicInternalId` (`topicInternalId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_fulltext_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_subscribers_perms`;
CREATE TABLE `_console_subscribers_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_targets`;
CREATE TABLE `_console_targets` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `userInternalId` varchar(255) DEFAULT NULL,
  `sessionId` varchar(255) DEFAULT NULL,
  `sessionInternalId` varchar(255) DEFAULT NULL,
  `providerType` varchar(255) DEFAULT NULL,
  `providerId` varchar(255) DEFAULT NULL,
  `providerInternalId` varchar(255) DEFAULT NULL,
  `identifier` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `expired` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  UNIQUE KEY `_key_identifier` (`identifier`),
  KEY `_key_userId` (`userId`),
  KEY `_key_userInternalId` (`userInternalId`),
  KEY `_key_providerId` (`providerId`),
  KEY `_key_providerInternalId` (`providerInternalId`),
  KEY `_key_expired` (`expired`),
  KEY `_key_session_internal_id` (`sessionInternalId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `_console_targets` (`_id`, `_uid`, `_createdAt`, `_updatedAt`, `_permissions`, `userId`, `userInternalId`, `sessionId`, `sessionInternalId`, `providerType`, `providerId`, `providerInternalId`, `identifier`, `name`, `expired`) VALUES
(1,	'68a47f0b0cb00ed13f98',	'2025-08-19 13:41:31.051',	'2025-08-19 13:41:31.051',	'[\"read(\\\"user:68a47f0a002bba8f8df7\\\")\",\"update(\\\"user:68a47f0a002bba8f8df7\\\")\",\"delete(\\\"user:68a47f0a002bba8f8df7\\\")\"]',	'68a47f0a002bba8f8df7',	'1',	NULL,	NULL,	'email',	NULL,	NULL,	'fuzzer@local.co',	NULL,	0);

DROP TABLE IF EXISTS `_console_targets_perms`;
CREATE TABLE `_console_targets_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `_console_targets_perms` (`_id`, `_type`, `_permission`, `_document`) VALUES
(3,	'delete',	'user:68a47f0a002bba8f8df7',	'68a47f0b0cb00ed13f98'),
(1,	'read',	'user:68a47f0a002bba8f8df7',	'68a47f0b0cb00ed13f98'),
(2,	'update',	'user:68a47f0a002bba8f8df7',	'68a47f0b0cb00ed13f98');

DROP TABLE IF EXISTS `_console_teams`;
CREATE TABLE `_console_teams` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `name` varchar(128) DEFAULT NULL,
  `total` int(11) DEFAULT NULL,
  `search` text DEFAULT NULL,
  `prefs` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_name` (`name`),
  KEY `_key_total` (`total`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_key_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `_console_teams` (`_id`, `_uid`, `_createdAt`, `_updatedAt`, `_permissions`, `name`, `total`, `search`, `prefs`) VALUES
(1,	'68a47f0b0035e5179e3b',	'2025-08-19 13:41:31.874',	'2025-08-19 13:41:31.874',	'[\"read(\\\"team:68a47f0b0035e5179e3b\\\")\",\"update(\\\"team:68a47f0b0035e5179e3b\\/owner\\\")\",\"delete(\\\"team:68a47f0b0035e5179e3b\\/owner\\\")\"]',	'Personal projects',	1,	'68a47f0b0035e5179e3b Personal projects',	'{}');

DROP TABLE IF EXISTS `_console_teams_perms`;
CREATE TABLE `_console_teams_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `_console_teams_perms` (`_id`, `_type`, `_permission`, `_document`) VALUES
(3,	'delete',	'team:68a47f0b0035e5179e3b/owner',	'68a47f0b0035e5179e3b'),
(1,	'read',	'team:68a47f0b0035e5179e3b',	'68a47f0b0035e5179e3b'),
(2,	'update',	'team:68a47f0b0035e5179e3b/owner',	'68a47f0b0035e5179e3b');

DROP TABLE IF EXISTS `_console_tokens`;
CREATE TABLE `_console_tokens` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `userInternalId` varchar(255) DEFAULT NULL,
  `userId` varchar(255) DEFAULT NULL,
  `type` int(11) DEFAULT NULL,
  `secret` varchar(512) DEFAULT NULL,
  `expire` datetime(3) DEFAULT NULL,
  `userAgent` text DEFAULT NULL,
  `ip` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_user` (`userInternalId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_tokens_perms`;
CREATE TABLE `_console_tokens_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_topics`;
CREATE TABLE `_console_topics` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `name` varchar(128) DEFAULT NULL,
  `subscribe` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`subscribe`)),
  `emailTotal` int(11) DEFAULT NULL,
  `smsTotal` int(11) DEFAULT NULL,
  `pushTotal` int(11) DEFAULT NULL,
  `targets` text DEFAULT NULL,
  `search` text DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_key_name` (`name`),
  FULLTEXT KEY `_key_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_topics_perms`;
CREATE TABLE `_console_topics_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_users`;
CREATE TABLE `_console_users` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `name` varchar(256) DEFAULT NULL,
  `email` varchar(320) DEFAULT NULL,
  `phone` varchar(16) DEFAULT NULL,
  `status` tinyint(1) DEFAULT NULL,
  `labels` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`labels`)),
  `passwordHistory` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`passwordHistory`)),
  `password` text DEFAULT NULL,
  `hash` varchar(256) DEFAULT NULL,
  `hashOptions` text DEFAULT NULL,
  `passwordUpdate` datetime(3) DEFAULT NULL,
  `prefs` text DEFAULT NULL,
  `registration` datetime(3) DEFAULT NULL,
  `emailVerification` tinyint(1) DEFAULT NULL,
  `phoneVerification` tinyint(1) DEFAULT NULL,
  `reset` tinyint(1) DEFAULT NULL,
  `mfa` tinyint(1) DEFAULT NULL,
  `mfaRecoveryCodes` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`mfaRecoveryCodes`)),
  `authenticators` text DEFAULT NULL,
  `sessions` text DEFAULT NULL,
  `tokens` text DEFAULT NULL,
  `challenges` text DEFAULT NULL,
  `memberships` text DEFAULT NULL,
  `targets` text DEFAULT NULL,
  `search` text DEFAULT NULL,
  `accessedAt` datetime(3) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  UNIQUE KEY `_key_phone` (`phone`),
  UNIQUE KEY `_key_email` (`email`(256)),
  KEY `_key_name` (`name`),
  KEY `_key_status` (`status`),
  KEY `_key_passwordUpdate` (`passwordUpdate`),
  KEY `_key_registration` (`registration`),
  KEY `_key_emailVerification` (`emailVerification`),
  KEY `_key_phoneVerification` (`phoneVerification`),
  KEY `_key_accessedAt` (`accessedAt`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`),
  FULLTEXT KEY `_key_search` (`search`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `_console_users` (`_id`, `_uid`, `_createdAt`, `_updatedAt`, `_permissions`, `name`, `email`, `phone`, `status`, `labels`, `passwordHistory`, `password`, `hash`, `hashOptions`, `passwordUpdate`, `prefs`, `registration`, `emailVerification`, `phoneVerification`, `reset`, `mfa`, `mfaRecoveryCodes`, `authenticators`, `sessions`, `tokens`, `challenges`, `memberships`, `targets`, `search`, `accessedAt`) VALUES
(1,	'68a47f0a002bba8f8df7',	'2025-08-19 13:41:30.962',	'2025-08-19 13:41:42.819',	'[\"read(\\\"any\\\")\",\"update(\\\"user:68a47f0a002bba8f8df7\\\")\",\"delete(\\\"user:68a47f0a002bba8f8df7\\\")\"]',	'Fuzzer',	'fuzzer@local.co',	NULL,	1,	'[]',	'[]',	'{\"data\":\"tx3wp7+9olb2oT9fOMCB4NbExoq8uoH30Ng5oO8v47OaecrolKFS7d8Owns7nPujclZ9GYS9lGLBfJTvMwfFoHJi5qenqykKDrTg7FyPEm3TyWsET1zfEQ4\\/om3\\/6KcMbQ==\",\"method\":\"aes-128-gcm\",\"iv\":\"c8602b5f3afe2f86a996502f\",\"tag\":\"5266eecae1324f20f8dbbe25aff7d552\",\"version\":\"1\"}',	'argon2',	'{\"type\":\"argon2\",\"memoryCost\":2048,\"timeCost\":4,\"threads\":3}',	'2025-08-19 13:41:30.961',	'{\"organization\":\"68a47f0b0035e5179e3b\"}',	'2025-08-19 13:41:30.961',	0,	NULL,	0,	0,	'[]',	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	'68a47f0a002bba8f8df7 fuzzer@local.co Fuzzer',	'2025-08-19 13:41:30.961');

DROP TABLE IF EXISTS `_console_users_perms`;
CREATE TABLE `_console_users_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `_console_users_perms` (`_id`, `_type`, `_permission`, `_document`) VALUES
(3,	'delete',	'user:68a47f0a002bba8f8df7',	'68a47f0a002bba8f8df7'),
(1,	'read',	'any',	'68a47f0a002bba8f8df7'),
(2,	'update',	'user:68a47f0a002bba8f8df7',	'68a47f0a002bba8f8df7');

DROP TABLE IF EXISTS `_console_vcsCommentLocks`;
CREATE TABLE `_console_vcsCommentLocks` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_vcsCommentLocks_perms`;
CREATE TABLE `_console_vcsCommentLocks_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_vcsComments`;
CREATE TABLE `_console_vcsComments` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `installationId` varchar(255) DEFAULT NULL,
  `installationInternalId` varchar(255) DEFAULT NULL,
  `projectId` varchar(255) DEFAULT NULL,
  `projectInternalId` varchar(255) DEFAULT NULL,
  `providerRepositoryId` varchar(255) DEFAULT NULL,
  `providerCommentId` varchar(255) DEFAULT NULL,
  `providerPullRequestId` varchar(255) DEFAULT NULL,
  `providerBranch` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_installationId` (`installationId`),
  KEY `_key_installationInternalId` (`installationInternalId`),
  KEY `_key_projectInternalId` (`projectInternalId`),
  KEY `_key_projectId` (`projectId`),
  KEY `_key_providerRepositoryId` (`providerRepositoryId`),
  KEY `_key_providerPullRequestId` (`providerPullRequestId`),
  KEY `_key_providerBranch` (`providerBranch`),
  KEY `_key_piid_prid_rt` (`projectInternalId`,`providerRepositoryId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_vcsComments_perms`;
CREATE TABLE `_console_vcsComments_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_webhooks`;
CREATE TABLE `_console_webhooks` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `projectInternalId` varchar(255) DEFAULT NULL,
  `projectId` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `url` varchar(255) DEFAULT NULL,
  `httpUser` varchar(255) DEFAULT NULL,
  `httpPass` varchar(255) DEFAULT NULL,
  `security` tinyint(1) DEFAULT NULL,
  `events` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`events`)),
  `signatureKey` varchar(2048) DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `logs` mediumtext DEFAULT NULL,
  `attempts` int(11) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_key_project` (`projectInternalId`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console_webhooks_perms`;
CREATE TABLE `_console_webhooks_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


DROP TABLE IF EXISTS `_console__metadata`;
CREATE TABLE `_console__metadata` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_uid` varchar(255) NOT NULL,
  `_createdAt` datetime(3) DEFAULT NULL,
  `_updatedAt` datetime(3) DEFAULT NULL,
  `_permissions` mediumtext DEFAULT NULL,
  `name` varchar(256) DEFAULT NULL,
  `attributes` mediumtext DEFAULT NULL,
  `indexes` mediumtext DEFAULT NULL,
  `documentSecurity` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_uid` (`_uid`),
  KEY `_created_at` (`_createdAt`),
  KEY `_updated_at` (`_updatedAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `_console__metadata` (`_id`, `_uid`, `_createdAt`, `_updatedAt`, `_permissions`, `name`, `attributes`, `indexes`, `documentSecurity`) VALUES
(1,	'projects',	'2025-08-19 13:17:47.079',	'2025-08-19 13:17:47.079',	'[\"create(\\\"any\\\")\"]',	'projects',	'[{\"$id\":\"teamInternalId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"teamId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"name\",\"type\":\"string\",\"size\":128,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"region\",\"type\":\"string\",\"size\":128,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"description\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"database\",\"type\":\"string\",\"size\":256,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"logo\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"url\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"version\",\"type\":\"string\",\"size\":16,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"legalName\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"legalCountry\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"legalState\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"legalCity\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"legalAddress\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"legalTaxId\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"accessedAt\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"services\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"json\"],\"default\":[],\"format\":\"\"},{\"$id\":\"apis\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"json\"],\"default\":[],\"format\":\"\"},{\"$id\":\"smtp\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"json\",\"encrypt\"],\"default\":[],\"format\":\"\"},{\"$id\":\"templates\",\"type\":\"string\",\"size\":1000000,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"json\"],\"default\":[],\"format\":\"\"},{\"$id\":\"auths\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"json\"],\"default\":[],\"format\":\"\"},{\"$id\":\"oAuthProviders\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"json\",\"encrypt\"],\"default\":[],\"format\":\"\"},{\"$id\":\"platforms\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"subQueryPlatforms\"],\"default\":null,\"format\":\"\"},{\"$id\":\"webhooks\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"subQueryWebhooks\"],\"default\":null,\"format\":\"\"},{\"$id\":\"keys\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"subQueryKeys\"],\"default\":null,\"format\":\"\"},{\"$id\":\"devKeys\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"subQueryDevKeys\"],\"default\":null,\"format\":\"\"},{\"$id\":\"search\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"pingCount\",\"type\":\"integer\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[],\"default\":0,\"format\":\"\"},{\"$id\":\"pingedAt\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_name\",\"type\":\"key\",\"attributes\":[\"name\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_team\",\"type\":\"key\",\"attributes\":[\"teamId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_pingCount\",\"type\":\"key\",\"attributes\":[\"pingCount\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_pingedAt\",\"type\":\"key\",\"attributes\":[\"pingedAt\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_database\",\"type\":\"key\",\"attributes\":[\"database\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_region_accessed_at\",\"type\":\"key\",\"attributes\":[\"region\",\"accessedAt\"],\"lengths\":[],\"orders\":[]}]',	1),
(2,	'schedules',	'2025-08-19 13:17:47.143',	'2025-08-19 13:17:47.143',	'[\"create(\\\"any\\\")\"]',	'schedules',	'[{\"$id\":\"resourceType\",\"type\":\"string\",\"size\":100,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"resourceInternalId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"resourceId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"resourceUpdatedAt\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"projectId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"schedule\",\"type\":\"string\",\"size\":100,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"data\",\"type\":\"string\",\"size\":65535,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"json\",\"encrypt\"],\"default\":{},\"format\":\"\"},{\"$id\":\"active\",\"type\":\"boolean\",\"size\":0,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"region\",\"type\":\"string\",\"size\":10,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_region_resourceType_resourceUpdatedAt\",\"type\":\"key\",\"attributes\":[\"region\",\"resourceType\",\"resourceUpdatedAt\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_region_resourceType_projectId_resourceId\",\"type\":\"key\",\"attributes\":[\"region\",\"resourceType\",\"projectId\",\"resourceId\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_project_id_region\",\"type\":\"key\",\"attributes\":[\"projectId\",\"region\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_region_rt_active\",\"type\":\"key\",\"attributes\":[\"region\",\"resourceType\",\"active\"],\"lengths\":[],\"orders\":[]}]',	1),
(3,	'platforms',	'2025-08-19 13:17:47.199',	'2025-08-19 13:17:47.199',	'[\"create(\\\"any\\\")\"]',	'platforms',	'[{\"$id\":\"projectInternalId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"projectId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"type\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"name\",\"type\":\"string\",\"size\":256,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"key\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"store\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"hostname\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_project\",\"type\":\"key\",\"attributes\":[\"projectInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]}]',	1),
(4,	'keys',	'2025-08-19 13:17:47.252',	'2025-08-19 13:17:47.252',	'[\"create(\\\"any\\\")\"]',	'keys',	'[{\"$id\":\"projectInternalId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"projectId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":0,\"format\":\"\"},{\"$id\":\"name\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"scopes\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":true,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"secret\",\"type\":\"string\",\"size\":512,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[\"encrypt\"],\"default\":null,\"format\":\"\"},{\"$id\":\"expire\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"accessedAt\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"sdks\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":true,\"filters\":[],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_project\",\"type\":\"key\",\"attributes\":[\"projectInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_accessedAt\",\"type\":\"key\",\"attributes\":[\"accessedAt\"],\"lengths\":[],\"orders\":[]}]',	1),
(5,	'devKeys',	'2025-08-19 13:17:47.302',	'2025-08-19 13:17:47.302',	'[\"create(\\\"any\\\")\"]',	'devKeys',	'[{\"$id\":\"projectInternalId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"projectId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":0,\"format\":\"\"},{\"$id\":\"name\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"secret\",\"type\":\"string\",\"size\":512,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[\"encrypt\"],\"default\":null,\"format\":\"\"},{\"$id\":\"expire\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"accessedAt\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"sdks\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":true,\"filters\":[],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_project\",\"type\":\"key\",\"attributes\":[\"projectInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_accessedAt\",\"type\":\"key\",\"attributes\":[\"accessedAt\"],\"lengths\":[],\"orders\":[]}]',	1),
(6,	'webhooks',	'2025-08-19 13:17:47.345',	'2025-08-19 13:17:47.345',	'[\"create(\\\"any\\\")\"]',	'webhooks',	'[{\"$id\":\"projectInternalId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"projectId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"name\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"url\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"httpUser\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"httpPass\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"encrypt\"],\"default\":null,\"format\":\"\"},{\"$id\":\"security\",\"type\":\"boolean\",\"size\":0,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"events\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":true,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"signatureKey\",\"type\":\"string\",\"size\":2048,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"enabled\",\"type\":\"boolean\",\"size\":0,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":true,\"format\":\"\"},{\"$id\":\"logs\",\"type\":\"string\",\"size\":1000000,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":\"\",\"format\":\"\"},{\"$id\":\"attempts\",\"type\":\"integer\",\"size\":0,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":0,\"format\":\"\"}]',	'[{\"$id\":\"_key_project\",\"type\":\"key\",\"attributes\":[\"projectInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]}]',	1),
(7,	'certificates',	'2025-08-19 13:17:47.386',	'2025-08-19 13:17:47.386',	'[\"create(\\\"any\\\")\"]',	'certificates',	'[{\"$id\":\"domain\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"issueDate\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"renewDate\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"attempts\",\"type\":\"integer\",\"size\":0,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"logs\",\"type\":\"string\",\"size\":1000000,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"updated\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_domain\",\"type\":\"key\",\"attributes\":[\"domain\"],\"lengths\":[null],\"orders\":[\"ASC\"]}]',	1),
(8,	'realtime',	'2025-08-19 13:17:47.441',	'2025-08-19 13:17:47.441',	'[\"create(\\\"any\\\")\"]',	'realtime',	'[{\"$id\":\"container\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"timestamp\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"value\",\"type\":\"string\",\"size\":16384,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_timestamp\",\"type\":\"key\",\"attributes\":[\"timestamp\"],\"lengths\":[],\"orders\":[\"DESC\"]}]',	1),
(9,	'rules',	'2025-08-19 13:17:47.531',	'2025-08-19 13:17:47.531',	'[\"create(\\\"any\\\")\"]',	'rules',	'[{\"$id\":\"projectId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"projectInternalId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"domain\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"type\",\"type\":\"string\",\"size\":32,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"trigger\",\"type\":\"string\",\"size\":32,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":\"\",\"format\":\"\"},{\"$id\":\"redirectUrl\",\"type\":\"string\",\"size\":2048,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":\"\",\"format\":\"\"},{\"$id\":\"redirectStatusCode\",\"type\":\"integer\",\"size\":0,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"deploymentResourceType\",\"type\":\"string\",\"size\":32,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":\"\",\"format\":\"\"},{\"$id\":\"deploymentId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":\"\",\"format\":\"\"},{\"$id\":\"deploymentInternalId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":\"\",\"format\":\"\"},{\"$id\":\"deploymentResourceId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":\"\",\"format\":\"\"},{\"$id\":\"deploymentResourceInternalId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":\"\",\"format\":\"\"},{\"$id\":\"deploymentVcsProviderBranch\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":\"\",\"format\":\"\"},{\"$id\":\"status\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"certificateId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"search\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"owner\",\"type\":\"string\",\"size\":16,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":\"\",\"format\":\"\"},{\"$id\":\"region\",\"type\":\"string\",\"size\":16,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_domain\",\"type\":\"unique\",\"attributes\":[\"domain\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_projectInternalId\",\"type\":\"key\",\"attributes\":[\"projectInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_projectId\",\"type\":\"key\",\"attributes\":[\"projectId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_type\",\"type\":\"key\",\"attributes\":[\"type\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_trigger\",\"type\":\"key\",\"attributes\":[\"trigger\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_deploymentResourceType\",\"type\":\"key\",\"attributes\":[\"deploymentResourceType\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_deploymentResourceId\",\"type\":\"key\",\"attributes\":[\"deploymentResourceId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_deploymentResourceInternalId\",\"type\":\"key\",\"attributes\":[\"deploymentResourceInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_deploymentId\",\"type\":\"key\",\"attributes\":[\"deploymentId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_deploymentInternalId\",\"type\":\"key\",\"attributes\":[\"deploymentInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_deploymentVcsProviderBranch\",\"type\":\"key\",\"attributes\":[\"deploymentVcsProviderBranch\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_owner\",\"type\":\"key\",\"attributes\":[\"owner\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_region\",\"type\":\"key\",\"attributes\":[\"region\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_piid_riid_rt\",\"type\":\"key\",\"attributes\":[\"projectInternalId\",\"deploymentInternalId\",\"deploymentResourceType\"],\"lengths\":[],\"orders\":[]}]',	1),
(10,	'installations',	'2025-08-19 13:17:47.584',	'2025-08-19 13:17:47.584',	'[\"create(\\\"any\\\")\"]',	'installations',	'[{\"$id\":\"projectId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"projectInternalId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"providerInstallationId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"organization\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"provider\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"personal\",\"type\":\"boolean\",\"size\":0,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":false,\"format\":\"\"},{\"$id\":\"personalAccessToken\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"encrypt\"],\"default\":null,\"format\":\"\"},{\"$id\":\"personalAccessTokenExpiry\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"personalRefreshToken\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"encrypt\"],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_projectInternalId\",\"type\":\"key\",\"attributes\":[\"projectInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_projectId\",\"type\":\"key\",\"attributes\":[\"projectId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_providerInstallationId\",\"type\":\"key\",\"attributes\":[\"providerInstallationId\"],\"lengths\":[null],\"orders\":[\"ASC\"]}]',	1),
(11,	'repositories',	'2025-08-19 13:17:47.642',	'2025-08-19 13:17:47.642',	'[\"create(\\\"any\\\")\"]',	'repositories',	'[{\"$id\":\"installationId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"installationInternalId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"projectId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"projectInternalId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"providerRepositoryId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"resourceId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"resourceInternalId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"resourceType\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"providerPullRequestIds\",\"type\":\"string\",\"size\":128,\"required\":false,\"signed\":true,\"array\":true,\"filters\":[],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_installationId\",\"type\":\"key\",\"attributes\":[\"installationId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_installationInternalId\",\"type\":\"key\",\"attributes\":[\"installationInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_projectInternalId\",\"type\":\"key\",\"attributes\":[\"projectInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_projectId\",\"type\":\"key\",\"attributes\":[\"projectId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_providerRepositoryId\",\"type\":\"key\",\"attributes\":[\"providerRepositoryId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_resourceId\",\"type\":\"key\",\"attributes\":[\"resourceId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_resourceInternalId\",\"type\":\"key\",\"attributes\":[\"resourceInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_resourceType\",\"type\":\"key\",\"attributes\":[\"resourceType\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_piid_riid_rt\",\"type\":\"key\",\"attributes\":[\"projectInternalId\",\"resourceInternalId\",\"resourceType\"],\"lengths\":[],\"orders\":[]}]',	1),
(12,	'vcsComments',	'2025-08-19 13:17:47.696',	'2025-08-19 13:17:47.696',	'[\"create(\\\"any\\\")\"]',	'vcsComments',	'[{\"$id\":\"installationId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"installationInternalId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"projectId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"projectInternalId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"providerRepositoryId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"providerCommentId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"providerPullRequestId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"providerBranch\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_installationId\",\"type\":\"key\",\"attributes\":[\"installationId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_installationInternalId\",\"type\":\"key\",\"attributes\":[\"installationInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_projectInternalId\",\"type\":\"key\",\"attributes\":[\"projectInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_projectId\",\"type\":\"key\",\"attributes\":[\"projectId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_providerRepositoryId\",\"type\":\"key\",\"attributes\":[\"providerRepositoryId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_providerPullRequestId\",\"type\":\"key\",\"attributes\":[\"providerPullRequestId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_providerBranch\",\"type\":\"key\",\"attributes\":[\"providerBranch\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_piid_prid_rt\",\"type\":\"key\",\"attributes\":[\"projectInternalId\",\"providerRepositoryId\"],\"lengths\":[],\"orders\":[]}]',	1),
(13,	'vcsCommentLocks',	'2025-08-19 13:17:47.733',	'2025-08-19 13:17:47.733',	'[\"create(\\\"any\\\")\"]',	'vcsCommentLocks',	'[]',	'[]',	1),
(14,	'cache',	'2025-08-19 13:17:47.774',	'2025-08-19 13:17:47.774',	'[\"create(\\\"any\\\")\"]',	'cache',	'[{\"$id\":\"resource\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"resourceType\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"mimeType\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"accessedAt\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"signature\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_accessedAt\",\"type\":\"key\",\"attributes\":[\"accessedAt\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_resource\",\"type\":\"key\",\"attributes\":[\"resource\"],\"lengths\":[],\"orders\":[]}]',	1),
(15,	'users',	'2025-08-19 13:17:47.867',	'2025-08-19 13:17:47.867',	'[\"create(\\\"any\\\")\"]',	'users',	'[{\"$id\":\"name\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"email\",\"type\":\"string\",\"size\":320,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"phone\",\"type\":\"string\",\"size\":16,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"status\",\"type\":\"boolean\",\"size\":0,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"labels\",\"type\":\"string\",\"size\":128,\"required\":false,\"signed\":true,\"array\":true,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"passwordHistory\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":true,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"password\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"encrypt\"],\"default\":null,\"format\":\"\"},{\"$id\":\"hash\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":\"argon2\",\"format\":\"\"},{\"$id\":\"hashOptions\",\"type\":\"string\",\"size\":65535,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"json\"],\"default\":{\"type\":\"argon2\",\"memoryCost\":2048,\"timeCost\":4,\"threads\":3},\"format\":\"\"},{\"$id\":\"passwordUpdate\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"prefs\",\"type\":\"string\",\"size\":65535,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"json\"],\"default\":{},\"format\":\"\"},{\"$id\":\"registration\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"emailVerification\",\"type\":\"boolean\",\"size\":0,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"phoneVerification\",\"type\":\"boolean\",\"size\":0,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"reset\",\"type\":\"boolean\",\"size\":0,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"mfa\",\"type\":\"boolean\",\"size\":0,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"mfaRecoveryCodes\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":true,\"filters\":[\"encrypt\"],\"default\":[],\"format\":\"\"},{\"$id\":\"authenticators\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"subQueryAuthenticators\"],\"default\":null,\"format\":\"\"},{\"$id\":\"sessions\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"subQuerySessions\"],\"default\":null,\"format\":\"\"},{\"$id\":\"tokens\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"subQueryTokens\"],\"default\":null,\"format\":\"\"},{\"$id\":\"challenges\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"subQueryChallenges\"],\"default\":null,\"format\":\"\"},{\"$id\":\"memberships\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"subQueryMemberships\"],\"default\":null,\"format\":\"\"},{\"$id\":\"targets\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"subQueryTargets\"],\"default\":null,\"format\":\"\"},{\"$id\":\"search\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"userSearch\"],\"default\":null,\"format\":\"\"},{\"$id\":\"accessedAt\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_name\",\"type\":\"key\",\"attributes\":[\"name\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_email\",\"type\":\"unique\",\"attributes\":[\"email\"],\"lengths\":[256],\"orders\":[\"ASC\"]},{\"$id\":\"_key_phone\",\"type\":\"unique\",\"attributes\":[\"phone\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_status\",\"type\":\"key\",\"attributes\":[\"status\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_passwordUpdate\",\"type\":\"key\",\"attributes\":[\"passwordUpdate\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_registration\",\"type\":\"key\",\"attributes\":[\"registration\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_emailVerification\",\"type\":\"key\",\"attributes\":[\"emailVerification\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_phoneVerification\",\"type\":\"key\",\"attributes\":[\"phoneVerification\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_accessedAt\",\"type\":\"key\",\"attributes\":[\"accessedAt\"],\"lengths\":[],\"orders\":[]}]',	1),
(16,	'tokens',	'2025-08-19 13:17:47.914',	'2025-08-19 13:17:47.914',	'[\"create(\\\"any\\\")\"]',	'tokens',	'[{\"$id\":\"userInternalId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"userId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"type\",\"type\":\"integer\",\"size\":0,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"secret\",\"type\":\"string\",\"size\":512,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"encrypt\"],\"default\":null,\"format\":\"\"},{\"$id\":\"expire\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"userAgent\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"ip\",\"type\":\"string\",\"size\":45,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_user\",\"type\":\"key\",\"attributes\":[\"userInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]}]',	1),
(17,	'authenticators',	'2025-08-19 13:17:47.958',	'2025-08-19 13:17:47.958',	'[\"create(\\\"any\\\")\"]',	'authenticators',	'[{\"$id\":\"userInternalId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"userId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"type\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"verified\",\"type\":\"boolean\",\"size\":0,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":false,\"format\":\"\"},{\"$id\":\"data\",\"type\":\"string\",\"size\":65535,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"json\",\"encrypt\"],\"default\":[],\"format\":\"\"}]',	'[{\"$id\":\"_key_userInternalId\",\"type\":\"key\",\"attributes\":[\"userInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]}]',	1),
(18,	'challenges',	'2025-08-19 13:17:48.007',	'2025-08-19 13:17:48.007',	'[\"create(\\\"any\\\")\"]',	'challenges',	'[{\"$id\":\"userInternalId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"userId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"type\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"token\",\"type\":\"string\",\"size\":512,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"encrypt\"],\"default\":null,\"format\":\"\"},{\"$id\":\"code\",\"type\":\"string\",\"size\":512,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"encrypt\"],\"default\":null,\"format\":\"\"},{\"$id\":\"expire\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_user\",\"type\":\"key\",\"attributes\":[\"userInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]}]',	1),
(19,	'sessions',	'2025-08-19 13:17:48.062',	'2025-08-19 13:17:48.062',	'[\"create(\\\"any\\\")\"]',	'sessions',	'[{\"$id\":\"userInternalId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"userId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"provider\",\"type\":\"string\",\"size\":128,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"providerUid\",\"type\":\"string\",\"size\":2048,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"providerAccessToken\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"encrypt\"],\"default\":null,\"format\":\"\"},{\"$id\":\"providerAccessTokenExpiry\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"providerRefreshToken\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"encrypt\"],\"default\":null,\"format\":\"\"},{\"$id\":\"secret\",\"type\":\"string\",\"size\":512,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"encrypt\"],\"default\":null,\"format\":\"\"},{\"$id\":\"userAgent\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"ip\",\"type\":\"string\",\"size\":45,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"countryCode\",\"type\":\"string\",\"size\":2,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"osCode\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"osName\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"osVersion\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"clientType\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"clientCode\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"clientName\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"clientVersion\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"clientEngine\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"clientEngineVersion\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"deviceName\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"deviceBrand\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"deviceModel\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"factors\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":true,\"filters\":[],\"default\":[],\"format\":\"\"},{\"$id\":\"expire\",\"type\":\"datetime\",\"size\":0,\"required\":true,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"mfaUpdatedAt\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_provider_providerUid\",\"type\":\"key\",\"attributes\":[\"provider\",\"providerUid\"],\"lengths\":[null,128],\"orders\":[\"ASC\",\"ASC\"]},{\"$id\":\"_key_user\",\"type\":\"key\",\"attributes\":[\"userInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]}]',	1),
(20,	'identities',	'2025-08-19 13:17:48.126',	'2025-08-19 13:17:48.126',	'[\"create(\\\"any\\\")\"]',	'identities',	'[{\"$id\":\"userInternalId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"userId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"provider\",\"type\":\"string\",\"size\":128,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"providerUid\",\"type\":\"string\",\"size\":2048,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"providerEmail\",\"type\":\"string\",\"size\":320,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"providerAccessToken\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"encrypt\"],\"default\":null,\"format\":\"\"},{\"$id\":\"providerAccessTokenExpiry\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"providerRefreshToken\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"encrypt\"],\"default\":null,\"format\":\"\"},{\"$id\":\"secrets\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"json\",\"encrypt\"],\"default\":[],\"format\":\"\"},{\"$id\":\"scopes\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":true,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"expire\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_userInternalId_provider_providerUid\",\"type\":\"unique\",\"attributes\":[\"userInternalId\",\"provider\",\"providerUid\"],\"lengths\":[11,null,128],\"orders\":[\"ASC\",\"ASC\"]},{\"$id\":\"_key_provider_providerUid\",\"type\":\"unique\",\"attributes\":[\"provider\",\"providerUid\"],\"lengths\":[null,128],\"orders\":[\"ASC\",\"ASC\"]},{\"$id\":\"_key_userId\",\"type\":\"key\",\"attributes\":[\"userId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_userInternalId\",\"type\":\"key\",\"attributes\":[\"userInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_provider\",\"type\":\"key\",\"attributes\":[\"provider\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_providerUid\",\"type\":\"key\",\"attributes\":[\"providerUid\"],\"lengths\":[255],\"orders\":[\"ASC\"]},{\"$id\":\"_key_providerEmail\",\"type\":\"key\",\"attributes\":[\"providerEmail\"],\"lengths\":[255],\"orders\":[\"ASC\"]},{\"$id\":\"_key_providerAccessTokenExpiry\",\"type\":\"key\",\"attributes\":[\"providerAccessTokenExpiry\"],\"lengths\":[],\"orders\":[\"ASC\"]}]',	1),
(21,	'teams',	'2025-08-19 13:17:48.203',	'2025-08-19 13:17:48.203',	'[\"create(\\\"any\\\")\"]',	'teams',	'[{\"$id\":\"name\",\"type\":\"string\",\"size\":128,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"total\",\"type\":\"integer\",\"size\":0,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"search\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"prefs\",\"type\":\"string\",\"size\":65535,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"json\"],\"default\":{},\"format\":\"\"}]',	'[{\"$id\":\"_key_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_name\",\"type\":\"key\",\"attributes\":[\"name\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_total\",\"type\":\"key\",\"attributes\":[\"total\"],\"lengths\":[],\"orders\":[\"ASC\"]}]',	1),
(22,	'memberships',	'2025-08-19 13:17:48.298',	'2025-08-19 13:17:48.298',	'[\"create(\\\"any\\\")\"]',	'memberships',	'[{\"$id\":\"userInternalId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"userId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"teamInternalId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"teamId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"roles\",\"type\":\"string\",\"size\":128,\"required\":false,\"signed\":true,\"array\":true,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"invited\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"joined\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"confirm\",\"type\":\"boolean\",\"size\":0,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"secret\",\"type\":\"string\",\"size\":256,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"encrypt\"],\"default\":null,\"format\":\"\"},{\"$id\":\"search\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_unique\",\"type\":\"unique\",\"attributes\":[\"teamInternalId\",\"userInternalId\"],\"lengths\":[null,null],\"orders\":[\"ASC\",\"ASC\"]},{\"$id\":\"_key_user\",\"type\":\"key\",\"attributes\":[\"userInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_team\",\"type\":\"key\",\"attributes\":[\"teamInternalId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_userId\",\"type\":\"key\",\"attributes\":[\"userId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_teamId\",\"type\":\"key\",\"attributes\":[\"teamId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_invited\",\"type\":\"key\",\"attributes\":[\"invited\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_joined\",\"type\":\"key\",\"attributes\":[\"joined\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_confirm\",\"type\":\"key\",\"attributes\":[\"confirm\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_roles\",\"type\":\"key\",\"attributes\":[\"roles\"],\"lengths\":[255],\"orders\":[null]}]',	1),
(23,	'buckets',	'2025-08-19 13:17:48.406',	'2025-08-19 13:17:48.406',	'[\"create(\\\"any\\\")\"]',	'buckets',	'[{\"$id\":\"enabled\",\"type\":\"boolean\",\"size\":0,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"name\",\"type\":\"string\",\"size\":128,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"fileSecurity\",\"type\":\"boolean\",\"size\":1,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"maximumFileSize\",\"type\":\"integer\",\"size\":8,\"required\":true,\"signed\":false,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"allowedFileExtensions\",\"type\":\"string\",\"size\":64,\"required\":true,\"signed\":true,\"array\":true,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"compression\",\"type\":\"string\",\"size\":10,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"encryption\",\"type\":\"boolean\",\"size\":0,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"antivirus\",\"type\":\"boolean\",\"size\":0,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"search\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_fulltext_name\",\"type\":\"fulltext\",\"attributes\":[\"name\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_enabled\",\"type\":\"key\",\"attributes\":[\"enabled\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_name\",\"type\":\"key\",\"attributes\":[\"name\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_fileSecurity\",\"type\":\"key\",\"attributes\":[\"fileSecurity\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_maximumFileSize\",\"type\":\"key\",\"attributes\":[\"maximumFileSize\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_encryption\",\"type\":\"key\",\"attributes\":[\"encryption\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_antivirus\",\"type\":\"key\",\"attributes\":[\"antivirus\"],\"lengths\":[],\"orders\":[\"ASC\"]}]',	1),
(24,	'stats',	'2025-08-19 13:17:48.459',	'2025-08-19 13:17:48.459',	'[\"create(\\\"any\\\")\"]',	'stats',	'[{\"$id\":\"metric\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"region\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"value\",\"type\":\"integer\",\"size\":8,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"time\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"period\",\"type\":\"string\",\"size\":4,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_time\",\"type\":\"key\",\"attributes\":[\"time\"],\"lengths\":[],\"orders\":[\"DESC\"]},{\"$id\":\"_key_period_time\",\"type\":\"key\",\"attributes\":[\"period\",\"time\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_metric_period_time\",\"type\":\"unique\",\"attributes\":[\"metric\",\"period\",\"time\"],\"lengths\":[],\"orders\":[\"DESC\"]}]',	1),
(25,	'providers',	'2025-08-19 13:17:48.540',	'2025-08-19 13:17:48.540',	'[\"create(\\\"any\\\")\"]',	'providers',	'[{\"$id\":\"name\",\"type\":\"string\",\"size\":128,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"provider\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"type\",\"type\":\"string\",\"size\":128,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"enabled\",\"type\":\"boolean\",\"size\":0,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":true,\"format\":\"\"},{\"$id\":\"credentials\",\"type\":\"string\",\"size\":16384,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[\"json\",\"encrypt\"],\"default\":null,\"format\":\"\"},{\"$id\":\"options\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"json\"],\"default\":[],\"format\":\"\"},{\"$id\":\"search\",\"type\":\"string\",\"size\":65535,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"providerSearch\"],\"default\":\"\",\"format\":\"\"}]',	'[{\"$id\":\"_key_provider\",\"type\":\"key\",\"attributes\":[\"provider\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_name\",\"type\":\"fulltext\",\"attributes\":[\"name\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_type\",\"type\":\"key\",\"attributes\":[\"type\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_enabled_type\",\"type\":\"key\",\"attributes\":[\"enabled\",\"type\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]}]',	1),
(26,	'messages',	'2025-08-19 13:17:48.613',	'2025-08-19 13:17:48.613',	'[\"create(\\\"any\\\")\"]',	'messages',	'[{\"$id\":\"providerType\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"status\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":\"processing\",\"format\":\"\"},{\"$id\":\"data\",\"type\":\"string\",\"size\":65535,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[\"json\"],\"default\":null,\"format\":\"\"},{\"$id\":\"topics\",\"type\":\"string\",\"size\":21845,\"required\":false,\"signed\":true,\"array\":true,\"filters\":[],\"default\":[],\"format\":\"\"},{\"$id\":\"users\",\"type\":\"string\",\"size\":21845,\"required\":false,\"signed\":true,\"array\":true,\"filters\":[],\"default\":[],\"format\":\"\"},{\"$id\":\"targets\",\"type\":\"string\",\"size\":21845,\"required\":false,\"signed\":true,\"array\":true,\"filters\":[],\"default\":[],\"format\":\"\"},{\"$id\":\"scheduledAt\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"scheduleInternalId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"scheduleId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"deliveredAt\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"deliveryErrors\",\"type\":\"string\",\"size\":65535,\"required\":false,\"signed\":true,\"array\":true,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"deliveredTotal\",\"type\":\"integer\",\"size\":0,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":0,\"format\":\"\"},{\"$id\":\"search\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"messageSearch\"],\"default\":\"\",\"format\":\"\"}]',	'[{\"$id\":\"_key_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]}]',	1),
(27,	'topics',	'2025-08-19 13:17:48.690',	'2025-08-19 13:17:48.690',	'[\"create(\\\"any\\\")\"]',	'topics',	'[{\"$id\":\"name\",\"type\":\"string\",\"size\":128,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"subscribe\",\"type\":\"string\",\"size\":128,\"required\":false,\"signed\":true,\"array\":true,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"emailTotal\",\"type\":\"integer\",\"size\":0,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":0,\"format\":\"\"},{\"$id\":\"smsTotal\",\"type\":\"integer\",\"size\":0,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":0,\"format\":\"\"},{\"$id\":\"pushTotal\",\"type\":\"integer\",\"size\":0,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":0,\"format\":\"\"},{\"$id\":\"targets\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"subQueryTopicTargets\"],\"default\":null,\"format\":\"\"},{\"$id\":\"search\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"topicSearch\"],\"default\":\"\",\"format\":\"\"}]',	'[{\"$id\":\"_key_name\",\"type\":\"fulltext\",\"attributes\":[\"name\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[\"ASC\"]}]',	1),
(28,	'subscribers',	'2025-08-19 13:17:48.769',	'2025-08-19 13:17:48.769',	'[\"create(\\\"any\\\")\"]',	'subscribers',	'[{\"$id\":\"targetId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"targetInternalId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"userId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"userInternalId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"topicId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"topicInternalId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"providerType\",\"type\":\"string\",\"size\":128,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"search\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_targetId\",\"type\":\"key\",\"attributes\":[\"targetId\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_targetInternalId\",\"type\":\"key\",\"attributes\":[\"targetInternalId\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_userId\",\"type\":\"key\",\"attributes\":[\"userId\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_userInternalId\",\"type\":\"key\",\"attributes\":[\"userInternalId\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_topicId\",\"type\":\"key\",\"attributes\":[\"topicId\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_topicInternalId\",\"type\":\"key\",\"attributes\":[\"topicInternalId\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_unique_target_topic\",\"type\":\"unique\",\"attributes\":[\"targetInternalId\",\"topicInternalId\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_fulltext_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]}]',	1),
(29,	'targets',	'2025-08-19 13:17:48.828',	'2025-08-19 13:17:48.828',	'[\"create(\\\"any\\\")\"]',	'targets',	'[{\"$id\":\"userId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"userInternalId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"sessionId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"sessionInternalId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"providerType\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"providerId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"providerInternalId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"identifier\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"name\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"expired\",\"type\":\"boolean\",\"size\":0,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":false,\"format\":\"\"}]',	'[{\"$id\":\"_key_userId\",\"type\":\"key\",\"attributes\":[\"userId\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_userInternalId\",\"type\":\"key\",\"attributes\":[\"userInternalId\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_providerId\",\"type\":\"key\",\"attributes\":[\"providerId\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_providerInternalId\",\"type\":\"key\",\"attributes\":[\"providerInternalId\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_identifier\",\"type\":\"unique\",\"attributes\":[\"identifier\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_expired\",\"type\":\"key\",\"attributes\":[\"expired\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_session_internal_id\",\"type\":\"key\",\"attributes\":[\"sessionInternalId\"],\"lengths\":[],\"orders\":[]}]',	1),
(30,	'audit',	'2025-08-19 13:17:48.885',	'2025-08-19 13:17:48.885',	'[\"create(\\\"any\\\")\"]',	'audit',	'[{\"$id\":\"userId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[]},{\"$id\":\"event\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[]},{\"$id\":\"resource\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[]},{\"$id\":\"userAgent\",\"type\":\"string\",\"size\":65534,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[]},{\"$id\":\"ip\",\"type\":\"string\",\"size\":45,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[]},{\"$id\":\"location\",\"type\":\"string\",\"size\":45,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[]},{\"$id\":\"time\",\"type\":\"datetime\",\"format\":\"\",\"size\":0,\"signed\":true,\"required\":false,\"array\":false,\"filters\":[\"datetime\"]},{\"$id\":\"data\",\"type\":\"string\",\"size\":16777216,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"json\"]}]',	'[{\"$id\":\"index2\",\"type\":\"key\",\"attributes\":[\"event\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"index4\",\"type\":\"key\",\"attributes\":[\"userId\",\"event\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"index5\",\"type\":\"key\",\"attributes\":[\"resource\",\"event\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"index-time\",\"type\":\"key\",\"attributes\":[\"time\"],\"lengths\":[],\"orders\":[\"DESC\"]}]',	1),
(31,	'bucket_1',	'2025-08-19 13:17:49.007',	'2025-08-19 13:17:49.007',	'[\"create(\\\"any\\\")\"]',	'bucket_1',	'[{\"$id\":\"bucketId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"bucketInternalId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"name\",\"type\":\"string\",\"size\":2048,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"path\",\"type\":\"string\",\"size\":2048,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"signature\",\"type\":\"string\",\"size\":2048,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"mimeType\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"metadata\",\"type\":\"string\",\"size\":75000,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"json\"],\"default\":null,\"format\":\"\"},{\"$id\":\"sizeOriginal\",\"type\":\"integer\",\"size\":8,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"sizeActual\",\"type\":\"integer\",\"size\":8,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"algorithm\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"comment\",\"type\":\"string\",\"size\":2048,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"openSSLVersion\",\"type\":\"string\",\"size\":64,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"openSSLCipher\",\"type\":\"string\",\"size\":64,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"openSSLTag\",\"type\":\"string\",\"size\":2048,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"openSSLIV\",\"type\":\"string\",\"size\":2048,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"chunksTotal\",\"type\":\"integer\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"chunksUploaded\",\"type\":\"integer\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"transformedAt\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"search\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_bucket\",\"type\":\"key\",\"attributes\":[\"bucketId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_name\",\"type\":\"key\",\"attributes\":[\"name\"],\"lengths\":[256],\"orders\":[\"ASC\"]},{\"$id\":\"_key_signature\",\"type\":\"key\",\"attributes\":[\"signature\"],\"lengths\":[256],\"orders\":[\"ASC\"]},{\"$id\":\"_key_mimeType\",\"type\":\"key\",\"attributes\":[\"mimeType\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_sizeOriginal\",\"type\":\"key\",\"attributes\":[\"sizeOriginal\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_chunksTotal\",\"type\":\"key\",\"attributes\":[\"chunksTotal\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_chunksUploaded\",\"type\":\"key\",\"attributes\":[\"chunksUploaded\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_transformedAt\",\"type\":\"key\",\"attributes\":[\"transformedAt\"],\"lengths\":[],\"orders\":[]}]',	1),
(32,	'bucket_2',	'2025-08-19 13:17:49.105',	'2025-08-19 13:17:49.105',	'[\"create(\\\"any\\\")\"]',	'bucket_2',	'[{\"$id\":\"bucketId\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"bucketInternalId\",\"type\":\"string\",\"size\":255,\"required\":true,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"name\",\"type\":\"string\",\"size\":2048,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"path\",\"type\":\"string\",\"size\":2048,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"signature\",\"type\":\"string\",\"size\":2048,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"mimeType\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"metadata\",\"type\":\"string\",\"size\":75000,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[\"json\"],\"default\":null,\"format\":\"\"},{\"$id\":\"sizeOriginal\",\"type\":\"integer\",\"size\":8,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"sizeActual\",\"type\":\"integer\",\"size\":8,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"algorithm\",\"type\":\"string\",\"size\":255,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"comment\",\"type\":\"string\",\"size\":2048,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"openSSLVersion\",\"type\":\"string\",\"size\":64,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"openSSLCipher\",\"type\":\"string\",\"size\":64,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"openSSLTag\",\"type\":\"string\",\"size\":2048,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"openSSLIV\",\"type\":\"string\",\"size\":2048,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"chunksTotal\",\"type\":\"integer\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"chunksUploaded\",\"type\":\"integer\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"},{\"$id\":\"transformedAt\",\"type\":\"datetime\",\"size\":0,\"required\":false,\"signed\":false,\"array\":false,\"filters\":[\"datetime\"],\"default\":null,\"format\":\"\"},{\"$id\":\"search\",\"type\":\"string\",\"size\":16384,\"required\":false,\"signed\":true,\"array\":false,\"filters\":[],\"default\":null,\"format\":\"\"}]',	'[{\"$id\":\"_key_search\",\"type\":\"fulltext\",\"attributes\":[\"search\"],\"lengths\":[],\"orders\":[]},{\"$id\":\"_key_bucket\",\"type\":\"key\",\"attributes\":[\"bucketId\"],\"lengths\":[null],\"orders\":[\"ASC\"]},{\"$id\":\"_key_name\",\"type\":\"key\",\"attributes\":[\"name\"],\"lengths\":[256],\"orders\":[\"ASC\"]},{\"$id\":\"_key_signature\",\"type\":\"key\",\"attributes\":[\"signature\"],\"lengths\":[256],\"orders\":[\"ASC\"]},{\"$id\":\"_key_mimeType\",\"type\":\"key\",\"attributes\":[\"mimeType\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_sizeOriginal\",\"type\":\"key\",\"attributes\":[\"sizeOriginal\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_chunksTotal\",\"type\":\"key\",\"attributes\":[\"chunksTotal\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_chunksUploaded\",\"type\":\"key\",\"attributes\":[\"chunksUploaded\"],\"lengths\":[],\"orders\":[\"ASC\"]},{\"$id\":\"_key_transformedAt\",\"type\":\"key\",\"attributes\":[\"transformedAt\"],\"lengths\":[],\"orders\":[]}]',	1);

DROP TABLE IF EXISTS `_console__metadata_perms`;
CREATE TABLE `_console__metadata_perms` (
  `_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `_type` varchar(12) NOT NULL,
  `_permission` varchar(255) NOT NULL,
  `_document` varchar(255) NOT NULL,
  PRIMARY KEY (`_id`),
  UNIQUE KEY `_index1` (`_document`,`_type`,`_permission`),
  KEY `_permission` (`_permission`,`_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `_console__metadata_perms` (`_id`, `_type`, `_permission`, `_document`) VALUES
(30,	'create',	'any',	'audit'),
(17,	'create',	'any',	'authenticators'),
(23,	'create',	'any',	'buckets'),
(31,	'create',	'any',	'bucket_1'),
(32,	'create',	'any',	'bucket_2'),
(14,	'create',	'any',	'cache'),
(7,	'create',	'any',	'certificates'),
(18,	'create',	'any',	'challenges'),
(5,	'create',	'any',	'devKeys'),
(20,	'create',	'any',	'identities'),
(10,	'create',	'any',	'installations'),
(4,	'create',	'any',	'keys'),
(22,	'create',	'any',	'memberships'),
(26,	'create',	'any',	'messages'),
(3,	'create',	'any',	'platforms'),
(1,	'create',	'any',	'projects'),
(25,	'create',	'any',	'providers'),
(8,	'create',	'any',	'realtime'),
(11,	'create',	'any',	'repositories'),
(9,	'create',	'any',	'rules'),
(2,	'create',	'any',	'schedules'),
(19,	'create',	'any',	'sessions'),
(24,	'create',	'any',	'stats'),
(28,	'create',	'any',	'subscribers'),
(29,	'create',	'any',	'targets'),
(21,	'create',	'any',	'teams'),
(16,	'create',	'any',	'tokens'),
(27,	'create',	'any',	'topics'),
(15,	'create',	'any',	'users'),
(13,	'create',	'any',	'vcsCommentLocks'),
(12,	'create',	'any',	'vcsComments'),
(6,	'create',	'any',	'webhooks');

-- 2025-08-19 13:44:06 UTC
