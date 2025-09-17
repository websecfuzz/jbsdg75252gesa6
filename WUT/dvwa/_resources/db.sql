-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: db
-- Generation Time: Jan 04, 2025 at 06:31 PM
-- Server version: 8.4.0
-- PHP Version: 8.2.27

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `db`
--

-- --------------------------------------------------------

--
-- Table structure for table `guestbook`
--

CREATE TABLE `guestbook` (
  `comment_id` smallint UNSIGNED NOT NULL,
  `comment` varchar(300) DEFAULT NULL,
  `name` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `guestbook`
--

INSERT INTO `guestbook` (`comment_id`, `comment`, `name`) VALUES
(1, 'This is a test comment.', 'test');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `user_id` int NOT NULL,
  `first_name` varchar(15) DEFAULT NULL,
  `last_name` varchar(15) DEFAULT NULL,
  `user` varchar(15) DEFAULT NULL,
  `password` varchar(32) DEFAULT NULL,
  `avatar` varchar(70) DEFAULT NULL,
  `last_login` timestamp NULL DEFAULT NULL,
  `failed_login` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`user_id`, `first_name`, `last_name`, `user`, `password`, `avatar`, `last_login`, `failed_login`) VALUES
(1, 'admin', 'admin', 'admin', '5f4dcc3b5aa765d61d8327deb882cf99', '/DVWA/hackable/users/admin.jpg', '2025-01-04 15:09:05', 0),
(2, 'Gordon', 'Brown', 'gordonb', 'e99a18c428cb38d5f260853678922e03', '/DVWA/hackable/users/gordonb.jpg', '2025-01-04 15:09:05', 0),
(3, 'Hack', 'Me', '1337', '8d3533d75ae2c3966d7e0d4fcc69216b', '/DVWA/hackable/users/1337.jpg', '2025-01-04 15:09:05', 0),
(4, 'Pablo', 'Picasso', 'pablo', '0d107d09f5bbe40cade3de5c71e9e9b7', '/DVWA/hackable/users/pablo.jpg', '2025-01-04 15:09:05', 0),
(5, 'Bob', 'Smith', 'smithy', '5f4dcc3b5aa765d61d8327deb882cf99', '/DVWA/hackable/users/smithy.jpg', '2025-01-04 15:09:05', 0);

--
-- Indexes for dumped tables
--

--
-- Indexes for table `guestbook`
--
ALTER TABLE `guestbook`
  ADD PRIMARY KEY (`comment_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`user_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `guestbook`
--
ALTER TABLE `guestbook`
  MODIFY `comment_id` smallint UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
