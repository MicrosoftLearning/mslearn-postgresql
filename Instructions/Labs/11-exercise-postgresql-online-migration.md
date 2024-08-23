---
lab:
    title: 'Online PostgreSQL Database Migration'
    module: 'Migrate to Azure Database for PostgreSQL Flexible Server'
---

## Online PostgreSQL Database Migration

In this exercise you will configure logical replication between a source PostgreSQL Server and Azure Database for PostgreSQL Flexible Server to allow for an online migration activity to take place.

## Before you start

> [!IMPORTANT]
> You need your own Azure subscription to complete this exercise. If you don't have an Azure subscription, you can create an [Azure free trial](https://azure.microsoft.com/free).
>

> [!NOTE]
> This exercise will require that the server you use as a source for the migration is accessible to the Azure Database for PostgreSQL Flexible Server so that it can connect and migrate databases. This will require that the source server is accessible via a public IP address and port. > A list of Azure Region IP Addresses can be downloaded from [Azure IP Ranges and Service Tags – Public Cloud](https://www.microsoft.com/en-gb/download/details.aspx?id=56519) to help minimize the allowed ranges of IP Addresses in your firewall rules based on the Azure region used.

Open your server's firewall to allow the Migration feature within the Azure Database for PostgreSQL Flexible Server access to the source PostgreSQL Server, which by default is TCP port 5432.
>
When using a firewall appliance in front of your source database, you may need to add firewall rules to allow the Migration feature within the Azure Database for PostgreSQL Flexible Server to access the source database(s) for migration.
>
> The maximum supported version of PostgreSQL for migration is version 16.

### Prerequisites

[!NOTE]
> Before starting this exercise you will need to have completed the previous exercise to have the source and target databases in place to configure logical replication as this exercise builds on the activity in that one.

## Create Publication - Source Server

1. Open PGAdmin and connect to the source server which contains the database which is going to act as the source for the data synchronization to the Azure Database for PostgreSQL Flexible Server.
1. Open a new Query window connected to the source database with the data we want to synchronize.
1. Configure the source server wal_level to **logical** to allow for publication of data.
    1. Locate and open the **postgresql.conf** file in the bin directory within the PostgreSQL installation directory.
    1. Find the line with the configuration setting **wal_level**.
    1. Ensure that the line is un-commented and set the value to **logical**.
    1. Save and close the file.
    1. Restart the PostgreSQL Service.
1. Now configure a publication which will contain all of the tables within the database.

    ```SQL
    CREATE PUBLICATION migration1 FOR ALL TABLES;
    ```

## Create Subscription - Target Server

1. Open PGAdmin and connect to the Azure Database for PostgreSQL Flexible Server which contains the database which is going to act as the target for the data synchronization from the source server.
1. Open a new Query window connected to the source database with the data we want to synchronize.
1. Create the subscription to the source server.

    ```sql
    CREATE SUBSCRIPTION migration1
    CONNECTION 'host=<source server name> port=<server port> dbname=adventureworks application_name=migration1 user=<username> password=<password>'
    PUBLICATION migration1
    WITH(copy_data = false)
    ;    
    ```

1. Check the status of the table replication.

    ```SQL
    SELECT PT.schemaname, PT.tablename,
        CASE PS.srsubstate
            WHEN 'i' THEN 'initialize'
            WHEN 'd' THEN 'data is being copied'
            WHEN 'f' THEN 'finished table copy'
            WHEN 's' THEN 'synchronized'
            WHEN 'r' THEN ' ready (normal replication)'
            ELSE 'unknown'
        END AS replicationState
    FROM pg_publication_tables PT,
            pg_subscription_rel PS
            JOIN pg_class C ON (C.oid = PS.srrelid)
            JOIN pg_namespace N ON (N.oid = C.relnamespace)
    ;
    ```

## Test Data Replication

1. On the Source Server check the row count of the workorder table.

    ```SQL
    SELECT COUNT(*) FROM production.workorder;
    ```

1. On the Target Server check the row count of the workorder table.

    ```SQL
    SELECT COUNT(*) FROM production.workorder;
    ```

1. Check that the row count values match.
1. Now download the Lab11_workorder.csv file from the repository [here](https://github.com/MicrosoftLearning/mslearn-postgresql/tree/main/Allfiles/Labs/11) to C:\
1. Load new data into the workorder table on the source server from the CSV using the following command.

    ```Bash
    psql --host=localhost --port=5432 --username=postgres --dbname=adventureworks --command="\COPY production.workorder FROM 'C:\Lab11_workorder.csv' CSV HEADER"
    ```

The command output should be `COPY 490`, indicating that 490 additional rows were written into the table from the CSV file.

1. Check the row counts for the workorder table in the source (72591 rows) and destination match to verify that the data replication is working.

## Exercise Clean-up

The Azure Database for PostgreSQL we deployed in this exercise will incur charges you can delete the server after this exercise. Alternatively, you can delete the **rg-learn-work-with-postgresql-eastus** resource group to remove all resources that we deployed as part of this exercise.
