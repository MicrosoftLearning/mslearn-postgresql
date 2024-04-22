write summary text here

-- Create Schema: production
DROP SCHEMA IF EXISTS production CASCADE;
CREATE SCHEMA production;

-- Create Table: production.workorder

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

ALTER TABLE production.workorder
    OWNER to pgAdmin;


--Insert data here