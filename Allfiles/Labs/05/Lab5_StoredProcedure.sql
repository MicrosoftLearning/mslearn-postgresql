-- Lab5_StoredProcedure
-- Version 1.0.1  16-May-2022


/*********************************************************************************
Check zoodb database is selected
*********************************************************************************/

SELECT current_database();


/*********************************************************************************
Repopulate zoodb so we start with clean data
*********************************************************************************/

CALL repopulate_zoo();


/*********************************************************************************
Create stored procedure

    Caveat: This is simple demo code. In a production system you would
    need to validate the parameters more thorougly. Also, you would need
    to guard against the possibility of SQL injection attacks.
*********************************************************************************/

DROP PROCEDURE IF EXISTS new_exhibit;

CREATE PROCEDURE new_exhibit
(
	prm_enc_id int,
    prm_enclosure varchar(50),
    prm_number_of_animals int,
    prm_animal_name varchar(50),
	prm_weight_kg decimal (8, 3),
    prm_cat_id int
)
LANGUAGE plpgsql
AS $$
    BEGIN
        -- Check prm_number_of_animals is acceptable
        IF prm_number_of_animals < 0 OR prm_number_of_animals > 10 THEN
            RAISE EXCEPTION 'Invalid value for prm_number_of_animals.';
        END IF;

        -- Insert a new enclosure
        INSERT INTO enclosure (enc_id, enclosure)
            VALUES
                (prm_enc_id, prm_enclosure);

        -- Insert animals
        DECLARE
            i int := 1;
            id int;
            aname varchar(50);
            factor decimal(8,3);
            wt decimal(8, 3);
        BEGIN
            WHILE i <= prm_number_of_animals LOOP
                
                id := 50 + i;
                aname := FORMAT('%s #%s', prm_animal_name, i);
                factor = 0.75 + (0.5 * RANDOM());
                wt = ROUND(prm_weight_kg * factor, 2);

                INSERT INTO animal (ani_id, name, weight_kg, cat_id, enc_id)
                    VALUES
                        (id, aname, wt, prm_cat_id, prm_enc_id);
            
                i := i + 1;
            END LOOP;
        END;

        COMMIT;
    END
$$;



/*********************************************************************************
Call the stored procedure
*********************************************************************************/

CALL new_exhibit
    (
        prm_enc_id => 21,
        prm_enclosure => 'West Enclosure',
        prm_number_of_animals => 5,
        prm_animal_name => 'Lemur',
        prm_weight_kg => 5.0,
        prm_cat_id => 8
    );



SELECT *
    FROM enclosure;

SELECT *
    FROM animal
    WHERE enc_id = 21;

    
