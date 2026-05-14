# Telco Project Setup

This document records the completed local setup and verification workflow for the Telco Oracle XE project.

## 1. Start Oracle XE with Docker

The repository includes `docker-compose.yml`, which starts Oracle XE with a named Docker volume and creates the application user `TELCO_APP`.

```powershell
docker compose up -d
```

Check that the container is running and wait for Oracle XE to finish startup:

```powershell
docker ps
docker logs -f telco-oracle-xe
```

The database is ready when the logs show that startup has completed and the container health check is passing.

The checked-in Docker Compose file maps host port `1522` to Oracle's container port `1521`:

```text
localhost:1522 -> container:1521
```

If you start Oracle XE manually instead of using Docker Compose, this equivalent command maps Oracle to host port `1522`:

```powershell
docker run -d `
  --name telco-oracle-xe `
  -p 1522:1521 `
  -e ORACLE_PASSWORD=oracle `
  -e APP_USER=TELCO_APP `
  -e APP_USER_PASSWORD=telco_app_pwd `
  -v telco-oracle-data:/opt/oracle/oradata `
  gvenzl/oracle-xe:21-slim
```

Do not commit generated Oracle database files, local Docker volume contents, logs, or client metadata to git. The repository only needs the source CSV files, SQL files, documentation, screenshots, and Docker Compose definition.

## 2. Connect with DBeaver

Create a new Oracle connection in DBeaver.

For the checked-in Docker Compose setup:

| Setting | Value |
| --- | --- |
| Host | `localhost` |
| Port | `1522` |
| Database / Service name | `XEPDB1` |
| Username | `TELCO_APP` |
| Password | `telco_app_pwd` |
| Driver | Oracle |

If you used the manual `docker run -p 1521:1521` command, use port `1521` instead.

If DBeaver asks to download the Oracle driver, allow it. Use service-name mode with `XEPDB1`; if a different Oracle image is used, confirm the service name from the container logs.

## 3. Create the tables manually

Tables were created manually from DBeaver after connecting as `TELCO_APP`.

1. Open `sql/TABLE_CREATION_SCRIPTS.sql` in DBeaver.
2. Select the `TELCO_APP` connection for the SQL editor.
3. Run the file as a SQL script.
4. Confirm these tables exist under the `TELCO_APP` schema:
   - `TARIFFS`
   - `CUSTOMERS`
   - `MONTHLY_STATS`

The table creation script drops and recreates the three project tables. Run it before CSV import, or only when intentionally resetting the schema.

## 4. Import the CSV files

Use DBeaver's table data import wizard. Import the files in this order so foreign key relationships are valid:

1. Import `TARIFFS.csv` into `TARIFFS`.
2. Import `CUSTOMERS.csv` into `CUSTOMERS`.
3. Import `MONTHLY_STATS.csv` into `MONTHLY_STATS`.

Recommended import settings:

| Setting | Value |
| --- | --- |
| File encoding | `UTF-8` |
| Delimiter | Comma |
| Header row | Enabled |
| Date format for `CUSTOMERS.SIGNUP_DATE` | `DD/MM/YYYY` |
| Decimal separator | Dot (`.`) |
| Empty string as NULL | Enabled |

On the mapping screen, keep each CSV column mapped to the matching database column. Do not rename, edit, or delete the original CSV files.

## 5. Verify the import

Run these checks in DBeaver after all imports complete.

```sql
SELECT COUNT(*) AS TARIFF_COUNT
FROM TARIFFS;

SELECT COUNT(*) AS CUSTOMER_COUNT
FROM CUSTOMERS;

SELECT COUNT(*) AS MONTHLY_STATS_COUNT
FROM MONTHLY_STATS;
```

Expected row counts:

| Table | Expected rows |
| --- | ---: |
| `TARIFFS` | 4 |
| `CUSTOMERS` | 10000 |
| `MONTHLY_STATS` | 9950 |

Verify the number of customers missing monthly usage records:

```sql
SELECT COUNT(*) AS MISSING_MONTHLY_RECORDS
FROM CUSTOMERS c
WHERE NOT EXISTS (
  SELECT 1
  FROM MONTHLY_STATS ms
  WHERE ms.CUSTOMER_ID = c.CUSTOMER_ID
);
```

Expected result:

| Check | Expected count |
| --- | ---: |
| Missing monthly records | 50 |

## 6. Run the solution queries

Open `sql/SOLUTIONS.sql` in DBeaver using the `TELCO_APP` connection. Run each numbered section separately so each result set is easy to review and capture.

If your submission needs pasted output, copy the matching DBeaver result grid values under the relevant result placeholder for that requirement. Otherwise, capture screenshots of each section's result and store them in `screenshots/`.

All queries in `sql/SOLUTIONS.sql` were tested successfully against the imported data.

