-- Lab8_setupTable
-- Version 1.0.1  27-April-2024
/*********************************************************************************
NOTE: You should not have to use this file at all - it is just here if you have 
downloaded this file individually.
*********************************************************************************/


/*********************************************************************************
Create Schema: production
*********************************************************************************/
DROP SCHEMA IF EXISTS production CASCADE;
CREATE SCHEMA production;

/*********************************************************************************
Create Table: production.workorder
*********************************************************************************/

DROP TABLE IF EXISTS production.workorder;
CREATE TABLE production.workorder
(
    workorderid integer NOT NULL,
    productid integer NOT NULL,
    orderqty integer NOT NULL,
    scrappedqty smallint NOT NULL,
    startdate timestamp without time zone NOT NULL,
    enddate timestamp without time zone,
    duedate timestamp without time zone NOT NULL,
    scrapreasonid smallint,
    modifieddate timestamp without time zone NOT NULL DEFAULT now()
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

/*********************************************************************************
You do need to insert the data from 

mslearn-postgresql/Allfiles/Labs/08/Lab8_workorder.csv

*********************************************************************************/

