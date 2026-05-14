/*
  Telco Project - table creation script

  Target database: Oracle XE
  Target schema/user: TELCO_APP

  The schema follows the provided CSV headers exactly:
    TARIFFS.csv        -> TARIFFS
    CUSTOMERS.csv      -> CUSTOMERS
    MONTHLY_STATS.csv  -> MONTHLY_STATS

  Import note:
  CUSTOMERS.SIGNUP_DATE is stored in the CSV as DD/MM/YYYY. The ALTER SESSION
  below helps manual CSV imports in DBeaver interpret those values correctly.
*/

ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';

/*
  Drop child tables before parent tables so foreign key dependencies do not
  block repeatable local testing. ORA-00942 is ignored so the script can run
  on a clean TELCO_APP schema.
*/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE MONTHLY_STATS CASCADE CONSTRAINTS PURGE';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
      RAISE;
    END IF;
END;
/

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE CUSTOMERS CASCADE CONSTRAINTS PURGE';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
      RAISE;
    END IF;
END;
/

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE TARIFFS CASCADE CONSTRAINTS PURGE';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
      RAISE;
    END IF;
END;
/

/*
  TARIFFS is the package definition table. Limits are kept as numeric columns
  and are allowed to be zero because some tariffs have no included data,
  minutes, or SMS in the source file.
*/
CREATE TABLE TARIFFS (
  TARIFF_ID    NUMBER(5)     NOT NULL,
  NAME         VARCHAR2(50)  NOT NULL,
  MONTHLY_FEE  NUMBER(10,2)  NOT NULL,
  DATA_LIMIT   NUMBER(10,2)  NOT NULL,
  MINUTE_LIMIT NUMBER(10)    NOT NULL,
  SMS_LIMIT    NUMBER(10)    NOT NULL,
  CONSTRAINT PK_TARIFFS PRIMARY KEY (TARIFF_ID),
  CONSTRAINT UQ_TARIFFS_NAME UNIQUE (NAME),
  CONSTRAINT CK_TARIFFS_ID_POSITIVE CHECK (TARIFF_ID > 0),
  CONSTRAINT CK_TARIFFS_MONTHLY_FEE_NN CHECK (MONTHLY_FEE >= 0),
  CONSTRAINT CK_TARIFFS_DATA_LIMIT_NN CHECK (DATA_LIMIT >= 0),
  CONSTRAINT CK_TARIFFS_MINUTE_LIMIT_NN CHECK (MINUTE_LIMIT >= 0),
  CONSTRAINT CK_TARIFFS_SMS_LIMIT_NN CHECK (SMS_LIMIT >= 0)
);

/*
  CUSTOMERS contains one row per subscriber. The source data has unique
  CUSTOMER_ID values and every TARIFF_ID matches TARIFFS, so the foreign key is
  safe and useful for tariff-based joins.
*/
CREATE TABLE CUSTOMERS (
  CUSTOMER_ID NUMBER(5)     NOT NULL,
  NAME        VARCHAR2(50)  NOT NULL,
  CITY        VARCHAR2(50)  NOT NULL,
  SIGNUP_DATE DATE          NOT NULL,
  TARIFF_ID   NUMBER(5)     NOT NULL,
  CONSTRAINT PK_CUSTOMERS PRIMARY KEY (CUSTOMER_ID),
  CONSTRAINT FK_CUSTOMERS_TARIFFS
    FOREIGN KEY (TARIFF_ID) REFERENCES TARIFFS (TARIFF_ID),
  CONSTRAINT CK_CUSTOMERS_ID_POSITIVE CHECK (CUSTOMER_ID > 0)
);

/*
  MONTHLY_STATS contains this month's usage and payment state. CUSTOMER_ID is
  unique because the CSV has at most one monthly row per customer; missing
  customer IDs are intentional and are part of requirement 4. In the current
  CSV, ID mirrors CUSTOMER_ID, but it is kept as a separate primary key because
  the file provides both columns explicitly.
*/
CREATE TABLE MONTHLY_STATS (
  ID             NUMBER(5)     NOT NULL,
  CUSTOMER_ID    NUMBER(5)     NOT NULL,
  DATA_USAGE     NUMBER(10,2)  NOT NULL,
  MINUTE_USAGE   NUMBER(10)    NOT NULL,
  SMS_USAGE      NUMBER(10)    NOT NULL,
  PAYMENT_STATUS VARCHAR2(10)  NOT NULL,
  CONSTRAINT PK_MONTHLY_STATS PRIMARY KEY (ID),
  CONSTRAINT UQ_MONTHLY_STATS_CUSTOMER UNIQUE (CUSTOMER_ID),
  CONSTRAINT FK_MONTHLY_STATS_CUSTOMERS
    FOREIGN KEY (CUSTOMER_ID) REFERENCES CUSTOMERS (CUSTOMER_ID),
  CONSTRAINT CK_MONTHLY_STATS_ID_POSITIVE CHECK (ID > 0),
  CONSTRAINT CK_MONTHLY_STATS_CUSTOMER_POSITIVE CHECK (CUSTOMER_ID > 0),
  CONSTRAINT CK_MONTHLY_STATS_DATA_USAGE_NN CHECK (DATA_USAGE >= 0),
  CONSTRAINT CK_MONTHLY_STATS_MINUTE_USAGE_NN CHECK (MINUTE_USAGE >= 0),
  CONSTRAINT CK_MONTHLY_STATS_SMS_USAGE_NN CHECK (SMS_USAGE >= 0),
  CONSTRAINT CK_MONTHLY_STATS_PAYMENT_STATUS
    CHECK (PAYMENT_STATUS IN ('PAID', 'UNPAID', 'LATE'))
);

/*
  Indexes for expected joins and filters. Primary key and unique constraints
  already create indexes for TARIFF_ID, CUSTOMER_ID, NAME, and monthly
  CUSTOMER_ID; this satisfies the requested indexes for tariff id/name and
  customer id joins. The additional indexes below support common filtering,
  grouping, and ordering in the functional requirements.
*/
CREATE INDEX IDX_CUSTOMERS_TARIFF_ID
  ON CUSTOMERS (TARIFF_ID);

CREATE INDEX IDX_CUSTOMERS_CITY
  ON CUSTOMERS (CITY);

CREATE INDEX IDX_CUSTOMERS_SIGNUP_DATE
  ON CUSTOMERS (SIGNUP_DATE);

CREATE INDEX IDX_MONTHLY_STATS_PAYMENT_STATUS
  ON MONTHLY_STATS (PAYMENT_STATUS);

COMMENT ON TABLE TARIFFS IS
  'Tariff/package definitions imported from TARIFFS.csv.';

COMMENT ON TABLE CUSTOMERS IS
  'Subscriber master data imported from CUSTOMERS.csv.';

COMMENT ON TABLE MONTHLY_STATS IS
  'Current-month usage and payment records imported from MONTHLY_STATS.csv.';

COMMENT ON COLUMN CUSTOMERS.SIGNUP_DATE IS
  'CSV date format is DD/MM/YYYY.';

COMMENT ON COLUMN MONTHLY_STATS.DATA_USAGE IS
  'Usage amount in the same unit as TARIFFS.DATA_LIMIT, likely MB based on package sizes.';

COMMENT ON COLUMN MONTHLY_STATS.PAYMENT_STATUS IS
  'Observed values in the CSV are PAID, UNPAID, and LATE.';
