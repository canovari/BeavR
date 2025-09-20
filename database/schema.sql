-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Host: m-13.th.seeweb.it
-- Generation Time: Sep 20, 2025 at 05:35 PM
-- Server version: 5.7.30
-- PHP Version: 7.4.33

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `canovari46540`
--

-- --------------------------------------------------------

--
-- Table structure for table `events`
--

CREATE TABLE `events` (
  `id` int(10) UNSIGNED NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `start_time` datetime NOT NULL,
  `end_time` datetime DEFAULT NULL,
  `location` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `organization` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `category` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `image_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `contact_type` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `contact_value` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `latitude` decimal(10,7) NOT NULL,
  `longitude` decimal(10,7) NOT NULL,
  `status` enum('pending','approved','old') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `creator` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `creator_user_id` int(10) UNSIGNED DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `events`
--

INSERT INTO `events` (`id`, `title`, `start_time`, `end_time`, `location`, `description`, `organization`, `category`, `image_url`, `contact_type`, `contact_value`, `latitude`, `longitude`, `status`, `creator`, `creator_user_id`, `created_at`, `updated_at`) VALUES
(8, 'Welcome Mixer', '2025-09-20 17:00:00', '2025-09-20 23:00:00', 'LSE Student Union', 'Kick off term with music, food and networking.', 'LSESU', '? Party', NULL, 'email', 'events@lsesu.com', 51.5145000, -0.1160000, 'approved', 'admin@lse.ac.uk', 1, '2025-09-20 11:43:47', '2025-09-20 11:43:47'),
(9, 'Career Fair', '2025-09-20 10:00:00', '2025-09-20 16:00:00', 'LSE Old Theatre', 'Meet top employers recruiting LSE students.', 'LSE Careers', '? Career', NULL, 'email', 'careers@lse.ac.uk', 51.5148000, -0.1159000, 'approved', 'admin@lse.ac.uk', 1, '2025-09-20 11:43:47', '2025-09-20 11:43:47'),
(10, 'Movie Night', '2025-09-20 19:30:00', '2025-09-20 22:30:00', 'LSE Auditorium', 'Screening of an all-time student favorite film.', 'Film Society', '? Movie', NULL, 'email', 'filmsoc@lse.ac.uk', 51.5150000, -0.1162000, 'approved', 'admin@lse.ac.uk', 1, '2025-09-20 11:43:47', '2025-09-20 11:43:47'),
(11, 'Sports Tournament', '2025-09-21 12:00:00', '2025-09-21 18:00:00', 'LSE Sports Ground', 'Inter-society football and basketball matches.', 'Athletics Union', '? Sports', NULL, 'email', 'sports@lse.ac.uk', 51.5139000, -0.1180000, 'approved', 'admin@lse.ac.uk', 1, '2025-09-20 11:43:47', '2025-09-20 11:43:47'),
(12, 'Wellness Workshop', '2025-09-21 09:00:00', '2025-09-21 12:00:00', 'LSE Library Room A', 'Mindfulness and stress management session.', 'Wellbeing Team', '? Wellness', NULL, 'email', 'wellbeing@lse.ac.uk', 51.5142000, -0.1155000, 'approved', 'admin@lse.ac.uk', 1, '2025-09-20 11:43:47', '2025-09-20 11:43:47'),
(13, 'Free Pizza Giveaway', '2025-09-25 13:00:00', '2025-09-25 14:00:00', 'Campus Square', 'Grab a free slice while supplies last!', 'Food Society', '? Freebie', NULL, 'email', 'foodsoc@lse.ac.uk', 51.5147000, -0.1157000, 'approved', 'admin@lse.ac.uk', 1, '2025-09-20 11:43:47', '2025-09-20 13:52:55'),
(14, 'Ccccchfh', '2025-09-20 13:46:00', '2025-09-20 13:52:00', 'LSE, 7 Portugal Street', 'Cc', 'Cc', '🎮 Gaming', NULL, NULL, NULL, 51.5145000, -0.1160000, 'approved', 'p.canovari@lse.ac.uk', 1, '2025-09-20 11:47:51', '2025-09-20 13:52:22'),
(15, 'Test event', '2025-09-20 15:21:00', '2025-09-20 16:21:00', '17 Old Buildings', 'Ccc', 'Pietro', '🎮 Gaming', NULL, NULL, NULL, 51.5165092, -0.1130615, 'approved', 'p.canovari@lse.ac.uk', 1, '2025-09-20 12:22:39', '2025-09-20 14:22:51'),
(16, 'Test', '2025-09-20 14:30:00', '2025-09-20 15:30:00', 'Lincoln\'s Inn Fields, Canada Walk', 'Cc', 'Cg', '🎮 Gaming', NULL, NULL, NULL, 51.5166388, -0.1166472, 'pending', 'p.canovari@lse.ac.uk', 1, '2025-09-20 12:32:17', '2025-09-20 12:32:17');

-- --------------------------------------------------------

--
-- Table structure for table `messages`
--

CREATE TABLE `messages` (
  `id` int(11) NOT NULL,
  `pin_id` int(11) NOT NULL,
  `sender_email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `receiver_email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `message` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `messages`
--

INSERT INTO `messages` (`id`, `pin_id`, `sender_email`, `receiver_email`, `message`, `created_at`) VALUES
(1, 3, 'p.canovari@lse.ac.uk', 'example@lse.ac.uk', '{\"text\":\"Test msg\",\"author\":null}', '2025-09-19 23:14:53'),
(2, 2, 'p.canovari@lse.ac.uk', 'p.canovari@lse.ac.uk', '{\"text\":\"What\",\"author\":null}', '2025-09-19 23:15:44'),
(3, 10, 'p.canovari@lse.ac.uk', 'example@lse.ac.uk', '{\"text\":\"Ciaoo\",\"author\":null}', '2025-09-19 23:57:29'),
(4, 14, 'p.canovari@lse.ac.uk', 'example@lse.ac.uk', '{\"text\":\"Hhu\",\"author\":\"Ggg\"}', '2025-09-20 12:54:09'),
(5, 13, 'p.canovari@lse.ac.uk', 'p.canovari@lse.ac.uk', '{\"text\":\"Dxx\",\"author\":\"Ddd\"}', '2025-09-20 12:54:22'),
(6, 17, 'p.canovari@lse.ac.uk', 'p.canovari@lse.ac.uk', '{\"text\":\"I\'m down!!\",\"author\":null}', '2025-09-20 13:13:15'),
(7, 17, 'p.canovari@lse.ac.uk', 'p.canovari@lse.ac.uk', '{\"text\":\"Hell yea\",\"author\":\"Hell Yea\"}', '2025-09-20 13:13:34');

-- --------------------------------------------------------

--
-- Table structure for table `pins`
--

CREATE TABLE `pins` (
  `id` int(11) NOT NULL,
  `emoji` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
  `text` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `author` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `creator_email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `grid_row` int(11) NOT NULL,
  `grid_col` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `pins`
--

INSERT INTO `pins` (`id`, `emoji`, `text`, `author`, `creator_email`, `grid_row`, `grid_col`, `created_at`) VALUES
(1, '⌨️', 'Interested in buying a gaming keyboard! Hmu if you\'re selling one :)', NULL, 'example@lse.ac.uk', 1, 1, '2025-09-19 21:10:09'),
(6, '🙄', 'Where have you beeennn', NULL, 'example@lse.ac.uk', 5, 0, '2025-09-19 23:24:02'),
(8, '😐', 'Hhshsjsjshs', NULL, 'example@lse.ac.uk', 2, 3, '2025-09-19 23:46:41'),
(9, '🫥', 'Yooo', 'Ciao', 'example@lse.ac.uk', 3, 3, '2025-09-19 23:47:02'),
(10, '😬', 'Test', NULL, 'example@lse.ac.uk', 4, 2, '2025-09-19 23:57:20'),
(15, '🤨', 'Test', NULL, 'example@lse.ac.uk', 1, 3, '2025-09-20 13:11:00'),
(16, '😑', 'Test', 'Authortest', 'example@lse.ac.uk', 1, 4, '2025-09-20 13:11:07');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` int(10) UNSIGNED NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `code` char(6) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `code_expires_at` datetime DEFAULT NULL,
  `verified` tinyint(1) NOT NULL DEFAULT '0',
  `login_token` char(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `email`, `code`, `code_expires_at`, `verified`, `login_token`, `created_at`, `updated_at`) VALUES
(1, 'p.canovari@lse.ac.uk', NULL, NULL, 1, 'd84743e13fd17eaa6e81f7bbf6ebfbb01fe68cd5ece780919528db991c3747f7', '2025-09-19 20:47:46', '2025-09-19 20:52:27');

-- --------------------------------------------------------

--
-- Table structure for table `user_locations`
--

CREATE TABLE `user_locations` (
  `latitude` decimal(10,7) NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `longitude` decimal(10,7) NOT NULL,
  `recorded_at` datetime NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `user_locations`
--

INSERT INTO `user_locations` (`latitude`, `email`, `longitude`, `recorded_at`, `updated_at`) VALUES
(51.5163163, 'p.canovari@lse.ac.uk', -0.1248199, '2025-09-20 15:22:33', '2025-09-20 15:23:31');

-- --------------------------------------------------------

--
-- Table structure for table `notification_devices`
--

CREATE TABLE `notification_devices` (
  `id` int(11) UNSIGNED NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `device_token` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `platform` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'ios',
  `environment` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'production',
  `app_version` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `os_version` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `last_used_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `notification_log`
--

CREATE TABLE `notification_log` (
  `id` int(11) UNSIGNED NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `body` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `payload` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `events`
--
ALTER TABLE `events`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_events_status` (`status`),
  ADD KEY `idx_events_creator` (`creator`),
  ADD KEY `fk_events_creator_user` (`creator_user_id`);

--
-- Indexes for table `messages`
--
ALTER TABLE `messages`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_messages_sender` (`sender_email`),
  ADD KEY `idx_messages_receiver` (`receiver_email`);

--
-- Indexes for table `pins`
--
ALTER TABLE `pins`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `idx_pins_location` (`grid_row`,`grid_col`),
  ADD KEY `idx_pins_creator` (`creator_email`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`),
  ADD KEY `idx_users_login_token` (`login_token`);

--
-- Indexes for table `user_locations`
--
ALTER TABLE `user_locations`
  ADD UNIQUE KEY `unique_email` (`email`);

--
-- Indexes for table `notification_devices`
--
ALTER TABLE `notification_devices`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `idx_notification_device_token` (`device_token`),
  ADD KEY `idx_notification_email` (`email`);

--
-- Indexes for table `notification_log`
--
ALTER TABLE `notification_log`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_notification_log_email` (`email`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `events`
--
ALTER TABLE `events`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=17;

--
-- AUTO_INCREMENT for table `messages`
--
ALTER TABLE `messages`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `pins`
--
ALTER TABLE `pins`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `notification_devices`
--
ALTER TABLE `notification_devices`
  MODIFY `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;

--
-- AUTO_INCREMENT for table `notification_log`
--
ALTER TABLE `notification_log`
  MODIFY `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `events`
--
ALTER TABLE `events`
  ADD CONSTRAINT `fk_events_creator_user` FOREIGN KEY (`creator_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
