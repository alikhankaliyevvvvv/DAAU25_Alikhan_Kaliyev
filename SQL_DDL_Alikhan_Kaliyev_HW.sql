--CREATE DATABASE Subway

CREATE SCHEMA IF NOT EXISTS Subway;

SET search_path = subway;

CREATE TABLE IF NOT EXISTS Subway.Repair_status_code --First, depends on 0 tables
(
	PK_Repair_status_code_ID       CHAR(3) PRIMARY KEY,
	Repair_status_code_name        VARCHAR(50) NOT NULL UNIQUE,
	Repair_status_code_description TEXT
);

CREATE TABLE IF NOT EXISTS Subway.Route --Second priority, depends on 1 relation (Repair Status Code(RSC))
(
	PK_Route_ID                     BIGSERIAL PRIMARY KEY,
	Route_name                      VARCHAR(50) NOT NULL,
	Route_required_number_of_trains INT NOT NULL,
	Route_current_number_of_trains  INT,
	Station_Route_start_station     VARCHAR(50) NOT NULL,
	Station_Route_end_station 	    VARCHAR(50) NOT NULL,
	FK_Route_repair_status_code_ID  CHAR(3) NOT NULL REFERENCES Subway.Repair_Status_Code(PK_Repair_status_code_ID)
);


CREATE TABLE IF NOT EXISTS Subway.Station --Second priority, depends on 1 relation (RSC)
(
	PK_Station_ID 							BIGSERIAL 	PRIMARY KEY,
	Station_name 							VARCHAR(50) NOT NULL UNIQUE,
	FK_Station_Repair_status_code_ID 		CHAR(3) 	NOT NULL REFERENCES Subway.Repair_Status_Code(PK_Repair_status_code_ID),
	Station_required_number_of_employees 	INT 		NOT NULL,
	Station_current_number_of_employees 	INT
);

CREATE TABLE IF NOT EXISTS Subway.Train --Third priority, depends on 2 relations: RSC, Route
(
	PK_Train_ID 						BIGSERIAL 	 PRIMARY KEY,
	FK_Route_ID 						BIGINT		 REFERENCES Subway.Route(PK_Route_ID),
	Train_schedule_start 				TIME,
	Train_schedule_end 					TIME,
	FK_Train_repair_status_code 		CHAR(3) 	 NOT NULL REFERENCES Subway.Repair_Status_Code(PK_Repair_status_code_ID),
	Train_required_number_of_employees  INT,
	Train_current_number_of_employees   INT
);
--On the stage of creating data, you may be unsure if train must be in use, so it can have NULL time, route, etc.

CREATE TABLE IF NOT EXISTS Subway.Line --Fourth priority, depends in core on 3 relations:RCS, Route, Station
(
	PK_FK_Line_Route_ID   	BIGINT NOT NULL,
	PK_FK_Line_Station_ID 	BIGINT NOT NULL,
	
	PRIMARY KEY (PK_FK_Line_Route_ID, PK_FK_Line_Station_ID),
	
	FOREIGN KEY (PK_FK_Line_Route_ID)
		REFERENCES Subway.Route(PK_Route_ID),
		
	FOREIGN KEY (PK_FK_Line_Station_ID)
		REFERENCES Subway.Station(PK_Station_ID)
); --The only one solution, i could find for resolving mechanic of compound key made of 2 foreigh keys

CREATE TABLE IF NOT EXISTS Subway.Operating_Frequency --Fourth priority, depends in core on 3 relations:RCS, Route, Station
(
	PK_FK_Operating_frequency_Route_ID   	BIGINT NOT NULL,
	PK_FK_Operating_frequency_Station_ID 	BIGINT NOT NULL,
	Operating_frequency_first_arrival 		TIME NOT NULL,
	Operating_frequency_interval_minutes 	INT NOT NULL,
	
	PRIMARY KEY (PK_FK_Operating_frequency_Route_ID, PK_FK_Operating_frequency_Station_ID),
	
	FOREIGN KEY (PK_FK_Operating_frequency_Route_ID)
		REFERENCES Subway.Route(PK_Route_ID),
		
	FOREIGN KEY (PK_FK_Operating_frequency_Station_ID)
		REFERENCES Subway.Station(PK_Station_ID)	
);

CREATE TABLE IF NOT EXISTS Subway.Employee --Fifth priority, in core: RCS, Route, Station, Train
(
	PK_Employee_ID 				BIGSERIAL PRIMARY KEY,
	Employee_first_name 		VARCHAR(50) NOT NULL,
	Employee_middle_name 		VARCHAR(50),
	Employee_surname 			VARCHAR(50),
	Employee_passport_ID 		VARCHAR(20) NOT NULL UNIQUE,
	Employee_salary 			INT NOT NULL,
	FK_Employee_Station_ID 		BIGINT NOT NULL REFERENCES Subway.Station(PK_Station_ID),
	FK_Employee_Train_ID 		BIGINT REFERENCES Subway.Train(PK_Train_ID),
	Employee_work_phone_number 	VARCHAR(15),
	Employee_email 				VARCHAR(50) UNIQUE
);

CREATE TABLE IF NOT EXISTS Subway.Card --First, zero dependencies
(
	PK_Card_ID 				BIGSERIAL PRIMARY KEY,
	Card_Number 			CHAR(19) NOT NULL CHECK (length(Card_Number) = 19),
	Card_Full_Holder_Name 	VARCHAR(100) NOT NULL,
	Card_CVV 				INT CHECK (Card_CVV BETWEEN 100 AND 999),
	Card_Expiry_Date 		DATE NOT NULL
);
--to ensure proper card, without CARD VALIDATION, just the database entity,

CREATE TABLE IF NOT EXISTS Subway.Boarding_Pass --First priority
(
	PK_Boarding_Pass_ID 			BIGSERIAL PRIMARY KEY,
	Boarding_Pass_Name 				VARCHAR(20) NOT NULL,
	Boarding_Pass_Duration_In_Days 	INT NOT NULL
);

CREATE TABLE IF NOT EXISTS Subway.Discount --First priority
(
	PK_Discount_ID 			BIGSERIAL PRIMARY KEY,
	Discount_name 			VARCHAR(50) NOT NULL,
	Discount_percent 		DECIMAL(5, 2) NOT NULL, --0.00 or 100.00, to fit both (5, 2)
	Discount_description 	TEXT
);

CREATE TABLE IF NOT EXISTS Subway.Promotion --First priority
(
	PK_Promotion_ID 		BIGSERIAL PRIMARY KEY,
	Promotion_name 			VARCHAR(50) NOT NULL,
	Promotion_description 	TEXT,
	Promotion_start_date 	DATE NOT NULL,
	Promotion_end_date 		DATE
);
-- promotion end date can be null, if uncertain
CREATE TABLE IF NOT EXISTS Subway.Payment_Method --First priority
(
	PK_Payment_Method_ID 	BIGSERIAL PRIMARY KEY,
	Payment_Method_Name 	VARCHAR(50)
);
ALTER TABLE Subway.Payment_Method
	ALTER COLUMN Payment_Method_Name SET NOT NULL;
--forgot to do it, so

CREATE TABLE IF NOT EXISTS Subway.Customer
(
	PK_Customer_ID 		BIGSERIAL PRIMARY KEY,
	Customer_Type 		VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS Subway.Ticket_Type --Depends on promotion
(
	PK_Ticket_Type_ID 				BIGSERIAL PRIMARY KEY,
	Ticket_Type_name 				VARCHAR(50) NOT NULL UNIQUE,
	Ticket_Type_price 				DECIMAL(5,2) NOT NULL,
	FK_Ticket_Type_Promotion_ID 	BIGINT REFERENCES Subway.Promotion(PK_Promotion_ID)
);

CREATE TABLE IF NOT EXISTS Subway.Account --On 1 table: customer
(
	PK_Account_ID 				BIGSERIAL PRIMARY KEY,
	FK_Account_Customer_ID 		BIGINT NOT NULL REFERENCES Subway.Customer(PK_Customer_ID)
);

CREATE TABLE IF NOT EXISTS Subway.Customer_Boarding_Pass --Depends on 2 tables: Customer, Boarding Pass
(
	PK_FK_Customer_Boarding_Pass_Customer_ID 		BIGINT,
	PK_FK_Customer_Boarding_Pass_Boarding_Pass_ID 	BIGINT,
	Customer_Boarding_Pass_Start_Date 				DATE,
	Customer_Boarding_Pass_End_Date 				DATE,
	
	PRIMARY KEY (PK_FK_Customer_Boarding_Pass_Customer_ID, PK_FK_Customer_Boarding_Pass_Boarding_Pass_ID),
	
	FOREIGN KEY (PK_FK_Customer_Boarding_Pass_Customer_ID)
		REFERENCES Subway.Customer(PK_Customer_ID),
		
	FOREIGN KEY (PK_FK_Customer_Boarding_Pass_Boarding_Pass_ID)
		REFERENCES Subway.Boarding_pass(PK_Boarding_Pass_ID)
);
ALTER TABLE Subway.Customer_Boarding_Pass
    ALTER COLUMN Customer_Boarding_Pass_Start_Date SET NOT NULL;
ALTER TABLE Subway.Customer_Boarding_Pass
    ALTER COLUMN Customer_Boarding_Pass_End_Date SET NOT NULL;
--forgot to do it, so
	
CREATE TABLE IF NOT EXISTS Subway.Balance -- On 2 tables: account, customer
(
	PK_Balance_ID 				BIGSERIAL PRIMARY KEY,
	FK_Balance_Account_ID 		BIGINT NOT NULL REFERENCES Subway.Account(PK_Account_ID),
	Balance_remaining_balance 	DECIMAL(10, 2) NOT NULL
);

CREATE TABLE IF NOT EXISTS Subway.Discount_Ticket_Type --Depends on 3 tables at the core: Promotion, Discount, Ticket type
(
	PK_FK_Discount_Ticket_Type_Ticket_Type_ID 	BIGINT,
	PK_FK_Discount_Ticket_Discount_ID 			BIGINT,
	
	PRIMARY KEY (PK_FK_Discount_Ticket_Type_Ticket_Type_ID, PK_FK_Discount_Ticket_Discount_ID),
	
	FOREIGN KEY (PK_FK_Discount_Ticket_Type_Ticket_Type_ID)
		REFERENCES Subway.Ticket_Type(PK_Ticket_Type_ID),
		
	FOREIGN KEY (PK_FK_Discount_Ticket_Discount_ID)
		REFERENCES Subway.Discount(PK_Discount_ID)
);

CREATE TABLE IF NOT EXISTS Subway.Account_Card --Depends on 3 tables: Account, Card, Cutomer
(
	PK_FK_Account_Card_Account_ID 	BIGINT,
	PK_FK_Account_Card_Card_ID 		BIGINT,
	
	PRIMARY KEY (PK_FK_Account_Card_Account_ID, PK_FK_Account_Card_Card_ID),
	
	FOREIGN KEY (PK_FK_Account_Card_Account_ID)
		REFERENCES Subway.Account(PK_Account_ID),
		
	FOREIGN KEY (PK_FK_Account_Card_Card_ID)
		REFERENCES Subway.Card(PK_Card_ID)
);


CREATE TABLE IF NOT EXISTS Subway.Ticket --Kinda in the center of my DB, depends on many relations
(
	PK_Ticket_ID 					BIGSERIAL PRIMARY KEY,
	FK_Ticket_Ticket_Type_ID 		BIGINT NOT NULL REFERENCES Subway.Ticket_Type(PK_Ticket_Type_ID),
	FK_Ticket_Customer_ID 			BIGINT NOT NULL REFERENCES Subway.Customer(PK_Customer_ID),
	FK_Ticket_Station_ID 			BIGINT NOT NULL REFERENCES Subway.Station(PK_Station_ID),
	FK_Ticket_Payment_Method_ID 	BIGINT NOT NULL REFERENCES Subway.Payment_Method(PK_Payment_Method_ID),
	Ticket_Date_Time 				TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

--Some new checks, that i made on finish_lane:
--Date after certain, as from requirements
ALTER TABLE subway.promotion
  ADD CONSTRAINT chk_promotion_start_date
  CHECK (promotion_start_date >= DATE '2000-01-02');

-- no negative salary
ALTER TABLE subway.employee
  ADD CONSTRAINT chk_employee_salary_nonneg
  CHECK (employee_salary >= 0);

-- no negative balance
ALTER TABLE subway.balance
  ADD CONSTRAINT chk_balance_nonneg
  CHECK (balance_remaining_balance >= 0);

-- no unreal percentage
ALTER TABLE subway.discount
  ADD CONSTRAINT chk_discount_pct
  CHECK (discount_percent >= 0 AND discount_percent <= 100);

--date from requirements
ALTER TABLE subway.customer_boarding_pass
  ADD CONSTRAINT chk_cbp_dates
  CHECK (customer_boarding_pass_start_date >= DATE '2000-01-02'
         AND customer_boarding_pass_end_date >= customer_boarding_pass_start_date);


-- Repair Status Code
INSERT INTO subway.repair_status_code
(PK_Repair_status_code_ID, Repair_status_code_name, Repair_status_code_description)
VALUES
('OKY', 'Operational', 'Fully operational'),
('REP', 'UnderRepair', 'Scheduled maintenance')
ON CONFLICT DO NOTHING;

-- Route
INSERT INTO subway.route
(Route_name, Route_required_number_of_trains, Route_current_number_of_trains,
 Station_Route_start_station, Station_Route_end_station,
 FK_Route_repair_status_code_ID)
VALUES
('Green Line', 10, 8, 'Station A', 'Station Z', 'OKY'),
('Blue Line', 8, 6, 'Station B', 'Station Y', 'REP')
ON CONFLICT DO NOTHING;

-- Station
INSERT INTO subway.station
(Station_name, FK_Station_Repair_status_code_ID,
 Station_required_number_of_employees, Station_current_number_of_employees)
VALUES
('Station A', 'OKY', 20, 18),
('Station Z', 'REP', 12, 10)
ON CONFLICT DO NOTHING;

-- Train
INSERT INTO subway.train
(FK_Route_ID, Train_schedule_start, Train_schedule_end,
 FK_Train_repair_status_code, Train_required_number_of_employees,
 Train_current_number_of_employees)
VALUES
(
 (SELECT PK_Route_ID FROM subway.route WHERE Route_name='Green Line' LIMIT 1),
 '06:00', '23:00', 'OKY', 3, 3
),
(
 (SELECT PK_Route_ID FROM subway.route WHERE Route_name='Blue Line' LIMIT 1),
 '07:00', '22:00', 'REP', 3, 2
)
ON CONFLICT DO NOTHING;

-- Line
INSERT INTO subway.line
(PK_FK_Line_Route_ID, PK_FK_Line_Station_ID)
VALUES
(
 (SELECT PK_Route_ID FROM subway.route WHERE Route_name='Green Line' LIMIT 1),
 (SELECT PK_Station_ID FROM subway.station WHERE Station_name='Station A' LIMIT 1)
),
(
 (SELECT PK_Route_ID FROM subway.route WHERE Route_name='Green Line' LIMIT 1),
 (SELECT PK_Station_ID FROM subway.station WHERE Station_name='Station Z' LIMIT 1)
)
ON CONFLICT DO NOTHING;

-- Operating Frequency
INSERT INTO subway.operating_frequency
(PK_FK_Operating_frequency_Route_ID,
 PK_FK_Operating_frequency_Station_ID,
 Operating_frequency_first_arrival,
 Operating_frequency_interval_minutes)
VALUES
(
 (SELECT PK_Route_ID FROM subway.route WHERE Route_name='Green Line' LIMIT 1),
 (SELECT PK_Station_ID FROM subway.station WHERE Station_name='Station A' LIMIT 1),
 '06:00', 5
),
(
 (SELECT PK_Route_ID FROM subway.route WHERE Route_name='Green Line' LIMIT 1),
 (SELECT PK_Station_ID FROM subway.station WHERE Station_name='Station Z' LIMIT 1),
 '06:10', 7
)
ON CONFLICT DO NOTHING;

-- Employee
INSERT INTO subway.employee
(Employee_first_name, Employee_middle_name, Employee_surname,
 Employee_passport_ID, Employee_salary,
 FK_Employee_Station_ID, FK_Employee_Train_ID,
 Employee_work_phone_number, Employee_email)
VALUES
(
 'John', 'A', 'Smith', 'P12345678', 300000,
 (SELECT PK_Station_ID FROM subway.station WHERE Station_name='Station A'),
 (SELECT PK_Train_ID FROM subway.train LIMIT 1),
 '87070010010', 'john.smith@mail.com'
),
(
 'Alice', NULL, 'Brown', 'P87654321', 280000,
 (SELECT PK_Station_ID FROM subway.station WHERE Station_name='Station Z'),
 (SELECT PK_Train_ID FROM subway.train ORDER BY PK_Train_ID DESC LIMIT 1),
 '87071234567', 'alice.brown@mail.com'
)
ON CONFLICT DO NOTHING;

-- Card
INSERT INTO subway.card
(Card_Number, Card_Full_Holder_Name, Card_CVV, Card_Expiry_Date)
VALUES
('1111222233334444555', 'John Smith', 123, '2027-01-01'),
('5555666677778888999', 'Alice Brown', 456, '2028-05-10')
ON CONFLICT DO NOTHING;

-- Boarding Pass
INSERT INTO subway.boarding_pass
(Boarding_Pass_Name, Boarding_Pass_Duration_In_Days)
VALUES
('1-Day Pass', 1),
('30-Day Pass', 30)
ON CONFLICT DO NOTHING;

-- Discount
INSERT INTO subway.discount
(Discount_name, Discount_percent, Discount_description)
VALUES
('Student', 50.00, 'Half price for students'),
('Senior', 30.00, 'Reduced fare for seniors')
ON CONFLICT DO NOTHING;

-- Promotion
INSERT INTO subway.promotion
(Promotion_name, Promotion_description, Promotion_start_date, Promotion_end_date)
VALUES
('Winter Sale', 'Winter promotion', '2025-01-01', '2025-03-01'),
('Spring Boost', 'Spring promo', '2025-03-15', NULL)
ON CONFLICT DO NOTHING;

-- Payment Method
INSERT INTO subway.payment_method
(Payment_Method_Name)
VALUES
('Card'),
('Cash')
ON CONFLICT DO NOTHING;

-- Customer
INSERT INTO subway.customer
(Customer_Type)
VALUES
('Adult'),
('Student')
ON CONFLICT DO NOTHING;

-- Ticket Type
INSERT INTO subway.ticket_type
(Ticket_Type_name, Ticket_Type_price, FK_Ticket_Type_Promotion_ID)
VALUES
('Single Ride', 150.00, (SELECT PK_Promotion_ID FROM subway.promotion LIMIT 1)),
('Daily Pass', 500.00, NULL)
ON CONFLICT DO NOTHING;

-- Account
INSERT INTO subway.account
(FK_Account_Customer_ID)
VALUES
((SELECT PK_Customer_ID FROM subway.customer WHERE Customer_Type='Adult' LIMIT 1)),
((SELECT PK_Customer_ID FROM subway.customer WHERE Customer_Type='Student' LIMIT 1))
ON CONFLICT DO NOTHING;

-- Customer Boarding Pass
INSERT INTO subway.customer_boarding_pass
(PK_FK_Customer_Boarding_Pass_Customer_ID,
 PK_FK_Customer_Boarding_Pass_Boarding_Pass_ID,
 Customer_Boarding_Pass_Start_Date,
 Customer_Boarding_Pass_End_Date)
VALUES
(
 (SELECT PK_Customer_ID FROM subway.customer WHERE Customer_Type='Adult' LIMIT 1),
 (SELECT PK_Boarding_Pass_ID FROM subway.boarding_pass WHERE Boarding_Pass_Name='1-Day Pass' LIMIT 1),
 '2025-01-01', '2025-01-02'
),
(
 (SELECT PK_Customer_ID FROM subway.customer WHERE Customer_Type='Student' LIMIT 1),
 (SELECT PK_Boarding_Pass_ID FROM subway.boarding_pass WHERE Boarding_Pass_Name='30-Day Pass' LIMIT 1),
 '2025-01-01', '2025-01-31'
)
ON CONFLICT DO NOTHING;

-- Balance
INSERT INTO subway.balance
(FK_Balance_Account_ID, Balance_remaining_balance)
VALUES
(
 (SELECT PK_Account_ID FROM subway.account LIMIT 1),
 1000.00
),
(
 (SELECT PK_Account_ID FROM subway.account ORDER BY PK_Account_ID DESC LIMIT 1),
 2500.50
)
ON CONFLICT DO NOTHING;

-- Discount Ticket Type
INSERT INTO subway.discount_ticket_type
(PK_FK_Discount_Ticket_Type_Ticket_Type_ID,
 PK_FK_Discount_Ticket_Discount_ID)
VALUES
(
 (SELECT PK_Ticket_Type_ID FROM subway.ticket_type WHERE Ticket_Type_name='Single Ride' LIMIT 1),
 (SELECT PK_Discount_ID FROM subway.discount WHERE Discount_name='Student' LIMIT 1)
),
(
 (SELECT PK_Ticket_Type_ID FROM subway.ticket_type WHERE Ticket_Type_name='Daily Pass' LIMIT 1),
 (SELECT PK_Discount_ID FROM subway.discount WHERE Discount_name='Senior' LIMIT 1)
)
ON CONFLICT DO NOTHING;

-- Account Card
INSERT INTO subway.account_card
(PK_FK_Account_Card_Account_ID, PK_FK_Account_Card_Card_ID)
VALUES
(
 (SELECT PK_Account_ID FROM subway.account LIMIT 1),
 (SELECT PK_Card_ID FROM subway.card LIMIT 1)
),
(
 (SELECT PK_Account_ID FROM subway.account ORDER BY PK_Account_ID DESC LIMIT 1),
 (SELECT PK_Card_ID FROM subway.card ORDER BY PK_Card_ID DESC LIMIT 1)
)
ON CONFLICT DO NOTHING;

-- Ticket
INSERT INTO subway.ticket
(FK_Ticket_Ticket_Type_ID, FK_Ticket_Customer_ID,
 FK_Ticket_Station_ID, FK_Ticket_Payment_Method_ID)
VALUES
(
 (SELECT PK_Ticket_Type_ID FROM subway.ticket_type WHERE Ticket_Type_name='Single Ride' LIMIT 1),
 (SELECT PK_Customer_ID FROM subway.customer WHERE Customer_Type='Adult' LIMIT 1),
 (SELECT PK_Station_ID FROM subway.station LIMIT 1),
 (SELECT PK_Payment_Method_ID FROM subway.payment_method WHERE Payment_Method_Name='Card' LIMIT 1)
),
(
 (SELECT PK_Ticket_Type_ID FROM subway.ticket_type WHERE Ticket_Type_name='Daily Pass' LIMIT 1),
 (SELECT PK_Customer_ID FROM subway.customer WHERE Customer_Type='Student' LIMIT 1),
 (SELECT PK_Station_ID FROM subway.station ORDER BY PK_Station_ID DESC LIMIT 1),
 (SELECT PK_Payment_Method_ID FROM subway.payment_method WHERE Payment_Method_Name='Cash' LIMIT 1)
)
ON CONFLICT DO NOTHING;


-- Add record_ts to every table (default = current_date)

ALTER TABLE subway.repair_status_code 
    ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT current_date;
UPDATE subway.repair_status_code SET record_ts = current_date WHERE record_ts IS NULL;

ALTER TABLE subway.route 
    ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT current_date;
UPDATE subway.route SET record_ts = current_date WHERE record_ts IS NULL;

ALTER TABLE subway.station 
    ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT current_date;
UPDATE subway.station SET record_ts = current_date WHERE record_ts IS NULL;

ALTER TABLE subway.train 
    ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT current_date;
UPDATE subway.train SET record_ts = current_date WHERE record_ts IS NULL;

ALTER TABLE subway.line 
    ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT current_date;
UPDATE subway.line SET record_ts = current_date WHERE record_ts IS NULL;

ALTER TABLE subway.operating_frequency 
    ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT current_date;
UPDATE subway.operating_frequency SET record_ts = current_date WHERE record_ts IS NULL;

ALTER TABLE subway.employee 
    ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT current_date;
UPDATE subway.employee SET record_ts = current_date WHERE record_ts IS NULL;

ALTER TABLE subway.card 
    ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT current_date;
UPDATE subway.card SET record_ts = current_date WHERE record_ts IS NULL;

ALTER TABLE subway.boarding_pass 
    ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT current_date;
UPDATE subway.boarding_pass SET record_ts = current_date WHERE record_ts IS NULL;

ALTER TABLE subway.discount 
    ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT current_date;
UPDATE subway.discount SET record_ts = current_date WHERE record_ts IS NULL;

ALTER TABLE subway.promotion 
    ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT current_date;
UPDATE subway.promotion SET record_ts = current_date WHERE record_ts IS NULL;

ALTER TABLE subway.payment_method 
    ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT current_date;
UPDATE subway.payment_method SET record_ts = current_date WHERE record_ts IS NULL;

ALTER TABLE subway.customer 
    ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT current_date;
UPDATE subway.customer SET record_ts = current_date WHERE record_ts IS NULL;

ALTER TABLE subway.ticket_type 
    ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT current_date;
UPDATE subway.ticket_type SET record_ts = current_date WHERE record_ts IS NULL;

ALTER TABLE subway.account 
    ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT current_date;
UPDATE subway.account SET record_ts = current_date WHERE record_ts IS NULL;

ALTER TABLE subway.customer_boarding_pass 
    ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT current_date;
UPDATE subway.customer_boarding_pass SET record_ts = current_date WHERE record_ts IS NULL;

ALTER TABLE subway.balance 
    ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT current_date;
UPDATE subway.balance SET record_ts = current_date WHERE record_ts IS NULL;

ALTER TABLE subway.discount_ticket_type 
    ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT current_date;
UPDATE subway.discount_ticket_type SET record_ts = current_date WHERE record_ts IS NULL;

ALTER TABLE subway.account_card 
    ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT current_date;
UPDATE subway.account_card SET record_ts = current_date WHERE record_ts IS NULL;

ALTER TABLE subway.ticket 
    ADD COLUMN IF NOT EXISTS record_ts DATE DEFAULT current_date;
UPDATE subway.ticket SET record_ts = current_date WHERE record_ts IS NULL;

SELECT * FROM Subway.Ticket
