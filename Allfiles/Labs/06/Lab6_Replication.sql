-- Lab6_Replication
-- Version 1.0.1  11-April-2024


/*********************************************************************************
Grant the admin user replication permission
    Do this for publisher and subscriber
*********************************************************************************/

ALTER ROLE "demo" WITH REPLICATION;


/*********************************************************************************
Create zoodb database
    Do this for publisher and subscriber
*********************************************************************************/

DROP DATABASE IF EXISTS zoodb;

CREATE DATABASE zoodb;

SELECT current_database();


/*********************************************************************************
Create tables and foreign key contraints in zoodb
    Do this for publisher and subscriber
*********************************************************************************/

CREATE TABLE category
(
	cat_id int PRIMARY KEY,
    category varchar(50) NOT NULL
);

CREATE TABLE enclosure
(
	enc_id int PRIMARY KEY,
    enclosure varchar(50) NOT NULL
);

CREATE TABLE animal
(
	ani_id int PRIMARY KEY,
    name varchar(50) NOT NULL,
	weight_kg decimal (8, 3) NOT NULL,
    cat_id int NOT NULL,
    enc_id int NOT NULL,
	CHECK (weight_kg >= 0 AND weight_kg <= 10000)
);

ALTER TABLE animal
	ADD	CONSTRAINT fk_animal_category FOREIGN KEY (cat_id)
		REFERENCES category (cat_id),
	ADD CONSTRAINT fk_animal_enclosure FOREIGN KEY (enc_id)
		REFERENCES enclosure (enc_id);


/*********************************************************************************
Populate the tables in zoodb
    Do this for publisher only
    Do NOT do this for subscriber
*********************************************************************************/

-- DELETE FROM category WHERE cat_id > 0;
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
    

-- DELETE FROM enclosure WHERE enc_id > 0;
INSERT INTO enclosure (enc_id, enclosure)
	VALUES
		(1, 'North Enclosure'),			-- camels, small mammals
        (2, 'South Enclosure'),			-- badgers
        (3, 'East Enclosure'),			-- big cats
        (4, 'Central'),					-- bats, monkeys
        (5, 'Aquarium'),				-- penguins
        (6, 'Insect house'),			-- insects
        (7, 'Reptile house');			-- reptiles
        

-- TRUNCATE TABLE animal;
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
    

/*********************************************************************************
Create a publication
    Do this for publisher only
    Do NOT do this for subscriber
*********************************************************************************/

DROP Publication IF EXISTS pub;

CREATE PUBLICATION pub FOR TABLE category, enclosure, animal;

SELECT *
    FROM pg_stat_replication;


/*********************************************************************************
Create a subscription
    Do this for subscriber only
    Do NOT do this for publisher

    Replace the following parts of the connection string:
        host=       the name of your publisher server, copy from Azure portal
        password=   the password for the admin user on your publisher server
*********************************************************************************/

DROP SUBSCRIPTION IF EXISTS sub;

CREATE SUBSCRIPTION sub CONNECTION 'host=postgresql-pub21.postgres.database.azure.com user=demo dbname=zoodb password=YOURSTRONGPASSWORD' PUBLICATION pub;

SELECT *
    FROM pg_stat_subscription;


/*********************************************************************************
Display the tables, which should be populated by replication
    Do this for subscriber only
    Do NOT do this for publisher
*********************************************************************************/

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


/*********************************************************************************
Insert more animals
    Do this for publisher only
    Do NOT do this for subscriber
*********************************************************************************/

INSERT INTO animal (ani_id, name, weight_kg, cat_id, enc_id)
	VALUES
		(31, 'Penguin #4', 13, 6, 5),        
		(32, 'Penguin #5', 11, 6, 5),        
		(33, 'Penguin #6', 12, 6, 5),
		(34, 'Gregory Goat', 119, 8, 1),        
		(35, 'Gogogo Goat', 108, 8, 1);


/*********************************************************************************
Display the animal tables, the new animals should be replicated
    Do this for subscriber only
    Do NOT do this for publisher
*********************************************************************************/

SELECT A.ani_id, A.name, A.weight_kg, C.category, E.enclosure
	FROM animal AS A
		INNER JOIN category AS C
			ON A.cat_id = C.cat_id
		INNER JOIN enclosure AS E
			ON A.enc_id = E.enc_id
	ORDER BY A.ani_id;

