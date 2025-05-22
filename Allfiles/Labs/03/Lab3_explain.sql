----------------------------------------------------------------------------
-- Lab3_Explain_1.SQL
-- 18-05-2022 Version 1.0.0
----------------------------------------------------------------------------

-- Reset the zoodb to the original records
-- CALL repopulate_zoo();


-- 1. Investigate EXPLAIN ANALYE
-- Run Statement A and Statement B separately and note the results


-- Statement A
EXPLAIN ANALYZE INSERT INTO Animal (ani_id, name, weight_kg, cat_id, enc_id) 
    VALUES (28, 'Robin Robin', 0.5, 1,2);

SELECT * FROM animal    

-- Statement B
BEGIN;
EXPLAIN ANALYZE INSERT INTO Animal (ani_id, name, weight_kg, cat_id, enc_id) 
    VALUES (29, 'Betty Boa', 0.9, 7, 7);
ROLLBACK;

SELECT * FROM category    

-- 2. Investigate EXPLAIN 

EXPLAIN SELECT A.ani_id, A.name, A.weight_kg, C.category, E.enclosure
	FROM animal AS A
		INNER JOIN category AS C
			ON A.cat_id = C.cat_id
		INNER JOIN enclosure AS E
			ON A.enc_id = E.enc_id
	ORDER BY A.ani_id;

-- 3. Investigate EXPLAIN options

EXPLAIN (ANALYZE, BUFFERS) SELECT A.ani_id, A.name, A.weight_kg, C.category, E.enclosure
	FROM animal AS A
		INNER JOIN category AS C
			ON A.cat_id = C.cat_id
		INNER JOIN enclosure AS E
			ON A.enc_id = E.enc_id
	ORDER BY A.ani_id;

EXPLAIN (ANALYZE, VERBOSE) SELECT A.ani_id, A.name, A.weight_kg, C.category, E.enclosure
	FROM animal AS A
		INNER JOIN category AS C
			ON A.cat_id = C.cat_id
		INNER JOIN enclosure AS E
			ON A.enc_id = E.enc_id
	ORDER BY A.ani_id;

EXPLAIN (Costs) SELECT A.ani_id, A.name, A.weight_kg, C.category, E.enclosure
	FROM animal AS A
		INNER JOIN category AS C
			ON A.cat_id = C.cat_id
		INNER JOIN enclosure AS E
			ON A.enc_id = E.enc_id
	ORDER BY A.ani_id;

   