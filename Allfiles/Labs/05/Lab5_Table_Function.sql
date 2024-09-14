-- Lab5_Table_Function
-- Version 1.0.1  16-May-2022


/*********************************************************************************
Check zoodb database is selected
*********************************************************************************/

SELECT current_database();


/*************************************************************************************************************************
Repopulate zoodb so we start with clean data
*********************************************************************************/

CALL repopulate_zoo();


/*****************************************
Create a table valued function
*********************************************************************************/

DROP FUNCTION IF EXISTS enclosure_summary;

CREATE FUNCTION enclosure_summary
(
    prm_enc_id int
)
RETURNS TABLE (category varchar(50), animal_count int, weight_kg decimal (8, 3))
LANGUAGE SQL
STABLE
CALLED ON NULL INPUT
AS $$
    SELECT C.category, COUNT(A.ani_id) AS "animal_count", SUM(A.weight_kg) AS "weight_kg"
        FROM animal AS A
            INNER JOIN category AS C
                ON A.cat_id = C.cat_id
        WHERE A.enc_id = prm_enc_id
        GROUP BY C.category
        ORDER BY C.category;
$$;



SELECT *
    FROM enclosure_summary(1);


SELECT *
    FROM enclosure_summary(4);



/*********************************************************************************
How to use a table valued function with a LATERAL join

    LATERAL joins are equivalent to CROSS APPLY or OUTER APPLY in Transact-SQL

*********************************************************************************/

SELECT E.enclosure, S.category, S.animal_count, s.weight_kg
    FROM enclosure AS E
        LEFT JOIN LATERAL enclosure_summary(E.enc_id) AS S ON true
    ORDER BY E.enclosure, S.category;
