-- Run against the SAME database as timeguard_api. No changes to the 11 core tables.
CREATE TABLE IF NOT EXISTS tech_web_audit_logs (
 id bigint unsigned AUTO_INCREMENT PRIMARY KEY,
 actor_id varchar(10) NOT NULL,
 actor_role varchar(20) NOT NULL,
 action varchar(30) NOT NULL,
 entity varchar(40) NOT NULL,
 record_id varchar(10) NOT NULL,
 changed_fields text NOT NULL,
 created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
 INDEX audit_record(entity,record_id,created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
