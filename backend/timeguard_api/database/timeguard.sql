-- Approved DD: exactly 11 core tables. No legacy DROP/ALTER or automatic data conversion.
-- AT.area_id always references an assigned work area, including offsite events.
-- See database/CONTRACT.md for explicitly documented constraints and migration decisions.
CREATE DATABASE IF NOT EXISTS timeguard_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE timeguard_db;
SET time_zone = '+07:00';
CREATE TABLE IF NOT EXISTS departments (
 department_id varchar(10) PRIMARY KEY,
 department_name varchar(100) NOT NULL,
 department_code varchar(20) NOT NULL UNIQUE,
 description varchar(255),
 status varchar(20) NOT NULL,
 created_date date NOT NULL
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS employees (
 employee_id varchar(10) PRIMARY KEY,
 full_name varchar(100) NOT NULL,
 email varchar(100) NOT NULL UNIQUE,
 google_uid varchar(50) UNIQUE,
 phone varchar(15),
 department_id varchar(10) NOT NULL,
 status varchar(20) NOT NULL,
 created_date date NOT NULL,
 FOREIGN KEY(department_id) REFERENCES departments(department_id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS admins (
 admin_id varchar(10) PRIMARY KEY,
 full_name varchar(100) NOT NULL,
 username varchar(50) NOT NULL UNIQUE,
 password_hash varchar(255) NOT NULL,
 email varchar(100) NOT NULL,
 phone varchar(15),
 status varchar(20) NOT NULL,
 last_login_date datetime,
 created_date date NOT NULL
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS human_resources (
 hr_id varchar(10) PRIMARY KEY,
 full_name varchar(100) NOT NULL,
 username varchar(50) NOT NULL UNIQUE,
 password_hash varchar(255) NOT NULL,
 email varchar(100) NOT NULL,
 phone varchar(15),
 status varchar(20) NOT NULL,
 last_login_date datetime,
 created_date date NOT NULL
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS supervisors (
 supervisor_id varchar(10) PRIMARY KEY,
 full_name varchar(100) NOT NULL,
 username varchar(50) NOT NULL UNIQUE,
 password_hash varchar(255) NOT NULL,
 email varchar(100) NOT NULL,
 phone varchar(15),
 department_id varchar(10) NOT NULL,
 status varchar(20) NOT NULL,
 last_login_date datetime,
 created_date date NOT NULL,
 FOREIGN KEY(department_id) REFERENCES departments(department_id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS system_configurations (
 config_id varchar(10) PRIMARY KEY,
 config_name varchar(100) NOT NULL,
 start_time time,
 start_late time,
 description varchar(255),
 updated_date datetime NOT NULL,
 config_type varchar(20) NOT NULL
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS face_biometrics (
 biometric_id varchar(10) PRIMARY KEY,
 user_id varchar(10) NOT NULL,
 face_image varchar(255) NOT NULL,
 face_encoding text NOT NULL,
 registration_date datetime NOT NULL,
 approval_status varchar(20) NOT NULL,
 approved_by varchar(10),
 approved_date datetime,
 status varchar(20) NOT NULL,
 FOREIGN KEY(user_id) REFERENCES employees(employee_id),
 FOREIGN KEY(approved_by) REFERENCES human_resources(hr_id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS geofence_areas (
 area_id varchar(10) PRIMARY KEY,
 area_name varchar(100) NOT NULL,
 department_id varchar(10) NOT NULL,
 polygon_coordinates text NOT NULL,
 center_latitude decimal(10,6) NOT NULL,
 center_longitude decimal(10,6) NOT NULL,
 status varchar(20) NOT NULL,
 created_date datetime NOT NULL,
 FOREIGN KEY(department_id) REFERENCES departments(department_id),
 CHECK(JSON_VALID(polygon_coordinates)),
 CHECK(center_latitude BETWEEN -90 AND 90),
 CHECK(center_longitude BETWEEN -180 AND 180)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS employee_work_areas (
 employee_area_id varchar(10) PRIMARY KEY,
 employee_id varchar(10) NOT NULL,
 area_id varchar(10) NOT NULL,
 is_primary boolean NOT NULL DEFAULT 0,
 effective_date date NOT NULL,
 end_date date NULL,
 status varchar(20) NOT NULL,
 FOREIGN KEY(employee_id) REFERENCES employees(employee_id),
 FOREIGN KEY(area_id) REFERENCES geofence_areas(area_id),
 INDEX assignment_lookup(employee_id,status,effective_date,end_date),
 CHECK(end_date IS NULL OR end_date>=effective_date)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS offsite_work_requests (
 offsite_request_id varchar(10) PRIMARY KEY,
 employee_id varchar(10) NOT NULL,
 request_date datetime NOT NULL,
 work_date_start date NOT NULL,
 work_date_end date NOT NULL,
 location_description varchar(255) NOT NULL,
 reason varchar(255) NOT NULL,
 approval_status varchar(20) NOT NULL,
 approved_by varchar(10),
 approved_date datetime,
 FOREIGN KEY(employee_id) REFERENCES employees(employee_id),
 FOREIGN KEY(approved_by) REFERENCES supervisors(supervisor_id),
 INDEX offsite_lookup(employee_id,approval_status,work_date_start,work_date_end),
 CHECK(work_date_end>=work_date_start)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS attendance_logs (
 attendance_id varchar(10) PRIMARY KEY,
 user_id varchar(10) NOT NULL,
 area_id varchar(10) NOT NULL,
 check_type varchar(20) NOT NULL,
 check_datetime datetime NOT NULL,
 latitude decimal(10,6) NOT NULL,
 longitude decimal(10,6) NOT NULL,
 verification_method varchar(50) NOT NULL,
 zone_status varchar(20) NOT NULL,
 device_info varchar(100),
 is_late boolean NOT NULL DEFAULT 0,
 evidence_photo varchar(255) NOT NULL,
 reason varchar(255),
 approval_status varchar(20) NOT NULL,
 approved_by varchar(10),
 approved_date datetime,
 offsite_request_id varchar(10) NULL,
 FOREIGN KEY(user_id) REFERENCES employees(employee_id),
 FOREIGN KEY(area_id) REFERENCES geofence_areas(area_id),
 FOREIGN KEY(approved_by) REFERENCES supervisors(supervisor_id),
 FOREIGN KEY(offsite_request_id) REFERENCES offsite_work_requests(offsite_request_id),
 INDEX attendance_lookup(user_id,check_datetime,check_type),
 CHECK(check_type IN ('เข้างาน','ออกงาน')),
 CHECK(latitude BETWEEN -90 AND 90),
 CHECK(longitude BETWEEN -180 AND 180)
) ENGINE=InnoDB;

-- Supporting technical tables, NOT substitutes for core entities.
CREATE TABLE IF NOT EXISTS tech_auth_tokens (
 token_hash char(64) PRIMARY KEY, employee_id varchar(10) NULL, admin_id varchar(10) NULL,
 hr_id varchar(10) NULL, supervisor_id varchar(10) NULL, expires_at datetime NOT NULL,
 FOREIGN KEY(employee_id) REFERENCES employees(employee_id), FOREIGN KEY(admin_id) REFERENCES admins(admin_id),
 FOREIGN KEY(hr_id) REFERENCES human_resources(hr_id), FOREIGN KEY(supervisor_id) REFERENCES supervisors(supervisor_id),
 CHECK((employee_id IS NOT NULL)+(admin_id IS NOT NULL)+(hr_id IS NOT NULL)+(supervisor_id IS NOT NULL)=1)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS tech_notifications (
 id bigint unsigned AUTO_INCREMENT PRIMARY KEY, employee_id varchar(10) NOT NULL,
 title varchar(200) NOT NULL, body text NOT NULL, read_at datetime NULL,
 created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY(employee_id) REFERENCES employees(employee_id), INDEX notice_lookup(employee_id,id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS tech_login_attempts (
 attempt_key char(64) PRIMARY KEY, attempts int unsigned NOT NULL DEFAULT 0, window_start datetime NOT NULL
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS tech_id_sequences (
 prefix varchar(3) PRIMARY KEY, next_value bigint unsigned NOT NULL
) ENGINE=InnoDB;
-- Primary-assignment and duplicate-event constraints are enforced by transactional PHP:
-- serialize on the E row. No extra columns are added to EA or AT.
INSERT IGNORE INTO departments VALUES ('D0001','เทคโนโลยีสารสนเทศ','IT','แผนกตัวอย่าง','active',CURDATE());
INSERT IGNORE INTO employees VALUES ('E0001','พนักงานตัวอย่าง','employee@test.com',NULL,'','D0001','active',CURDATE());
-- Backoffice demo only; password is 123456, never stored as plaintext.
INSERT IGNORE INTO admins VALUES ('A0001','ผู้ดูแลระบบ','admin','$2y$10$9Rr0Ygj6nqX5D2bw53pRkey0vTOs.9X04lvLqFJn0pKII0VZa1dVy','admin@test.com','','active',NULL,CURDATE());
INSERT IGNORE INTO human_resources VALUES ('H0001','เจ้าหน้าที่บุคคล','hr','$2y$10$9Rr0Ygj6nqX5D2bw53pRkey0vTOs.9X04lvLqFJn0pKII0VZa1dVy','hr@test.com','','active',NULL,CURDATE());
INSERT IGNORE INTO supervisors VALUES ('S0001','หัวหน้างาน','supervisor','$2y$10$9Rr0Ygj6nqX5D2bw53pRkey0vTOs.9X04lvLqFJn0pKII0VZa1dVy','supervisor@test.com','','D0001','active',NULL,CURDATE());
INSERT IGNORE INTO system_configurations VALUES ('CFG0001','เวลาปฏิบัติงาน','09:00:00','09:00:00','ค่าเริ่มต้น ต้องปรับตามนโยบายองค์กร',NOW(),'attendance');
INSERT IGNORE INTO geofence_areas VALUES ('G0001','สำนักงานตัวอย่าง','D0001','[{"lat":13.7553,"lng":100.5008},{"lat":13.7553,"lng":100.5028},{"lat":13.7573,"lng":100.5028},{"lat":13.7573,"lng":100.5008}]',13.756300,100.501800,'active',NOW());
INSERT IGNORE INTO employee_work_areas VALUES ('EA0001','E0001','G0001',1,CURDATE(),NULL,'active');
-- No fake Google identity, face encoding, verified attendance, or approval is seeded.
