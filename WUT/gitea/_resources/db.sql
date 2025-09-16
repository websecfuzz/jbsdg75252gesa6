-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: db
-- Generation Time: Aug 26, 2025 at 10:13 AM
-- Server version: 8.4.6
-- PHP Version: 8.2.27

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `gitea`
--

-- --------------------------------------------------------

--
-- Table structure for table `access`
--

CREATE TABLE `access` (
  `id` bigint NOT NULL,
  `user_id` bigint DEFAULT NULL,
  `repo_id` bigint DEFAULT NULL,
  `mode` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `access_token`
--

CREATE TABLE `access_token` (
  `id` bigint NOT NULL,
  `uid` bigint DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `token_hash` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `token_salt` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `token_last_eight` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `scope` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `action`
--

CREATE TABLE `action` (
  `id` bigint NOT NULL,
  `user_id` bigint DEFAULT NULL,
  `op_type` int DEFAULT NULL,
  `act_user_id` bigint DEFAULT NULL,
  `repo_id` bigint DEFAULT NULL,
  `comment_id` bigint DEFAULT NULL,
  `is_deleted` tinyint(1) NOT NULL DEFAULT '0',
  `ref_name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `is_private` tinyint(1) NOT NULL DEFAULT '0',
  `content` text COLLATE utf8mb4_0900_as_cs,
  `created_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `action_artifact`
--

CREATE TABLE `action_artifact` (
  `id` bigint NOT NULL,
  `run_id` bigint DEFAULT NULL,
  `runner_id` bigint DEFAULT NULL,
  `repo_id` bigint DEFAULT NULL,
  `owner_id` bigint DEFAULT NULL,
  `commit_sha` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `storage_path` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `file_size` bigint DEFAULT NULL,
  `file_compressed_size` bigint DEFAULT NULL,
  `content_encoding` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `artifact_path` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `artifact_name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `status` bigint DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL,
  `expired_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `action_run`
--

CREATE TABLE `action_run` (
  `id` bigint NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `repo_id` bigint DEFAULT NULL,
  `owner_id` bigint DEFAULT NULL,
  `workflow_id` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `index` bigint DEFAULT NULL,
  `trigger_user_id` bigint DEFAULT NULL,
  `schedule_id` bigint DEFAULT NULL,
  `ref` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `commit_sha` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `is_fork_pull_request` tinyint(1) DEFAULT NULL,
  `need_approval` tinyint(1) DEFAULT NULL,
  `approved_by` bigint DEFAULT NULL,
  `event` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `event_payload` longtext COLLATE utf8mb4_0900_as_cs,
  `trigger_event` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `status` int DEFAULT NULL,
  `version` int DEFAULT '0',
  `started` bigint DEFAULT NULL,
  `stopped` bigint DEFAULT NULL,
  `previous_duration` bigint DEFAULT NULL,
  `created` bigint DEFAULT NULL,
  `updated` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `action_runner`
--

CREATE TABLE `action_runner` (
  `id` bigint NOT NULL,
  `uuid` char(36) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `version` varchar(64) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `owner_id` bigint DEFAULT NULL,
  `repo_id` bigint DEFAULT NULL,
  `description` text COLLATE utf8mb4_0900_as_cs,
  `base` int DEFAULT NULL,
  `repo_range` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `token_hash` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `token_salt` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `last_online` bigint DEFAULT NULL,
  `last_active` bigint DEFAULT NULL,
  `agent_labels` text COLLATE utf8mb4_0900_as_cs,
  `ephemeral` tinyint(1) NOT NULL DEFAULT '0',
  `created` bigint DEFAULT NULL,
  `updated` bigint DEFAULT NULL,
  `deleted` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `action_runner_token`
--

CREATE TABLE `action_runner_token` (
  `id` bigint NOT NULL,
  `token` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `owner_id` bigint DEFAULT NULL,
  `repo_id` bigint DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT NULL,
  `created` bigint DEFAULT NULL,
  `updated` bigint DEFAULT NULL,
  `deleted` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `action_run_index`
--

CREATE TABLE `action_run_index` (
  `group_id` bigint NOT NULL,
  `max_index` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `action_run_job`
--

CREATE TABLE `action_run_job` (
  `id` bigint NOT NULL,
  `run_id` bigint DEFAULT NULL,
  `repo_id` bigint DEFAULT NULL,
  `owner_id` bigint DEFAULT NULL,
  `commit_sha` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `is_fork_pull_request` tinyint(1) DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `attempt` bigint DEFAULT NULL,
  `workflow_payload` blob,
  `job_id` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `needs` text COLLATE utf8mb4_0900_as_cs,
  `runs_on` text COLLATE utf8mb4_0900_as_cs,
  `task_id` bigint DEFAULT NULL,
  `status` int DEFAULT NULL,
  `started` bigint DEFAULT NULL,
  `stopped` bigint DEFAULT NULL,
  `created` bigint DEFAULT NULL,
  `updated` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `action_schedule`
--

CREATE TABLE `action_schedule` (
  `id` bigint NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `specs` text COLLATE utf8mb4_0900_as_cs,
  `repo_id` bigint DEFAULT NULL,
  `owner_id` bigint DEFAULT NULL,
  `workflow_id` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `trigger_user_id` bigint DEFAULT NULL,
  `ref` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `commit_sha` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `event` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `event_payload` longtext COLLATE utf8mb4_0900_as_cs,
  `content` blob,
  `created` bigint DEFAULT NULL,
  `updated` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `action_schedule_spec`
--

CREATE TABLE `action_schedule_spec` (
  `id` bigint NOT NULL,
  `repo_id` bigint DEFAULT NULL,
  `schedule_id` bigint DEFAULT NULL,
  `next` bigint DEFAULT NULL,
  `prev` bigint DEFAULT NULL,
  `spec` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `created` bigint DEFAULT NULL,
  `updated` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `action_task`
--

CREATE TABLE `action_task` (
  `id` bigint NOT NULL,
  `job_id` bigint DEFAULT NULL,
  `attempt` bigint DEFAULT NULL,
  `runner_id` bigint DEFAULT NULL,
  `status` int DEFAULT NULL,
  `started` bigint DEFAULT NULL,
  `stopped` bigint DEFAULT NULL,
  `repo_id` bigint DEFAULT NULL,
  `owner_id` bigint DEFAULT NULL,
  `commit_sha` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `is_fork_pull_request` tinyint(1) DEFAULT NULL,
  `token_hash` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `token_salt` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `token_last_eight` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `log_filename` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `log_in_storage` tinyint(1) DEFAULT NULL,
  `log_length` bigint DEFAULT NULL,
  `log_size` bigint DEFAULT NULL,
  `log_indexes` longblob,
  `log_expired` tinyint(1) DEFAULT NULL,
  `created` bigint DEFAULT NULL,
  `updated` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `action_tasks_version`
--

CREATE TABLE `action_tasks_version` (
  `id` bigint NOT NULL,
  `owner_id` bigint DEFAULT NULL,
  `repo_id` bigint DEFAULT NULL,
  `version` bigint DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `action_task_output`
--

CREATE TABLE `action_task_output` (
  `id` bigint NOT NULL,
  `task_id` bigint DEFAULT NULL,
  `output_key` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `output_value` mediumtext COLLATE utf8mb4_0900_as_cs
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `action_task_step`
--

CREATE TABLE `action_task_step` (
  `id` bigint NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `task_id` bigint DEFAULT NULL,
  `index` bigint DEFAULT NULL,
  `repo_id` bigint DEFAULT NULL,
  `status` int DEFAULT NULL,
  `log_index` bigint DEFAULT NULL,
  `log_length` bigint DEFAULT NULL,
  `started` bigint DEFAULT NULL,
  `stopped` bigint DEFAULT NULL,
  `created` bigint DEFAULT NULL,
  `updated` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `action_variable`
--

CREATE TABLE `action_variable` (
  `id` bigint NOT NULL,
  `owner_id` bigint DEFAULT NULL,
  `repo_id` bigint DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `data` longtext COLLATE utf8mb4_0900_as_cs NOT NULL,
  `description` text COLLATE utf8mb4_0900_as_cs,
  `created_unix` bigint NOT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `app_state`
--

CREATE TABLE `app_state` (
  `id` varchar(200) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `revision` bigint DEFAULT NULL,
  `content` longtext COLLATE utf8mb4_0900_as_cs
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

--
-- Dumping data for table `app_state`
--

INSERT INTO `app_state` (`id`, `revision`, `content`) VALUES
('runtime-state', 0, '{\"last_app_path\":\"/usr/local/bin/gitea\",\"last_custom_conf\":\"/etc/gitea/app.ini\"}');

-- --------------------------------------------------------

--
-- Table structure for table `attachment`
--

CREATE TABLE `attachment` (
  `id` bigint NOT NULL,
  `uuid` varchar(40) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `repo_id` bigint DEFAULT NULL,
  `issue_id` bigint DEFAULT NULL,
  `release_id` bigint DEFAULT NULL,
  `uploader_id` bigint DEFAULT '0',
  `comment_id` bigint DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `download_count` bigint DEFAULT '0',
  `size` bigint DEFAULT '0',
  `created_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `auth_token`
--

CREATE TABLE `auth_token` (
  `id` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `token_hash` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `user_id` bigint DEFAULT NULL,
  `expires_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `badge`
--

CREATE TABLE `badge` (
  `id` bigint NOT NULL,
  `slug` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `description` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `image_url` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `branch`
--

CREATE TABLE `branch` (
  `id` bigint NOT NULL,
  `repo_id` bigint DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `commit_id` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `commit_message` text COLLATE utf8mb4_0900_as_cs,
  `pusher_id` bigint DEFAULT NULL,
  `is_deleted` tinyint(1) DEFAULT NULL,
  `deleted_by_id` bigint DEFAULT NULL,
  `deleted_unix` bigint DEFAULT NULL,
  `commit_time` bigint DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `collaboration`
--

CREATE TABLE `collaboration` (
  `id` bigint NOT NULL,
  `repo_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `mode` int NOT NULL DEFAULT '2',
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `comment`
--

CREATE TABLE `comment` (
  `id` bigint NOT NULL,
  `type` int DEFAULT NULL,
  `poster_id` bigint DEFAULT NULL,
  `original_author` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `original_author_id` bigint DEFAULT NULL,
  `issue_id` bigint DEFAULT NULL,
  `label_id` bigint DEFAULT NULL,
  `old_project_id` bigint DEFAULT NULL,
  `project_id` bigint DEFAULT NULL,
  `old_milestone_id` bigint DEFAULT NULL,
  `milestone_id` bigint DEFAULT NULL,
  `time_id` bigint DEFAULT NULL,
  `assignee_id` bigint DEFAULT NULL,
  `removed_assignee` tinyint(1) DEFAULT NULL,
  `assignee_team_id` bigint NOT NULL DEFAULT '0',
  `resolve_doer_id` bigint DEFAULT NULL,
  `old_title` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `new_title` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `old_ref` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `new_ref` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `dependent_issue_id` bigint DEFAULT NULL,
  `commit_id` bigint DEFAULT NULL,
  `line` bigint DEFAULT NULL,
  `tree_path` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `content` longtext COLLATE utf8mb4_0900_as_cs,
  `content_version` int NOT NULL DEFAULT '0',
  `patch` longtext COLLATE utf8mb4_0900_as_cs,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL,
  `commit_sha` varchar(64) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `review_id` bigint DEFAULT NULL,
  `invalidated` tinyint(1) DEFAULT NULL,
  `ref_repo_id` bigint DEFAULT NULL,
  `ref_issue_id` bigint DEFAULT NULL,
  `ref_comment_id` bigint DEFAULT NULL,
  `ref_action` smallint DEFAULT NULL,
  `ref_is_pull` tinyint(1) DEFAULT NULL,
  `comment_meta_data` text COLLATE utf8mb4_0900_as_cs
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `commit_status`
--

CREATE TABLE `commit_status` (
  `id` bigint NOT NULL,
  `index` bigint DEFAULT NULL,
  `repo_id` bigint DEFAULT NULL,
  `state` varchar(7) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `sha` varchar(64) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `target_url` text COLLATE utf8mb4_0900_as_cs,
  `description` text COLLATE utf8mb4_0900_as_cs,
  `context_hash` varchar(64) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `context` text COLLATE utf8mb4_0900_as_cs,
  `creator_id` bigint DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `commit_status_index`
--

CREATE TABLE `commit_status_index` (
  `id` bigint NOT NULL,
  `repo_id` bigint DEFAULT NULL,
  `sha` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `max_index` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `commit_status_summary`
--

CREATE TABLE `commit_status_summary` (
  `id` bigint NOT NULL,
  `repo_id` bigint DEFAULT NULL,
  `sha` varchar(64) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `state` varchar(7) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `target_url` text COLLATE utf8mb4_0900_as_cs
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `dbfs_data`
--

CREATE TABLE `dbfs_data` (
  `id` bigint NOT NULL,
  `revision` bigint NOT NULL,
  `meta_id` bigint NOT NULL,
  `blob_offset` bigint NOT NULL,
  `blob_size` bigint NOT NULL,
  `blob_data` blob NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `dbfs_meta`
--

CREATE TABLE `dbfs_meta` (
  `id` bigint NOT NULL,
  `full_path` varchar(500) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `block_size` bigint NOT NULL,
  `file_size` bigint NOT NULL,
  `create_timestamp` bigint NOT NULL,
  `modify_timestamp` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `deploy_key`
--

CREATE TABLE `deploy_key` (
  `id` bigint NOT NULL,
  `key_id` bigint DEFAULT NULL,
  `repo_id` bigint DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `fingerprint` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `mode` int NOT NULL DEFAULT '1',
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `email_address`
--

CREATE TABLE `email_address` (
  `id` bigint NOT NULL,
  `uid` bigint NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `lower_email` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `is_activated` tinyint(1) DEFAULT NULL,
  `is_primary` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

--
-- Dumping data for table `email_address`
--

INSERT INTO `email_address` (`id`, `uid`, `email`, `lower_email`, `is_activated`, `is_primary`) VALUES
(1, 1, 'admin2@local.co', 'admin2@local.co', 1, 1);

-- --------------------------------------------------------

--
-- Table structure for table `email_hash`
--

CREATE TABLE `email_hash` (
  `hash` varchar(32) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `external_login_user`
--

CREATE TABLE `external_login_user` (
  `external_id` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `user_id` bigint NOT NULL,
  `login_source_id` bigint NOT NULL,
  `raw_data` text COLLATE utf8mb4_0900_as_cs,
  `provider` varchar(25) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `first_name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `last_name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `nick_name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `description` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `avatar_url` text COLLATE utf8mb4_0900_as_cs,
  `location` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `access_token` text COLLATE utf8mb4_0900_as_cs,
  `access_token_secret` text COLLATE utf8mb4_0900_as_cs,
  `refresh_token` text COLLATE utf8mb4_0900_as_cs,
  `expires_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `follow`
--

CREATE TABLE `follow` (
  `id` bigint NOT NULL,
  `user_id` bigint DEFAULT NULL,
  `follow_id` bigint DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `gpg_key`
--

CREATE TABLE `gpg_key` (
  `id` bigint NOT NULL,
  `owner_id` bigint NOT NULL,
  `key_id` char(16) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `primary_key_id` char(16) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `content` mediumtext COLLATE utf8mb4_0900_as_cs NOT NULL,
  `created_unix` bigint DEFAULT NULL,
  `expired_unix` bigint DEFAULT NULL,
  `added_unix` bigint DEFAULT NULL,
  `emails` text COLLATE utf8mb4_0900_as_cs,
  `verified` tinyint(1) NOT NULL DEFAULT '0',
  `can_sign` tinyint(1) DEFAULT NULL,
  `can_encrypt_comms` tinyint(1) DEFAULT NULL,
  `can_encrypt_storage` tinyint(1) DEFAULT NULL,
  `can_certify` tinyint(1) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `gpg_key_import`
--

CREATE TABLE `gpg_key_import` (
  `key_id` char(16) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `content` mediumtext COLLATE utf8mb4_0900_as_cs NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `hook_task`
--

CREATE TABLE `hook_task` (
  `id` bigint NOT NULL,
  `hook_id` bigint DEFAULT NULL,
  `uuid` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `payload_content` longtext COLLATE utf8mb4_0900_as_cs,
  `payload_version` int DEFAULT '1',
  `event_type` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `is_delivered` tinyint(1) DEFAULT NULL,
  `delivered` bigint DEFAULT NULL,
  `is_succeed` tinyint(1) DEFAULT NULL,
  `request_content` longtext COLLATE utf8mb4_0900_as_cs,
  `response_content` longtext COLLATE utf8mb4_0900_as_cs
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `issue`
--

CREATE TABLE `issue` (
  `id` bigint NOT NULL,
  `repo_id` bigint DEFAULT NULL,
  `index` bigint DEFAULT NULL,
  `poster_id` bigint DEFAULT NULL,
  `original_author` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `original_author_id` bigint DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `content` longtext COLLATE utf8mb4_0900_as_cs,
  `content_version` int NOT NULL DEFAULT '0',
  `milestone_id` bigint DEFAULT NULL,
  `priority` int DEFAULT NULL,
  `is_closed` tinyint(1) DEFAULT NULL,
  `is_pull` tinyint(1) DEFAULT NULL,
  `num_comments` int DEFAULT NULL,
  `ref` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `deadline_unix` bigint DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL,
  `closed_unix` bigint DEFAULT NULL,
  `is_locked` tinyint(1) NOT NULL DEFAULT '0',
  `time_estimate` bigint NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `issue_assignees`
--

CREATE TABLE `issue_assignees` (
  `id` bigint NOT NULL,
  `assignee_id` bigint DEFAULT NULL,
  `issue_id` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `issue_content_history`
--

CREATE TABLE `issue_content_history` (
  `id` bigint NOT NULL,
  `poster_id` bigint DEFAULT NULL,
  `issue_id` bigint DEFAULT NULL,
  `comment_id` bigint DEFAULT NULL,
  `edited_unix` bigint DEFAULT NULL,
  `content_text` longtext COLLATE utf8mb4_0900_as_cs,
  `is_first_created` tinyint(1) DEFAULT NULL,
  `is_deleted` tinyint(1) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `issue_dependency`
--

CREATE TABLE `issue_dependency` (
  `id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `issue_id` bigint NOT NULL,
  `dependency_id` bigint NOT NULL,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `issue_index`
--

CREATE TABLE `issue_index` (
  `group_id` bigint NOT NULL,
  `max_index` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `issue_label`
--

CREATE TABLE `issue_label` (
  `id` bigint NOT NULL,
  `issue_id` bigint DEFAULT NULL,
  `label_id` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `issue_pin`
--

CREATE TABLE `issue_pin` (
  `id` bigint NOT NULL,
  `repo_id` bigint NOT NULL,
  `issue_id` bigint NOT NULL,
  `is_pull` tinyint(1) NOT NULL,
  `pin_order` int DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `issue_user`
--

CREATE TABLE `issue_user` (
  `id` bigint NOT NULL,
  `uid` bigint DEFAULT NULL,
  `issue_id` bigint DEFAULT NULL,
  `is_read` tinyint(1) DEFAULT NULL,
  `is_mentioned` tinyint(1) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `issue_watch`
--

CREATE TABLE `issue_watch` (
  `id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `issue_id` bigint NOT NULL,
  `is_watching` tinyint(1) NOT NULL,
  `created_unix` bigint NOT NULL,
  `updated_unix` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `label`
--

CREATE TABLE `label` (
  `id` bigint NOT NULL,
  `repo_id` bigint DEFAULT NULL,
  `org_id` bigint DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `exclusive` tinyint(1) DEFAULT NULL,
  `exclusive_order` int DEFAULT '0',
  `description` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `color` varchar(7) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `num_issues` int DEFAULT NULL,
  `num_closed_issues` int DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL,
  `archived_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `language_stat`
--

CREATE TABLE `language_stat` (
  `id` bigint NOT NULL,
  `repo_id` bigint NOT NULL,
  `commit_id` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `is_primary` tinyint(1) DEFAULT NULL,
  `language` varchar(50) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `size` bigint NOT NULL DEFAULT '0',
  `created_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `lfs_lock`
--

CREATE TABLE `lfs_lock` (
  `id` bigint NOT NULL,
  `repo_id` bigint NOT NULL,
  `owner_id` bigint NOT NULL,
  `path` text COLLATE utf8mb4_0900_as_cs,
  `created` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `lfs_meta_object`
--

CREATE TABLE `lfs_meta_object` (
  `id` bigint NOT NULL,
  `oid` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `size` bigint NOT NULL,
  `repository_id` bigint NOT NULL,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `login_source`
--

CREATE TABLE `login_source` (
  `id` bigint NOT NULL,
  `type` int DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '0',
  `is_sync_enabled` tinyint(1) NOT NULL DEFAULT '0',
  `two_factor_policy` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL DEFAULT '',
  `cfg` text COLLATE utf8mb4_0900_as_cs,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `milestone`
--

CREATE TABLE `milestone` (
  `id` bigint NOT NULL,
  `repo_id` bigint DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `content` text COLLATE utf8mb4_0900_as_cs,
  `is_closed` tinyint(1) DEFAULT NULL,
  `num_issues` int DEFAULT NULL,
  `num_closed_issues` int DEFAULT NULL,
  `completeness` int DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL,
  `deadline_unix` bigint DEFAULT NULL,
  `closed_date_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `mirror`
--

CREATE TABLE `mirror` (
  `id` bigint NOT NULL,
  `repo_id` bigint DEFAULT NULL,
  `interval` bigint DEFAULT NULL,
  `enable_prune` tinyint(1) NOT NULL DEFAULT '1',
  `updated_unix` bigint DEFAULT NULL,
  `next_update_unix` bigint DEFAULT NULL,
  `lfs_enabled` tinyint(1) NOT NULL DEFAULT '0',
  `lfs_endpoint` text COLLATE utf8mb4_0900_as_cs,
  `remote_address` varchar(2048) COLLATE utf8mb4_0900_as_cs DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `notice`
--

CREATE TABLE `notice` (
  `id` bigint NOT NULL,
  `type` int DEFAULT NULL,
  `description` text COLLATE utf8mb4_0900_as_cs,
  `created_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `notification`
--

CREATE TABLE `notification` (
  `id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `repo_id` bigint NOT NULL,
  `status` smallint NOT NULL,
  `source` smallint NOT NULL,
  `issue_id` bigint NOT NULL,
  `commit_id` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `comment_id` bigint DEFAULT NULL,
  `updated_by` bigint NOT NULL,
  `created_unix` bigint NOT NULL,
  `updated_unix` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `oauth2_application`
--

CREATE TABLE `oauth2_application` (
  `id` bigint NOT NULL,
  `uid` bigint DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `client_id` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `client_secret` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `confidential_client` tinyint(1) NOT NULL DEFAULT '1',
  `skip_secondary_authorization` tinyint(1) NOT NULL DEFAULT '0',
  `redirect_uris` text COLLATE utf8mb4_0900_as_cs,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

--
-- Dumping data for table `oauth2_application`
--

INSERT INTO `oauth2_application` (`id`, `uid`, `name`, `client_id`, `client_secret`, `confidential_client`, `skip_secondary_authorization`, `redirect_uris`, `created_unix`, `updated_unix`) VALUES
(1, 0, 'git-credential-oauth', 'a4792ccc-144e-407e-86c9-5e7d8d9c3269', '', 0, 0, '[\"http://127.0.0.1\",\"https://127.0.0.1\"]', 1756202589, 1756202589),
(2, 0, 'Git Credential Manager', 'e90ee53c-94e2-48ac-9358-a874fb9e0662', '', 0, 0, '[\"http://127.0.0.1\",\"https://127.0.0.1\"]', 1756202589, 1756202589),
(3, 0, 'tea', 'd57cb8c4-630c-4168-8324-ec79935e18d4', '', 0, 0, '[\"http://127.0.0.1\",\"https://127.0.0.1\"]', 1756202589, 1756202589);

-- --------------------------------------------------------

--
-- Table structure for table `oauth2_authorization_code`
--

CREATE TABLE `oauth2_authorization_code` (
  `id` bigint NOT NULL,
  `grant_id` bigint DEFAULT NULL,
  `code` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `code_challenge` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `code_challenge_method` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `redirect_uri` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `valid_until` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `oauth2_grant`
--

CREATE TABLE `oauth2_grant` (
  `id` bigint NOT NULL,
  `user_id` bigint DEFAULT NULL,
  `application_id` bigint DEFAULT NULL,
  `counter` bigint NOT NULL DEFAULT '1',
  `scope` text COLLATE utf8mb4_0900_as_cs,
  `nonce` text COLLATE utf8mb4_0900_as_cs,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `org_user`
--

CREATE TABLE `org_user` (
  `id` bigint NOT NULL,
  `uid` bigint DEFAULT NULL,
  `org_id` bigint DEFAULT NULL,
  `is_public` tinyint(1) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `package`
--

CREATE TABLE `package` (
  `id` bigint NOT NULL,
  `owner_id` bigint NOT NULL,
  `repo_id` bigint DEFAULT NULL,
  `type` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `lower_name` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `semver_compatible` tinyint(1) NOT NULL DEFAULT '0',
  `is_internal` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `package_blob`
--

CREATE TABLE `package_blob` (
  `id` bigint NOT NULL,
  `size` bigint NOT NULL DEFAULT '0',
  `hash_md5` char(32) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `hash_sha1` char(40) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `hash_sha256` char(64) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `hash_sha512` char(128) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `created_unix` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `package_blob_upload`
--

CREATE TABLE `package_blob_upload` (
  `id` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `bytes_received` bigint NOT NULL DEFAULT '0',
  `hash_state_bytes` blob,
  `created_unix` bigint NOT NULL,
  `updated_unix` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `package_cleanup_rule`
--

CREATE TABLE `package_cleanup_rule` (
  `id` bigint NOT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT '0',
  `owner_id` bigint NOT NULL DEFAULT '0',
  `type` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `keep_count` int NOT NULL DEFAULT '0',
  `keep_pattern` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL DEFAULT '',
  `remove_days` int NOT NULL DEFAULT '0',
  `remove_pattern` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL DEFAULT '',
  `match_full_name` tinyint(1) NOT NULL DEFAULT '0',
  `created_unix` bigint NOT NULL DEFAULT '0',
  `updated_unix` bigint NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `package_file`
--

CREATE TABLE `package_file` (
  `id` bigint NOT NULL,
  `version_id` bigint NOT NULL,
  `blob_id` bigint NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `lower_name` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `composite_key` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `is_lead` tinyint(1) NOT NULL DEFAULT '0',
  `created_unix` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `package_property`
--

CREATE TABLE `package_property` (
  `id` bigint NOT NULL,
  `ref_type` bigint NOT NULL,
  `ref_id` bigint NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `value` text COLLATE utf8mb4_0900_as_cs NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `package_version`
--

CREATE TABLE `package_version` (
  `id` bigint NOT NULL,
  `package_id` bigint NOT NULL,
  `creator_id` bigint NOT NULL DEFAULT '0',
  `version` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `lower_version` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `created_unix` bigint NOT NULL,
  `is_internal` tinyint(1) NOT NULL DEFAULT '0',
  `metadata_json` longtext COLLATE utf8mb4_0900_as_cs,
  `download_count` bigint NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `project`
--

CREATE TABLE `project` (
  `id` bigint NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `description` text COLLATE utf8mb4_0900_as_cs,
  `owner_id` bigint DEFAULT NULL,
  `repo_id` bigint DEFAULT NULL,
  `creator_id` bigint NOT NULL,
  `is_closed` tinyint(1) DEFAULT NULL,
  `board_type` int UNSIGNED DEFAULT NULL,
  `card_type` int UNSIGNED DEFAULT NULL,
  `type` int UNSIGNED DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL,
  `closed_date_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `project_board`
--

CREATE TABLE `project_board` (
  `id` bigint NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `default` tinyint(1) NOT NULL DEFAULT '0',
  `sorting` int NOT NULL DEFAULT '0',
  `color` varchar(7) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `project_id` bigint NOT NULL,
  `creator_id` bigint NOT NULL,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `project_issue`
--

CREATE TABLE `project_issue` (
  `id` bigint NOT NULL,
  `issue_id` bigint DEFAULT NULL,
  `project_id` bigint DEFAULT NULL,
  `project_board_id` bigint DEFAULT NULL,
  `sorting` bigint NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `protected_branch`
--

CREATE TABLE `protected_branch` (
  `id` bigint NOT NULL,
  `repo_id` bigint DEFAULT NULL,
  `branch_name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `priority` bigint NOT NULL DEFAULT '0',
  `can_push` tinyint(1) NOT NULL DEFAULT '0',
  `enable_whitelist` tinyint(1) DEFAULT NULL,
  `whitelist_user_i_ds` text COLLATE utf8mb4_0900_as_cs,
  `whitelist_team_i_ds` text COLLATE utf8mb4_0900_as_cs,
  `enable_merge_whitelist` tinyint(1) NOT NULL DEFAULT '0',
  `whitelist_deploy_keys` tinyint(1) NOT NULL DEFAULT '0',
  `merge_whitelist_user_i_ds` text COLLATE utf8mb4_0900_as_cs,
  `merge_whitelist_team_i_ds` text COLLATE utf8mb4_0900_as_cs,
  `can_force_push` tinyint(1) NOT NULL DEFAULT '0',
  `enable_force_push_allowlist` tinyint(1) NOT NULL DEFAULT '0',
  `force_push_allowlist_user_i_ds` text COLLATE utf8mb4_0900_as_cs,
  `force_push_allowlist_team_i_ds` text COLLATE utf8mb4_0900_as_cs,
  `force_push_allowlist_deploy_keys` tinyint(1) NOT NULL DEFAULT '0',
  `enable_status_check` tinyint(1) NOT NULL DEFAULT '0',
  `status_check_contexts` text COLLATE utf8mb4_0900_as_cs,
  `enable_approvals_whitelist` tinyint(1) NOT NULL DEFAULT '0',
  `approvals_whitelist_user_i_ds` text COLLATE utf8mb4_0900_as_cs,
  `approvals_whitelist_team_i_ds` text COLLATE utf8mb4_0900_as_cs,
  `required_approvals` bigint NOT NULL DEFAULT '0',
  `block_on_rejected_reviews` tinyint(1) NOT NULL DEFAULT '0',
  `block_on_official_review_requests` tinyint(1) NOT NULL DEFAULT '0',
  `block_on_outdated_branch` tinyint(1) NOT NULL DEFAULT '0',
  `dismiss_stale_approvals` tinyint(1) NOT NULL DEFAULT '0',
  `ignore_stale_approvals` tinyint(1) NOT NULL DEFAULT '0',
  `require_signed_commits` tinyint(1) NOT NULL DEFAULT '0',
  `protected_file_patterns` text COLLATE utf8mb4_0900_as_cs,
  `unprotected_file_patterns` text COLLATE utf8mb4_0900_as_cs,
  `block_admin_merge_override` tinyint(1) NOT NULL DEFAULT '0',
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `protected_tag`
--

CREATE TABLE `protected_tag` (
  `id` bigint NOT NULL,
  `repo_id` bigint DEFAULT NULL,
  `name_pattern` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `allowlist_user_i_ds` text COLLATE utf8mb4_0900_as_cs,
  `allowlist_team_i_ds` text COLLATE utf8mb4_0900_as_cs,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `public_key`
--

CREATE TABLE `public_key` (
  `id` bigint NOT NULL,
  `owner_id` bigint NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `fingerprint` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `content` mediumtext COLLATE utf8mb4_0900_as_cs NOT NULL,
  `mode` int NOT NULL DEFAULT '2',
  `type` int NOT NULL DEFAULT '1',
  `login_source_id` bigint NOT NULL DEFAULT '0',
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL,
  `verified` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `pull_auto_merge`
--

CREATE TABLE `pull_auto_merge` (
  `id` bigint NOT NULL,
  `pull_id` bigint DEFAULT NULL,
  `doer_id` bigint NOT NULL,
  `merge_style` varchar(30) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `message` longtext COLLATE utf8mb4_0900_as_cs,
  `delete_branch_after_merge` tinyint(1) DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `pull_request`
--

CREATE TABLE `pull_request` (
  `id` bigint NOT NULL,
  `type` int DEFAULT NULL,
  `status` int DEFAULT NULL,
  `conflicted_files` text COLLATE utf8mb4_0900_as_cs,
  `commits_ahead` int DEFAULT NULL,
  `commits_behind` int DEFAULT NULL,
  `changed_protected_files` text COLLATE utf8mb4_0900_as_cs,
  `issue_id` bigint DEFAULT NULL,
  `index` bigint DEFAULT NULL,
  `head_repo_id` bigint DEFAULT NULL,
  `base_repo_id` bigint DEFAULT NULL,
  `head_branch` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `base_branch` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `merge_base` varchar(64) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `allow_maintainer_edit` tinyint(1) NOT NULL DEFAULT '0',
  `has_merged` tinyint(1) DEFAULT NULL,
  `merged_commit_id` varchar(64) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `merger_id` bigint DEFAULT NULL,
  `merged_unix` bigint DEFAULT NULL,
  `flow` int NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `push_mirror`
--

CREATE TABLE `push_mirror` (
  `id` bigint NOT NULL,
  `repo_id` bigint DEFAULT NULL,
  `remote_name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `remote_address` varchar(2048) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `sync_on_commit` tinyint(1) NOT NULL DEFAULT '1',
  `interval` bigint DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL,
  `last_update` bigint DEFAULT NULL,
  `last_error` text COLLATE utf8mb4_0900_as_cs
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `reaction`
--

CREATE TABLE `reaction` (
  `id` bigint NOT NULL,
  `type` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `issue_id` bigint NOT NULL,
  `comment_id` bigint DEFAULT NULL,
  `user_id` bigint NOT NULL,
  `original_author_id` bigint NOT NULL DEFAULT '0',
  `original_author` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `release`
--

CREATE TABLE `release` (
  `id` bigint NOT NULL,
  `repo_id` bigint DEFAULT NULL,
  `publisher_id` bigint DEFAULT NULL,
  `tag_name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `original_author` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `original_author_id` bigint DEFAULT NULL,
  `lower_tag_name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `target` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `title` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `sha1` varchar(64) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `num_commits` bigint DEFAULT NULL,
  `note` text COLLATE utf8mb4_0900_as_cs,
  `is_draft` tinyint(1) NOT NULL DEFAULT '0',
  `is_prerelease` tinyint(1) NOT NULL DEFAULT '0',
  `is_tag` tinyint(1) NOT NULL DEFAULT '0',
  `created_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `renamed_branch`
--

CREATE TABLE `renamed_branch` (
  `id` bigint NOT NULL,
  `repo_id` bigint NOT NULL,
  `from` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `to` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `repository`
--

CREATE TABLE `repository` (
  `id` bigint NOT NULL,
  `owner_id` bigint DEFAULT NULL,
  `owner_name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `lower_name` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `description` text COLLATE utf8mb4_0900_as_cs,
  `website` varchar(2048) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `original_service_type` int DEFAULT NULL,
  `original_url` varchar(2048) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `default_branch` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `default_wiki_branch` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `num_watches` int DEFAULT NULL,
  `num_stars` int DEFAULT NULL,
  `num_forks` int DEFAULT NULL,
  `num_issues` int DEFAULT NULL,
  `num_closed_issues` int DEFAULT NULL,
  `num_pulls` int DEFAULT NULL,
  `num_closed_pulls` int DEFAULT NULL,
  `num_milestones` int NOT NULL DEFAULT '0',
  `num_closed_milestones` int NOT NULL DEFAULT '0',
  `num_projects` int NOT NULL DEFAULT '0',
  `num_closed_projects` int NOT NULL DEFAULT '0',
  `num_action_runs` int NOT NULL DEFAULT '0',
  `num_closed_action_runs` int NOT NULL DEFAULT '0',
  `is_private` tinyint(1) DEFAULT NULL,
  `is_empty` tinyint(1) DEFAULT NULL,
  `is_archived` tinyint(1) DEFAULT NULL,
  `is_mirror` tinyint(1) DEFAULT NULL,
  `status` int NOT NULL DEFAULT '0',
  `is_fork` tinyint(1) NOT NULL DEFAULT '0',
  `fork_id` bigint DEFAULT NULL,
  `is_template` tinyint(1) NOT NULL DEFAULT '0',
  `template_id` bigint DEFAULT NULL,
  `size` bigint NOT NULL DEFAULT '0',
  `git_size` bigint NOT NULL DEFAULT '0',
  `lfs_size` bigint NOT NULL DEFAULT '0',
  `is_fsck_enabled` tinyint(1) NOT NULL DEFAULT '1',
  `close_issues_via_commit_in_any_branch` tinyint(1) NOT NULL DEFAULT '0',
  `topics` text COLLATE utf8mb4_0900_as_cs,
  `object_format_name` varchar(6) COLLATE utf8mb4_0900_as_cs NOT NULL DEFAULT 'sha1',
  `trust_model` int DEFAULT NULL,
  `avatar` varchar(64) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL,
  `archived_unix` bigint DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `repo_archiver`
--

CREATE TABLE `repo_archiver` (
  `id` bigint NOT NULL,
  `repo_id` bigint DEFAULT NULL,
  `type` int DEFAULT NULL,
  `status` int DEFAULT NULL,
  `commit_id` varchar(64) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `created_unix` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `repo_indexer_status`
--

CREATE TABLE `repo_indexer_status` (
  `id` bigint NOT NULL,
  `repo_id` bigint DEFAULT NULL,
  `commit_sha` varchar(64) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `indexer_type` int NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `repo_license`
--

CREATE TABLE `repo_license` (
  `id` bigint NOT NULL,
  `repo_id` bigint NOT NULL,
  `commit_id` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `license` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `repo_redirect`
--

CREATE TABLE `repo_redirect` (
  `id` bigint NOT NULL,
  `owner_id` bigint DEFAULT NULL,
  `lower_name` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `redirect_repo_id` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `repo_topic`
--

CREATE TABLE `repo_topic` (
  `repo_id` bigint NOT NULL,
  `topic_id` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `repo_transfer`
--

CREATE TABLE `repo_transfer` (
  `id` bigint NOT NULL,
  `doer_id` bigint DEFAULT NULL,
  `recipient_id` bigint DEFAULT NULL,
  `repo_id` bigint DEFAULT NULL,
  `team_i_ds` text COLLATE utf8mb4_0900_as_cs,
  `created_unix` bigint NOT NULL,
  `updated_unix` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `repo_unit`
--

CREATE TABLE `repo_unit` (
  `id` bigint NOT NULL,
  `repo_id` bigint DEFAULT NULL,
  `type` int DEFAULT NULL,
  `config` text COLLATE utf8mb4_0900_as_cs,
  `created_unix` bigint DEFAULT NULL,
  `anonymous_access_mode` int NOT NULL DEFAULT '0',
  `everyone_access_mode` int NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `review`
--

CREATE TABLE `review` (
  `id` bigint NOT NULL,
  `type` int DEFAULT NULL,
  `reviewer_id` bigint DEFAULT NULL,
  `reviewer_team_id` bigint NOT NULL DEFAULT '0',
  `original_author` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `original_author_id` bigint DEFAULT NULL,
  `issue_id` bigint DEFAULT NULL,
  `content` text COLLATE utf8mb4_0900_as_cs,
  `official` tinyint(1) NOT NULL DEFAULT '0',
  `commit_id` varchar(64) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `stale` tinyint(1) NOT NULL DEFAULT '0',
  `dismissed` tinyint(1) NOT NULL DEFAULT '0',
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `review_state`
--

CREATE TABLE `review_state` (
  `id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `pull_id` bigint NOT NULL DEFAULT '0',
  `commit_sha` varchar(64) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `updated_files` text COLLATE utf8mb4_0900_as_cs NOT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `secret`
--

CREATE TABLE `secret` (
  `id` bigint NOT NULL,
  `owner_id` bigint NOT NULL,
  `repo_id` bigint NOT NULL DEFAULT '0',
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `data` longtext COLLATE utf8mb4_0900_as_cs,
  `description` text COLLATE utf8mb4_0900_as_cs,
  `created_unix` bigint NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `session`
--

CREATE TABLE `session` (
  `key` char(16) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `data` blob,
  `expiry` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `star`
--

CREATE TABLE `star` (
  `id` bigint NOT NULL,
  `uid` bigint DEFAULT NULL,
  `repo_id` bigint DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `stopwatch`
--

CREATE TABLE `stopwatch` (
  `id` bigint NOT NULL,
  `issue_id` bigint DEFAULT NULL,
  `user_id` bigint DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `system_setting`
--

CREATE TABLE `system_setting` (
  `id` bigint NOT NULL,
  `setting_key` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `setting_value` text COLLATE utf8mb4_0900_as_cs,
  `version` int DEFAULT NULL,
  `created` bigint DEFAULT NULL,
  `updated` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

--
-- Dumping data for table `system_setting`
--

INSERT INTO `system_setting` (`id`, `setting_key`, `setting_value`, `version`, `created`, `updated`) VALUES
(1, 'revision', '', 1, 1756202967, 1756202967);

-- --------------------------------------------------------

--
-- Table structure for table `task`
--

CREATE TABLE `task` (
  `id` bigint NOT NULL,
  `doer_id` bigint DEFAULT NULL,
  `owner_id` bigint DEFAULT NULL,
  `repo_id` bigint DEFAULT NULL,
  `type` int DEFAULT NULL,
  `status` int DEFAULT NULL,
  `start_time` bigint DEFAULT NULL,
  `end_time` bigint DEFAULT NULL,
  `payload_content` text COLLATE utf8mb4_0900_as_cs,
  `message` text COLLATE utf8mb4_0900_as_cs,
  `created` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `team`
--

CREATE TABLE `team` (
  `id` bigint NOT NULL,
  `org_id` bigint DEFAULT NULL,
  `lower_name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `description` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `authorize` int DEFAULT NULL,
  `num_repos` int DEFAULT NULL,
  `num_members` int DEFAULT NULL,
  `includes_all_repositories` tinyint(1) NOT NULL DEFAULT '0',
  `can_create_org_repo` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `team_invite`
--

CREATE TABLE `team_invite` (
  `id` bigint NOT NULL,
  `token` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL DEFAULT '',
  `inviter_id` bigint NOT NULL DEFAULT '0',
  `org_id` bigint NOT NULL DEFAULT '0',
  `team_id` bigint NOT NULL DEFAULT '0',
  `email` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL DEFAULT '',
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `team_repo`
--

CREATE TABLE `team_repo` (
  `id` bigint NOT NULL,
  `org_id` bigint DEFAULT NULL,
  `team_id` bigint DEFAULT NULL,
  `repo_id` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `team_unit`
--

CREATE TABLE `team_unit` (
  `id` bigint NOT NULL,
  `org_id` bigint DEFAULT NULL,
  `team_id` bigint DEFAULT NULL,
  `type` int DEFAULT NULL,
  `access_mode` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `team_user`
--

CREATE TABLE `team_user` (
  `id` bigint NOT NULL,
  `org_id` bigint DEFAULT NULL,
  `team_id` bigint DEFAULT NULL,
  `uid` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `topic`
--

CREATE TABLE `topic` (
  `id` bigint NOT NULL,
  `name` varchar(50) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `repo_count` int DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `tracked_time`
--

CREATE TABLE `tracked_time` (
  `id` bigint NOT NULL,
  `issue_id` bigint DEFAULT NULL,
  `user_id` bigint DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL,
  `time` bigint NOT NULL,
  `deleted` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `two_factor`
--

CREATE TABLE `two_factor` (
  `id` bigint NOT NULL,
  `uid` bigint DEFAULT NULL,
  `secret` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `scratch_salt` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `scratch_hash` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `last_used_passcode` varchar(10) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `upload`
--

CREATE TABLE `upload` (
  `id` bigint NOT NULL,
  `uuid` varchar(40) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `user`
--

CREATE TABLE `user` (
  `id` bigint NOT NULL,
  `lower_name` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `full_name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `keep_email_private` tinyint(1) DEFAULT NULL,
  `email_notifications_preference` varchar(20) COLLATE utf8mb4_0900_as_cs NOT NULL DEFAULT 'enabled',
  `passwd` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `passwd_hash_algo` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL DEFAULT 'argon2',
  `must_change_password` tinyint(1) NOT NULL DEFAULT '0',
  `login_type` int DEFAULT NULL,
  `login_source` bigint NOT NULL DEFAULT '0',
  `login_name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `type` int DEFAULT NULL,
  `location` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `website` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `rands` varchar(32) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `salt` varchar(32) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `language` varchar(5) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `description` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL,
  `last_login_unix` bigint DEFAULT NULL,
  `last_repo_visibility` tinyint(1) DEFAULT NULL,
  `max_repo_creation` int NOT NULL DEFAULT '-1',
  `is_active` tinyint(1) DEFAULT NULL,
  `is_admin` tinyint(1) DEFAULT NULL,
  `is_restricted` tinyint(1) NOT NULL DEFAULT '0',
  `allow_git_hook` tinyint(1) DEFAULT NULL,
  `allow_import_local` tinyint(1) DEFAULT NULL,
  `allow_create_organization` tinyint(1) DEFAULT '1',
  `prohibit_login` tinyint(1) NOT NULL DEFAULT '0',
  `avatar` varchar(2048) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `avatar_email` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `use_custom_avatar` tinyint(1) DEFAULT NULL,
  `num_followers` int DEFAULT NULL,
  `num_following` int NOT NULL DEFAULT '0',
  `num_stars` int DEFAULT NULL,
  `num_repos` int DEFAULT NULL,
  `num_teams` int DEFAULT NULL,
  `num_members` int DEFAULT NULL,
  `visibility` int NOT NULL DEFAULT '0',
  `repo_admin_change_team_access` tinyint(1) NOT NULL DEFAULT '0',
  `diff_view_style` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL DEFAULT '',
  `theme` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL DEFAULT '',
  `keep_activity_private` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

--
-- Dumping data for table `user`
--

INSERT INTO `user` (`id`, `lower_name`, `name`, `full_name`, `email`, `keep_email_private`, `email_notifications_preference`, `passwd`, `passwd_hash_algo`, `must_change_password`, `login_type`, `login_source`, `login_name`, `type`, `location`, `website`, `rands`, `salt`, `language`, `description`, `created_unix`, `updated_unix`, `last_login_unix`, `last_repo_visibility`, `max_repo_creation`, `is_active`, `is_admin`, `is_restricted`, `allow_git_hook`, `allow_import_local`, `allow_create_organization`, `prohibit_login`, `avatar`, `avatar_email`, `use_custom_avatar`, `num_followers`, `num_following`, `num_stars`, `num_repos`, `num_teams`, `num_members`, `visibility`, `repo_admin_change_team_access`, `diff_view_style`, `theme`, `keep_activity_private`) VALUES
(1, 'admin', 'admin', '', 'admin2@local.co', 0, 'enabled', 'fc3c74258571b1a9d2e4c56d2c499b4e4886dec51d7731751b34a4e737dc612a184f609901cdf1281d3ff29573052344be60', 'pbkdf2$50000$50', 0, 0, 0, '', 0, '', '', '206b9200b73677a51eb5df559b4e3f95', '365729bde3949a9ff64b2ba3f2af1729', 'en-US', '', 1756202967, 1756202967, 1756202967, 0, -1, 1, 1, 0, 0, 0, 1, 0, '538da185eedef9a6e35186ff52094d44', 'admin2@local.co', 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 'gitea-auto', 0);

-- --------------------------------------------------------

--
-- Table structure for table `user_badge`
--

CREATE TABLE `user_badge` (
  `id` bigint NOT NULL,
  `badge_id` bigint DEFAULT NULL,
  `user_id` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `user_blocking`
--

CREATE TABLE `user_blocking` (
  `id` bigint NOT NULL,
  `blocker_id` bigint DEFAULT NULL,
  `blockee_id` bigint DEFAULT NULL,
  `note` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `user_open_id`
--

CREATE TABLE `user_open_id` (
  `id` bigint NOT NULL,
  `uid` bigint NOT NULL,
  `uri` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `show` tinyint(1) DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `user_redirect`
--

CREATE TABLE `user_redirect` (
  `id` bigint NOT NULL,
  `lower_name` varchar(255) COLLATE utf8mb4_0900_as_cs NOT NULL,
  `redirect_user_id` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `user_setting`
--

CREATE TABLE `user_setting` (
  `id` bigint NOT NULL,
  `user_id` bigint DEFAULT NULL,
  `setting_key` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `setting_value` text COLLATE utf8mb4_0900_as_cs
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `version`
--

CREATE TABLE `version` (
  `id` bigint NOT NULL,
  `version` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

--
-- Dumping data for table `version`
--

INSERT INTO `version` (`id`, `version`) VALUES
(1, 321);

-- --------------------------------------------------------

--
-- Table structure for table `watch`
--

CREATE TABLE `watch` (
  `id` bigint NOT NULL,
  `user_id` bigint DEFAULT NULL,
  `repo_id` bigint DEFAULT NULL,
  `mode` smallint NOT NULL DEFAULT '1',
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `webauthn_credential`
--

CREATE TABLE `webauthn_credential` (
  `id` bigint NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `lower_name` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `user_id` bigint DEFAULT NULL,
  `credential_id` varbinary(1024) DEFAULT NULL,
  `public_key` blob,
  `attestation_type` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `aaguid` blob,
  `sign_count` bigint DEFAULT NULL,
  `clone_warning` tinyint(1) DEFAULT NULL,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

-- --------------------------------------------------------

--
-- Table structure for table `webhook`
--

CREATE TABLE `webhook` (
  `id` bigint NOT NULL,
  `repo_id` bigint DEFAULT NULL,
  `owner_id` bigint DEFAULT NULL,
  `is_system_webhook` tinyint(1) DEFAULT NULL,
  `url` text COLLATE utf8mb4_0900_as_cs,
  `http_method` varchar(255) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `content_type` int DEFAULT NULL,
  `secret` text COLLATE utf8mb4_0900_as_cs,
  `events` text COLLATE utf8mb4_0900_as_cs,
  `is_active` tinyint(1) DEFAULT NULL,
  `type` varchar(16) COLLATE utf8mb4_0900_as_cs DEFAULT NULL,
  `meta` text COLLATE utf8mb4_0900_as_cs,
  `last_status` int DEFAULT NULL,
  `header_authorization_encrypted` text COLLATE utf8mb4_0900_as_cs,
  `created_unix` bigint DEFAULT NULL,
  `updated_unix` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_as_cs ROW_FORMAT=DYNAMIC;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `access`
--
ALTER TABLE `access`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_access_s` (`user_id`,`repo_id`);

--
-- Indexes for table `access_token`
--
ALTER TABLE `access_token`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_access_token_token_hash` (`token_hash`),
  ADD KEY `IDX_access_token_token_last_eight` (`token_last_eight`),
  ADD KEY `IDX_access_token_created_unix` (`created_unix`),
  ADD KEY `IDX_access_token_updated_unix` (`updated_unix`),
  ADD KEY `IDX_access_token_uid` (`uid`);

--
-- Indexes for table `action`
--
ALTER TABLE `action`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_action_au_r_c_u_d` (`act_user_id`,`repo_id`,`created_unix`,`user_id`,`is_deleted`),
  ADD KEY `IDX_action_r_u_d` (`repo_id`,`user_id`,`is_deleted`),
  ADD KEY `IDX_action_c_u_d` (`created_unix`,`user_id`,`is_deleted`),
  ADD KEY `IDX_action_c_u` (`user_id`,`is_deleted`),
  ADD KEY `IDX_action_au_c_u` (`act_user_id`,`created_unix`,`user_id`),
  ADD KEY `IDX_action_user_id` (`user_id`),
  ADD KEY `IDX_action_comment_id` (`comment_id`);

--
-- Indexes for table `action_artifact`
--
ALTER TABLE `action_artifact`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_action_artifact_runid_name_path` (`run_id`,`artifact_path`,`artifact_name`),
  ADD KEY `IDX_action_artifact_artifact_name` (`artifact_name`),
  ADD KEY `IDX_action_artifact_status` (`status`),
  ADD KEY `IDX_action_artifact_updated_unix` (`updated_unix`),
  ADD KEY `IDX_action_artifact_expired_unix` (`expired_unix`),
  ADD KEY `IDX_action_artifact_run_id` (`run_id`),
  ADD KEY `IDX_action_artifact_repo_id` (`repo_id`),
  ADD KEY `IDX_action_artifact_artifact_path` (`artifact_path`);

--
-- Indexes for table `action_run`
--
ALTER TABLE `action_run`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_action_run_repo_index` (`repo_id`,`index`),
  ADD KEY `IDX_action_run_index` (`index`),
  ADD KEY `IDX_action_run_trigger_user_id` (`trigger_user_id`),
  ADD KEY `IDX_action_run_ref` (`ref`),
  ADD KEY `IDX_action_run_repo_id` (`repo_id`),
  ADD KEY `IDX_action_run_owner_id` (`owner_id`),
  ADD KEY `IDX_action_run_approved_by` (`approved_by`),
  ADD KEY `IDX_action_run_status` (`status`),
  ADD KEY `IDX_action_run_workflow_id` (`workflow_id`);

--
-- Indexes for table `action_runner`
--
ALTER TABLE `action_runner`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_action_runner_token_hash` (`token_hash`),
  ADD UNIQUE KEY `UQE_action_runner_uuid` (`uuid`),
  ADD KEY `IDX_action_runner_owner_id` (`owner_id`),
  ADD KEY `IDX_action_runner_repo_id` (`repo_id`),
  ADD KEY `IDX_action_runner_last_online` (`last_online`),
  ADD KEY `IDX_action_runner_last_active` (`last_active`);

--
-- Indexes for table `action_runner_token`
--
ALTER TABLE `action_runner_token`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_action_runner_token_token` (`token`),
  ADD KEY `IDX_action_runner_token_owner_id` (`owner_id`),
  ADD KEY `IDX_action_runner_token_repo_id` (`repo_id`);

--
-- Indexes for table `action_run_index`
--
ALTER TABLE `action_run_index`
  ADD PRIMARY KEY (`group_id`),
  ADD KEY `IDX_action_run_index_max_index` (`max_index`);

--
-- Indexes for table `action_run_job`
--
ALTER TABLE `action_run_job`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_action_run_job_commit_sha` (`commit_sha`),
  ADD KEY `IDX_action_run_job_status` (`status`),
  ADD KEY `IDX_action_run_job_updated` (`updated`),
  ADD KEY `IDX_action_run_job_run_id` (`run_id`),
  ADD KEY `IDX_action_run_job_repo_id` (`repo_id`),
  ADD KEY `IDX_action_run_job_owner_id` (`owner_id`);

--
-- Indexes for table `action_schedule`
--
ALTER TABLE `action_schedule`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_action_schedule_repo_id` (`repo_id`),
  ADD KEY `IDX_action_schedule_owner_id` (`owner_id`);

--
-- Indexes for table `action_schedule_spec`
--
ALTER TABLE `action_schedule_spec`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_action_schedule_spec_repo_id` (`repo_id`),
  ADD KEY `IDX_action_schedule_spec_schedule_id` (`schedule_id`),
  ADD KEY `IDX_action_schedule_spec_next` (`next`);

--
-- Indexes for table `action_task`
--
ALTER TABLE `action_task`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_action_task_token_hash` (`token_hash`),
  ADD KEY `IDX_action_task_status` (`status`),
  ADD KEY `IDX_action_task_started` (`started`),
  ADD KEY `IDX_action_task_stopped_log_expired` (`stopped`,`log_expired`),
  ADD KEY `IDX_action_task_commit_sha` (`commit_sha`),
  ADD KEY `IDX_action_task_runner_id` (`runner_id`),
  ADD KEY `IDX_action_task_repo_id` (`repo_id`),
  ADD KEY `IDX_action_task_owner_id` (`owner_id`),
  ADD KEY `IDX_action_task_token_last_eight` (`token_last_eight`),
  ADD KEY `IDX_action_task_updated` (`updated`);

--
-- Indexes for table `action_tasks_version`
--
ALTER TABLE `action_tasks_version`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_action_tasks_version_owner_repo` (`owner_id`,`repo_id`),
  ADD KEY `IDX_action_tasks_version_repo_id` (`repo_id`);

--
-- Indexes for table `action_task_output`
--
ALTER TABLE `action_task_output`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_action_task_output_task_id_output_key` (`task_id`,`output_key`),
  ADD KEY `IDX_action_task_output_task_id` (`task_id`);

--
-- Indexes for table `action_task_step`
--
ALTER TABLE `action_task_step`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_action_task_step_task_index` (`task_id`,`index`),
  ADD KEY `IDX_action_task_step_task_id` (`task_id`),
  ADD KEY `IDX_action_task_step_index` (`index`),
  ADD KEY `IDX_action_task_step_repo_id` (`repo_id`),
  ADD KEY `IDX_action_task_step_status` (`status`);

--
-- Indexes for table `action_variable`
--
ALTER TABLE `action_variable`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_action_variable_owner_repo_name` (`owner_id`,`repo_id`,`name`),
  ADD KEY `IDX_action_variable_repo_id` (`repo_id`);

--
-- Indexes for table `app_state`
--
ALTER TABLE `app_state`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `attachment`
--
ALTER TABLE `attachment`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_attachment_uuid` (`uuid`),
  ADD KEY `IDX_attachment_repo_id` (`repo_id`),
  ADD KEY `IDX_attachment_issue_id` (`issue_id`),
  ADD KEY `IDX_attachment_release_id` (`release_id`),
  ADD KEY `IDX_attachment_uploader_id` (`uploader_id`),
  ADD KEY `IDX_attachment_comment_id` (`comment_id`);

--
-- Indexes for table `auth_token`
--
ALTER TABLE `auth_token`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_auth_token_user_id` (`user_id`),
  ADD KEY `IDX_auth_token_expires_unix` (`expires_unix`);

--
-- Indexes for table `badge`
--
ALTER TABLE `badge`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_badge_slug` (`slug`);

--
-- Indexes for table `branch`
--
ALTER TABLE `branch`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_branch_s` (`repo_id`,`name`),
  ADD KEY `IDX_branch_is_deleted` (`is_deleted`),
  ADD KEY `IDX_branch_deleted_unix` (`deleted_unix`);

--
-- Indexes for table `collaboration`
--
ALTER TABLE `collaboration`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_collaboration_s` (`repo_id`,`user_id`),
  ADD KEY `IDX_collaboration_repo_id` (`repo_id`),
  ADD KEY `IDX_collaboration_user_id` (`user_id`),
  ADD KEY `IDX_collaboration_created_unix` (`created_unix`),
  ADD KEY `IDX_collaboration_updated_unix` (`updated_unix`);

--
-- Indexes for table `comment`
--
ALTER TABLE `comment`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_comment_type` (`type`),
  ADD KEY `IDX_comment_poster_id` (`poster_id`),
  ADD KEY `IDX_comment_dependent_issue_id` (`dependent_issue_id`),
  ADD KEY `IDX_comment_review_id` (`review_id`),
  ADD KEY `IDX_comment_ref_repo_id` (`ref_repo_id`),
  ADD KEY `IDX_comment_ref_issue_id` (`ref_issue_id`),
  ADD KEY `IDX_comment_ref_comment_id` (`ref_comment_id`),
  ADD KEY `IDX_comment_issue_id` (`issue_id`),
  ADD KEY `IDX_comment_created_unix` (`created_unix`),
  ADD KEY `IDX_comment_updated_unix` (`updated_unix`);

--
-- Indexes for table `commit_status`
--
ALTER TABLE `commit_status`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_commit_status_repo_sha_index` (`index`,`repo_id`,`sha`),
  ADD KEY `IDX_commit_status_index` (`index`),
  ADD KEY `IDX_commit_status_repo_id` (`repo_id`),
  ADD KEY `IDX_commit_status_sha` (`sha`),
  ADD KEY `IDX_commit_status_context_hash` (`context_hash`),
  ADD KEY `IDX_commit_status_created_unix` (`created_unix`),
  ADD KEY `IDX_commit_status_updated_unix` (`updated_unix`);

--
-- Indexes for table `commit_status_index`
--
ALTER TABLE `commit_status_index`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_commit_status_index_repo_sha` (`repo_id`,`sha`),
  ADD KEY `IDX_commit_status_index_max_index` (`max_index`);

--
-- Indexes for table `commit_status_summary`
--
ALTER TABLE `commit_status_summary`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_commit_status_summary_repo_id_sha` (`repo_id`,`sha`),
  ADD KEY `IDX_commit_status_summary_repo_id` (`repo_id`),
  ADD KEY `IDX_commit_status_summary_sha` (`sha`);

--
-- Indexes for table `dbfs_data`
--
ALTER TABLE `dbfs_data`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_dbfs_data_meta_offset` (`meta_id`,`blob_offset`);

--
-- Indexes for table `dbfs_meta`
--
ALTER TABLE `dbfs_meta`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_dbfs_meta_full_path` (`full_path`);

--
-- Indexes for table `deploy_key`
--
ALTER TABLE `deploy_key`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_deploy_key_s` (`key_id`,`repo_id`),
  ADD KEY `IDX_deploy_key_key_id` (`key_id`),
  ADD KEY `IDX_deploy_key_repo_id` (`repo_id`);

--
-- Indexes for table `email_address`
--
ALTER TABLE `email_address`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_email_address_email` (`email`),
  ADD UNIQUE KEY `UQE_email_address_lower_email` (`lower_email`),
  ADD KEY `IDX_email_address_uid` (`uid`);

--
-- Indexes for table `email_hash`
--
ALTER TABLE `email_hash`
  ADD PRIMARY KEY (`hash`),
  ADD UNIQUE KEY `UQE_email_hash_email` (`email`);

--
-- Indexes for table `external_login_user`
--
ALTER TABLE `external_login_user`
  ADD PRIMARY KEY (`external_id`,`login_source_id`),
  ADD KEY `IDX_external_login_user_user_id` (`user_id`),
  ADD KEY `IDX_external_login_user_provider` (`provider`);

--
-- Indexes for table `follow`
--
ALTER TABLE `follow`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_follow_follow` (`user_id`,`follow_id`),
  ADD KEY `IDX_follow_created_unix` (`created_unix`);

--
-- Indexes for table `gpg_key`
--
ALTER TABLE `gpg_key`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_gpg_key_owner_id` (`owner_id`),
  ADD KEY `IDX_gpg_key_key_id` (`key_id`);

--
-- Indexes for table `gpg_key_import`
--
ALTER TABLE `gpg_key_import`
  ADD PRIMARY KEY (`key_id`);

--
-- Indexes for table `hook_task`
--
ALTER TABLE `hook_task`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_hook_task_uuid` (`uuid`),
  ADD KEY `IDX_hook_task_hook_id` (`hook_id`);

--
-- Indexes for table `issue`
--
ALTER TABLE `issue`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_issue_repo_index` (`repo_id`,`index`),
  ADD KEY `IDX_issue_deadline_unix` (`deadline_unix`),
  ADD KEY `IDX_issue_closed_unix` (`closed_unix`),
  ADD KEY `IDX_issue_repo_id` (`repo_id`),
  ADD KEY `IDX_issue_is_closed` (`is_closed`),
  ADD KEY `IDX_issue_is_pull` (`is_pull`),
  ADD KEY `IDX_issue_created_unix` (`created_unix`),
  ADD KEY `IDX_issue_updated_unix` (`updated_unix`),
  ADD KEY `IDX_issue_poster_id` (`poster_id`),
  ADD KEY `IDX_issue_original_author_id` (`original_author_id`),
  ADD KEY `IDX_issue_milestone_id` (`milestone_id`);

--
-- Indexes for table `issue_assignees`
--
ALTER TABLE `issue_assignees`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_issue_assignees_assignee_id` (`assignee_id`),
  ADD KEY `IDX_issue_assignees_issue_id` (`issue_id`);

--
-- Indexes for table `issue_content_history`
--
ALTER TABLE `issue_content_history`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_issue_content_history_issue_id` (`issue_id`),
  ADD KEY `IDX_issue_content_history_comment_id` (`comment_id`),
  ADD KEY `IDX_issue_content_history_edited_unix` (`edited_unix`);

--
-- Indexes for table `issue_dependency`
--
ALTER TABLE `issue_dependency`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_issue_dependency_issue_dependency` (`issue_id`,`dependency_id`);

--
-- Indexes for table `issue_index`
--
ALTER TABLE `issue_index`
  ADD PRIMARY KEY (`group_id`),
  ADD KEY `IDX_issue_index_max_index` (`max_index`);

--
-- Indexes for table `issue_label`
--
ALTER TABLE `issue_label`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_issue_label_s` (`issue_id`,`label_id`);

--
-- Indexes for table `issue_pin`
--
ALTER TABLE `issue_pin`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_issue_pin_s` (`repo_id`,`issue_id`);

--
-- Indexes for table `issue_user`
--
ALTER TABLE `issue_user`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_issue_user_uid_to_issue` (`uid`,`issue_id`),
  ADD KEY `IDX_issue_user_uid` (`uid`),
  ADD KEY `IDX_issue_user_issue_id` (`issue_id`);

--
-- Indexes for table `issue_watch`
--
ALTER TABLE `issue_watch`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_issue_watch_watch` (`user_id`,`issue_id`);

--
-- Indexes for table `label`
--
ALTER TABLE `label`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_label_repo_id` (`repo_id`),
  ADD KEY `IDX_label_org_id` (`org_id`),
  ADD KEY `IDX_label_created_unix` (`created_unix`),
  ADD KEY `IDX_label_updated_unix` (`updated_unix`);

--
-- Indexes for table `language_stat`
--
ALTER TABLE `language_stat`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_language_stat_s` (`repo_id`,`language`),
  ADD KEY `IDX_language_stat_repo_id` (`repo_id`),
  ADD KEY `IDX_language_stat_language` (`language`),
  ADD KEY `IDX_language_stat_created_unix` (`created_unix`);

--
-- Indexes for table `lfs_lock`
--
ALTER TABLE `lfs_lock`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_lfs_lock_repo_id` (`repo_id`),
  ADD KEY `IDX_lfs_lock_owner_id` (`owner_id`);

--
-- Indexes for table `lfs_meta_object`
--
ALTER TABLE `lfs_meta_object`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_lfs_meta_object_s` (`oid`,`repository_id`),
  ADD KEY `IDX_lfs_meta_object_oid` (`oid`),
  ADD KEY `IDX_lfs_meta_object_repository_id` (`repository_id`),
  ADD KEY `IDX_lfs_meta_object_updated_unix` (`updated_unix`);

--
-- Indexes for table `login_source`
--
ALTER TABLE `login_source`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_login_source_name` (`name`),
  ADD KEY `IDX_login_source_is_active` (`is_active`),
  ADD KEY `IDX_login_source_is_sync_enabled` (`is_sync_enabled`),
  ADD KEY `IDX_login_source_created_unix` (`created_unix`),
  ADD KEY `IDX_login_source_updated_unix` (`updated_unix`);

--
-- Indexes for table `milestone`
--
ALTER TABLE `milestone`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_milestone_created_unix` (`created_unix`),
  ADD KEY `IDX_milestone_updated_unix` (`updated_unix`),
  ADD KEY `IDX_milestone_repo_id` (`repo_id`);

--
-- Indexes for table `mirror`
--
ALTER TABLE `mirror`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_mirror_next_update_unix` (`next_update_unix`),
  ADD KEY `IDX_mirror_repo_id` (`repo_id`),
  ADD KEY `IDX_mirror_updated_unix` (`updated_unix`);

--
-- Indexes for table `notice`
--
ALTER TABLE `notice`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_notice_created_unix` (`created_unix`);

--
-- Indexes for table `notification`
--
ALTER TABLE `notification`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_notification_idx_notification_repo_id` (`repo_id`),
  ADD KEY `IDX_notification_idx_notification_status` (`status`),
  ADD KEY `IDX_notification_idx_notification_source` (`source`),
  ADD KEY `IDX_notification_idx_notification_issue_id` (`issue_id`),
  ADD KEY `IDX_notification_idx_notification_commit_id` (`commit_id`),
  ADD KEY `IDX_notification_idx_notification_updated_by` (`updated_by`),
  ADD KEY `IDX_notification_u_s_uu` (`user_id`,`status`,`updated_unix`),
  ADD KEY `IDX_notification_idx_notification_user_id` (`user_id`);

--
-- Indexes for table `oauth2_application`
--
ALTER TABLE `oauth2_application`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_oauth2_application_client_id` (`client_id`),
  ADD KEY `IDX_oauth2_application_uid` (`uid`),
  ADD KEY `IDX_oauth2_application_created_unix` (`created_unix`),
  ADD KEY `IDX_oauth2_application_updated_unix` (`updated_unix`);

--
-- Indexes for table `oauth2_authorization_code`
--
ALTER TABLE `oauth2_authorization_code`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_oauth2_authorization_code_code` (`code`),
  ADD KEY `IDX_oauth2_authorization_code_valid_until` (`valid_until`);

--
-- Indexes for table `oauth2_grant`
--
ALTER TABLE `oauth2_grant`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_oauth2_grant_user_application` (`user_id`,`application_id`),
  ADD KEY `IDX_oauth2_grant_user_id` (`user_id`),
  ADD KEY `IDX_oauth2_grant_application_id` (`application_id`);

--
-- Indexes for table `org_user`
--
ALTER TABLE `org_user`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_org_user_s` (`uid`,`org_id`),
  ADD KEY `IDX_org_user_uid` (`uid`),
  ADD KEY `IDX_org_user_org_id` (`org_id`),
  ADD KEY `IDX_org_user_is_public` (`is_public`);

--
-- Indexes for table `package`
--
ALTER TABLE `package`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_package_s` (`owner_id`,`type`,`lower_name`),
  ADD KEY `IDX_package_owner_id` (`owner_id`),
  ADD KEY `IDX_package_repo_id` (`repo_id`),
  ADD KEY `IDX_package_type` (`type`),
  ADD KEY `IDX_package_lower_name` (`lower_name`);

--
-- Indexes for table `package_blob`
--
ALTER TABLE `package_blob`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_package_blob_md5` (`hash_md5`),
  ADD UNIQUE KEY `UQE_package_blob_sha1` (`hash_sha1`),
  ADD UNIQUE KEY `UQE_package_blob_sha256` (`hash_sha256`),
  ADD UNIQUE KEY `UQE_package_blob_sha512` (`hash_sha512`),
  ADD KEY `IDX_package_blob_hash_sha256` (`hash_sha256`),
  ADD KEY `IDX_package_blob_hash_sha512` (`hash_sha512`),
  ADD KEY `IDX_package_blob_hash_sha1` (`hash_sha1`),
  ADD KEY `IDX_package_blob_created_unix` (`created_unix`),
  ADD KEY `IDX_package_blob_hash_md5` (`hash_md5`);

--
-- Indexes for table `package_blob_upload`
--
ALTER TABLE `package_blob_upload`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_package_blob_upload_updated_unix` (`updated_unix`);

--
-- Indexes for table `package_cleanup_rule`
--
ALTER TABLE `package_cleanup_rule`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_package_cleanup_rule_s` (`owner_id`,`type`),
  ADD KEY `IDX_package_cleanup_rule_enabled` (`enabled`),
  ADD KEY `IDX_package_cleanup_rule_owner_id` (`owner_id`),
  ADD KEY `IDX_package_cleanup_rule_type` (`type`);

--
-- Indexes for table `package_file`
--
ALTER TABLE `package_file`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_package_file_s` (`version_id`,`lower_name`,`composite_key`),
  ADD KEY `IDX_package_file_version_id` (`version_id`),
  ADD KEY `IDX_package_file_blob_id` (`blob_id`),
  ADD KEY `IDX_package_file_lower_name` (`lower_name`),
  ADD KEY `IDX_package_file_composite_key` (`composite_key`),
  ADD KEY `IDX_package_file_created_unix` (`created_unix`);

--
-- Indexes for table `package_property`
--
ALTER TABLE `package_property`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_package_property_ref_type` (`ref_type`),
  ADD KEY `IDX_package_property_ref_id` (`ref_id`),
  ADD KEY `IDX_package_property_name` (`name`);

--
-- Indexes for table `package_version`
--
ALTER TABLE `package_version`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_package_version_s` (`package_id`,`lower_version`),
  ADD KEY `IDX_package_version_created_unix` (`created_unix`),
  ADD KEY `IDX_package_version_is_internal` (`is_internal`),
  ADD KEY `IDX_package_version_package_id` (`package_id`),
  ADD KEY `IDX_package_version_lower_version` (`lower_version`);

--
-- Indexes for table `project`
--
ALTER TABLE `project`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_project_repo_id` (`repo_id`),
  ADD KEY `IDX_project_is_closed` (`is_closed`),
  ADD KEY `IDX_project_created_unix` (`created_unix`),
  ADD KEY `IDX_project_updated_unix` (`updated_unix`),
  ADD KEY `IDX_project_title` (`title`),
  ADD KEY `IDX_project_owner_id` (`owner_id`);

--
-- Indexes for table `project_board`
--
ALTER TABLE `project_board`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_project_board_project_id` (`project_id`),
  ADD KEY `IDX_project_board_created_unix` (`created_unix`),
  ADD KEY `IDX_project_board_updated_unix` (`updated_unix`);

--
-- Indexes for table `project_issue`
--
ALTER TABLE `project_issue`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_project_issue_project_id` (`project_id`),
  ADD KEY `IDX_project_issue_project_board_id` (`project_board_id`),
  ADD KEY `IDX_project_issue_issue_id` (`issue_id`);

--
-- Indexes for table `protected_branch`
--
ALTER TABLE `protected_branch`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_protected_branch_s` (`repo_id`,`branch_name`);

--
-- Indexes for table `protected_tag`
--
ALTER TABLE `protected_tag`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `public_key`
--
ALTER TABLE `public_key`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_public_key_owner_id` (`owner_id`),
  ADD KEY `IDX_public_key_fingerprint` (`fingerprint`);

--
-- Indexes for table `pull_auto_merge`
--
ALTER TABLE `pull_auto_merge`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_pull_auto_merge_pull_id` (`pull_id`),
  ADD KEY `IDX_pull_auto_merge_doer_id` (`doer_id`);

--
-- Indexes for table `pull_request`
--
ALTER TABLE `pull_request`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_pull_request_head_repo_id` (`head_repo_id`),
  ADD KEY `IDX_pull_request_base_repo_id` (`base_repo_id`),
  ADD KEY `IDX_pull_request_has_merged` (`has_merged`),
  ADD KEY `IDX_pull_request_merger_id` (`merger_id`),
  ADD KEY `IDX_pull_request_merged_unix` (`merged_unix`),
  ADD KEY `IDX_pull_request_issue_id` (`issue_id`);

--
-- Indexes for table `push_mirror`
--
ALTER TABLE `push_mirror`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_push_mirror_repo_id` (`repo_id`),
  ADD KEY `IDX_push_mirror_last_update` (`last_update`);

--
-- Indexes for table `reaction`
--
ALTER TABLE `reaction`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_reaction_s` (`type`,`issue_id`,`comment_id`,`user_id`,`original_author_id`,`original_author`),
  ADD KEY `IDX_reaction_comment_id` (`comment_id`),
  ADD KEY `IDX_reaction_user_id` (`user_id`),
  ADD KEY `IDX_reaction_original_author_id` (`original_author_id`),
  ADD KEY `IDX_reaction_original_author` (`original_author`),
  ADD KEY `IDX_reaction_created_unix` (`created_unix`),
  ADD KEY `IDX_reaction_type` (`type`),
  ADD KEY `IDX_reaction_issue_id` (`issue_id`);

--
-- Indexes for table `release`
--
ALTER TABLE `release`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_release_n` (`repo_id`,`tag_name`),
  ADD KEY `IDX_release_publisher_id` (`publisher_id`),
  ADD KEY `IDX_release_tag_name` (`tag_name`),
  ADD KEY `IDX_release_original_author_id` (`original_author_id`),
  ADD KEY `IDX_release_sha1` (`sha1`),
  ADD KEY `IDX_release_created_unix` (`created_unix`),
  ADD KEY `IDX_release_repo_id` (`repo_id`);

--
-- Indexes for table `renamed_branch`
--
ALTER TABLE `renamed_branch`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_renamed_branch_repo_id` (`repo_id`);

--
-- Indexes for table `repository`
--
ALTER TABLE `repository`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_repository_s` (`owner_id`,`lower_name`),
  ADD KEY `IDX_repository_is_mirror` (`is_mirror`),
  ADD KEY `IDX_repository_created_unix` (`created_unix`),
  ADD KEY `IDX_repository_is_empty` (`is_empty`),
  ADD KEY `IDX_repository_is_archived` (`is_archived`),
  ADD KEY `IDX_repository_is_fork` (`is_fork`),
  ADD KEY `IDX_repository_is_template` (`is_template`),
  ADD KEY `IDX_repository_original_service_type` (`original_service_type`),
  ADD KEY `IDX_repository_is_private` (`is_private`),
  ADD KEY `IDX_repository_fork_id` (`fork_id`),
  ADD KEY `IDX_repository_template_id` (`template_id`),
  ADD KEY `IDX_repository_updated_unix` (`updated_unix`),
  ADD KEY `IDX_repository_owner_id` (`owner_id`),
  ADD KEY `IDX_repository_lower_name` (`lower_name`),
  ADD KEY `IDX_repository_name` (`name`);

--
-- Indexes for table `repo_archiver`
--
ALTER TABLE `repo_archiver`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_repo_archiver_s` (`repo_id`,`type`,`commit_id`),
  ADD KEY `IDX_repo_archiver_repo_id` (`repo_id`),
  ADD KEY `IDX_repo_archiver_created_unix` (`created_unix`);

--
-- Indexes for table `repo_indexer_status`
--
ALTER TABLE `repo_indexer_status`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_repo_indexer_status_s` (`repo_id`,`indexer_type`);

--
-- Indexes for table `repo_license`
--
ALTER TABLE `repo_license`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_repo_license_s` (`repo_id`,`license`),
  ADD KEY `IDX_repo_license_created_unix` (`created_unix`),
  ADD KEY `IDX_repo_license_updated_unix` (`updated_unix`);

--
-- Indexes for table `repo_redirect`
--
ALTER TABLE `repo_redirect`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_repo_redirect_s` (`owner_id`,`lower_name`),
  ADD KEY `IDX_repo_redirect_lower_name` (`lower_name`);

--
-- Indexes for table `repo_topic`
--
ALTER TABLE `repo_topic`
  ADD PRIMARY KEY (`repo_id`,`topic_id`);

--
-- Indexes for table `repo_transfer`
--
ALTER TABLE `repo_transfer`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_repo_transfer_created_unix` (`created_unix`),
  ADD KEY `IDX_repo_transfer_updated_unix` (`updated_unix`);

--
-- Indexes for table `repo_unit`
--
ALTER TABLE `repo_unit`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_repo_unit_s` (`repo_id`,`type`),
  ADD KEY `IDX_repo_unit_created_unix` (`created_unix`);

--
-- Indexes for table `review`
--
ALTER TABLE `review`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_review_issue_id` (`issue_id`),
  ADD KEY `IDX_review_created_unix` (`created_unix`),
  ADD KEY `IDX_review_updated_unix` (`updated_unix`),
  ADD KEY `IDX_review_reviewer_id` (`reviewer_id`);

--
-- Indexes for table `review_state`
--
ALTER TABLE `review_state`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_review_state_pull_commit_user` (`user_id`,`pull_id`,`commit_sha`),
  ADD KEY `IDX_review_state_pull_id` (`pull_id`);

--
-- Indexes for table `secret`
--
ALTER TABLE `secret`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_secret_owner_repo_name` (`owner_id`,`repo_id`,`name`),
  ADD KEY `IDX_secret_owner_id` (`owner_id`),
  ADD KEY `IDX_secret_repo_id` (`repo_id`);

--
-- Indexes for table `session`
--
ALTER TABLE `session`
  ADD PRIMARY KEY (`key`);

--
-- Indexes for table `star`
--
ALTER TABLE `star`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_star_s` (`uid`,`repo_id`),
  ADD KEY `IDX_star_created_unix` (`created_unix`);

--
-- Indexes for table `stopwatch`
--
ALTER TABLE `stopwatch`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_stopwatch_issue_id` (`issue_id`),
  ADD KEY `IDX_stopwatch_user_id` (`user_id`);

--
-- Indexes for table `system_setting`
--
ALTER TABLE `system_setting`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_system_setting_setting_key` (`setting_key`);

--
-- Indexes for table `task`
--
ALTER TABLE `task`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_task_owner_id` (`owner_id`),
  ADD KEY `IDX_task_repo_id` (`repo_id`),
  ADD KEY `IDX_task_status` (`status`),
  ADD KEY `IDX_task_doer_id` (`doer_id`);

--
-- Indexes for table `team`
--
ALTER TABLE `team`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_team_org_id` (`org_id`);

--
-- Indexes for table `team_invite`
--
ALTER TABLE `team_invite`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_team_invite_team_mail` (`team_id`,`email`),
  ADD KEY `IDX_team_invite_created_unix` (`created_unix`),
  ADD KEY `IDX_team_invite_updated_unix` (`updated_unix`),
  ADD KEY `IDX_team_invite_token` (`token`),
  ADD KEY `IDX_team_invite_org_id` (`org_id`),
  ADD KEY `IDX_team_invite_team_id` (`team_id`);

--
-- Indexes for table `team_repo`
--
ALTER TABLE `team_repo`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_team_repo_s` (`team_id`,`repo_id`),
  ADD KEY `IDX_team_repo_org_id` (`org_id`);

--
-- Indexes for table `team_unit`
--
ALTER TABLE `team_unit`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_team_unit_s` (`team_id`,`type`),
  ADD KEY `IDX_team_unit_org_id` (`org_id`);

--
-- Indexes for table `team_user`
--
ALTER TABLE `team_user`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_team_user_s` (`team_id`,`uid`),
  ADD KEY `IDX_team_user_org_id` (`org_id`);

--
-- Indexes for table `topic`
--
ALTER TABLE `topic`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_topic_name` (`name`),
  ADD KEY `IDX_topic_created_unix` (`created_unix`),
  ADD KEY `IDX_topic_updated_unix` (`updated_unix`);

--
-- Indexes for table `tracked_time`
--
ALTER TABLE `tracked_time`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_tracked_time_issue_id` (`issue_id`),
  ADD KEY `IDX_tracked_time_user_id` (`user_id`);

--
-- Indexes for table `two_factor`
--
ALTER TABLE `two_factor`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_two_factor_uid` (`uid`),
  ADD KEY `IDX_two_factor_created_unix` (`created_unix`),
  ADD KEY `IDX_two_factor_updated_unix` (`updated_unix`);

--
-- Indexes for table `upload`
--
ALTER TABLE `upload`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_upload_uuid` (`uuid`);

--
-- Indexes for table `user`
--
ALTER TABLE `user`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_user_lower_name` (`lower_name`),
  ADD UNIQUE KEY `UQE_user_name` (`name`),
  ADD KEY `IDX_user_created_unix` (`created_unix`),
  ADD KEY `IDX_user_updated_unix` (`updated_unix`),
  ADD KEY `IDX_user_last_login_unix` (`last_login_unix`),
  ADD KEY `IDX_user_is_active` (`is_active`);

--
-- Indexes for table `user_badge`
--
ALTER TABLE `user_badge`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_user_badge_user_id` (`user_id`);

--
-- Indexes for table `user_blocking`
--
ALTER TABLE `user_blocking`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_user_blocking_block` (`blocker_id`,`blockee_id`),
  ADD KEY `IDX_user_blocking_created_unix` (`created_unix`);

--
-- Indexes for table `user_open_id`
--
ALTER TABLE `user_open_id`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_user_open_id_uri` (`uri`),
  ADD KEY `IDX_user_open_id_uid` (`uid`);

--
-- Indexes for table `user_redirect`
--
ALTER TABLE `user_redirect`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_user_redirect_s` (`lower_name`),
  ADD KEY `IDX_user_redirect_lower_name` (`lower_name`);

--
-- Indexes for table `user_setting`
--
ALTER TABLE `user_setting`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_user_setting_key_userid` (`user_id`,`setting_key`),
  ADD KEY `IDX_user_setting_user_id` (`user_id`),
  ADD KEY `IDX_user_setting_setting_key` (`setting_key`);

--
-- Indexes for table `version`
--
ALTER TABLE `version`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `watch`
--
ALTER TABLE `watch`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_watch_watch` (`user_id`,`repo_id`),
  ADD KEY `IDX_watch_updated_unix` (`updated_unix`),
  ADD KEY `IDX_watch_created_unix` (`created_unix`);

--
-- Indexes for table `webauthn_credential`
--
ALTER TABLE `webauthn_credential`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQE_webauthn_credential_s` (`lower_name`,`user_id`),
  ADD KEY `IDX_webauthn_credential_created_unix` (`created_unix`),
  ADD KEY `IDX_webauthn_credential_updated_unix` (`updated_unix`),
  ADD KEY `IDX_webauthn_credential_user_id` (`user_id`),
  ADD KEY `IDX_webauthn_credential_credential_id` (`credential_id`);

--
-- Indexes for table `webhook`
--
ALTER TABLE `webhook`
  ADD PRIMARY KEY (`id`),
  ADD KEY `IDX_webhook_repo_id` (`repo_id`),
  ADD KEY `IDX_webhook_owner_id` (`owner_id`),
  ADD KEY `IDX_webhook_is_active` (`is_active`),
  ADD KEY `IDX_webhook_created_unix` (`created_unix`),
  ADD KEY `IDX_webhook_updated_unix` (`updated_unix`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `access`
--
ALTER TABLE `access`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `access_token`
--
ALTER TABLE `access_token`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `action`
--
ALTER TABLE `action`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `action_artifact`
--
ALTER TABLE `action_artifact`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `action_run`
--
ALTER TABLE `action_run`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `action_runner`
--
ALTER TABLE `action_runner`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `action_runner_token`
--
ALTER TABLE `action_runner_token`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `action_run_job`
--
ALTER TABLE `action_run_job`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `action_schedule`
--
ALTER TABLE `action_schedule`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `action_schedule_spec`
--
ALTER TABLE `action_schedule_spec`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `action_task`
--
ALTER TABLE `action_task`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `action_tasks_version`
--
ALTER TABLE `action_tasks_version`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `action_task_output`
--
ALTER TABLE `action_task_output`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `action_task_step`
--
ALTER TABLE `action_task_step`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `action_variable`
--
ALTER TABLE `action_variable`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `attachment`
--
ALTER TABLE `attachment`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `badge`
--
ALTER TABLE `badge`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `branch`
--
ALTER TABLE `branch`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `collaboration`
--
ALTER TABLE `collaboration`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `comment`
--
ALTER TABLE `comment`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `commit_status`
--
ALTER TABLE `commit_status`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `commit_status_index`
--
ALTER TABLE `commit_status_index`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `commit_status_summary`
--
ALTER TABLE `commit_status_summary`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `dbfs_data`
--
ALTER TABLE `dbfs_data`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `dbfs_meta`
--
ALTER TABLE `dbfs_meta`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `deploy_key`
--
ALTER TABLE `deploy_key`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `email_address`
--
ALTER TABLE `email_address`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `follow`
--
ALTER TABLE `follow`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `gpg_key`
--
ALTER TABLE `gpg_key`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `hook_task`
--
ALTER TABLE `hook_task`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `issue`
--
ALTER TABLE `issue`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `issue_assignees`
--
ALTER TABLE `issue_assignees`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `issue_content_history`
--
ALTER TABLE `issue_content_history`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `issue_dependency`
--
ALTER TABLE `issue_dependency`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `issue_label`
--
ALTER TABLE `issue_label`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `issue_pin`
--
ALTER TABLE `issue_pin`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `issue_user`
--
ALTER TABLE `issue_user`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `issue_watch`
--
ALTER TABLE `issue_watch`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `label`
--
ALTER TABLE `label`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `language_stat`
--
ALTER TABLE `language_stat`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `lfs_lock`
--
ALTER TABLE `lfs_lock`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `lfs_meta_object`
--
ALTER TABLE `lfs_meta_object`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `login_source`
--
ALTER TABLE `login_source`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `milestone`
--
ALTER TABLE `milestone`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `mirror`
--
ALTER TABLE `mirror`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `notice`
--
ALTER TABLE `notice`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `notification`
--
ALTER TABLE `notification`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `oauth2_application`
--
ALTER TABLE `oauth2_application`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `oauth2_authorization_code`
--
ALTER TABLE `oauth2_authorization_code`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `oauth2_grant`
--
ALTER TABLE `oauth2_grant`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `org_user`
--
ALTER TABLE `org_user`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `package`
--
ALTER TABLE `package`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `package_blob`
--
ALTER TABLE `package_blob`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `package_cleanup_rule`
--
ALTER TABLE `package_cleanup_rule`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `package_file`
--
ALTER TABLE `package_file`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `package_property`
--
ALTER TABLE `package_property`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `package_version`
--
ALTER TABLE `package_version`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `project`
--
ALTER TABLE `project`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `project_board`
--
ALTER TABLE `project_board`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `project_issue`
--
ALTER TABLE `project_issue`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `protected_branch`
--
ALTER TABLE `protected_branch`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `protected_tag`
--
ALTER TABLE `protected_tag`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `public_key`
--
ALTER TABLE `public_key`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `pull_auto_merge`
--
ALTER TABLE `pull_auto_merge`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `pull_request`
--
ALTER TABLE `pull_request`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `push_mirror`
--
ALTER TABLE `push_mirror`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `reaction`
--
ALTER TABLE `reaction`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `release`
--
ALTER TABLE `release`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `renamed_branch`
--
ALTER TABLE `renamed_branch`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `repository`
--
ALTER TABLE `repository`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `repo_archiver`
--
ALTER TABLE `repo_archiver`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `repo_indexer_status`
--
ALTER TABLE `repo_indexer_status`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `repo_license`
--
ALTER TABLE `repo_license`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `repo_redirect`
--
ALTER TABLE `repo_redirect`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `repo_transfer`
--
ALTER TABLE `repo_transfer`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `repo_unit`
--
ALTER TABLE `repo_unit`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `review`
--
ALTER TABLE `review`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `review_state`
--
ALTER TABLE `review_state`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `secret`
--
ALTER TABLE `secret`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `star`
--
ALTER TABLE `star`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `stopwatch`
--
ALTER TABLE `stopwatch`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `system_setting`
--
ALTER TABLE `system_setting`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `task`
--
ALTER TABLE `task`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `team`
--
ALTER TABLE `team`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `team_invite`
--
ALTER TABLE `team_invite`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `team_repo`
--
ALTER TABLE `team_repo`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `team_unit`
--
ALTER TABLE `team_unit`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `team_user`
--
ALTER TABLE `team_user`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `topic`
--
ALTER TABLE `topic`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `tracked_time`
--
ALTER TABLE `tracked_time`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `two_factor`
--
ALTER TABLE `two_factor`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `upload`
--
ALTER TABLE `upload`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `user`
--
ALTER TABLE `user`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `user_badge`
--
ALTER TABLE `user_badge`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `user_blocking`
--
ALTER TABLE `user_blocking`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `user_open_id`
--
ALTER TABLE `user_open_id`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `user_redirect`
--
ALTER TABLE `user_redirect`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `user_setting`
--
ALTER TABLE `user_setting`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `version`
--
ALTER TABLE `version`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `watch`
--
ALTER TABLE `watch`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `webauthn_credential`
--
ALTER TABLE `webauthn_credential`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `webhook`
--
ALTER TABLE `webhook`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
