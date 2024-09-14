-- RepopulateZoo
-- Version 1.0.0  15-May-2022


/*********************************************************************************
Check zoodb database is selected
*********************************************************************************/

SELECT current_database();


/*********************************************************************************
Create stored procedure
*********************************************************************************/

DROP PROCEDURE IF EXISTS repopulate_zoo;

CREATE OR REPLACE PROCEDURE repopulate_zoo ()
LANGUAGE plpgsql
AS $$
    BEGIN
        -- Clear the tables
        TRUNCATE animal;

        DELETE FROM category WHERE cat_id > 0;

        DELETE FROM enclosure WHERE enc_id > 0;


        -- Insert data
        INSERT INTO category (cat_id, category)
            VALUES
                (1, 'Badgers'),
                (2, 'Bats'),
                (3, 'Big cats'),
                (4, 'Camels'),
                (5, 'Insects'),
                (6, 'Penguins'),
                (7, 'Reptiles'),
                (8, 'Small mammals');
            

        INSERT INTO enclosure (enc_id, enclosure)
            VALUES
                (1, 'North Enclosure'),			-- camels, small mammals
                (2, 'South Enclosure'),			-- badgers
                (3, 'East Enclosure'),			-- big cats
                (4, 'Central'),					-- bats, monkeys
                (5, 'Aquarium'),				-- penguins
                (6, 'Insect house'),			-- insects
                (7, 'Reptile house');			-- reptiles
                

        INSERT INTO animal (ani_id, name, weight_kg, cat_id, enc_id)
            VALUES
                (1, 'Bart Badger', 16.2, 1, 2),
                (2, 'Barley Badger', 14.5, 1, 2),
                (3, 'Vampire #1', 0.033, 2, 4),        
                (4, 'Vampire #2', 0.033, 2, 4),        
                (5, 'Flying fox', 0.970, 2, 4),
                (6, 'Leo Lion', 190, 3, 3),        
                (7, 'Leonie Lion', 130, 3, 3),        
                (8, 'Dromedary #1', 580, 4, 1),        
                (9, 'Dromedary #2', 470, 4, 1),        
                (10, 'Dromedary #3', 530, 4, 1),        
                (11, 'Ants', 0.60, 5, 6),        
                (12, 'Tarantula', 0.085, 5, 6),        
                (13, 'Emperor moth', 0.002, 5, 6),        
                (14, 'Penguin #1', 12, 6, 5),        
                (15, 'Penguin #2', 14, 6, 5),        
                (16, 'Penguin #3', 10, 6, 5),
                (17, 'Anaconda', 250, 7, 7),
                (18, 'Monitor lizard #1', 91, 7, 7),        
                (19, 'Monitor lizard #2', 86, 7, 7),        
                (20, 'Chameleon', 0.170, 7, 7),
                (21, 'Monkey #1', 27, 8, 4),        
                (22, 'Monkey #2', 35, 8, 4),        
                (23, 'Rabbit #1', 1.9, 8, 1),        
                (24, 'Rabbit #2', 2.1, 8, 1),        
                (25, 'Rabbit #3', 2.3, 8, 1),        
                (26, 'Griselda Goat', 105, 8, 1),        
                (27, 'George Goat', 120, 8, 1);
    END
$$;


/*********************************************************************************
Test the stored procedure
*********************************************************************************/

CALL repopulate_zoo();

SELECT *
	FROM category
    ORDER BY cat_id;
    
SELECT *
	FROM enclosure
    ORDER BY enc_id;
    
SELECT A.ani_id, A.name, A.weight_kg, C.category, E.enclosure
	FROM animal AS A
		INNER JOIN category AS C
			ON A.cat_id = C.cat_id
		INNER JOIN enclosure AS E
			ON A.enc_id = E.enc_id
	ORDER BY A.ani_id;
    
    
