-- SimpleFunctions

-- String functions
SELECT SUBSTRING('The quick brown fox', 5, 11);

SELECT LEFT('The quick brown fox', 9);

SELECT UPPER ('The quick brown fox');


-- Math functions
SELECT FLOOR(3.72);

SELECT CEILING(3.72);

SELECT SQRT(9);

SELECT ABS(-4.2);


-- Date/time functions
SELECT CURRENT_DATE;

SELECT CURRENT_TIME;

SELECT DATE_PART('year', TIMESTAMP '2022-05-14');

SELECT NOW();

SELECT DATE_PART('minute', NOW());


-- Conditional
SELECT COALESCE(NULL, NULL, 'Apples', 'Bananas', 'Cantaloupe');

SELECT NULLIF('A', 'B');

SELECT NULLIF('A', 'A');


