-- phpMyAdmin SQL Dump
-- version 5.2.0
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:3306
-- Generation Time: Oct 06, 2025 at 02:12 AM
-- Server version: 8.0.31
-- PHP Version: 8.0.26

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `db_health`
--

-- --------------------------------------------------------

--
-- Table structure for table `appointments`
--

DROP TABLE IF EXISTS `appointments`;
CREATE TABLE IF NOT EXISTS `appointments` (
  `aid` int NOT NULL AUTO_INCREMENT,
  `cid` int NOT NULL,
  `date` date NOT NULL,
  `status` enum('upcoming','successful','unsuccessful','canceled') CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `payment` enum('successful','unsuccessful','pending','canceled') NOT NULL,
  PRIMARY KEY (`aid`)
) ENGINE=MyISAM AUTO_INCREMENT=41 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `appointments`
--

INSERT INTO `appointments` (`aid`, `cid`, `date`, `status`, `payment`) VALUES
(1, 1, '2025-10-01', 'successful', 'successful'),
(2, 1, '2025-10-18', 'upcoming', 'unsuccessful'),
(3, 2, '2025-10-03', 'unsuccessful', 'unsuccessful'),
(4, 4, '2025-10-14', 'successful', 'successful'),
(5, 3, '2025-10-23', 'upcoming', 'successful'),
(6, 47, '2025-09-12', 'upcoming', 'successful'),
(7, 3, '2025-12-01', 'upcoming', 'unsuccessful'),
(8, 22, '2025-11-20', 'upcoming', 'successful'),
(9, 58, '2025-12-15', 'upcoming', 'unsuccessful'),
(10, 9, '2025-11-02', 'upcoming', 'unsuccessful'),
(11, 41, '2025-11-25', 'canceled', 'unsuccessful'),
(12, 14, '2025-12-05', 'upcoming', 'unsuccessful'),
(13, 36, '2025-10-05', 'canceled', 'successful'),
(14, 7, '2025-10-21', 'upcoming', 'unsuccessful'),
(15, 60, '2025-11-11', 'upcoming', 'successful'),
(16, 5, '2025-12-20', 'upcoming', 'unsuccessful'),
(17, 28, '2025-11-30', 'upcoming', 'successful'),
(18, 51, '2025-10-25', 'canceled', 'unsuccessful'),
(19, 17, '2026-01-10', 'upcoming', 'unsuccessful'),
(20, 43, '2025-09-30', 'successful', 'successful'),
(21, 2, '2026-02-05', 'canceled', 'unsuccessful'),
(22, 33, '2025-11-03', 'upcoming', 'successful'),
(23, 19, '2025-10-29', 'upcoming', 'successful'),
(24, 8, '2025-12-09', 'upcoming', 'successful'),
(25, 39, '2025-11-17', 'canceled', 'unsuccessful'),
(26, 26, '2025-12-22', 'upcoming', 'successful'),
(27, 54, '2026-01-20', 'successful', 'successful'),
(28, 11, '2025-10-11', 'upcoming', 'unsuccessful'),
(29, 30, '2025-11-08', 'upcoming', 'unsuccessful'),
(30, 15, '2025-12-03', '', 'successful'),
(31, 49, '2025-11-15', 'unsuccessful', 'unsuccessful'),
(32, 6, '2026-02-01', 'upcoming', 'unsuccessful'),
(33, 38, '2025-09-20', 'successful', 'successful'),
(34, 24, '2025-11-27', 'upcoming', 'unsuccessful'),
(35, 12, '2025-10-30', 'canceled', 'successful'),
(36, 56, '2025-12-12', 'canceled', 'unsuccessful'),
(37, 4, '2025-11-02', 'upcoming', 'unsuccessful'),
(38, 18, '2025-10-07', 'successful', 'successful'),
(39, 21, '2026-01-18', 'successful', 'successful'),
(40, 37, '2025-12-28', 'canceled', 'unsuccessful');

-- --------------------------------------------------------

--
-- Table structure for table `customers`
--

DROP TABLE IF EXISTS `customers`;
CREATE TABLE IF NOT EXISTS `customers` (
  `cid` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `email` varchar(255) NOT NULL,
  `phone` varchar(25) NOT NULL,
  `address` varchar(255) NOT NULL,
  `insurance` enum('verified','unverified','pending') NOT NULL,
  PRIMARY KEY (`cid`)
) ENGINE=MyISAM AUTO_INCREMENT=69 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `customers`
--

INSERT INTO `customers` (`cid`, `name`, `email`, `phone`, `address`, `insurance`) VALUES
(1, 'John Smith', 'john955@john955.com', '+14425225642', '609-621 Sandy Ridge Dr, Glen Burnie, MD 21061', 'verified'),
(2, 'Emma Davis', 'emma231@emma236.net', '+15324563213', '901-907 William St, Fredericksburg, VA 22401', 'verified'),
(3, 'Hannah Brown', 'hannah005@hannah005.com', '+11433324564', '624-600 Winsford Rd, Bryn Mawr, PA 19010', 'unverified'),
(4, 'Emily Garcia', 'emily0032@emily0032.org', '+16432456333', '1069-997 Riga Alley, Columbus, OH 43201', 'pending'),
(5, 'Michael Johnson', 'michael_johnson001@outlook.com', '+14354235224', '2899-2873 Church Ave, Cleveland, OH 44113', 'verified'),
(6, 'Liam Carter', 'liam000@liam000.com', '+13445632567', '112-198 N Sand St, Peoria, IL 61605', 'pending'),
(7, 'Hailey James', 'hailey005@hailey005.com', '+12357642235', '795-701 N Hollywood St, Memphis, TN 38112', 'verified'),
(8, 'Ella Patterson', 'ella@ella.com', '+14566325563', '3739 Gough St, Baltimore, MD 21224', 'verified'),
(9, 'Jacob Reed', 'jacob01@jacob01.com', '+14432001234', '7137 Hilltop Rd, Towson, MD 21204', 'verified'),
(10, 'Sophia Bennett', 'sophia02@sophia02.com', '+14435564567', '5211 Maple Ave, Baltimore, MD 21227', 'pending'),
(11, 'Noah Bennett', 'noah03@noah03.com', '+14437652345', '9824 River Rd, Bethesda, MD 20816', 'verified'),
(12, 'Grace Turner', 'grace04@grace04.com', '+14439875678', '1140 Pinewood Dr, Silver Spring, MD 20910', 'unverified'),
(13, 'Mason Cooper', 'mason05@mason05.com', '+14435549911', '8772 Glenoak Ave, Columbia, MD 21045', 'verified'),
(14, 'Ava Mitchell', 'ava06@ava06.com', '+14432225678', '2441 Chestnut St, Rockville, MD 20852', 'pending'),
(15, 'Ryan Mitchell', 'ryan07@ryan07.com', '+14436665588', '3305 Oak Grove Rd, Gaithersburg, MD 20877', 'verified'),
(16, 'Chloe Hayes', 'chloe08@chloe08.com', '+14439990012', '7548 Pine Valley Dr, Catonsville, MD 21228', 'verified'),
(17, 'Nathan Hayes', 'nathan09@nathan09.com', '+14436660044', '8231 Hillcrest Rd, Frederick, MD 21703', 'verified'),
(18, 'Caleb Turner', 'caleb10@caleb10.com', '+14435551212', '2197 Liberty Rd, Westminster, MD 21157', 'verified'),
(19, 'Dylan Foster', 'dylan11@dylan11.com', '+14437773399', '6114 Rolling Rd, Ellicott City, MD 21043', 'verified'),
(20, 'Zachary Collins', 'zachary12@zachary12.com', '+14431119900', '4513 Glen Ridge Dr, Laurel, MD 20707', 'pending'),
(21, 'Luke Henderson', 'luke13@luke13.com', '+14432227788', '1324 Oakwood Ave, Baltimore, MD 21234', 'verified'),
(22, 'Connor Price', 'connor14@connor14.com', '+14430009977', '5619 Willow Ct, Towson, MD 21286', 'pending'),
(23, 'Austin Ward', 'austin15@austin15.com', '+14437778866', '7071 Elm St, Hyattsville, MD 20783', 'verified'),
(24, 'Brandon Scott', 'brandon16@brandon16.com', '+14433334455', '4001 Summit Ave, College Park, MD 20742', 'unverified'),
(25, 'Blake Patterson', 'blake17@blake17.com', '+14434445566', '9230 Spring Hill Rd, Silver Spring, MD 20906', 'verified'),
(26, 'Aaron James', 'aaron18@aaron18.com', '+14436667722', '5181 Cedar Ln, Columbia, MD 21044', 'pending'),
(27, 'Tyler Hughes', 'tyler19@tyler19.com', '+14431112211', '8039 Park Ave, Glen Burnie, MD 21061', 'verified'),
(28, 'Eric Lawson', 'eric20@eric20.com', '+14432223344', '2420 Birchwood Dr, Rockville, MD 20853', 'verified'),
(29, 'Jason Miller', 'jason21@jason21.com', '+14435557711', '1185 Laurel Blvd, Frederick, MD 21701', 'pending'),
(30, 'Ethan Parker', 'ethan22@ethan22.com', '+14436668899', '3337 Willow Brook Rd, Ellicott City, MD 21043', 'verified'),
(31, 'Olivia Green', 'olivia23@olivia23.com', '+14439991122', '1098 Aspen Hill Rd, Silver Spring, MD 20906', 'verified'),
(32, 'Sophia Clark', 'sophia24@sophia24.com', '+14432225599', '6257 Baywood Dr, Towson, MD 21286', 'verified'),
(33, 'Hannah Lee', 'hannah25@hannah25.com', '+14434448800', '4390 Maple Ave, Baltimore, MD 21207', 'unverified'),
(34, 'Emily Johnson', 'emily26@emily26.com', '+14431119922', '9503 Oak Ave, Columbia, MD 21045', 'verified'),
(35, 'Aiden Rogers', 'aiden27@aiden27.com', '+14438885511', '7325 Beechwood Rd, Rockville, MD 20850', 'verified'),
(36, 'Logan White', 'logan28@logan28.com', '+14436663388', '5908 Cherry St, Gaithersburg, MD 20878', 'verified'),
(37, 'Lily Evans', 'lily29@lily29.com', '+14437774499', '2200 Cedar Ave, Ellicott City, MD 21043', 'pending'),
(38, 'Grace Nelson', 'grace30@grace30.com', '+14431116655', '1123 Oak St, Glen Burnie, MD 21060', 'unverified'),
(39, 'Matthew Reed', 'matthew31@matthew31.com', '+14439997788', '5542 Birch Rd, Frederick, MD 21704', 'verified'),
(40, 'Ava Cooper', 'ava32@ava32.com', '+14438882233', '2080 Summit Dr, Towson, MD 21204', 'verified'),
(41, 'Natalie Price', 'natalie33@natalie33.com', '+14434447722', '6131 Pinewood Rd, Baltimore, MD 21212', 'verified'),
(42, 'Jack Ramirez', 'jack34@jack34.com', '+14435558833', '7443 Hill St, Columbia, MD 21046', 'pending'),
(43, 'Ella Peterson', 'ella35@ella35.com', '+14436669944', '1359 Brookfield Rd, Silver Spring, MD 20901', 'unverified'),
(44, 'Hailey Foster', 'hailey36@hailey36.com', '+14439992255', '2217 Greenview Dr, Rockville, MD 20852', 'verified'),
(45, 'Lucas Turner', 'lucas37@lucas37.com', '+14438883366', '3309 Maple Grove Rd, Baltimore, MD 21218', 'verified'),
(46, 'Aiden Fisher', 'aiden38@aiden38.com', '+14431117788', '915 Cedarwood Ln, Frederick, MD 21702', 'pending'),
(47, 'Mia Rivera', 'mia39@mia39.com', '+14434448899', '4859 Parkwood Dr, Columbia, MD 21044', 'verified'),
(48, 'Benjamin Gray', 'benjamin40@benjamin40.com', '+14432221177', '6601 Beech Hill Rd, Towson, MD 21204', 'verified'),
(49, 'Zoe Adams', 'zoe41@zoe41.com', '+14436669922', '7842 Maple Ln, Silver Spring, MD 20910', 'pending'),
(50, 'Owen Russell', 'owen42@owen42.com', '+14431118855', '1920 Oak Grove Rd, Glen Burnie, MD 21061', 'verified'),
(51, 'Layla Ward', 'layla43@layla43.com', '+14438889933', '9054 Rolling Hill Rd, Baltimore, MD 21234', 'verified'),
(52, 'Elijah Scott', 'elijah44@elijah44.com', '+14434443322', '1193 Pine View Rd, Columbia, MD 21044', 'verified'),
(53, 'Abigail James', 'abigail45@abigail45.com', '+14437771100', '2059 Laurel Ridge Rd, Rockville, MD 20850', 'pending'),
(54, 'Logan Hughes', 'logan46@logan46.com', '+14431115522', '5115 Oak Hollow Rd, Towson, MD 21286', 'verified'),
(55, 'Zoe Brooks', 'zoe47@zoe47.com', '+14432229900', '7395 Maple Ridge Rd, Frederick, MD 21701', 'unverified'),
(56, 'Evelyn Carter', 'evelyn48@evelyn48.com', '+14438882244', '9013 Park Ridge Rd, Silver Spring, MD 20903', 'verified'),
(57, 'Julian Reed', 'julian49@julian49.com', '+14435556677', '3335 Birch Hill Rd, Baltimore, MD 21207', 'pending'),
(58, 'Scarlett Brown', 'scarlett50@scarlett50.com', '+14436665511', '1061 Riverbend Rd, Columbia, MD 21046', 'verified'),
(59, 'Aria Peterson', 'aria51@aria51.com', '+14439998822', '4279 Elmwood Dr, Rockville, MD 20852', 'verified'),
(60, 'Henry Walker', 'henry52@henry52.com', '+14431113366', '8834 Pine Crest Rd, Towson, MD 21204', 'verified'),
(61, 'Victoria Hayes', 'victoria53@victoria53.com', '+14432226699', '1908 Hilltop Dr, Glen Burnie, MD 21060', 'pending'),
(62, 'Daniel Ward', 'daniel54@daniel54.com', '+14438887755', '1152 Beechwood Ave, Columbia, MD 21045', 'verified'),
(63, 'Avery Green', 'avery55@avery55.com', '+14437778811', '7604 Oak Hill Rd, Baltimore, MD 21218', 'verified'),
(64, 'Madison Young', 'madison56@madison56.com', '+14434449922', '2309 Cedar View Rd, Rockville, MD 20853', 'verified'),
(65, 'Isaac Price', 'isaac57@isaac57.com', '+14431114433', '5147 Willow Brook Rd, Silver Spring, MD 20906', 'unverified'),
(66, 'Ella Rogers', 'ella58@ella58.com', '+14436668877', '6782 Laurel Hill Rd, Frederick, MD 21703', 'verified'),
(67, 'Jack Turner', 'jack59@jack59.com', '+14432223311', '8038 Birchwood Rd, Columbia, MD 21044', 'verified'),
(68, 'Sofia Collins', 'sofia60@sofia60.com', '+14439994422', '2951 Oak Grove Dr, Towson, MD 21204', 'verified');
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
