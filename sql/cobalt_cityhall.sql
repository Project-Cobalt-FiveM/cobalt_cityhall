CREATE TABLE IF NOT EXISTS `job_payouts` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `job` VARCHAR(32) NOT NULL,
  `amount` INT UNSIGNED NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `created_job` (`created_at`, `job`),
  KEY `citizenid` (`citizenid`),
  CONSTRAINT `job_payouts_citizenid` FOREIGN KEY (`citizenid`) REFERENCES `players` (`citizenid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `job_settings` (
  `job` VARCHAR(32) NOT NULL,
  `open` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
