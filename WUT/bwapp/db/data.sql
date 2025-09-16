-- MySQL dump 10.16  Distrib 10.1.48-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: db
-- ------------------------------------------------------
-- Server version	10.1.48-MariaDB-0+deb9u2

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `blog`
--

DROP TABLE IF EXISTS `blog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `blog` (
  `id` varchar(0) DEFAULT NULL,
  `owner` varchar(0) DEFAULT NULL,
  `entry` varchar(0) DEFAULT NULL,
  `date` varchar(0) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `blog`
--

LOCK TABLES `blog` WRITE;
/*!40000 ALTER TABLE `blog` DISABLE KEYS */;
/*!40000 ALTER TABLE `blog` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `heroes`
--

DROP TABLE IF EXISTS `heroes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `heroes` (
  `id` tinyint(4) DEFAULT NULL,
  `login` varchar(9) DEFAULT NULL,
  `password` varchar(14) DEFAULT NULL,
  `secret` varchar(37) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `heroes`
--

LOCK TABLES `heroes` WRITE;
/*!40000 ALTER TABLE `heroes` DISABLE KEYS */;
INSERT INTO `heroes` VALUES (1,'neo','trinity','Oh why didn\'t I took that BLACK pill?'),(2,'alice','loveZombies','There\'s a cure!'),(3,'thor','Asgard','Oh, no... this is Earth... isn\'t it?'),(4,'wolverine','Log@N','What\'s a Magneto?'),(5,'johnny','m3ph1st0ph3l3s','I\'m the Ghost Rider!'),(6,'seline','m00n','It wasn\'t the Lycans. It was you.');
/*!40000 ALTER TABLE `heroes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `movies`
--

DROP TABLE IF EXISTS `movies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `movies` (
  `id` tinyint(4) DEFAULT NULL,
  `title` varchar(22) DEFAULT NULL,
  `release_year` smallint(6) DEFAULT NULL,
  `genre` varchar(6) DEFAULT NULL,
  `main_character` varchar(15) DEFAULT NULL,
  `imdb` varchar(9) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `movies`
--

LOCK TABLES `movies` WRITE;
/*!40000 ALTER TABLE `movies` DISABLE KEYS */;
INSERT INTO `movies` VALUES (1,'G.I. Joe: Retaliation',2013,'action','Cobra Commander','tt1583421'),(2,'Iron Man',2008,'action','Tony Stark','tt0371746'),(3,'Man of Steel',2013,'action','Clark Kent','tt0770828'),(4,'Terminator Salvation',2009,'sci-fi','John Connor','tt0438488'),(5,'The Amazing Spider-Man',2012,'action','Peter Parker','tt0948470'),(6,'The Cabin in the Woods',2011,'horror','Some zombies','tt1259521'),(7,'The Dark Knight Rises',2012,'action','Bruce Wayne','tt1345836'),(8,'The Incredible Hulk',2008,'action','Bruce Banner','tt0800080'),(9,'World War Z',2013,'horror','Gerry Lane','tt0816711');
/*!40000 ALTER TABLE `movies` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `users` (
  `id` tinyint(4) DEFAULT NULL,
  `login` varchar(6) DEFAULT NULL,
  `password` varchar(40) DEFAULT NULL,
  `email` varchar(24) DEFAULT NULL,
  `secret` varchar(35) DEFAULT NULL,
  `activation_code` varchar(0) DEFAULT NULL,
  `activated` tinyint(4) DEFAULT NULL,
  `reset_code` varchar(0) DEFAULT NULL,
  `admin` tinyint(4) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'A.I.M.','6885858486f31043e5839c735d99457f045affd0','bwapp-aim@mailinator.com','A.I.M. or Authentication Is Missing','',1,'',1),(2,'bee','6885858486f31043e5839c735d99457f045affd0','bwapp-bee@mailinator.com','Any bugs?','',1,'',0);
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2024-04-30 16:42:41
